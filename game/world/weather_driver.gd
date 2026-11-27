class_name WeatherDriver
extends Node
## M3.8: lässt die Wetter-Zeit (Weather.time) mit dem Spiel laufen und gibt den Wind am Boden
## an die Shader (globaler Parameter wind_state: x/z Richtung „wohin“, y Stärke m/s in 10 m
## über Grund, w Böe 0..1) – Gras, Bäume, Wasser. Ein Knoten je Spiel/Menü-Kulisse.

## Bezugspunkt für Böen in den Shadern (Kamera bzw. Spieler); ohne: Ursprung
var focus: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	push_shader_state()


func _physics_process(dt: float) -> void:
	Weather.time += dt


func _process(_dt: float) -> void:
	push_shader_state()


func push_shader_state() -> void:
	var p := Vector3.ZERO
	if focus != null and is_instance_valid(focus) and focus.is_inside_tree():
		p = focus.global_position
	var w := Weather.wind_at_agl(p, Weather.REF_H)
	var spd := Vector2(w.x, w.z).length()
	var d := Vector2(w.x, w.z) / spd if spd > 0.01 else Vector2(0, 1)
	var g := clampf(0.5 + Weather.gust_at(Weather.time, WorldOrigin.to_abs(p)) / (2.0 * Weather.GUST), 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("wind_state", Vector4(d.x, spd, d.y, g))
