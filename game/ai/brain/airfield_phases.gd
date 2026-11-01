class_name AirfieldPhases
extends RefCounted
## Flugplatz-Phasen der KI (M3 Pakete 9a/9b, Strang C), aufgerufen von AIPilotBrain.
## tick(aircraft, intent, dt) -> true = Phase hat den Intent gesetzt, false = Kampf-
## Logik wie M2. Ohne layout (Standard) bleibt phase = COMBAT -> M2-Verhalten.
##
## PARKED   wartet auf Versorgung (≥ MIN_FUEL Treibstoff, ≥ MIN_AMMO Munition), nach
##          scramble_timeout s „Notstart“ mit dem, was da ist (Treibstoff > 0).
## TAXI_OUT Rollweg-Graph Abstellplatz -> Haltepunkt, 20 km/h, Kurs über hold_heading.
## HOLD     wartet auf die Pistenfreigabe (RunwayControl).
## TAKEOFF  Aufrollen, Klappen 50 %, Vollgas, Heck heben, Abheben bei ~135 km/h,
##          Fahrwerk ein, Steigflug bis CLIMB_AGL über Grund -> COMBAT.
## COMBAT   M2-Kampf. RTB bei Munition < 10 %, Treibstoff < 25 % oder Schaden.
## RTB      Flug zum Platz in Platzrundenhöhe -> PATTERN.
## PATTERN  Gegenanflug, Queranflug -> LANDING (Endanflug).
## LANDING  Endanflug 160 km/h, Klappen 100 %, Abfangen, Aufsetzen, Bremsen.
##          Durchstarten bei belegter Piste oder Sinkrate > GO_AROUND_SINK.
## TAXI_IN  Pistenausfahrt -> Abstellplatz -> PARKED.
## Notlandung (Motor aus, Brand) bleibt bei der Kampf-KI (false).

enum Phase { PARKED, TAXI_OUT, HOLD, TAKEOFF, COMBAT, RTB, PATTERN, LANDING, TAXI_IN }
const PHASE_NAMES := ["Abgestellt", "Rollen", "Halten", "Start", "Kampf", "Rückflug",
		"Platzrunde", "Landung", "Einrollen"]
const MIN_FUEL := 0.6
const MIN_AMMO := 0.8
const TAXI_SPEED := 20.0 / 3.6
const ROTATE_SPEED := 135.0 / 3.6
const APPROACH_SPEED := 160.0 / 3.6

## RTB-Schwellen (ersetzen RETREAT der Kampf-KI).
const RTB_AMMO := 0.1
const RTB_FUEL := 0.25
const RTB_HP := 0.6
## Steigflug nach dem Start bis zu dieser Höhe über Grund, dann Kampf.
const CLIMB_AGL := 320.0
## Steigfluggeschwindigkeit (m/s).
const CLIMB_SPEED := 215.0 / 3.6
const LINEUP_SPEED := 24.0 / 3.6
static var TAIL_UP_DEG := 0.0
static var YAW_KP_FAST := 1.5
static var YAW_KD_FAST := 2.0
## Durchstarten ab dieser Sinkrate (m/s) im Endanflug unterhalb GO_AROUND_CHECK_AGL.
const GO_AROUND_SINK := 4.0
const GO_AROUND_CHECK_AGL := 60.0
## Rollen: Abstand, ab dem ein Flugzeug vorn zum Anhalten zwingt (m), Kegel (Grad).
const TAXI_GAP := 38.0
const TAXI_CONE_DEG := 35.0

var phase: Phase = Phase.COMBAT
var layout: AirfieldLayout = null
var runway: RunwayControl = null
var parking_index := 0
## Sekunden bis zum Notstart ohne volle Versorgung.
var scramble_timeout := 90.0
## false = nach Landung nicht wieder starten (Tests / Abfertigung durch Paket 14).
var auto_restart := true
var phase_time := 0.0
## Diagnose: Zähler und Protokoll.
var go_arounds := 0
var scrambled := false
var trace: PackedStringArray = []
var trace_enabled := false

## Aktive Instanzen (für Abstand beim Rollen), WeakRefs auf Flugzeuge.
static var _fleet: Array = []

var _aircraft: Aircraft = null
var _path := PackedVector3Array()     # lokale Punkte
var _path_i := 0
var _sub := 0
var _ticks := 0
var _wait := 0.0


func set_phase(p: Phase) -> void:
	if p != phase and trace_enabled:
		trace.append("%.1f:%s" % [_ticks / 60.0, PHASE_NAMES[p]])
	phase = p
	phase_time = 0.0
	_sub = 0
	_path = PackedVector3Array()
	_path_i = 0
	_wait = 0.0


func phase_name() -> String:
	return PHASE_NAMES[phase]


## Für einen Abstellplatz einrichten (Maschine steht dort).
func setup(a_layout: AirfieldLayout, a_runway: RunwayControl, spot: int,
		start: Phase = Phase.PARKED) -> void:
	layout = a_layout
	runway = a_runway
	parking_index = spot
	set_phase(start)


func tick(a: Node, i: PilotIntent, dt: float) -> bool:
	var ac := a as Aircraft
	if ac == null or layout == null:
		return false
	if _aircraft != ac:
		_aircraft = ac
		_register(ac)
	_ticks += 1
	phase_time += dt
	i.fire_primary = false
	i.fire_secondary = false
	i.assist_mode = FlightAssist.Mode.ARCADE \
			if FlightAssist.Mode.ARCADE in ac.allowed_assist_modes else ac.assist_mode
	var dm := ac.damage
	if dm != null and dm.outcome == DamageModel.Outcome.CRASHED:
		_release()
		return false
	match phase:
		Phase.PARKED:
			return _parked(ac, i, dt)
		Phase.TAXI_OUT:
			return _taxi_out(ac, i, dt)
		Phase.HOLD:
			return _hold(ac, i, dt)
		Phase.TAKEOFF:
			return _takeoff(ac, i, dt)
		Phase.COMBAT:
			if needs_rtb(ac):
				set_phase(Phase.RTB)
				return _rtb(ac, i, dt)
			return false
		Phase.RTB:
			return _rtb(ac, i, dt)
		Phase.PATTERN:
			return _pattern(ac, i, dt)
		Phase.LANDING:
			return _landing(ac, i, dt)
		Phase.TAXI_IN:
			return _taxi_in(ac, i, dt)
	return false


## RTB nötig? Bei Motorausfall oder Brand nicht (Notlandung der Kampf-KI).
func needs_rtb(a: Aircraft) -> bool:
	var dm := a.damage
	if dm != null and (dm.is_engine_failed() or dm.is_burning()):
		return false
	var w := a.weapons
	if w != null and w.ammo_max() > 0 and float(w.ammo()) / w.ammo_max() < RTB_AMMO:
		return true
	if a.telemetry().fuel_fraction < RTB_FUEL:
		return true
	return dm != null and dm.health_fraction() < RTB_HP


static func ammo_fraction(a: Aircraft) -> float:
	var w := a.weapons
	if w == null or w.ammo_max() <= 0:
		return 1.0
	return float(w.ammo()) / w.ammo_max()


# --- Boden -------------------------------------------------------------------------

func _parked(a: Aircraft, i: PilotIntent, _dt: float) -> bool:
	_hold_still(a, i)
	if _sub == 1:   # nach Landung ohne auto_restart: stehen bleiben
		return true
	var fuel := a.telemetry().fuel_fraction
	var ready := fuel >= MIN_FUEL and ammo_fraction(a) >= MIN_AMMO
	var scramble := phase_time >= scramble_timeout and fuel > 0.02
	if (ready or scramble) and phase_time > 1.0:
		scrambled = not ready
		set_phase(Phase.TAXI_OUT)
		var spot := parking_index
		_path = PackedVector3Array([layout.parking_positions[spot]])
		_path.append_array(layout.path_points(layout.taxi_path(layout.parking_nodes[spot], layout.hold_node)))
	return true


func _taxi_out(a: Aircraft, i: PilotIntent, dt: float) -> bool:
	if _path.is_empty():
		_path = layout.path_points(layout.taxi_path(_nearest_node(a), layout.hold_node))
	# Piste frei: ohne Anhalten am Haltepunkt weiter auf die Piste.
	var hold := layout.taxi_nodes[layout.hold_node]
	var p := layout.to_local(a.global_position)
	if Vector2(hold.x - p.x, hold.z - p.z).length() < 14.0 and phase_time > 2.0 \
			and (runway == null or runway.request(a)):
		set_phase(Phase.TAKEOFF)
		_path = layout.path_points(layout.taxi_path(layout.hold_node, layout.runway_node))
		return _takeoff(a, i, dt)
	if _follow(a, i, dt, TAXI_SPEED, 3.0):
		set_phase(Phase.HOLD)
	return true


func _hold(a: Aircraft, i: PilotIntent, _dt: float) -> bool:
	_hold_still(a, i)
	if phase_time > 1.0 and runway != null and runway.request(a):
		set_phase(Phase.TAKEOFF)
		_path = layout.path_points(layout.taxi_path(layout.hold_node, layout.runway_node))
	elif runway == null and phase_time > 1.0:
		set_phase(Phase.TAKEOFF)
		_path = layout.path_points(layout.taxi_path(layout.hold_node, layout.runway_node))
	return true


func _takeoff(a: Aircraft, i: PilotIntent, dt: float) -> bool:
	var t := a.telemetry()
	var b := a.global_transform.basis
	var rdir := layout.runway_dir()
	i.flaps = 0.5
	i.roll = clampf(b.x.y * 2.5, -1.0, 1.0)
	match _sub:
		0:   # Aufrollen auf die Mittellinie
			i.gear_down = true
			var done := _follow(a, i, dt, LINEUP_SPEED, 4.0, 6.0, false)
			var herr := absf(rad_to_deg(_flat(-b.z).signed_angle_to(rdir, Vector3.UP)))
			if done or _path_i >= _path.size() - 2 and herr < 12.0:
				_sub = 1
		1:   # Startlauf: Mittellinie halten, Heck heben, bei ROTATE_SPEED abheben
			i.gear_down = true
			i.throttle = clampf(phase_time * 0.5, 0.5, 1.0) if _wait < 2.0 else 1.0
			_wait += dt
			i.brakes = 0.0
			var p := layout.to_local(a.global_position)
			var along := (p - layout.runway_start).dot(rdir)
			var aim := layout.runway_start + rdir * (along + 80.0)
			var to := layout.to_scene(aim) - a.global_position
			i.yaw = _roll_yaw(a, to)
			var pitch_deg := rad_to_deg(asin(clampf(-b.z.y, -1.0, 1.0)))
			# Heck nur leicht anheben (TAIL_UP_DEG unter der Dreipunktlage): voll gehobenes
			# Heck lässt die Maschine bei ~100 km/h ausbrechen (Spornrad-Lenkung fehlt).
			var want := data_ground_pitch(a) - TAIL_UP_DEG if t.airspeed < ROTATE_SPEED else 11.0
			if t.airspeed < 20.0:
				i.pitch = 0.3
			else:
				i.pitch = clampf((want - pitch_deg) * 0.15 - t.angular_velocity_local.x * 0.5, -0.4, 0.8)
			if t.wheels_in_contact == 0 and t.height_agl > 2.5:
				_sub = 2
		2:   # Steigflug mit Fahrt ~CLIMB_SPEED, Flügel fast waagerecht
			i.throttle = 1.0
			if t.height_agl > 10.0:
				i.gear_down = false
			if t.height_agl > 30.0 and t.airspeed > 175.0 / 3.6:
				i.flaps = 0.0
			var pitch_deg := rad_to_deg(asin(clampf(-b.z.y, -1.0, 1.0)))
			var want := clampf(10.0 + (t.airspeed - CLIMB_SPEED) * 0.5, 7.0, 16.0)
			if t.height_agl < 25.0:
				want = minf(want, 9.0)
			i.pitch = clampf((want - pitch_deg) * 0.08 - t.angular_velocity_local.x * 0.3, -0.5, 0.5)
			_level_turn(a, i, rdir, 12.0)
			if t.height_agl > 60.0 and runway != null:
				runway.release(a)
			if t.height_agl > CLIMB_AGL:
				i.flaps = 0.0
				i.gear_down = false
				_release()
				set_phase(Phase.COMBAT)
				return false
	i.clamp_values()
	return true


func _taxi_in(a: Aircraft, i: PilotIntent, dt: float) -> bool:
	i.flaps = 0.0
	i.gear_down = true
	if _path.is_empty():
		var start := _exit_node(a)
		_path = layout.path_points(layout.taxi_path(start, layout.parking_in_nodes[parking_index]))
		_path.append(layout.parking_positions[parking_index])
	var p := layout.to_local(a.global_position)
	if runway != null and runway.holds(a) and absf(p.x) > layout.runway_width * 0.5 + 4.0:
		runway.release(a)
	if _follow(a, i, dt, TAXI_SPEED, 2.5, 7.0):
		_release()
		set_phase(Phase.PARKED)
		_sub = 1 if not auto_restart else 0
	return true


## Ausfahrt: Ausfahrknoten vor uns (Rollrichtung), sonst der nächste.
func _exit_node(a: Aircraft) -> int:
	var p := layout.to_local(a.global_position)
	var rdir := layout.runway_dir()
	var best := -1
	var best_d := INF
	for e in layout.exit_nodes:
		var q := layout.taxi_nodes[e]
		var ahead := (q - p).dot(rdir)
		var d := Vector2(q.x - p.x, q.z - p.z).length() + (0.0 if ahead > 10.0 else 2000.0)
		if d < best_d:
			best_d = d
			best = e
	return best


func _nearest_node(a: Aircraft) -> int:
	var p := layout.to_local(a.global_position)
	var best := 0
	for k in layout.taxi_nodes.size():
		if Vector2(layout.taxi_nodes[k].x - p.x, layout.taxi_nodes[k].z - p.z).length() < \
				Vector2(layout.taxi_nodes[best].x - p.x, layout.taxi_nodes[best].z - p.z).length():
			best = k
	return best


func _hold_still(a: Aircraft, i: PilotIntent) -> void:
	i.throttle = 0.0
	i.brakes = 1.0
	i.pitch = 0.5
	i.roll = 0.0
	i.yaw = 0.0
	i.flaps = 0.0
	i.gear_down = true


## Pfad verfolgen (Pure Pursuit, lokale Punkte). true = Ende erreicht.
func _follow(a: Aircraft, i: PilotIntent, _dt: float, speed: float, reach: float,
		lookahead: float = 9.0, stop_at_end: bool = true) -> bool:
	var t := a.telemetry()
	var b := a.global_transform.basis
	var pos := layout.to_local(a.global_position)
	pos.y = 0.0
	if _path.is_empty():
		_hold_still(a, i)
		return true
	# Fortschritt: nächstes Segment, sobald der Punkt erreicht oder überholt ist.
	while _path_i < _path.size() - 1:
		var p0 := _path[_path_i]
		var p1 := _path[_path_i + 1]
		var seg := Vector3(p1.x - p0.x, 0, p1.z - p0.z)
		var u := (pos - Vector3(p0.x, 0, p0.z)).dot(seg) / maxf(seg.length_squared(), 1e-3)
		if u >= 1.0 or Vector2(p1.x - pos.x, p1.z - pos.z).length() < reach:
			_path_i += 1
		else:
			break
	var last := _path[_path.size() - 1]
	var d_end := Vector2(last.x - pos.x, last.z - pos.z).length()
	if _path_i >= _path.size() - 1 and d_end < reach:
		if stop_at_end:
			_hold_still(a, i)
		return true
	var aim := _lookahead_point(pos, lookahead)
	var to := Vector3(aim.x - pos.x, 0, aim.z - pos.z)
	var fwd := _flat(-b.z)
	var err := absf(rad_to_deg(fwd.signed_angle_to(to, Vector3.UP)))
	var want := speed * clampf(1.0 - err / 90.0, 0.35, 1.0)
	if stop_at_end:
		want = minf(want, maxf(d_end * 0.35, 1.0))
	if _blocked(a):
		want = 0.0
	var v := a.linear_velocity.dot(fwd)
	i.throttle = clampf(0.18 + (want - v) * 0.25, 0.0, 0.7) if want > 0.1 else 0.0
	i.brakes = clampf((v - want - 0.8) * 0.4, 0.0, 0.8)
	if want <= 0.1 and v < 0.6:
		i.brakes = 1.0
	i.pitch = 0.5
	i.roll = 0.0
	i.yaw = Autopilot.hold_heading(b, -t.angular_velocity_local.y, to)
	i.flaps = 0.0 if phase != Phase.TAKEOFF else 0.5
	return false


func _lookahead_point(pos: Vector3, dist: float) -> Vector3:
	var p0 := _path[_path_i]
	if _path_i >= _path.size() - 1:
		return p0
	var p1 := _path[_path_i + 1]
	var seg := Vector3(p1.x - p0.x, 0, p1.z - p0.z)
	var u := clampf((pos - Vector3(p0.x, 0, p0.z)).dot(seg) / maxf(seg.length_squared(), 1e-3), 0.0, 1.0)
	var cur := Vector3(p0.x, 0, p0.z) + seg * u
	var left := dist
	var k := _path_i + 1
	while k < _path.size():
		var q := Vector3(_path[k].x, 0, _path[k].z)
		var l := cur.distance_to(q)
		if l >= left:
			return cur + (q - cur) * (left / maxf(l, 1e-3))
		left -= l
		cur = q
		k += 1
	return cur


## Steht ein anderes Flugzeug am Boden vor uns im Weg?
func _blocked(a: Aircraft) -> bool:
	var fwd := _flat(-a.global_transform.basis.z)
	for w in _fleet:
		var o = w.get_ref()
		if o == null or o == a or not is_instance_valid(o):
			continue
		var oa := o as Aircraft
		if oa.telemetry().height_agl > 6.0:
			continue
		var to := oa.global_position - a.global_position
		to.y = 0.0
		var d := to.length()
		if d < TAXI_GAP and d > 0.1 and rad_to_deg(fwd.angle_to(to)) < TAXI_CONE_DEG:
			# Gegenseitig blockiert: der mit der kleineren Kennung fährt.
			var ofwd := _flat(-oa.global_transform.basis.z)
			var mutual := rad_to_deg(ofwd.angle_to(-to)) < TAXI_CONE_DEG
			if mutual and a.entity_id < oa.entity_id:
				continue
			return true
	return false


# --- Luft (Paket 9b) ----------------------------------------------------------------

func _rtb(_a: Aircraft, _i: PilotIntent, _dt: float) -> bool:
	return false


func _pattern(_a: Aircraft, _i: PilotIntent, _dt: float) -> bool:
	return false


func _landing(_a: Aircraft, _i: PilotIntent, _dt: float) -> bool:
	return false


# --- Hilfen -------------------------------------------------------------------------

static func data_ground_pitch(a: Aircraft) -> float:
	return a.data.ground_pitch_deg


## Seitenruder im schnellen Bodenlauf: Verstärkung sinkt mit der Fahrt (Ruder wirkt
## stärker, Spornrad-Lenkung schwächer), kräftige Gierdämpfung gegen Ausbrechen.
func _roll_yaw(a: Aircraft, to: Vector3) -> float:
	var b := a.global_transform.basis
	var t := a.telemetry()
	var err := _flat(-b.z).signed_angle_to(_flat(to), Vector3.UP)   # + = Ziel links
	var r := -t.angular_velocity_local.y                              # + = nach rechts
	var u := clampf(t.airspeed / 35.0, 0.0, 1.0)
	return clampf(-err * lerpf(4.0, YAW_KP_FAST, u) - r * lerpf(1.2, YAW_KD_FAST, u), -1.0, 1.0)


## Kurs dir mit begrenzter Querlage (max_bank Grad) fliegen (ARCADE: Knüppel = Rollrate).
func _level_turn(a: Aircraft, i: PilotIntent, dir: Vector3, max_bank: float) -> void:
	var b := a.global_transform.basis
	var t := a.telemetry()
	var herr := rad_to_deg(_flat(-b.z).signed_angle_to(_flat(dir), Vector3.UP))  # + = links
	var bank := rad_to_deg(atan2(-b.x.y, b.y.y))                                   # + = rechts
	var bank_want := clampf(-herr * 1.5, -max_bank, max_bank)
	i.roll = clampf((bank_want - bank) * 0.05 + t.angular_velocity_local.z * 0.2, -1.0, 1.0)
	i.yaw = clampf(-herr * 0.03, -0.3, 0.3)


func _release() -> void:
	if runway != null and _aircraft != null:
		runway.release(_aircraft)


static func _register(a: Aircraft) -> void:
	for k in range(_fleet.size() - 1, -1, -1):
		var o = _fleet[k].get_ref()
		if o == null or not is_instance_valid(o):
			_fleet.remove_at(k)
		elif o == a:
			return
	_fleet.append(weakref(a))


static func _flat(v: Vector3) -> Vector3:
	v.y = 0.0
	return v.normalized() if v.length() > 1e-4 else Vector3.FORWARD
