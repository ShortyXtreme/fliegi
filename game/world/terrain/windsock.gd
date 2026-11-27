class_name Windsock
extends Node3D
## M3.4: Windsack (Mast + Sack aus drei Ringen orange/weiß/orange), richtet sich nach dem Wind aus
## und hängt bei Flaute schlaff herab. M3.8: zeigt den echten Wind (Weather, Höhe des Sacks über
## Grund, mit Böen): Sack zeigt wohin der Wind weht, ab 7,5 m/s (~15 kn) waagerecht.

const MAST_H := 7.0
const SOCK_LEN := 3.6

var _pivot: Node3D
var _t := 0.0
var _yaw := 0.0
## Zuletzt angezeigter Wind (m/s, waagerecht) – für Tests
var shown_wind := Vector3.ZERO


## Wind am Sack (waagerecht, m/s): [Richtung „wohin“ (Einheitsvektor), Stärke m/s].
func wind_here() -> Array:
	var p := global_position + Vector3(0, MAST_H, 0) if is_inside_tree() else Vector3(0, MAST_H, 0)
	var w := Weather.wind_at_agl(p, MAST_H)
	w.y = 0.0
	var spd := w.length()
	return [w / spd if spd > 0.01 else Vector3.ZERO, spd]


## Hängewinkel des Sacks unter der Waagerechten (Grad): 0 m/s = 75°, ab 7,5 m/s waagerecht.
static func droop_deg(speed: float) -> float:
	return lerpf(75.0, 0.0, clampf(speed / 7.5, 0.0, 1.0))


func _ready() -> void:
	name = "Windsack"
	var white := AirfieldDressing.mat("weiss", Color(0.93, 0.93, 0.9))
	var orange := AirfieldDressing.mat("orange", Color(0.95, 0.45, 0.08))
	var mast := CylinderMesh.new()
	mast.top_radius = 0.06
	mast.bottom_radius = 0.1
	mast.height = MAST_H
	mast.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mast
	mi.material_override = white
	mi.position = Vector3(0, MAST_H * 0.5, 0)
	add_child(mi)
	_pivot = Node3D.new()
	_pivot.position = Vector3(0, MAST_H - 0.2, 0)
	add_child(_pivot)
	# Ring am Mast und drei Abschnitte (Kegelstümpfe) entlang -Z des Pivots
	var r0 := 0.45
	var r1 := 0.2
	for k in 3:
		var a := k / 3.0
		var b := (k + 1) / 3.0
		var cm := CylinderMesh.new()
		cm.top_radius = lerpf(r0, r1, a)
		cm.bottom_radius = lerpf(r0, r1, b)
		cm.height = SOCK_LEN / 3.0
		cm.radial_segments = 10
		cm.cap_top = false
		cm.cap_bottom = false
		var s := MeshInstance3D.new()
		s.mesh = cm
		s.material_override = orange if k != 1 else white
		s.rotation_degrees = Vector3(-90, 0, 0)   # Zylinderachse Y -> -Z
		s.position = Vector3(0, 0, -SOCK_LEN * (a + b) * 0.5)
		_pivot.add_child(s)
	_update(0.0)


func _process(dt: float) -> void:
	_update(dt)


func _update(dt: float) -> void:
	_t += dt
	var w := wind_here()
	var dir: Vector3 = w[0]
	var spd: float = w[1]
	shown_wind = dir * spd
	if spd > 0.05:
		_yaw = lerp_angle(_yaw, atan2(-dir.x, -dir.z), clampf(dt * 2.5, 0.0, 1.0) if dt > 0.0 else 1.0)   # -Z des Pivots zeigt mit dem Wind
	var flutter := sin(_t * (6.0 + spd)) * (0.3 + spd * 0.3)
	_pivot.rotation = Vector3(deg_to_rad(-droop_deg(spd) + flutter * 0.4), _yaw + deg_to_rad(flutter), 0.0)


## Richtung, in die der Sack zeigt (waagerecht, Welt) – für Tests.
func sock_direction() -> Vector3:
	var f := -_pivot.global_transform.basis.z
	f.y = 0.0
	return f.normalized()
