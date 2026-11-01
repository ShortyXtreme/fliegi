class_name DamageModel
extends RefCounted
## Schadensmodell eines Flugzeugs (Pakete 4 und 6, Agent B).
## Vom Flugzeug an festen Stellen aufgerufen (aircraft.gd, jeden Physik-Tick):
##   filter_intent(intent, dt)  -> verwundeter/toter/ausgestiegener Pilot
##   tick(dt)                   -> Brand, Lecks, Treibstoff, Festfress-Timer; schreibt modifiers
##   can_eject()                -> Notausstieg erlaubt? (beim Drücken von "eject")
##   on_impact(body, velocity)  -> Bodenberührung/Kollision (Bauchlandung vs. Absturz)
##   reset()                    -> Aircraft.place() (Neustart/Respawn)
## Treffer kommen über apply_hit() (ProjectileSystem/HitValidator, nur Server).
## Zustandsänderungen nur wenn Authority.is_server(); Zustand kompakt über to_array().
##
## Wirkungen (Werte im DamageProfile, Plan §3):
##   engine  < 70 %: Leistung ×0,85, Ölspur, Festfressen nach 90 s; < 30 %: ×0,5, Brandrisiko; 0: Stillstand
##   tanks   Leck proportional zum Schaden (FuelSystem), Brandrisiko je Treffer
##   wings   Auftrieb sinkt, < 50 % Querruder aus, 0 = Flügelbruch = Abschuss
##   tail    Höhen-/Seitenruder schwächer, Chance auf klemmendes Ruder
##   cockpit < 60 % verwundet (Eingabe gedämpft + verrauscht), 0 = Pilot tot = Abschuss
## Brand: fire_dps auf die Zone, nach fire_spread_time Tank -> Flügel, Sturzflug löscht.

enum Zone { ENGINE, FUEL_L, FUEL_R, WING_L, WING_R, TAIL, COCKPIT, COUNT }
const ZONE_NAMES := ["engine", "fuel_tank_L", "fuel_tank_R", "wing_L", "wing_R", "tail", "cockpit"]

## Stub-Startwerte (Plan §3); das echte Profil kommt aus damage_profile_t1.tres.
const DEFAULT_HP := [120.0, 80.0, 80.0, 200.0, 200.0, 120.0, 100.0]

enum PilotState { OK, WOUNDED, DEAD, EJECTED }
## Wie der Flug geendet hat (für SpawnManager/XP).
enum Outcome { FLYING, BELLY_LANDED, CRASHED }

signal zone_changed(zone: int, hp_fraction: float)
signal destroyed(cause: int, killer: Node)
## Pilot ist ausgestiegen (Fallschirm-Knoten oder null).
signal ejected(parachute: Node)
## Flug zu Ende am Boden (Bauchlandung oder Absturz), auch ohne Abschuss.
signal grounded(outcome: int)
## reset() wurde aufgerufen (Neustart, auch über Debugtaste R).
signal was_reset()

var aircraft: Node3D
var modifiers: FlightModifiers
var hitboxes: HitboxSet
var profile: DamageProfile
var fuel := FuelSystem.new()
var hp: PackedFloat32Array = []
var hp_max: PackedFloat32Array = []
var is_destroyed := false
var destroy_cause: int = CombatEvents.Cause.UNKNOWN
var killer: Node = null
var last_attacker: Node = null
## Simulationszeit (s) des letzten Treffers, -1 = nie. Zeitbasis: elapsed.
var last_hit_time := -1.0
## Simulationszeit seit reset() (Summe der dt aus tick()).
var elapsed := 0.0
var pilot_state: int = PilotState.OK
var outcome: int = Outcome.FLYING
## Brennzeit je Zone (s), -1 = kein Brand.
var fire_time: PackedFloat32Array = []
## Festfress-Timer Motor (s bis Stillstand), -1 = inaktiv.
var seize_timer := -1.0
var engine_dead := false
## Mitwirkende: Angreifer -> letzte Trefferzeit (Beteiligung).
var contributors := {}
## Deterministischer Zufall (Brand, klemmendes Ruder, Zittern). Seed aus entity_id.
var rng := RandomNumberGenerator.new()
## Letzter Fallschirm (characters/parachute.gd) oder null.
var parachute: Node = null

var _wound_noise := Vector3.ZERO
var _fire_acc: PackedFloat32Array = []
var _surf_wing := {Zone.WING_L: [], Zone.WING_R: []}   # [index, ist_aussen, ist_querruder]
var _surf_tail: Array[int] = []
var _resets := 0


func _init(a: Node3D, mods: FlightModifiers) -> void:
	aircraft = a
	modifiers = mods
	var d: Resource = a.get("data")
	profile = DamageProfile.load_for(d)
	hp_max = profile.hp.duplicate() if profile.hp.size() == Zone.COUNT else PackedFloat32Array(DEFAULT_HP)
	hitboxes = HitboxSet.from_aircraft_data(d)
	fuel.setup(profile.tank_capacity_l, profile.burn_full_lps, profile.burn_idle_lps)
	fire_time.resize(Zone.COUNT)
	_fire_acc.resize(Zone.COUNT)
	_index_surfaces(d)
	if a.has_signal("eject_requested"):
		a.eject_requested.connect(_on_eject_requested)
	reset()


func _index_surfaces(d: Resource) -> void:
	var surfaces = d.get("surfaces") if d != null else null
	if not (surfaces is Array):
		return
	for i in surfaces.size():
		var s = surfaces[i]
		var nm: String = s.name
		if nm.begins_with("wing"):
			var z := Zone.WING_L if s.position.x < 0.0 else Zone.WING_R
			var outer := not nm.ends_with("root")
			var aileron: bool = s.control_axis == AeroSurfaceDef.ControlAxis.ROLL
			_surf_wing[z].append([i, outer, aileron])
		elif nm.contains("tail"):
			_surf_tail.append(i)


func reset() -> void:
	hp = hp_max.duplicate()
	is_destroyed = false
	destroy_cause = CombatEvents.Cause.UNKNOWN
	killer = null
	last_attacker = null
	last_hit_time = -1.0
	elapsed = 0.0
	pilot_state = PilotState.OK
	outcome = Outcome.FLYING
	fire_time.fill(-1.0)
	_fire_acc.fill(0.0)
	seize_timer = -1.0
	engine_dead = false
	contributors.clear()
	_wound_noise = Vector3.ZERO
	parachute = null
	var eid = aircraft.get("entity_id")
	rng.seed = hash([eid if eid is int else 0, _resets])
	_resets += 1
	fuel.refill()
	modifiers.reset()
	was_reset.emit()


# --- Treffer ------------------------------------------------------------------

## Treffer anwenden (nur Server). local_point im Flugzeug-Koordinatensystem.
func apply_hit(zone: int, damage: float, attacker: Node, _local_point := Vector3.ZERO) -> void:
	if not Authority.is_server() or zone < 0 or zone >= Zone.COUNT or damage <= 0.0:
		return
	if outcome != Outcome.FLYING and is_destroyed:
		return
	if _is_friendly(attacker) and not MatchRules.friendly_fire_damage:
		return
	if attacker != null and attacker != aircraft:
		last_attacker = attacker
		last_hit_time = elapsed
		contributors[attacker] = elapsed
	var before := hp[zone]
	_damage_zone(zone, damage)
	CombatEvents.bus().aircraft_damaged.emit(aircraft, zone, before - hp[zone], attacker)
	_on_hit_effects(zone)
	_apply_modifiers()
	_check_destroyed()


func _damage_zone(zone: int, damage: float) -> void:
	var before := hp[zone]
	hp[zone] = maxf(hp[zone] - damage, 0.0)
	if hp[zone] != before:
		zone_changed.emit(zone, hp_fraction(zone))


## Zufallswirkungen eines Treffers (Brand, klemmendes Ruder, Festfress-Timer).
func _on_hit_effects(zone: int) -> void:
	var f := hp_fraction(zone)
	match zone:
		Zone.ENGINE:
			if f < profile.engine_light_below and seize_timer < 0.0 and not engine_dead:
				seize_timer = profile.engine_seize_time
			if f < profile.engine_heavy_below and f > 0.0 and rng.randf() < profile.engine_fire_chance:
				start_fire(Zone.ENGINE)
		Zone.FUEL_L, Zone.FUEL_R:
			if rng.randf() < profile.tank_fire_chance:
				start_fire(zone)
		Zone.TAIL:
			if not _surf_tail.is_empty() and rng.randf() < profile.tail_stuck_chance * (1.0 - f):
				var i: int = _surf_tail[rng.randi_range(0, _surf_tail.size() - 1)]
				if modifiers.stuck.size() > i and modifiers.stuck[i] == 0:
					modifiers.set_stuck(i, rng.randf_range(-0.4, 0.4))


func hp_fraction(zone: int) -> float:
	return hp[zone] / maxf(hp_max[zone], 1e-3)


func is_burning(zone := -1) -> bool:
	if zone >= 0:
		return fire_time[zone] >= 0.0
	for z in Zone.COUNT:
		if fire_time[z] >= 0.0:
			return true
	return false


## Brand in einer Zone auslösen (nur Server).
func start_fire(zone: int) -> void:
	if Authority.is_server() and fire_time[zone] < 0.0 and hp[zone] > 0.0:
		fire_time[zone] = 0.0


func extinguish(zone := -1) -> void:
	for z in Zone.COUNT:
		if zone < 0 or z == zone:
			fire_time[z] = -1.0


func oil_leaking() -> bool:
	return hp_fraction(Zone.ENGINE) < profile.engine_light_below


func is_wing_broken(zone: int) -> bool:
	return (zone == Zone.WING_L or zone == Zone.WING_R) and hp[zone] <= 0.0


func is_engine_failed() -> bool:
	return modifiers.engine_failed


# --- Tick ---------------------------------------------------------------------

func tick(dt: float) -> void:
	if not Authority.is_server():
		return
	elapsed += dt
	var t = _telemetry()
	# Treibstoff und Lecks
	for k in 2:
		var z := Zone.FUEL_L + k
		fuel.leak_lps[k] = profile.leak_max_lps * (1.0 - hp_fraction(z))
	var thr: float = t.throttle_actual if t != null else 0.0
	fuel.tick(dt, thr, not modifiers.engine_failed)
	# Festfressen
	if seize_timer >= 0.0:
		seize_timer -= dt
		if seize_timer <= 0.0:
			seize_timer = -1.0
			engine_dead = true
	# Brand
	if is_burning():
		_tick_fire(dt, t)
	_wound_noise = _wound_noise * 0.95 + Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * 0.05
	_apply_modifiers()
	_check_destroyed()
	# Bauchlandung ohne Kollisionsereignis (Kufenpunkte sind Strahlen, keine Körper)
	if outcome == Outcome.FLYING and t != null and t.belly_contact and t.gear_extension < 0.5:
		_evaluate_ground_contact((aircraft as RigidBody3D).linear_velocity if aircraft is RigidBody3D else Vector3.ZERO)


func _tick_fire(dt: float, t) -> void:
	var speed_kmh: float = t.airspeed * 3.6 if t != null else 0.0
	var p_out := 0.0
	if speed_kmh > profile.fire_extinguish_speed_kmh:
		p_out = 1.0 - pow(1.0 - profile.fire_extinguish_rate, dt)
	for z in Zone.COUNT:
		if fire_time[z] < 0.0:
			continue
		if p_out > 0.0 and rng.randf() < p_out:
			fire_time[z] = -1.0
			continue
		fire_time[z] += dt
		var dmg := profile.fire_dps * dt
		_damage_zone(z, dmg)
		_fire_acc[z] += dmg
		if _fire_acc[z] >= profile.fire_dps:   # gebündelt ~1×/s ins Ereignis-Log
			CombatEvents.bus().aircraft_damaged.emit(aircraft, z, _fire_acc[z], null)
			_fire_acc[z] = 0.0
		if fire_time[z] >= profile.fire_spread_time:
			if z == Zone.FUEL_L:
				start_fire(Zone.WING_L)
			elif z == Zone.FUEL_R:
				start_fire(Zone.WING_R)
		if hp[z] <= 0.0 and z != Zone.WING_L and z != Zone.WING_R:
			# Zone ausgebrannt; Tank: Treibstoff verloren
			if z == Zone.FUEL_L or z == Zone.FUEL_R:
				fuel.liters[z - Zone.FUEL_L] = 0.0
			fire_time[z] = -1.0


## Wirkung aller Zonen auf die FlightModifiers (vollständig neu berechnet, nur geklemmte
## Ruder bleiben erhalten). Intakt = exakt neutral.
func _apply_modifiers() -> void:
	var n := modifiers.lift.size()
	if n == 0:
		return
	for i in n:
		modifiers.lift[i] = 1.0
		modifiers.drag[i] = 0.0
		modifiers.control[i] = 1.0
	for z in [Zone.WING_L, Zone.WING_R]:
		var f := hp_fraction(z)
		if f >= 1.0:
			continue
		for e in _surf_wing[z]:
			var i: int = e[0]
			if i >= n:
				continue
			if hp[z] <= 0.0:
				modifiers.lift[i] = profile.broken_outer_lift if e[1] else profile.broken_root_lift
				modifiers.drag[i] = profile.wing_drag_max * 2.0
			else:
				modifiers.lift[i] = 1.0 - profile.wing_lift_loss * (1.0 - f)
				modifiers.drag[i] = profile.wing_drag_max * (1.0 - f)
			if e[2] and f < profile.aileron_off_below:
				modifiers.control[i] = 0.0
	var ft := hp_fraction(Zone.TAIL)
	if ft < 1.0:
		for i in _surf_tail:
			if i < n:
				modifiers.control[i] = lerpf(profile.tail_control_min, 1.0, ft)
	# Motor
	var fe := hp_fraction(Zone.ENGINE)
	var pm := 1.0
	if fe < profile.engine_heavy_below:
		pm = profile.engine_heavy_power
	elif fe < profile.engine_light_below:
		pm = profile.engine_light_power
	modifiers.engine_power_mul = pm
	modifiers.engine_failed = engine_dead or hp[Zone.ENGINE] <= 0.0 or fuel.is_empty() \
		or outcome == Outcome.CRASHED
	# Einschusslöcher
	var holes := 0.0
	for z in Zone.COUNT:
		holes += 1.0 - hp_fraction(z)
	modifiers.extra_drag_area = profile.hole_drag_area * holes if holes > 0.0 else 0.0
	# Pilot
	if pilot_state == PilotState.OK and hp_fraction(Zone.COCKPIT) < profile.wounded_below and hp[Zone.COCKPIT] > 0.0:
		pilot_state = PilotState.WOUNDED


func _check_destroyed() -> void:
	if is_destroyed:
		return
	if hp[Zone.WING_L] <= 0.0 or hp[Zone.WING_R] <= 0.0:
		_destroy(CombatEvents.Cause.WING_BROKEN)
	elif hp[Zone.COCKPIT] <= 0.0 and pilot_state != PilotState.EJECTED:
		pilot_state = PilotState.DEAD
		_set_pilot_alive(false)
		_destroy(CombatEvents.Cause.PILOT_KILLED)


## Abschuss melden (nur einmal je Flug). Kredit: letzter Schütze im Zeitfenster.
func _destroy(cause: int) -> void:
	if is_destroyed or not Authority.is_server():
		return
	is_destroyed = true
	killer = credited_attacker()
	if killer != null and _is_friendly(killer):
		cause = CombatEvents.Cause.FRIENDLY
	destroy_cause = cause
	destroyed.emit(cause, killer)
	CombatEvents.bus().aircraft_destroyed.emit(aircraft, killer, cause)


## Letzter Schütze, wenn sein Treffer höchstens MatchRules.kill_credit_window zurückliegt.
func credited_attacker() -> Node:
	if last_attacker == null or not is_instance_valid(last_attacker) or last_hit_time < 0.0:
		return null
	if elapsed - last_hit_time > MatchRules.kill_credit_window:
		return null
	return last_attacker


## Mitwirkende im Kreditfenster ohne den Abschießenden (Beteiligung).
func assists() -> Array:
	var out := []
	for a in contributors:
		if is_instance_valid(a) and a != killer and elapsed - float(contributors[a]) <= MatchRules.kill_credit_window:
			out.append(a)
	return out


# --- Pilot --------------------------------------------------------------------

func filter_intent(intent: PilotIntent, _dt: float) -> void:
	match pilot_state:
		PilotState.OK:
			return
		PilotState.WOUNDED:
			var k := profile.wound_input_mul
			var nz := profile.wound_noise
			intent.pitch = clampf(intent.pitch * k + _wound_noise.x * nz * 4.0, -1.0, 1.0)
			intent.roll = clampf(intent.roll * k + _wound_noise.y * nz * 4.0, -1.0, 1.0)
			intent.yaw = clampf(intent.yaw * k + _wound_noise.z * nz * 4.0, -1.0, 1.0)
		_:
			# Kein Pilot mehr am Steuer: Ruder lose, Waffen aus, Gas bleibt stehen.
			var thr := intent.throttle
			var t = _telemetry()
			if t != null:
				thr = t.throttle_actual
			intent.pitch = 0.0
			intent.roll = 0.0
			intent.yaw = 0.0
			intent.throttle = thr
			intent.fire_primary = false
			intent.fire_secondary = false
			intent.eject = false


## Notausstieg nur bei schwerem Schaden oder Feuer (GDD §6.3): Motorausfall, Brand,
## Leitwerk/Tragwerk kritisch, klemmendes Ruder, Pilot verwundet, oder bereits abgeschossen.
func can_eject() -> bool:
	if pilot_state == PilotState.DEAD or pilot_state == PilotState.EJECTED or outcome != Outcome.FLYING:
		return false
	if is_destroyed or pilot_state == PilotState.WOUNDED or is_burning():
		return true
	if modifiers.engine_failed or hp_fraction(Zone.ENGINE) < profile.engine_heavy_below:
		return true
	if hp_fraction(Zone.TAIL) < profile.tail_critical_below:
		return true
	if hp_fraction(Zone.WING_L) < profile.aileron_off_below or hp_fraction(Zone.WING_R) < profile.aileron_off_below:
		return true
	for s in modifiers.stuck:
		if s != 0:
			return true
	return false


## Pilot verwundet. HUD-Vignette, Spotting.
func pilot_wounded() -> bool:
	return pilot_state == PilotState.WOUNDED


func pilot_aboard() -> bool:
	return pilot_state == PilotState.OK or pilot_state == PilotState.WOUNDED


func _on_eject_requested(_a: Node, allowed: bool) -> void:
	if allowed:
		eject()


## Notausstieg ausführen (nur Server, nur wenn can_eject()). Abschuss mit Ursache EJECTED,
## falls das Flugzeug noch nicht abgeschossen war; der Kredit geht an den letzten Schützen.
func eject(force := false) -> bool:
	if not Authority.is_server() or (not force and not can_eject()) or not pilot_aboard():
		return false
	pilot_state = PilotState.EJECTED
	var rec: PilotRecord = aircraft.get("pilot")
	var t = _telemetry()
	var agl: float = t.height_agl if t != null else 1000.0
	if rec != null:
		rec.on_ejected()
	parachute = Parachute.spawn_from(aircraft, rec, agl >= profile.eject_min_agl)
	ejected.emit(parachute)
	CombatEvents.bus().pilot_ejected.emit(aircraft, rec)
	_destroy(CombatEvents.Cause.EJECTED)
	return true


func _set_pilot_alive(v: bool) -> void:
	var rec: PilotRecord = aircraft.get("pilot")
	if rec != null and not v:
		rec.on_killed()


# --- Bodenberührung -------------------------------------------------------------

func on_impact(body: Node, velocity: Vector3) -> void:
	if not Authority.is_server() or outcome != Outcome.FLYING:
		return
	if body != null and body.get("damage") is DamageModel:
		# Zusammenstoß in der Luft
		var other_v: Vector3 = body.linear_velocity if body is RigidBody3D else Vector3.ZERO
		if (velocity - other_v).length() > 15.0:
			hp[Zone.WING_L if rng.randf() < 0.5 else Zone.WING_R] = 0.0
			_apply_modifiers()
			_check_destroyed()
		return
	_evaluate_ground_contact(velocity)


## Bauchlandung (langsam, flach, geringe Querlage) -> Pilot überlebt; sonst Absturz.
func _evaluate_ground_contact(velocity: Vector3) -> void:
	var speed := velocity.length()
	if speed < profile.impact_ignore_speed and not is_destroyed:
		return
	var bank := 0.0
	if aircraft is Node3D:
		var up := aircraft.global_transform.basis.y
		bank = rad_to_deg(acos(clampf(up.dot(Vector3.UP), -1.0, 1.0)))
	var gentle := speed < profile.belly_max_speed and -velocity.y < profile.belly_max_sink \
		and bank < profile.belly_max_bank_deg and hp[Zone.WING_L] > 0.0 and hp[Zone.WING_R] > 0.0
	if gentle:
		outcome = Outcome.BELLY_LANDED
		# Bodenberührung kurz nach einem Treffer zählt als Abschuss (Pilot lebt).
		if credited_attacker() != null:
			_destroy(CombatEvents.Cause.CRASH)
	else:
		outcome = Outcome.CRASHED
		if pilot_aboard():
			pilot_state = PilotState.DEAD
			_set_pilot_alive(false)
		_destroy(CombatEvents.Cause.CRASH)
		extinguish()
	_apply_modifiers()
	grounded.emit(outcome)


# --- Hilfen -------------------------------------------------------------------

func _telemetry():
	var f = aircraft.get("flight")
	return f.telemetry if f != null else null


func _is_friendly(attacker: Node) -> bool:
	if attacker == null or attacker == aircraft or not is_instance_valid(attacker):
		return false
	var n = attacker.get("nation_id")
	var own = aircraft.get("nation_id")
	return n is int and own is int and Nations.is_friendly(own, n)


## Kompakter Zustand: HP[7], zerstört, Brand-Bits, Pilotzustand, Ausgang, Treibstoff L/R, Motor tot.
func to_array() -> PackedFloat32Array:
	var a := hp.duplicate()
	a.append(1.0 if is_destroyed else 0.0)
	var bits := 0
	for z in Zone.COUNT:
		if fire_time[z] >= 0.0:
			bits |= 1 << z
	a.append(float(bits))
	a.append(float(pilot_state))
	a.append(float(outcome))
	a.append_array(fuel.to_array())
	a.append(1.0 if engine_dead else 0.0)
	return a


func from_array(a: PackedFloat32Array) -> void:
	for i in mini(a.size(), Zone.COUNT):
		hp[i] = a[i]
	if a.size() > Zone.COUNT:
		is_destroyed = a[Zone.COUNT] > 0.5
	if a.size() >= Zone.COUNT + 7:
		var bits := int(a[Zone.COUNT + 1])
		for z in Zone.COUNT:
			var on := bits & (1 << z) != 0
			if on and fire_time[z] < 0.0:
				fire_time[z] = 0.0
			elif not on:
				fire_time[z] = -1.0
		pilot_state = int(a[Zone.COUNT + 2])
		outcome = int(a[Zone.COUNT + 3])
		fuel.from_array(a.slice(Zone.COUNT + 4, Zone.COUNT + 6))
		engine_dead = a[Zone.COUNT + 6] > 0.5
	_apply_modifiers()
