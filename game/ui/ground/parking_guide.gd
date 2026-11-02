class_name ParkingGuide
extends Control
## Nach der Landung: Bodenmarke (Ring auf dem Boden, in den Bildschirm projiziert) am zugewiesenen
## Abstellplatz und Richtungspfeil mit Entfernung. Ganzer Bildschirm, zeichnet in Pixeln.

const RING_R := 9.0          # m
const ARROW_Y := 0.24        # Anteil der Bildschirmhöhe
const ARRIVED := 6.0         # m: angekommen

var cam: Camera3D = null
var target := Vector3.ZERO
var from := Vector3.ZERO
var s := 1.0
var active := false


func _init() -> void:
	name = "ParkingGuide"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Peilung des Ziels relativ zur Blickrichtung (rad, + = rechts).
static func relative_bearing(cam_xf: Transform3D, from_pos: Vector3, to_pos: Vector3) -> float:
	var fwd := -cam_xf.basis.z
	fwd.y = 0
	var d := to_pos - from_pos
	d.y = 0
	if fwd.length() < 1e-4 or d.length() < 1e-4:
		return 0.0
	return fwd.normalized().signed_angle_to(d.normalized(), Vector3.DOWN)


func distance() -> float:
	return Vector2(target.x - from.x, target.z - from.z).length()


func _draw() -> void:
	if not active or cam == null or not is_instance_valid(cam):
		return
	var vs := get_viewport_rect().size
	var dist := distance()
	var arrived := dist <= ARRIVED
	var col := HudStyle.OK if arrived else HudStyle.ACCENT
	# Bodenmarke
	var pts := PackedVector2Array()
	var ok := true
	for k in 41:
		var a := k * TAU / 40.0
		var p := target + Vector3(cos(a), 0.05, sin(a)) * RING_R
		if cam.is_position_behind(p):
			ok = false
			break
		pts.append(cam.unproject_position(p))
	if ok and pts.size() > 2:
		draw_polyline(pts, Color(0, 0, 0, 0.45), 6.0 * s, true)
		draw_polyline(pts, Color(col, 0.9), 3.0 * s, true)
		if not cam.is_position_behind(target + Vector3.UP * 3.0):
			var top := cam.unproject_position(target + Vector3.UP * 3.0)
			HudStyle.text(self, top, "ABSTELLPLATZ", 14 * s, col, true, 1)
	if arrived:
		HudStyle.text(self, Vector2(vs.x * 0.5, vs.y * ARROW_Y), "Abstellplatz erreicht – Motor aus, aussteigen",
				18 * s, HudStyle.OK, true, 1)
		return
	# Pfeil
	var c := Vector2(vs.x * 0.5, vs.y * ARROW_Y)
	var rb := relative_bearing(cam.global_transform, from, target)
	var r := 26.0 * s
	var tri := PackedVector2Array([Vector2(0, -r), Vector2(r * 0.62, r * 0.55), Vector2(0, r * 0.25),
		Vector2(-r * 0.62, r * 0.55)])
	var xf := Transform2D(rb, c)
	var out := PackedVector2Array()
	for p in tri:
		out.append(xf * p)
	draw_circle(c, r * 1.45, Color(0.05, 0.07, 0.09, 0.5))
	draw_colored_polygon(out, col)
	HudStyle.text(self, c + Vector2(0, r * 1.45 + 22 * s), "Abstellplatz  " + HudStyle.distance(dist),
			16 * s, HudStyle.VALUE, true, 1)
