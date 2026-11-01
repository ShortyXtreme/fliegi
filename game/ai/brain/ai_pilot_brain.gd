class_name AIPilotBrain
extends Controller
## Kampf-KI (Paket 7). Liefert ausschließlich PilotIntents, lenkt über
## Autopilot.steer_to_direction, nimmt Ziele über AIPerception (Nations.is_hostile,
## Spotting.spot_range, Sichtkegel, Reaktionsverzögerung) wahr und zielt mit LeadSolver.
## Schwierigkeit als AIDifficulty-Ressource (ai/data/rekrut|erfahren|veteran.tres).
##
## Zustände (Vorrang von oben): BODENSCHUTZ > RÜCKZUG > AUSWEICHEN > ENERGIE >
## FEUERN/VERFOLGEN (Lead/Pure/Lag) > ANFLUG (Höhenvorteil) > PATROUILLE.
## Deterministisch bei gleichem rng_seed (eigener Zufallsgenerator, Tick-Zählung).

enum State { PATROL, APPROACH, PURSUIT, FIRE, EVADE, ENERGY, RETREAT, GROUND_AVOID }
const STATE_NAMES := ["Patrouille", "Anflug", "Verfolgen", "Feuern", "Ausweichen",
		"Energie", "Rückzug", "Bodenschutz"]
enum Pursuit { LEAD, PURE, LAG }

## Ab dieser Entfernung zum Ziel: Verfolgen statt Anflug (m).
const ENGAGE_RANGE := 1500.0
## Energie-Zustand unter / bis über dieser Fahrt (m/s): 220 bzw. 270 km/h.
const ENERGY_LOW := 220.0 / 3.6
const ENERGY_OK := 270.0 / 3.6
## Ausweichen: Feind am Heck näher als (m), Heckwinkel ab (Grad), Feindnase auf uns (Grad).
const EVADE_RANGE := 600.0
const EVADE_REAR_DEG := 110.0
const EVADE_AIM_DEG := 20.0
const EVADE_MIN_TIME := 2.0
## Rückzug: Munition unter Anteil, Zustand (min. Zonen-HP-Anteil) unter.
const RETREAT_AMMO := 0.1
const RETREAT_HP := 0.35
## Bodenschutz-Vorausschau (s).
const LOOKAHEAD := [1.0, 2.0, 4.0]
## Kollisionsvermeidung: Mindestabstand im nächsten Punkt (m) und Zeithorizont (s).
const COLLISION_MISS := 60.0
const COLLISION_TIME := 2.5

var difficulty: Resource = null
var rng_seed := 0
## Patrouille: Mittelpunkt (Standard Position bei Übernahme), Höhe, Radius.
var patrol_center := Vector3.INF
var patrol_altitude := 1500.0
var patrol_radius := 1500.0
## Rückzugsziel (Standard: Patrouillenmittelpunkt).
var home := Vector3.INF

var state: int = State.PATROL
var pursuit_mode: int = Pursuit.PURE
var state_time := 0.0
var perception: AIPerception
var target: AIPerception.Contact = null
## Diagnose/Tests: Vorhaltfehler (Grad) des letzten Ticks, -1 = kein Ziel.
var aim_error_deg := -1.0
var in_fire_window := false
## Zustandswechsel als "tick:state" (für Log-Hash in Tests), nur wenn trace_enabled.
var trace_enabled := false
var trace: PackedStringArray = []

var _intent := PilotIntent.new()
var _rng := RandomNumberGenerator.new()
var _ticks := 0
var _diff: AIDifficulty
var _burst_left := 0.0
var _pause_left := 0.0
var _noise := Vector2.ZERO
var _noise_goal := Vector2.ZERO
var _noise_timer := 0.0
var _maneuver := AIDifficulty.Maneuver.BREAK
var _evade_side := 1.0
var _scissor_timer := 0.0
var _ground_clear_time := 0.0
var _started := false


func on_possess(s: Seat) -> void:
	super.on_possess(s)
	_started = false


func _start(a: Aircraft) -> void:
	_started = true
	_diff = difficulty as AIDifficulty
	if _diff == null:
		_diff = AIDifficulty.load_level("erfahren")
		difficulty = _diff
	_rng.seed = hash(rng_seed) ^ 0x5eed
	perception = AIPerception.new(a, _diff.reaction_time)
	if patrol_center == Vector3.INF:
		patrol_center = a.global_position
	if home == Vector3.INF:
		home = patrol_center
	_intent.gear_down = false
	_intent.flaps = 0.0
	_intent.brakes = 0.0


func state_name() -> String:
	return STATE_NAMES[state]


func compute_intent(dt: float) -> PilotIntent:
	var a := get_vehicle() as Aircraft
	var i := _intent
	i.fire_primary = false
	i.fire_secondary = false
	if a == null:
		return i
	if not _started:
		_start(a)
	_ticks += 1
	i.assist_mode = FlightAssist.Mode.ARCADE \
			if FlightAssist.Mode.ARCADE in a.allowed_assist_modes else a.assist_mode
	perception.update(dt)
	target = perception.best_target()
	_update_noise(dt)
	_set_state(_decide(a, dt), dt)

	var b := a.global_transform.basis
	var dir := Vector3.ZERO
	var g_scale := _diff.g_use
	i.throttle = 1.0
	aim_error_deg = -1.0
	in_fire_window = false
	match state:
		State.GROUND_AVOID:
			return _ground_recovery(a, i)
		State.RETREAT:
			dir = _retreat_dir(a)
		State.EVADE:
			dir = _evade_dir(a, dt)
			i.throttle = 0.6 if _maneuver == AIDifficulty.Maneuver.SCISSORS else 1.0
		State.ENERGY:
			dir = _flat(-b.z)
			if a.telemetry().height_agl > 600.0:
				dir += Vector3.DOWN * 0.15
		State.APPROACH:
			dir = _approach_dir(a)
		State.PURSUIT, State.FIRE:
			dir = _pursuit_dir(a, i, dt)
			g_scale = maxf(g_scale, 0.9) if state == State.FIRE else g_scale
		_:
			dir = _patrol_dir(a)
	dir = _avoid_collision(a, dir)
	var s := _steer(b, dir.normalized(), state == State.PURSUIT or state == State.FIRE)
	i.pitch = s.x * (g_scale if s.x > 0.0 else 1.0)
	i.roll = s.y
	i.yaw = s.z
	return i.clamp_values()


## Grob: Autopilot.steer_to_direction. Fein (Zielen, < FINE_DEG): Wunsch-Drehraten aus
## Winkelfehler (Zeitkonstante FINE_TAU) plus Vorsteuerung aus der Drehung der Ziel-
## richtung; Nicken direkt (Arcade: Knüppel = Nickrate), seitlich über Querlage
## (koordinierte Kurve) und etwas Seitenruder.
const FINE_DEG := 6.0
const FINE_TAU := 0.3
var _want_prev := Vector3.ZERO
func _steer(b: Basis, dir: Vector3, fine: bool) -> Vector3:
	var s := Autopilot.steer_to_direction(b, dir)
	var l := b.inverse() * dir
	var prev := _want_prev
	_want_prev = dir
	if not fine or l.z > 0.0:
		return Vector3(s.x, s.y, 0.0)
	var ax := atan2(l.x, -l.z)
	var ay := atan2(l.y, -l.z)
	var off := rad_to_deg(sqrt(ax * ax + ay * ay))
	if off > FINE_DEG:
		return Vector3(s.x, s.y, 0.0)
	var a := get_vehicle() as Aircraft
	var d := a.data
	var hz := float(Engine.physics_ticks_per_second)
	var ff := Vector3.ZERO
	if prev != Vector3.ZERO:
		ff = b.inverse() * ((dir - prev) * hz)   # Drehrate der Zielrichtung (rad/s)
	var q_cmd := ay / FINE_TAU + ff.y
	var r_cmd := ax / FINE_TAU + ff.x
	var v := maxf(a.telemetry().airspeed, 30.0)
	var bank := atan2(-b.x.y, b.y.y)
	var bank_want := clampf(atan(r_cmd * v / 9.81), -1.2, 1.2)
	var roll := clampf((bank_want - bank) * 3.0 / d.arcade_max_roll_rate, -1.0, 1.0)
	var fine_v := Vector3(clampf(q_cmd / d.arcade_max_pitch_rate, -1.0, 1.0), roll,
			clampf(ax * 3.0, -1.0, 1.0))
	var w := clampf((off - FINE_DEG * 0.5) / (FINE_DEG * 0.5), 0.0, 1.0)
	return fine_v.lerp(Vector3(s.x, s.y, 0.0), w)


# --- Entscheidung ----------------------------------------------------------------

func _set_state(st: int, dt: float) -> void:
	if st != state:
		state = st
		state_time = 0.0
		if trace_enabled:
			trace.append("%d:%d" % [_ticks, st])
	else:
		state_time += dt


func _decide(a: Aircraft, dt: float) -> int:
	# 1) Bodenschutz mit Vorrang (Hysterese: erst nach 1 s frei verlassen)
	if _ground_threat(a, 1.0):
		_ground_clear_time = 0.0
		return State.GROUND_AVOID
	if state == State.GROUND_AVOID:
		if not _ground_threat(a, 1.4) and a.telemetry().climb_rate > -2.0:
			_ground_clear_time += dt
		if _ground_clear_time < 1.0:
			return State.GROUND_AVOID
	# 2) Rückzug
	if _should_retreat(a):
		return State.RETREAT
	# 3) Ausweichen
	var threat := _threat(a)
	if threat != null:
		if state != State.EVADE:
			_pick_maneuver(a, threat)
		return State.EVADE
	if state == State.EVADE and state_time < EVADE_MIN_TIME:
		return State.EVADE
	# 4) Energie
	var v := a.telemetry().airspeed
	if v < ENERGY_LOW or state == State.ENERGY and v < ENERGY_OK:
		return State.ENERGY
	# 5) Kampf
	if target == null:
		return State.PATROL
	var d := a.global_position.distance_to(target.pos)
	if d > ENGAGE_RANGE and state != State.PURSUIT and state != State.FIRE \
			or d > ENGAGE_RANGE * 1.3:
		return State.APPROACH
	return State.FIRE if _burst_left > 0.0 or _fire_window(a) else State.PURSUIT


func _should_retreat(a: Aircraft) -> bool:
	var w := a.weapons
	if w != null and w.ammo_max() > 0 and float(w.ammo()) / w.ammo_max() < RETREAT_AMMO:
		return true
	var dm := a.damage
	if dm != null:
		for z in dm.hp.size():
			if dm.hp_fraction(z) < RETREAT_HP:
				return true
	return false


## Feind am Heck, nah und mit der Nase auf uns (wahrgenommen, also verzögert).
func _threat(a: Aircraft) -> AIPerception.Contact:
	for c in perception.contacts.values():
		if not c.known:
			continue
		var to: Vector3 = c.pos - a.global_position
		var d := to.length()
		if d > EVADE_RANGE or d < 1.0:
			continue
		if rad_to_deg((-a.global_transform.basis.z).angle_to(to)) < EVADE_REAR_DEG:
			continue
		var enemy_fwd: Vector3 = -c.node.global_transform.basis.z
		if rad_to_deg(enemy_fwd.angle_to(-to)) <= EVADE_AIM_DEG:
			return c
	return null


func _pick_maneuver(a: Aircraft, threat: AIPerception.Contact) -> void:
	var opts := []
	for m in [AIDifficulty.Maneuver.BREAK, AIDifficulty.Maneuver.SCISSORS,
			AIDifficulty.Maneuver.SPIRAL]:
		if _diff.has_maneuver(m):
			opts.append(m)
	if opts.is_empty():
		opts.append(AIDifficulty.Maneuver.BREAK)
	_maneuver = opts[_rng.randi() % opts.size()]
	if _maneuver == AIDifficulty.Maneuver.SPIRAL and a.telemetry().height_agl < 900.0:
		_maneuver = AIDifficulty.Maneuver.BREAK
	var local := a.global_transform.basis.inverse() * (threat.pos - a.global_position)
	_evade_side = 1.0 if local.x >= 0.0 else -1.0   # in den Angreifer hinein drehen
	_scissor_timer = 0.0


# --- Bodenschutz -----------------------------------------------------------------

func _ground_threat(a: Aircraft, margin_mul: float) -> bool:
	var p := a.global_position
	var v := a.linear_velocity
	var m := _diff.ground_margin * margin_mul
	if p.y - WorldGround.height_at(p.x, p.z) < m * 0.6:
		return true
	for t in LOOKAHEAD:
		var q: Vector3 = p + v * t
		var h := maxf(WorldGround.height_at(q.x, q.z), WorldGround.height_at(
				lerpf(p.x, q.x, 0.5), lerpf(p.z, q.z, 0.5)))
		if q.y < h + m:
			return true
	# Sinkflug: Abfangweg bei ~2,5 g plus Rollzeit
	if v.y < 0.0:
		var need := v.y * v.y / (2.0 * 9.81 * 2.5) + absf(v.y) * 1.0 + m
		if p.y - WorldGround.height_at(p.x, p.z) < need:
			return true
	return false


func _ground_recovery(a: Aircraft, i: PilotIntent) -> PilotIntent:
	var b := a.global_transform.basis
	i.throttle = 1.0
	i.yaw = 0.0
	if b.y.y < 0.25:
		# Kopfüber/steil seitlich: erst aufrichten, nicht in den Boden ziehen
		i.roll = 1.0 if b.x.y > 0.0 else -1.0
		i.pitch = 0.0 if b.y.y < 0.0 else 0.3
	else:
		var dir := _flat(-b.z) + Vector3.UP * 1.2
		var s := Autopilot.steer_to_direction(b, dir.normalized())
		i.pitch = maxf(s.x, 0.5)
		i.roll = s.y
	return i.clamp_values()


# --- Lenkziele -------------------------------------------------------------------

static func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 1e-3 else Vector3.FORWARD


func _alt_hold(a: Aircraft, alt: float, max_climb := 0.25) -> float:
	return clampf((alt - a.global_position.y) / 400.0, -max_climb, max_climb)


func _patrol_dir(a: Aircraft) -> Vector3:
	var pos := a.global_position
	var to_c := patrol_center - pos
	to_c.y = 0.0
	var dir: Vector3
	if to_c.length() < 1.0:
		dir = _flat(-a.global_transform.basis.z)
	else:
		var radial := -to_c.normalized()
		var tangent := Vector3.UP.cross(radial)
		var err := clampf((to_c.length() - patrol_radius) / patrol_radius, -0.6, 0.6)
		dir = (tangent - radial * err).normalized()
	return dir + Vector3.UP * _alt_hold(a, patrol_altitude)


func _approach_dir(a: Aircraft) -> Vector3:
	var to := target.pos - a.global_position
	var d := to.length()
	var lead_t := clampf(d / maxf(a.linear_velocity.length() + 150.0, 100.0), 0.0, 4.0) * 0.5
	var aim := target.pos + target.vel * lead_t
	var dir := _flat(aim - a.global_position)
	var want := target.pos.y + _diff.altitude_advantage
	# Bei kurzer Entfernung Höhe nicht mehr erzwingen, sondern auf das Ziel zeigen
	if d < ENGAGE_RANGE * 1.2:
		return (aim - a.global_position).normalized() + Vector3.UP * 0.05
	return dir + Vector3.UP * _alt_hold(a, want, 0.3)


func _gun_params(a: Aircraft) -> Vector2:
	var w: WeaponDef = a.weapons.weapon_of_group() if a.weapons != null else null
	return Vector2(w.muzzle_velocity, w.ballistic_k) if w != null else Vector2(800.0, 7.0e-4)


## Gewünschte Nasenrichtung, damit die (konvergierenden) Waffen den Vorhaltepunkt laut
## LeadSolver treffen: je Waffe die nötige Abschussrichtung (inkl. Eigenfahrt, Fall)
## minus der aktuellen Waffenrichtung, gemittelt, auf die Nase addiert.
## Vector3.ZERO, wenn keine Lösung. `_aim_err_rad` = Restfehler.
var _aim_err_rad := -1.0
func _lead_dir(a: Aircraft) -> Vector3:
	var g := _gun_params(a)
	var tp := target.extrapolated(_diff.reaction_time)
	var tv := target.vel + target.acc * _diff.reaction_time
	var r := LeadSolver.solve(a.global_position, a.linear_velocity, tp, tv,
			g.x, g.y, target.acc, _diff.fire_range * 2.0, 4)
	_aim_err_rad = -1.0
	if not r.valid:
		return Vector3.ZERO
	var xf := a.global_transform
	var nose := -xf.basis.z
	var ms := a.weapons.mounts() if a.weapons != null else []
	if ms.is_empty() or a.weapons.aim_dirs.size() != ms.size():
		_aim_err_rad = nose.angle_to(r.dir)
		return r.dir
	var corr := Vector3.ZERO
	for gi in ms.size():
		var gp: Vector3 = xf * ms[gi].position
		var need := Ballistics.solve_direction(gp, r.intercept, g.x, g.y, a.linear_velocity,
				1.0 / 60.0, 3)
		corr += need - xf.basis * a.weapons.aim_dirs[gi]
	corr /= ms.size()
	var want := (nose + corr).normalized()
	_aim_err_rad = nose.angle_to(want)
	return want


func _pursuit_dir(a: Aircraft, i: PilotIntent, dt: float) -> Vector3:
	var pos := a.global_position
	var to := target.pos - pos
	var d := to.length()
	var closing := -(target.vel - a.linear_velocity).dot(to / maxf(d, 1.0))
	var angle_off := rad_to_deg(target.vel.angle_to(to)) if target.vel.length() > 1.0 else 0.0
	if d < 250.0 and closing > 40.0 and angle_off < 90.0:
		pursuit_mode = Pursuit.LAG
	elif d < _diff.fire_range * 2.0:
		pursuit_mode = Pursuit.LEAD
	elif angle_off > 50.0 and angle_off < 135.0:
		pursuit_mode = Pursuit.LEAD
	else:
		pursuit_mode = Pursuit.PURE
	# Gas: Überschießen vermeiden
	i.throttle = 0.55 if d < 300.0 and closing > 25.0 and angle_off < 90.0 else 1.0
	var dir: Vector3
	match pursuit_mode:
		Pursuit.LAG:
			dir = (target.pos - target.vel * 0.8) - pos
		Pursuit.PURE:
			dir = to
		_:
			var ld := _lead_dir(a)
			if ld == Vector3.ZERO:
				var t := d / 800.0
				ld = (target.pos + target.vel * t + target.acc * 0.5 * t * t - pos).normalized()
			dir = ld
	dir = dir.normalized()
	# Zielfehler (langsam wandernd, je Schwierigkeit)
	var b := a.global_transform.basis
	dir = (dir + b.x * _noise.x * 0.001 + b.y * _noise.y * 0.001).normalized()
	_fire_control(a, i, dt)
	return dir


func _fire_window(a: Aircraft) -> bool:
	if target == null:
		return false
	var d := a.global_position.distance_to(target.pos)
	if d > _diff.fire_range or a.weapons == null or a.weapons.ammo() <= 0:
		return false
	var ld := _lead_dir(a)
	if ld == Vector3.ZERO:
		return false
	aim_error_deg = rad_to_deg(_aim_err_rad)
	return aim_error_deg <= _diff.fire_max_error_deg


## Feuerstöße: Stoß 0,5–1,5 s (je Schwierigkeit), dann Pause; Abbruch, wenn das
## Fenster deutlich verloren geht.
func _fire_control(a: Aircraft, i: PilotIntent, dt: float) -> void:
	in_fire_window = _fire_window(a)
	_pause_left = maxf(_pause_left - dt, 0.0)
	if _burst_left > 0.0:
		if not in_fire_window and (aim_error_deg < 0.0 \
				or aim_error_deg > _diff.fire_max_error_deg * 2.0):
			_burst_left = 0.0
		else:
			_burst_left -= dt
		if _burst_left <= 0.0:
			_burst_left = 0.0
			_pause_left = _rng.randf_range(_diff.pause_min, _diff.pause_max)
	elif in_fire_window and _pause_left <= 0.0:
		_burst_left = _rng.randf_range(_diff.burst_min, _diff.burst_max)
	i.fire_primary = _burst_left > 0.0 and _friendly_clear(a)


## Kein Freund in der Schusslinie (≤ 600 m, 3°).
func _friendly_clear(a: Aircraft) -> bool:
	var fwd := -a.global_transform.basis.z
	for t in ProjectileSystem.targets():
		var n := t.node
		if n == null or n == a or not is_instance_valid(n):
			continue
		if not Nations.is_friendly(AIPerception.nation_of(a), AIPerception.nation_of(n)):
			continue
		var to := n.global_position - a.global_position
		if to.length() < 600.0 and rad_to_deg(fwd.angle_to(to)) < 3.0:
			return false
	return true


func _update_noise(dt: float) -> void:
	_noise_timer -= dt
	if _noise_timer <= 0.0:
		_noise_timer = 0.6
		var s := _diff.aim_error_mrad
		_noise_goal = Vector2(_rng.randfn(0.0, s), _rng.randfn(0.0, s))
	_noise = _noise.lerp(_noise_goal, clampf(dt / 0.5, 0.0, 1.0))


func _evade_dir(a: Aircraft, dt: float) -> Vector3:
	var b := a.global_transform.basis
	var side := _evade_side
	var down := -0.15
	match _maneuver:
		AIDifficulty.Maneuver.SCISSORS:
			_scissor_timer += dt
			if _scissor_timer > 2.5:
				_scissor_timer = 0.0
				_evade_side = -_evade_side
			down = 0.0
		AIDifficulty.Maneuver.SPIRAL:
			down = -0.6
	return _flat(b.x * side + _flat(-b.z) * 0.2) + Vector3.UP * down


func _retreat_dir(a: Aircraft) -> Vector3:
	var away := home - a.global_position
	if target != null:
		var from_t := a.global_position - target.pos
		if from_t.length() < 2000.0:
			away = from_t
	return _flat(away) + Vector3.UP * _alt_hold(a, patrol_altitude, 0.15)


## Zusammenstoß vermeiden (frontal oder beim Überschießen).
func _avoid_collision(a: Aircraft, dir: Vector3) -> Vector3:
	for c in perception.contacts.values():
		var rp: Vector3 = c.node.global_position - a.global_position
		var rv: Vector3 = c.node.linear_velocity - a.linear_velocity if c.node is RigidBody3D \
				else -a.linear_velocity
		var vv := rv.length_squared()
		if vv < 1.0:
			continue
		var t := -rp.dot(rv) / vv
		if t < 0.0 or t > COLLISION_TIME:
			continue
		var miss := rp + rv * t
		if miss.length() < COLLISION_MISS:
			var away := -miss.normalized() if miss.length() > 1.0 \
					else a.global_transform.basis.y
			return (dir.normalized() * 0.3 + away).normalized()
	return dir
