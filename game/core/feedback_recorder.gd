class_name FeedbackRecorder
extends RefCounted
## Feedback-Taste: Ringpuffer der letzten WINDOW_S Sekunden.
##  - Telemetrie des Spielerflugzeugs mit TELE_HZ (vorab angelegtes PackedFloat32Array, keine
##    Allokation je Probe),
##  - Bildrate je Sekunde (Mittel, Minimum),
##  - Spielereignisse (Funk, Treffer, Schäden, Kontextwechsel, Abfertigung) als Text.

const WINDOW_S := 60.0
const TELE_HZ := 10.0
const TELE_ROWS := int(WINDOW_S * TELE_HZ)   # 600
## Spalten der Telemetrie (Reihenfolge = CSV).
const TELE_COLS := ["zeit_s", "x_m", "y_m", "z_m", "hoehe_nn_m", "hoehe_grund_m", "ias_kmh", "tas_kmh",
	"grund_kmh", "nick_grad", "roll_grad", "kurs_grad", "g", "gas", "drehzahl_upm", "kuehlmittel_c",
	"wind_x_ms", "wind_y_ms", "wind_z_ms"]
const NC := 19
const FPS_SLOTS := 60
const EVENT_MAX := 400

var tele := PackedFloat32Array()
var tele_head := 0     # nächster Schreibplatz
var tele_count := 0
var _tele_acc := 0.0

## je Sekunde: [Mittel, Minimum]
var fps := PackedFloat32Array()
var fps_head := 0
var fps_count := 0
var _fps_frames := 0
var _fps_time := 0.0
var _fps_max_dt := 0.0

## [ticks_msec, Spielzeit s, Text]
var events: Array = []


func _init() -> void:
	tele.resize(TELE_ROWS * NC)
	fps.resize(FPS_SLOTS * 2)


func clear() -> void:
	tele.fill(0.0)
	tele_head = 0
	tele_count = 0
	_tele_acc = 0.0
	fps.fill(0.0)
	fps_head = 0
	fps_count = 0
	_fps_frames = 0
	_fps_time = 0.0
	_fps_max_dt = 0.0
	events.clear()


## Kopie im Moment des Tastendrucks (Arrays kopieren, keine Formatierung).
func freeze() -> FeedbackRecorder:
	var r := FeedbackRecorder.new()
	r.tele = tele.duplicate()
	r.tele_head = tele_head
	r.tele_count = tele_count
	r.fps = fps.duplicate()
	r.fps_head = fps_head
	r.fps_count = fps_count
	r.events = events.duplicate()
	return r


# --- Telemetrie -------------------------------------------------------------------------------

## Je Physik-Tick aufrufen; schreibt mit TELE_HZ eine Zeile. Rückgabe: Zeile geschrieben.
func tick_telemetry(dt: float, game_t: float, a: Node3D) -> bool:
	_tele_acc += dt
	if _tele_acc < 1.0 / TELE_HZ - 1e-4:
		return false
	_tele_acc = maxf(_tele_acc - 1.0 / TELE_HZ, 0.0)
	if _tele_acc >= 1.0 / TELE_HZ:   # nach langem Frame nicht nachholen
		_tele_acc = 0.0
	if a == null or not is_instance_valid(a) or not a.has_method("telemetry"):
		return false
	write_row(game_t, a)
	return true


func write_row(game_t: float, a: Node3D) -> void:
	var t: FlightTelemetry = a.telemetry()
	var xf := a.global_transform
	var fwd := -xf.basis.z
	var i := tele_head * NC
	tele[i] = game_t
	tele[i + 1] = xf.origin.x
	tele[i + 2] = xf.origin.y
	tele[i + 3] = xf.origin.z
	tele[i + 4] = t.altitude
	tele[i + 5] = t.height_agl
	tele[i + 6] = t.ias * 3.6
	tele[i + 7] = t.airspeed * 3.6
	tele[i + 8] = t.ground_speed * 3.6
	tele[i + 9] = rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0)))
	tele[i + 10] = roll_deg(xf.basis)
	tele[i + 11] = fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0)
	tele[i + 12] = t.g_load
	tele[i + 13] = t.throttle_actual
	tele[i + 14] = engine_rpm(a)
	tele[i + 15] = t.coolant_temp
	tele[i + 16] = t.wind.x
	tele[i + 17] = t.wind.y
	tele[i + 18] = t.wind.z
	tele_head = (tele_head + 1) % TELE_ROWS
	tele_count = mini(tele_count + 1, TELE_ROWS)


## Rollwinkel in Grad (rechts hängend = positiv).
static func roll_deg(b: Basis) -> float:
	var fwd := -b.z
	var right := b.x
	# Querachse gegen die waagerechte Querachse zur Flugrichtung
	var flat_right := fwd.cross(Vector3.UP)
	if flat_right.length_squared() < 1e-6:
		return 0.0
	flat_right = flat_right.normalized()
	return -rad_to_deg(right.signed_angle_to(flat_right, fwd))


## Drehzahl wie im Klangmodell (AircraftSound): aus Gas und Fahrt, 0 bei stehendem Motor.
static func engine_rpm(a: Node) -> float:
	var t: FlightTelemetry = a.telemetry()
	var fm = a.get("flight")
	if fm != null and fm.engine != null and not fm.engine.running and t.throttle_actual <= 0.0:
		return 0.0
	var d = a.get("data")
	var lo: float = d.engine_rpm_idle if d != null else 850.0
	var hi: float = d.engine_rpm_max if d != null else 2800.0
	var r := clampf(0.25 + 0.6 * t.throttle_actual + 0.15 * clampf(t.airspeed / 120.0, 0.0, 1.0), 0.0, 1.0)
	return lerpf(lo, hi, (r - 0.25) / 0.75)


## Zeile k (0 = älteste) als Werte (für CSV und Tests).
func tele_row(k: int) -> PackedFloat32Array:
	var start := (tele_head - tele_count + TELE_ROWS) % TELE_ROWS
	var i := ((start + k) % TELE_ROWS) * NC
	return tele.slice(i, i + NC)


func telemetry_csv() -> String:
	var out := PackedStringArray([";".join(PackedStringArray(TELE_COLS))])
	for k in tele_count:
		var r := tele_row(k)
		var cells := PackedStringArray()
		for c in NC:
			cells.append(("%.2f" if c != 0 else "%.1f") % r[c])
		out.append(";".join(cells))
	return "\n".join(out) + "\n"


# --- Bildrate -----------------------------------------------------------------------------------

## Je Frame mit der echten Frame-Dauer aufrufen.
func tick_fps(real_dt: float) -> void:
	_fps_frames += 1
	_fps_time += real_dt
	_fps_max_dt = maxf(_fps_max_dt, real_dt)
	if _fps_time < 1.0:
		return
	fps[fps_head * 2] = _fps_frames / _fps_time
	fps[fps_head * 2 + 1] = 1.0 / maxf(_fps_max_dt, 1e-4)
	fps_head = (fps_head + 1) % FPS_SLOTS
	fps_count = mini(fps_count + 1, FPS_SLOTS)
	_fps_frames = 0
	_fps_time = 0.0
	_fps_max_dt = 0.0


## [Mittel, Minimum] der letzten 60 s (0, 0 ohne Messung).
func fps_stats() -> Vector2:
	if fps_count == 0:
		return Vector2.ZERO
	var s := 0.0
	var mn := INF
	for k in fps_count:
		s += fps[k * 2]
		mn = minf(mn, fps[k * 2 + 1])
	return Vector2(s / fps_count, mn)


# --- Ereignisse -----------------------------------------------------------------------------------

func add_event(game_t: float, text: String) -> void:
	var now := Time.get_ticks_msec()
	events.append([now, game_t, text])
	var limit := now - int(WINDOW_S * 1000.0)
	var cut := 0
	while cut < events.size() and (int(events[cut][0]) < limit or events.size() - cut > EVENT_MAX):
		cut += 1
	if cut > 0:
		events = events.slice(cut)


func recent_events() -> Array:
	var limit := Time.get_ticks_msec() - int(WINDOW_S * 1000.0)
	return events.filter(func(e): return int(e[0]) >= limit)
