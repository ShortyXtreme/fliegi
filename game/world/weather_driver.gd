class_name WeatherDriver
extends Node
## M3.8: lässt die Wetter-Zeit (Weather.time) mit dem Spiel laufen und gibt den Wind am Boden
## an die Shader (globaler Parameter wind_state: x/z Richtung „wohin“, y Stärke m/s in 10 m
## über Grund, w Böe 0..1) – Gras, Bäume, Wasser. Ein Knoten je Spiel/Menü-Kulisse.
## M3.9: meldet Wetteränderungen (Drehen, Auffrischen/Abflauen, Front) über das Signal changed;
## eine Änderung wird erst gemeldet, wenn sie CONFIRM_S lang besteht (kein Hin und Her).

signal changed(text: String)

const CHECK_S := 15.0
const CONFIRM_S := 60.0

## Bezugspunkt für Böen in den Shadern (Kamera bzw. Spieler); ohne: Ursprung
var focus: Node3D
var _last_state: Array = []
var _pending: Array = []
var _pending_since := 0.0
var _check_t := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_last_state = Weather.report_state(Weather.time) if Weather.enabled() else []
	push_shader_state()


func _physics_process(dt: float) -> void:
	Weather.time += dt
	_check_t += dt
	if _check_t >= CHECK_S:
		_check_t = 0.0
		check_changes()


## Änderungen prüfen (auch von Tests aufgerufen). Gibt die gemeldete Nachricht zurück (oder "").
func check_changes() -> String:
	if not Weather.enabled() or Weather.steady:
		return ""
	var now := Weather.report_state(Weather.time)
	if _last_state.is_empty():
		_last_state = now
		return ""
	if now == _last_state:
		_pending = []
		return ""
	if now != _pending:
		_pending = now
		_pending_since = Weather.time
		# Frontdurchgang sofort melden
		if not (now[2] == 1 and _last_state[2] == 0):
			return ""
	elif Weather.time - _pending_since < CONFIRM_S:
		return ""
	var txt := Weather.change_report(_last_state, now)
	_last_state = now
	_pending = []
	if txt != "":
		changed.emit(txt)
	return txt


func _process(_dt: float) -> void:
	push_shader_state()


func push_shader_state() -> void:
	var p := Vector3.ZERO
	if focus != null and is_instance_valid(focus) and focus.is_inside_tree():
		p = focus.global_position
	var w := Weather.wind_at_agl(p, Weather.REF_H)
	var spd := Vector2(w.x, w.z).length()
	var d := Vector2(w.x, w.z) / spd if spd > 0.01 else Vector2(0, 1)
	var g := clampf(0.5 + Weather.gust_at(Weather.time, p) / (2.0 * Weather.GUST), 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("wind_state", Vector4(d.x, spd, d.y, g))
