class_name Selbsttest
extends Node
## M2.2: Treffer-Selbsttest im laufenden Hauptspiel (Startoption `--selbsttest`).
## Phase A: Gegner 250 m vor dem Spieler, der Spieler feuert 3 s über die echte Eingabe-
## Aktion „fire_primary“. Phase B: Gegner 250 m hinter dem Spieler feuert 3 s.
## Zählt Geschosse, Segmenttests, Trefferberichte (akzeptiert/abgelehnt) und Schaden,
## M3: danach Boden-Phasen (Spielzeit; dauert im Spiel etwa 3 min):
##  D1 Spieler steht leer (15 %/0) am Abstellplatz und steigt über „eject_hold“ (J) aus.
##  C  KI-Mannschaft fertigt die Maschine ab: Lagerabgang = Tankzufluss (±1 %), Zeitgrenze.
##  D2 Figur nimmt mit „crew_interact“ eine Kiste vom Munitionswagen, lädt MG links an der
##     Klappe (E halten), Munition kommt aus dem Wagen; D3 steigt mit „crew_enter“ (F) ein.
##  E  Eine rote KI rollt vom Abstellplatz und erreicht 300 m über Grund in ≤ 90 s.
## Diagnose: Modelle (Meshes > 0), Animationen ≥ 6, Layouts, Lager, Hitbox-Zonen.
## schreibt ins Godot-Log und nach user://logs/selbsttest_*.txt und beendet das Spiel
## (Exit-Code 0 = alle Phasen bestanden, sonst 1).

const DIST := 250.0
const FIRE_TIME := 3.0
const SETTLE := 1.0
const C_LIMIT := 300.0
const E_LIMIT := 90.0
const E_AGL := 300.0

## Gerader Flug mit festem Gas, optional Dauerfeuer.
class StraightPilot extends Controller:
	var fire := false
	func compute_intent(_dt: float) -> PilotIntent:
		var i := PilotIntent.new()
		i.throttle = 0.9
		i.gear_down = false
		i.fire_primary = fire
		return i

var game: Node
var _t := 0.0
var _phase := 0
var _enemy: Aircraft
var _pilot := StraightPilot.new()
var _lines: PackedStringArray = []
# Zähler je Phase: [geschosse, segmenttests, berichte, akzeptiert, abgelehnt, schaden]
var _c := {}
var _seg0 := 0
var _phase_key := ""
## Ergebnisse der Boden-Phasen: name -> bool
var _ground := {}


static func requested() -> bool:
	return "--selbsttest" in OS.get_cmdline_args() or "--selbsttest" in OS.get_cmdline_user_args()


func _ready() -> void:
	process_physics_priority = 1000
	add_child(_pilot)
	var ps: ProjectileSystem = game.projectiles
	ps.spawned.connect(func(_s): _count("geschosse"))
	ps.hit_resolved.connect(_on_hit)
	CombatEvents.bus().aircraft_damaged.connect(_on_damaged)
	_log("Selbsttest %s gestartet (Renderer %s, Bildrate frei: %s)" % [Hud.VERSION,
			RenderingServer.get_current_rendering_driver_name(), str(Engine.max_fps == 0)])


func _count(k: String, v := 1.0) -> void:
	if _phase_key == "":
		return
	var d: Dictionary = _c[_phase_key]
	d[k] = d.get(k, 0.0) + v


func _on_hit(_sh: Node, _tg: Node, _z: int, _dmg: float, _wp: Vector3, _lp: Vector3, res: int) -> void:
	_count("berichte")
	_count("akzeptiert" if res == HitValidator.Result.OK else "abgelehnt")


func _on_damaged(_a: Node, _z: int, dmg: float, _att: Node) -> void:
	_count("schaden", dmg)


func _physics_process(dt: float) -> void:
	_t += dt
	match _phase:
		0:
			if _t >= SETTLE:
				_start("A_spieler_schiesst", false)
		1:
			if _t >= FIRE_TIME:
				Input.action_release("fire_primary")
				_finish_phase()
				_start("B_gegner_schiesst", true)
		2:
			if _t >= FIRE_TIME:
				_pilot.fire = false
				_finish_phase()
				_phase = 3
				_ground_phases()


func _start(key: String, enemy_fires: bool) -> void:
	_phase += 1
	_t = 0.0
	_phase_key = key
	_c[key] = {}
	var pl: Aircraft = game.player_aircraft
	var enemies: Array = game.ai_aircrafts
	_enemy = enemies[0]
	var dir := Vector3(0, 0, -1)
	var b := Basis.looking_at(dir, Vector3.UP)
	var base := pl.global_position
	base.y = WorldGround.height_at(base.x, base.z) + 1500.0
	# Übrige Gegner weit weg parken, damit sie nicht stören.
	for k in range(1, enemies.size()):
		var e: Aircraft = enemies[k]
		e.place(Transform3D(b, base + Vector3(3000.0 + k * 400.0, 500.0, 0)), 110.0, 0.9, false)
	_enemy.pilot_seat.possess(_pilot)
	_pilot.fire = enemy_fires
	pl.damage.reset()
	_enemy.damage.reset()
	if enemy_fires:
		pl.place(Transform3D(b, base), 110.0, 0.9, false)
		_enemy.place(Transform3D(b, base - dir * DIST), 110.0, 0.9, false)
	else:
		pl.place(Transform3D(b, base), 110.0, 0.9, false)
		_enemy.place(Transform3D(b, base + dir * DIST), 110.0, 0.9, false)
	game.player.reset_state(0.9, false)
	if not enemy_fires:
		Input.action_press("fire_primary")
	_seg0 = game.projectiles.segment_tests


func _finish_phase() -> void:
	_count("segmenttests", float(game.projectiles.segment_tests - _seg0))
	var d: Dictionary = _c[_phase_key]
	_log("%s: Geschosse %d, Segmenttests %d, Trefferberichte %d, akzeptiert %d, abgelehnt %d, Schaden %.1f" % [
			_phase_key, int(d.get("geschosse", 0)), int(d.get("segmenttests", 0)),
			int(d.get("berichte", 0)), int(d.get("akzeptiert", 0)), int(d.get("abgelehnt", 0)),
			float(d.get("schaden", 0.0))])
	_phase_key = ""


# --- M3: Boden-Phasen ----------------------------------------------------------------

func _frames(sec: float) -> void:
	var n := int(sec * Engine.physics_ticks_per_second)
	for i in n:
		await get_tree().physics_frame


func _hold(action: String, sec: float) -> void:
	Input.action_press(action)
	await _frames(sec)
	Input.action_release(action)
	await _frames(0.1)


## Figur vor p stellen, Blick auf p (CrewCharacter + CrewPlayerController).
func _face(ch: CrewCharacter, p: Vector3, dist: float) -> void:
	var d := ch.global_position - p
	d.y = 0.0
	if d.length() < 0.1:
		d = Vector3.RIGHT
	var pos := p + d.normalized() * dist
	ch.global_position = Vector3(pos.x, WorldGround.height_at(pos.x, pos.z), pos.z)
	var to := p - ch.global_position
	var yaw := atan2(-to.x, -to.z)
	ch.heading = yaw
	ch.look_yaw = yaw
	var c = ch.crew_seat.controller
	if c != null and c.get("look_yaw") != null:
		c.set("look_yaw", yaw)
		c.set("look_pitch", -0.2)


func _diag_lines() -> bool:
	var ok := true
	var zones := []
	for a: Aircraft in [game.player_aircraft] + game.ai_aircrafts:
		var n: int = a.damage.hitboxes.zones.size() if a.damage != null and a.damage.hitboxes != null else 0
		zones.append(n)
		ok = ok and n == 9
	_log("Diagnose Hitbox-Zonen: %s" % str(zones))
	ok = ok and game.airfields.size() >= 2
	for i in game.airfields:
		var ops: AirfieldOps = game.airfields[i]
		var meshes_ok: bool = ops.model_meshes.values().all(func(v): return int(v) > 0) and ops.model_meshes.size() >= 7
		var anim := ops.animation_count()
		_log("Diagnose Platz %d: Modelle %s (Meshes > 0: %s), Animationen %d, Layout gefunden %s (%d Abstellplätze), Lager %.0f l, Bunker %d Schuss" % [
			i, str(ops.model_meshes), str(meshes_ok), anim, str(ops.layout != null), ops.layout.parking_count(),
			ops.depot.total(), ops.bunker.available(AmmoBunker.AMMO_792)])
		ok = ok and meshes_ok and anim >= 6 and ops.layout.parking_count() > 0 and ops.depot.total() > 0.0
	var tut := Tutorial.diagnose()
	_log("Diagnose %s" % tut[1])
	# M3.3: Audio (optional – ohne Audio-Paket stumm, kein Fehler)
	_log("Diagnose " + GameAudio.diagnostics())
	ok = ok and tut[0]
	var pa := Game._anim_count(game.crew)
	_log("Diagnose Spielerfigur: Meshes %d, Animationen %d" % [AirfieldOps.mesh_count(game.crew.visual), pa])
	return ok and pa >= 6 and AirfieldOps.mesh_count(game.crew.visual) > 0


func _blue_stock() -> float:
	var ops: AirfieldOps = game.blue_ops
	return ops.depot.total() + ops.truck.tank.total()


func _ground_phases() -> void:
	_ground["Diagnose"] = _diag_lines()
	var pl: Aircraft = game.player_aircraft
	var ops: AirfieldOps = game.blue_ops
	var lay: AirfieldLayout = ops.layout
	var sess: PlayerSession = game.session
	var ch: CrewCharacter = game.crew
	# D1: leer am Abstellplatz, Aussteigen über J
	pl.damage.reset()
	var spot: int = game.spawn_manager.free_spot(lay, pl)
	var xf := lay.parking_transform(maxi(spot, 0))
	pl.place_on_ground(xf.origin, -xf.basis.z, false, ServiceState.make(0.15, 0.0))
	game.player.reset_state(0.0)
	await _frames(3.0)
	await _hold("eject_hold", 1.4)
	var d1: bool = sess.context == InputBindings.Context.CREW and ch.in_seat == null and ch.visible
	_ground["D1_aussteigen"] = d1
	_log("D1_aussteigen: Kontext %s, Figur %s, Abstand %.1f m" % [InputBindings.CONTEXT_NAMES.get(sess.context, "?"),
		"sichtbar" if ch.visible else "versteckt", ch.global_position.distance_to(pl.global_position)])
	# Figur aus dem Weg (KI arbeitet allein)
	_face(ch, pl.global_position, 14.0)
	# C: KI-Abfertigung
	var stock0 := _blue_stock()
	var fuel0 := pl.damage.fuel.total()
	var inflow := 0.0
	var last := fuel0
	var t := 0.0
	var done := false
	while t < C_LIMIT:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		var f := pl.damage.fuel.total()
		if f > last:
			inflow += f - last
		last = f
		if OS.has_environment("SELBSTTEST_DEBUG") and int(t * 60) % 900 == 0:
			var js: Array = game.job_board.open_jobs(pl).map(func(j): return "%s:%s:%s:%s" % [j.kind, j.current_step(), j.worker.name if j.worker else "-", j.blocked_reason])
			var tr: FuelTruck = ops.truck
			print("DBG truck pos=%s spd=%.2f thr=%.2f brk=%.2f yaw=%.2f ctrl=%s goal=%s col=%d" % [str(lay.to_local(tr.global_position).round()), tr.speed, tr.driver_seat.intent.throttle, tr.driver_seat.intent.brakes, tr.driver_seat.intent.yaw, tr.driver_seat.controller, str(ops.brains[0]._drive_goal), tr.get_slide_collision_count()])
			if tr.get_slide_collision_count() > 0:
				print("DBG col ", tr.get_slide_collision(0).get_collider())
			print("DBG t=%.0f jobs=%s prop=%s parked=%s brains=%s" % [t, str(js), GroundCrewBrain.prop_danger(pl), ops.dispatch.is_parked(pl),
				str(ops.brains.map(func(b): return "%d/%s/%s/veh=%s/legs=%s/v=%.1f" % [b.state, str(lay.to_local(b.position_now()).round()), str(lay.to_local(pl.global_position).round()), b.in_vehicle() != null, str(b._legs.map(func(l): return [l.keys(), lay.to_local(l.pos).round()])), b.body().velocity.length() if b.body() else -1.0]))])
		if t > 2.0 and game.job_board.is_serviced(pl) and pl.damage.fuel.fraction() > 0.97 \
				and pl.weapons.ammo() == pl.weapons.ammo_max():
			done = true
			break
	var drawn := stock0 - _blue_stock()
	var dev := absf(drawn - inflow)
	var c_ok := done and dev <= maxf(1.0, drawn * 0.01)
	_ground["C_ki_abfertigung"] = c_ok
	_log("C_ki_abfertigung: %s nach %.0f s, Treibstoff %.0f -> %.0f l, Lagerabgang %.1f l, Tankzufluss %.1f l (Abweichung %.2f l), Munition %d/%d, Helfer %d" % [
		"fertig" if done else "NICHT fertig", t, fuel0, pl.damage.fuel.total(), drawn, inflow, dev,
		pl.weapons.ammo(), pl.weapons.ammo_max(), ops.brains.size()])
	# D2: Kiste nehmen, MG links laden (Personal pausiert)
	GroundCrewBrain.issue(GroundCrewBrain.Command.PAUSE, null, ops.brains)
	pl.weapons.set_ammo_fraction(0.0)
	await _frames(0.5)
	var cart: AmmoCart = ops.cart
	var cart0 := cart.store.available(AmmoBunker.AMMO_792)
	var slot: Interactable = cart.slot_points[0]
	_face(ch, slot.global_position, 1.3)
	await _frames(0.3)
	await _hold("crew_interact", 0.3)
	var got_crate: bool = ch.carried is CarryItem and ch.carried.kind == CarryItem.CRATE
	var hatch := pl.service_point(ServiceMarkers.SVC_GUN_HATCH_L)
	# M3.1: von außen an die Klappe treten (Wagen steht weiter hinten; von dort läge der Einstieg im Blick)
	var lat := pl.global_transform.basis.x
	lat = lat * signf(lat.dot(hatch - pl.global_position))
	ch.global_position = hatch + Vector3(lat.x, 0.0, lat.z).normalized() * 3.0
	_face(ch, hatch, 1.2)
	await _frames(0.3)
	Input.action_press("crew_interact")
	var tt := 0.0
	while tt < 30.0 and pl.weapons.gun_ammo(0) < pl.weapons.gun_capacity(0):
		await get_tree().physics_frame
		tt += 1.0 / Engine.physics_ticks_per_second
	Input.action_release("crew_interact")
	await _frames(0.2)
	if ch.carried != null:
		ch.drop_item()
	var loaded := pl.weapons.gun_ammo(0)
	var cart_used := cart0 - cart.store.available(AmmoBunker.AMMO_792)
	var d2 := got_crate and loaded > 0 and loaded <= cart_used
	_ground["D2_interaktion"] = d2
	_log("D2_interaktion: Kiste genommen %s, MG links %d Schuss in %.1f s, aus dem Wagen %d" % [
		str(got_crate), loaded, tt, cart_used])
	GroundCrewBrain.issue(GroundCrewBrain.Command.FULL_SERVICE, null, ops.brains)
	# D3: Einsteigen über F
	_face(ch, pl.pilot_seat.entry_position(), 1.0)
	await _frames(0.3)
	await _hold("crew_enter", 0.2)
	await _frames(0.3)
	var d3: bool = sess.context == InputBindings.Context.FLIGHT and pl.pilot_seat.controller == game.player
	_ground["D3_einsteigen"] = d3
	_log("D3_einsteigen: Kontext %s, Pilotensitz %s" % [InputBindings.CONTEXT_NAMES.get(sess.context, "?"),
		pl.pilot_seat.controller.name if pl.pilot_seat.controller != null else "leer"])
	# E: rote KI startet vom Abstellplatz
	await _phase_e()
	_done()


func _phase_e() -> void:
	var enemies: Array = game.ai_aircrafts
	var a: Aircraft = enemies[1] if enemies.size() > 1 else enemies[0]
	var br: AIPilotBrain = a.pilot_seat.controller as AIPilotBrain
	if br == null:
		br = game.scenario.brains[enemies.find(a)]
	var lay: AirfieldLayout = (game.world as TerrainWorld).airfield_layout(game.scenario.red_field)
	# Abstellplatz nächst dem Haltepunkt (südlichster), sonst erster freier
	var spot: int = lay.parking_count() - 1
	for o in enemies:
		if o != a and o.global_position.distance_to(lay.parking_transform(spot).origin) < 14.0:
			spot = maxi(game.spawn_manager.free_spot(lay, a), 0)
	var xf := lay.parking_transform(spot)
	a.damage.reset()
	a.place_on_ground(xf.origin, -xf.basis.z, true, ServiceState.full())
	if br.airfield == null:
		br.airfield = AirfieldPhases.new()
	br.airfield.setup(lay, RunwayControl.find_or_create(game.spawn_manager, lay.airfield_index), spot,
		AirfieldPhases.Phase.PARKED)
	a.pilot_seat.possess(null)
	a.pilot_seat.possess(br)
	var t := 0.0
	var t_roll := -1.0
	var max_t := E_LIMIT + 120.0
	var agl := 0.0
	while t < max_t:
		await get_tree().physics_frame
		t += 1.0 / Engine.physics_ticks_per_second
		if t_roll < 0.0 and br.airfield.phase != AirfieldPhases.Phase.PARKED:
			t_roll = t
		agl = a.telemetry().height_agl
		if agl >= E_AGL or a.damage.is_destroyed:
			break
	var dur := t - t_roll if t_roll >= 0.0 else -1.0
	var ok := agl >= E_AGL and t_roll >= 0.0 and dur <= E_LIMIT and not a.damage.is_destroyed
	_ground["E_ki_start"] = ok
	_log("E_ki_start: %s rollt nach %.0f s los, %.0f m über Grund nach %.0f s ab Rollen (Grenze %.0f s), Phase %s, Schaden %s" % [
		a.get_meta("display_name", a.name), t_roll, agl, dur, E_LIMIT, br.airfield.phase_name(),
		str(a.damage.health_fraction() < 0.999)])


func _done() -> void:
	var a: Dictionary = _c["A_spieler_schiesst"]
	var b: Dictionary = _c["B_gegner_schiesst"]
	var ok: bool = a.get("akzeptiert", 0) > 0 and b.get("akzeptiert", 0) > 0 \
			and a.get("schaden", 0.0) > 0.0 and b.get("schaden", 0.0) > 0.0
	for k in ["Diagnose", "D1_aussteigen", "C_ki_abfertigung", "D2_interaktion", "D3_einsteigen", "E_ki_start"]:
		var r: bool = _ground.get(k, false)
		if not r:
			_log("Phase %s FEHLGESCHLAGEN" % k)
		ok = ok and r
	_log("SELBSTTEST %s" % ("OK" if ok else "FEHLGESCHLAGEN"))
	DirAccess.make_dir_recursive_absolute("user://logs")
	var path := "user://logs/selbsttest_%s.txt" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
		print("Selbsttest-Ergebnis: ", ProjectSettings.globalize_path(path))
	get_tree().quit(0 if ok else 1)


func _log(s: String) -> void:
	_lines.append(s)
	print(s)
