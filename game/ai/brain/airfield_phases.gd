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
const TAXI_CLEAR := 12.0

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
	_aircraft = null   # beim nächsten tick neu anmelden


func tick(a: Node, i: PilotIntent, dt: float) -> bool:
	var ac := a as Aircraft
	if ac == null or layout == null:
		return false
	if _aircraft != ac:
		_aircraft = ac
		_register(ac)
		ac.set_meta("airfield_phases", self)
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
			if _sub == 3:
				return _pattern_climbout(ac, i)
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
	var scramble := phase_time >= scramble_timeout and fuel > RTB_FUEL + 0.05 \
			and ammo_fraction(a) >= RTB_AMMO * 2.0
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


## Steht ein anderes Flugzeug am Boden auf unserem Weg (nächste TAXI_GAP m des Pfads)?
func _blocked(a: Aircraft) -> bool:
	var pos := layout.to_local(a.global_position)
	pos.y = 0.0
	var fwd := _flat(-a.global_transform.basis.z)
	var samples := PackedVector3Array([pos + fwd * 6.0])
	var cur := pos
	var left := TAXI_GAP
	var k := _path_i + 1
	while k < _path.size() and left > 0.0:
		var q := Vector3(_path[k].x, 0, _path[k].z)
		var l := cur.distance_to(q)
		var n := int(ceil(minf(l, left) / 4.0))
		for j in range(1, n + 1):
			samples.append(cur + (q - cur) * (minf(j * 4.0, l) / maxf(l, 1e-3)))
		left -= l
		cur = q
		k += 1
	for w in _fleet:
		var o = w.get_ref()
		if o == null or o == a or not is_instance_valid(o):
			continue
		var oa := o as Aircraft
		if oa.telemetry().height_agl > 6.0:
			continue
		var op := layout.to_local(oa.global_position)
		op.y = 0.0
		if op.distance_to(pos) > TAXI_GAP + 10.0:
			continue
		for sp in samples:
			if sp.distance_to(op) < TAXI_CLEAR:
				# Gegenseitig blockiert: der mit der kleineren Kennung fährt.
				var oph = oa.get_meta("airfield_phases", null)
				if oph is AirfieldPhases and oph != self and oph._path_blocks(op, pos) \
						and a.entity_id < oa.entity_id:
					return false
				return true
	return false


## Liegt p auf meinem nächsten Wegstück (für gegenseitige Blockade)?
func _path_blocks(me: Vector3, p: Vector3) -> bool:
	if phase != Phase.TAXI_OUT and phase != Phase.TAXI_IN and phase != Phase.TAKEOFF:
		return false
	var dir := Vector3.ZERO
	if _path_i + 1 < _path.size():
		dir = Vector3(_path[_path_i + 1].x - me.x, 0, _path[_path_i + 1].z - me.z)
	var to := p - me
	return to.length() < TAXI_GAP and dir.length() > 0.1 and to.dot(dir.normalized()) > 0.0


# --- Luft (Paket 9b) ----------------------------------------------------------------

## Platzrunde (lokal, Landerichtung = runway_dir = -Z): Gegenanflug auf x = side·PATTERN_X
## von Norden nach Süden, Queranflug bei z = FINAL_Z, Endanflug auf der Mittellinie.
const PATTERN_X := 900.0
const FINAL_Z := 2500.0
const TOUCHDOWN_PAST := 60.0          # Aufsetzpunkt hinter der Schwelle (m)
const GLIDE_DEG := 4.0
const FLARE_AGL := 7.0
const DOWNWIND_SPEED := 210.0 / 3.6
const BASE_SPEED := 180.0 / 3.6
## Durchstarten, wenn die Piste bis hierhin (m vor dem Aufsetzpunkt) nicht frei ist.
const RUNWAY_NEEDED := 1300.0


func _field_h() -> float:
	return WorldGround.height_at(layout.center.x, layout.center.z)


func _rtb(a: Aircraft, i: PilotIntent, _dt: float) -> bool:
	var p := layout.to_local(a.global_position)
	var side := layout.pattern_side
	var entry := Vector3(side * PATTERN_X, 0, -600.0)
	var to := Vector3(entry.x - p.x, 0, entry.z - p.z)
	var d := to.length()
	# Höhe: Platzrunde, unterwegs mindestens 150 m über dem Gelände voraus.
	var want_h := layout.pattern_altitude
	if d > 2500.0:
		var fwd := _flat(to)
		for k in [500.0, 1000.0, 2000.0, 3000.0]:
			var q: Vector3 = a.global_position + fwd * k
			want_h = maxf(want_h, WorldGround.height_at(q.x, q.z) - _field_h() + 150.0)
	_fly(a, i, to, want_h, DOWNWIND_SPEED if d < 4000.0 else 260.0 / 3.6, 35.0)
	i.gear_down = false
	i.flaps = 0.0
	if d < 700.0:
		set_phase(Phase.PATTERN)
	return true


func _pattern(a: Aircraft, i: PilotIntent, _dt: float) -> bool:
	var p := layout.to_local(a.global_position)
	var side := layout.pattern_side
	match _sub:
		0:   # Gegenanflug (nach Süden, +Z)
			var aim := Vector3(side * PATTERN_X, 0, p.z + 900.0)
			_fly(a, i, Vector3(aim.x - p.x, 0, aim.z - p.z), layout.pattern_altitude, DOWNWIND_SPEED, 30.0)
			i.gear_down = false
			if p.z > FINAL_Z - 450.0:
				_sub = 1
		1:   # Queranflug (nach Westen), Fahrwerk und Klappen
			var aim := Vector3(-side * 700.0, 0, FINAL_Z)
			_fly(a, i, Vector3(aim.x - p.x, 0, aim.z - p.z), 200.0, BASE_SPEED, 30.0)
			i.gear_down = true
			i.flaps = 0.5
			# Kurve auf den Endanflug rechtzeitig einleiten (Kurvenradius bei 35° ~ 400 m)
			var r_turn := t_speed_sq(a) / (9.81 * tan(deg_to_rad(35.0)))
			if absf(p.x) < r_turn + 60.0:
				set_phase(Phase.LANDING)
	return true


func _landing(a: Aircraft, i: PilotIntent, dt: float) -> bool:
	var t := a.telemetry()
	var b := a.global_transform.basis
	var p := layout.to_local(a.global_position)
	var rdir := layout.runway_dir()
	var td := layout.runway_start + rdir * TOUCHDOWN_PAST
	var to_td := (td - p).dot(rdir)                     # m bis zum Aufsetzpunkt (> 0 = davor)
	var along := (p - layout.runway_start).dot(rdir)
	var h := a.global_position.y - _field_h()
	i.gear_down = true
	match _sub:
		0:   # Endanflug
			if runway != null and not runway.request(a) and to_td < RUNWAY_NEEDED:
				return _go_around(a, i, "Piste belegt")
			i.flaps = 1.0 if t.airspeed < 210.0 / 3.6 else 0.5
			var gp := maxf(to_td * tan(deg_to_rad(GLIDE_DEG)), 0.0) + 2.0
			var want_vs := -t.airspeed * tan(deg_to_rad(GLIDE_DEG)) + clampf((gp - h) * 0.2, -2.5, 2.5)
			want_vs = clampf(want_vs, -4.0 if t.height_agl > GO_AROUND_CHECK_AGL + 30.0 else -3.3, 2.0)
			i.throttle = clampf(0.3 + (APPROACH_SPEED - t.airspeed) * 0.06, 0.0, 1.0)
			i.pitch = clampf((want_vs - t.climb_rate) * 0.12, -1.0, 1.0)
			var aim := layout.runway_start + rdir * (along + clampf(to_td * 0.2, 120.0, 500.0))
			var lat_bank := 35.0 if t.height_agl > 100.0 else (14.0 if t.height_agl > 40.0 else 6.0)
			_level_turn(a, i, Vector3(aim.x - p.x, 0, aim.z - p.z), lat_bank)
			var lat := absf(p.x - layout.runway_start.x)
			if t.height_agl < GO_AROUND_CHECK_AGL and t.height_agl > FLARE_AGL + 3.0 \
					and t.climb_rate < -GO_AROUND_SINK:
				return _go_around(a, i, "Sinkrate")
			if t.height_agl < 40.0 and lat > layout.runway_width * 0.5:
				return _go_around(a, i, "Versatz")
			if to_td < -350.0 and not t.on_ground:
				return _go_around(a, i, "zu lang")
			if t.height_agl < FLARE_AGL:
				_sub = 1
		1:   # Abfangen
			i.flaps = 1.0
			i.throttle = 0.0
			var want_vs := -0.7 if t.height_agl > 1.0 else -0.3
			i.pitch = clampf((want_vs - t.climb_rate) * 0.15, -1.0, 1.0)
			var aim := layout.runway_start + rdir * (along + 300.0)
			_level_turn(a, i, Vector3(aim.x - p.x, 0, aim.z - p.z), 4.0)
			i.yaw = _roll_yaw(a, layout.to_scene(aim) - a.global_position) * 0.5
			if t.wheels_in_contact > 0:
				_sub = 2
			if to_td < -450.0:
				return _go_around(a, i, "zu lang")
		2:   # Ausrollen und Bremsen, Knüppel gezogen (Spornrad unten)
			i.flaps = 1.0
			i.throttle = 0.0
			i.pitch = 0.7
			var aim := layout.runway_start + rdir * (along + 80.0)
			i.yaw = _roll_yaw(a, layout.to_scene(aim) - a.global_position)
			i.roll = clampf(b.x.y * 2.5, -1.0, 1.0)
			var herr := absf(rad_to_deg(_flat(-b.z).angle_to(rdir)))
			i.brakes = clampf((25.0 - t.airspeed) * 0.08, 0.0, 0.6) if herr < 8.0 else 0.0
			if t.airspeed < 6.0:
				set_phase(Phase.TAXI_IN)
	i.clamp_values()
	return true


static func t_speed_sq(a: Aircraft) -> float:
	return a.telemetry().airspeed * a.telemetry().airspeed


func _go_around(a: Aircraft, i: PilotIntent, why: String) -> bool:
	go_arounds += 1
	if trace_enabled:
		trace.append("%.1f:Durchstarten (%s)" % [_ticks / 60.0, why])
	_release()
	set_phase(Phase.PATTERN)
	_sub = 3
	return _pattern_climbout(a, i)


## Durchstarten: Vollgas, steigen auf Pistenkurs, dann Gegenanflug.
func _pattern_climbout(a: Aircraft, i: PilotIntent) -> bool:
	var t := a.telemetry()
	i.throttle = 1.0
	i.flaps = 0.5 if t.airspeed < 190.0 / 3.6 else 0.0
	i.gear_down = t.height_agl < 30.0
	var rdir := layout.runway_dir()
	_fly(a, i, rdir, layout.pattern_altitude, 210.0 / 3.6, 15.0, 5.0)
	i.gear_down = t.height_agl < 30.0
	var p := layout.to_local(a.global_position)
	if t.height_agl > 150.0 and (p - layout.runway_start).dot(rdir) > 1200.0:
		set_phase(Phase.RTB)
	return true


## Kurs dir (waagerecht) mit Höhe want_h über Platz und Fahrt v fliegen.
func _fly(a: Aircraft, i: PilotIntent, dir: Vector3, want_h: float, v: float,
		max_bank: float, max_vs: float = 8.0) -> void:
	var t := a.telemetry()
	var h := a.global_position.y - _field_h()
	var want_vs := clampf((want_h - h) * 0.08, -max_vs, max_vs)
	i.pitch = clampf((want_vs - t.climb_rate) * 0.1, -1.0, 1.0)
	i.throttle = clampf(0.55 + (v - t.airspeed) * 0.05, 0.15, 1.0)
	if t.airspeed > 200.0 / 3.6:
		i.flaps = 0.0
	_level_turn(a, i, dir, max_bank)


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


## Lebende Flugzeuge mit Flugplatz-Phasen.
static func fleet() -> Array:
	var out := []
	for w in _fleet:
		var o = w.get_ref()
		if o != null and is_instance_valid(o):
			out.append(o)
	return out


## Abstellplätze von layout, zu denen gerade eine KI zurückkehrt (RTB … TAXI_IN).
static func reserved_spots(l: AirfieldLayout, exclude: Node = null) -> Array:
	var out := []
	for a in fleet():
		if a == exclude:
			continue
		var ph = a.get_meta("airfield_phases", null)
		if ph is AirfieldPhases and ph.layout == l and ph.phase in [Phase.RTB, Phase.PATTERN,
				Phase.LANDING, Phase.TAXI_IN]:
			out.append(ph.parking_index)
	return out


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
