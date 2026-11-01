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
const RETREAT_FUEL := 0.12
## Höchstlast bei G-Nutzung 1,0 (Rekrut 0,6 → 5,4 g, Veteran 0,95 → 8,6 g).
const MAX_G := 9.0
## Bodenschutz-Vorausschau (s).
const LOOKAHEAD := [1.0, 2.0, 4.0]
## Kollisionsvermeidung: Mindestabstand im nächsten Punkt (m) und Zeithorizont (s).
const COLLISION_MISS := 30.0
const COLLISION_TIME := 1.5

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
var _was_ahead := true
## Nach jedem Vorbeiflug zufällig (je Seed): vertikal statt flach kurven (bricht Symmetrie).
var _vertical_pref := false
## Patt im Kurvenkampf (beide drehen gleich, keiner kommt ans Heck): nach NEUTRAL_MAX s
## Taktikwechsel für BREAK_TIME s (0 = vertikal, 1 = Umkehrkurve/One-Circle, 2 = Extend).
const NEUTRAL_MAX := 8.0
const BREAK_TIME := 5.0
var _neutral_time := 0.0
var _breaker := -1
var _breaker_time := 0.0
var _breaker_side := Vector3.ZERO
## Ab diesem Winkel Ziel–Nase: Kurvenkampf statt direktem Anzielen (Grad).
const TURN_FIGHT_DEG := 45.0


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
	perception.tracking_delay = _diff.tracking_delay
	if patrol_center == Vector3.INF:
		patrol_center = a.global_position
	if home == Vector3.INF:
		home = patrol_center
	_intent.gear_down = false
	_intent.flaps = 0.0
	_intent.brakes = 0.0


## Zuletzt gelieferter Intent (Tests/Diagnose, nur lesen).
func last_intent() -> PilotIntent:
	return _intent


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
		_:
			dir = _patrol_dir(a)
	dir = _avoid_collision(a, dir)
	var s := _steer(b, dir.normalized(), state == State.PURSUIT or state == State.FIRE)
	# G-Nutzung: Ziehen auf g_use × MAX_G begrenzen (Arcade: Knüppel = Nickrate).
	var v := maxf(a.telemetry().airspeed, 30.0)
	var stick_max := clampf(g_scale * MAX_G * 9.81 / (v * a.data.arcade_max_pitch_rate), 0.1, 1.0)
	i.pitch = minf(s.x, stick_max)
	i.roll = s.y
	i.yaw = s.z
	return i.clamp_values()


## Grob: Autopilot.steer_to_direction. Fein (Zielen, < FINE_DEG): Wunsch-Drehraten aus
## Winkelfehler (Zeitkonstante FINE_TAU) plus Vorsteuerung aus der Drehung der Ziel-
## richtung; Nicken direkt (Arcade: Knüppel = Nickrate), seitlich über Querlage
## (koordinierte Kurve) und etwas Seitenruder.
const FINE_DEG := 15.0
const FINE_TAU := 0.3
## Ab dieser Wunsch-Drehrate (rad/s) im Feinmodus: Querlage zum Ziel + Ziehen.
const BANK_TURN_RATE := 0.25
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
	var rate := Vector2(ax, ay) / FINE_TAU + Vector2(ff.x, ff.y)   # Wunsch (Gieren, Nicken)
	var v := maxf(a.telemetry().airspeed, 30.0)
	var fine_v: Vector3
	var big := rate.length()
	if big > BANK_TURN_RATE:
		# Kräftige Drehung nötig: Auftriebsvektor zum Ziel rollen und ziehen.
		var phi := atan2(rate.x, rate.y)        # 0 = Ziel genau "über" der Nase
		if absf(phi) > deg_to_rad(150.0):      # fast genau unten: drücken statt 180° rollen
			phi = phi - signf(phi) * PI
			big = -big
		var pull := big * cos(phi)
		fine_v = Vector3(clampf(pull / d.arcade_max_pitch_rate, -1.0, 1.0),
				clampf((phi * 2.5 + a.telemetry().angular_velocity_local.z * 0.3) \
					/ d.arcade_max_roll_rate, -1.0, 1.0), clampf(ax * 3.0, -1.0, 1.0))
	else:
		var bank := atan2(-b.x.y, b.y.y)
		var bank_want := clampf(atan(rate.x * v / 9.81), -1.45, 1.45)
		fine_v = Vector3(clampf(rate.y / d.arcade_max_pitch_rate, -1.0, 1.0),
				clampf((bank_want - bank) * 3.0 / d.arcade_max_roll_rate, -1.0, 1.0),
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
	if (v < ENERGY_LOW or state == State.ENERGY and v < ENERGY_OK) and not _offensive(a, v):
		return State.ENERGY
	# 5) Kampf
	if target == null:
		return State.PATROL
	var d := a.global_position.distance_to(target.pos)
	if d > ENGAGE_RANGE and state != State.PURSUIT and state != State.FIRE \
			or d > ENGAGE_RANGE * 1.3:
		return State.APPROACH
	return State.FIRE if _burst_left > 0.0 or _fire_window(a) else State.PURSUIT


## Am Heck des Ziels in Schussnähe: trotz geringer Fahrt (bis ENERGY_MIN) dranbleiben.
const ENERGY_MIN := 175.0 / 3.6
func _offensive(a: Aircraft, v: float) -> bool:
	if target == null or v < ENERGY_MIN:
		return false
	var to := target.pos - a.global_position
	if to.length() > 700.0:
		return false
	var aa := rad_to_deg(target.vel.angle_to(to)) if target.vel.length() > 1.0 else 0.0
	return aa < 60.0 and rad_to_deg((-a.global_transform.basis.z).angle_to(to)) < 30.0


func _should_retreat(a: Aircraft) -> bool:
	var w := a.weapons
	if w != null and w.ammo_max() > 0 and float(w.ammo()) / w.ammo_max() < RETREAT_AMMO:
		return true
	var dm := a.damage
	if dm != null and (dm.health_fraction() < RETREAT_HP or dm.is_burning() \
			or dm.is_engine_failed()):
		return true
	return a.telemetry().fuel_fraction < RETREAT_FUEL


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
	# Bei kurzer Entfernung Höhe nicht mehr erzwingen, sondern auf das Ziel zeigen;
	# frontal: seitlichen Versatz für den Vorbeiflug aufbauen (Merge-Management)
	if d < ENGAGE_RANGE * 2.5:
		var aa := rad_to_deg(target.vel.angle_to(to)) if target.vel.length() > 1.0 else 0.0
		if aa > 135.0:
			return (_merge_point(a.global_position, target.pos, target.vel) - a.global_position).normalized()
	if d < ENGAGE_RANGE * 1.2:
		return (aim - a.global_position).normalized() + Vector3.UP * 0.05
	return dir + Vector3.UP * _alt_hold(a, want, 0.3)


## Merge-Punkt: neben dem Ziel (MERGE_OFFSET quer zu seiner Flugrichtung, auf unserer
## Seite, leicht erhöht), damit nach dem Vorbeiflug Raum zum Eindrehen bleibt.
const MERGE_OFFSET := 450.0
func _merge_point(pos: Vector3, tp: Vector3, tv: Vector3) -> Vector3:
	var fwd := tv.normalized() if tv.length() > 1.0 else Vector3.FORWARD
	var rel := pos - tp
	var lat := rel - fwd * rel.dot(fwd)
	lat.y *= 0.3
	if lat.length() < 5.0:
		lat = fwd.cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
	return tp + lat.normalized() * MERGE_OFFSET + Vector3.UP * 80.0


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
	var td := _diff.tracking_delay
	var tp := target.aim_extrapolated(td)
	var tv := target.aim_vel + target.aim_acc * td
	var r := LeadSolver.solve(a.global_position, a.linear_velocity, tp, tv,
			g.x, g.y, target.aim_acc, _diff.fire_range * 2.0, 4)
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


## Spezifische Energiehöhe (m): Höhe + v²/2g.
static func _energy_height(pos: Vector3, vel: Vector3) -> float:
	return pos.y + vel.length_squared() / (2.0 * 9.81)


## Verfolgung (Paket 14, BFM): Modus nach Winkel vom Ziel-Heck (AA) und Annäherung mit
## Hysterese – LAG zum Annähern/Konvertieren ohne Überschießen (hinter das Ziel zielen),
## PURE zum Halten, LEAD nur nahe dem Schussfenster. Kurvenkampf (Ziel weit seitlich):
## Auftriebsvektor aufs Ziel, mit Energievorteil vertikal (High-Yo-Yo), mit Rückstand
## und Höhe Low-Yo-Yo. Schnappschüsse bei Kreuzungen erlaubt, wenn die Ablage passt.
func _pursuit_dir(a: Aircraft, i: PilotIntent, dt: float) -> Vector3:
	var pos := a.global_position
	var tp := target.aim_pos
	var tv := target.aim_vel
	var to := tp - pos
	var d := to.length()
	var los := to / maxf(d, 1.0)
	var closing := -(tv - a.linear_velocity).dot(los)
	# AA: 0° = wir genau hinter dem Ziel, 180° = frontal
	var aa := rad_to_deg(tv.angle_to(to)) if tv.length() > 1.0 else 0.0
	var nose_off := rad_to_deg((-a.global_transform.basis.z).angle_to(to))
	var fire_r := _diff.fire_range
	# Moduswahl mit Hysterese
	match pursuit_mode:
		Pursuit.LEAD:
			if aa > 70.0 or d > fire_r * 2.2 or (d < 90.0 and closing > 10.0):
				pursuit_mode = Pursuit.LAG if d < 1500.0 else Pursuit.PURE
		Pursuit.LAG:
			if aa < 45.0 and d < fire_r * 1.8 and closing < 40.0:
				pursuit_mode = Pursuit.LEAD
			elif d > 1800.0:
				pursuit_mode = Pursuit.PURE
		_:
			if aa < 50.0 and d < fire_r * 1.8:
				pursuit_mode = Pursuit.LEAD
			elif aa > 60.0 and d < 1500.0:
				pursuit_mode = Pursuit.LAG
	var ahead := nose_off < 90.0
	if _was_ahead and not ahead:
		state_time = 0.0
		_vertical_pref = _rng.randf() < 0.5
	_was_ahead = ahead
	# Schnappschuss: passt die Vorhalt-Lösung schon, direkt darauf (auch bei Kreuzung)
	var snap := d < fire_r and nose_off < 12.0 and aa < 150.0
	var dir: Vector3
	var e_adv := _energy_height(pos, a.linear_velocity) - _energy_height(tp, tv)
	var t := a.telemetry()
	# Patt erkennen und mit einem Taktikwechsel brechen
	if _breaker >= 0:
		_breaker_time += dt
		if _breaker_time > BREAK_TIME or (nose_off < 25.0 and aa < 60.0):
			_breaker = -1
			_neutral_time = 0.0
	elif nose_off > 40.0 and aa > 45.0 and d < 1500.0:
		_neutral_time += dt
		if _neutral_time > NEUTRAL_MAX:
			_breaker = _rng.randi() % 3
			_breaker_time = 0.0
			_breaker_side = a.global_transform.basis.x * (1.0 if \
					a.global_transform.basis.x.dot(to) < 0.0 else -1.0)
	else:
		_neutral_time = maxf(_neutral_time - dt * 2.0, 0.0)
	if _breaker >= 0:
		var fwd := _flat(-a.global_transform.basis.z)
		var t0 := a.telemetry()
		i.throttle = 1.0
		_fire_control(a, i, dt)
		match _breaker:
			0:
				if t0.airspeed > 95.0 and t0.height_agl > 400.0:
					return (fwd + Vector3.UP * 1.0).normalized()
				return (to.normalized() + Vector3.UP * 0.2).normalized()
			1:
				# Umkehrkurve: weg vom Ziel drehen (One-Circle statt Two-Circle)
				return (_flat(_breaker_side) + Vector3.UP * 0.15).normalized()
			_:
				return (fwd + Vector3.UP * 0.05).normalized()
	if nose_off > TURN_FIGHT_DEG and not snap:
		# Kurvenkampf: Nase in Richtung des (leicht vorausberechneten) Ziels ziehen;
		# bei großem AA hinter das Ziel (Lag), damit wir am Heck herauskommen.
		var tl := clampf(d / 600.0, 0.2, 1.5)
		# AA < 90°: Vorhalt (Winkel gewinnen); sonst hinter das Ziel (Lag-Versatz,
		# verhindert das Frontal-Pendeln und bringt uns ans Heck)
		var aimp := tp + tv * tl if aa < 90.0 else tp - tv * clampf(d / 400.0, 0.3, 1.2)
		dir = (aimp - pos).normalized()
		if (e_adv > 250.0 or _vertical_pref and state_time < 4.0) and t.airspeed > 110.0 \
				and aa > 60.0:
			dir.y = maxf(dir.y, 0.45)        # High-Yo-Yo / vertikal: Fahrt in Höhe tauschen
		elif e_adv < -250.0 and t.height_agl > 900.0 and t.airspeed < 95.0:
			dir.y = minf(dir.y, -0.25)       # Low-Yo-Yo: Höhe gegen Fahrt
		# keine absteigende Kreisspirale: unterhalb der Patrouillenhöhe nicht nach unten
		if pos.y < patrol_altitude - 300.0:
			dir.y = maxf(dir.y, 0.0 if t.height_agl > 700.0 else 0.15)
		dir = dir.normalized()
		i.throttle = 1.0
		_fire_control(a, i, dt)
		return dir
	# Gas: Abstand im Heckbereich auf ~200 m halten, sonst voll
	i.throttle = clampf(0.75 + (d - 200.0) / 150.0 - closing / 30.0, 0.2, 1.0) \
			if aa < 70.0 else 1.0
	if snap:
		var ls := _lead_dir(a)
		dir = ls if ls != Vector3.ZERO else los
	else:
		match pursuit_mode:
			Pursuit.LAG:
				var lag_t := clampf(d / 350.0, 0.4, 1.5)
				dir = (tp - tv * lag_t) - pos
				if aa > 135.0 and d > 350.0:
					dir = _merge_point(pos, tp, tv) - pos
				if e_adv > 250.0 and closing > 30.0:
					dir += Vector3.UP * d * 0.25   # Überschießen vermeiden: hoch
			Pursuit.PURE:
				dir = to
			_:
				var ld := _lead_dir(a)
				if ld == Vector3.ZERO:
					var tt := d / 800.0
					ld = (tp + tv * tt + target.aim_acc * 0.5 * tt * tt - pos).normalized()
				dir = ld
	dir = dir.normalized()
	# Zielfehler (langsam wandernd, je Schwierigkeit)
	var b := a.global_transform.basis
	dir = (dir + b.x * _noise.x * 0.001 + b.y * _noise.y * 0.001).normalized()
	_fire_control(a, i, dt)
	return dir


var _last_miss := INF
var _miss_limit := 4.0
func _fire_window(a: Aircraft) -> bool:
	_last_miss = INF
	if target == null:
		return false
	var d := a.global_position.distance_to(target.pos)
	if d > fire_range_now(a) or a.weapons == null or a.weapons.ammo() <= 0:
		return false
	if d < 50.0:
		return false
	var ld := _lead_dir(a)
	if ld == Vector3.ZERO:
		return false
	aim_error_deg = rad_to_deg(_aim_err_rad)
	if aim_error_deg > _diff.fire_max_error_deg:
		return false
	# Vorhergesagte Ablage am Ziel (m): Winkelfehler × Entfernung. Frontal strenger.
	var miss := _aim_err_rad * d
	var to := a.global_position - target.aim_pos
	var frontal := target.aim_vel.length() > 1.0 and target.aim_vel.angle_to(to) < deg_to_rad(45.0)
	_miss_limit = _diff.fire_max_miss_frontal_m if frontal else _diff.fire_max_miss_m
	_last_miss = miss
	return miss <= _miss_limit


## M2.1: In einer festgefahrenen Heckverfolgung (gleich schnelles Ziel, kaum Annäherung,
## Ziel fliegt von uns weg) darf die KI bis TAIL_CHASE_RANGE_MUL × fire_range feuern.
## Vorher blieb sie z. B. 560 m hinter einem geradeaus fliegenden Spieler „kleben“
## (fire_range 400 m) und schoss nie – Tester: „kein Schaden erhalten“.
const TAIL_CHASE_RANGE_MUL := 1.6
const TAIL_CHASE_MAX_CLOSING := 25.0
func fire_range_now(a: Aircraft) -> float:
	var r := _diff.fire_range
	if target == null:
		return r
	var to := target.pos - a.global_position
	if target.vel.length() < 1.0 or to.length() < 1.0:
		return r
	var aa := rad_to_deg(target.vel.angle_to(to))
	var closing := (a.linear_velocity - target.vel).dot(to.normalized())
	if aa < 30.0 and closing < TAIL_CHASE_MAX_CLOSING:
		return r * TAIL_CHASE_RANGE_MUL
	return r


## Feuerstöße: Stoß 0,5–1,5 s (je Schwierigkeit), dann Pause; Abbruch, wenn das
## Fenster deutlich verloren geht.
func _fire_control(a: Aircraft, i: PilotIntent, dt: float) -> void:
	in_fire_window = _fire_window(a)
	_pause_left = maxf(_pause_left - dt, 0.0)
	if _burst_left > 0.0:
		if not in_fire_window and (aim_error_deg < 0.0 \
				or aim_error_deg > _diff.fire_max_error_deg * 2.0 or _last_miss > _miss_limit * 1.6):
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
