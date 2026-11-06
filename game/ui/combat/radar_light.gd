class_name RadarLight
extends Control
## Radar-Light (nur Arcade): Kreis mit 3 km Reichweite, Nase oben.
## Rot = Feind, Blau = eigene Seite; kleiner Strich oben/unten = deutlich höher/tiefer.

const R := 92.0
const RANGE := HudContacts.RADAR_RANGE

## Blips: [{x, y (−1..1, y negativ = voraus), hostile, dz}]
var blips: Array = []


func _init() -> void:
	name = "RadarLight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Kontakte → Radar-Koordinaten relativ zu Lage/Kurs des eigenen Flugzeugs.
static func project(own_xf: Transform3D, contacts: Array, rng := 3000.0) -> Array:
	var fwd := -own_xf.basis.z
	fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = own_xf.basis.y   # senkrecht: Rumpf-Oberseite zeigt nach „vorn“
		fwd.y = 0.0
	fwd = fwd.normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var res := []
	for c in contacts:
		var rel: Vector3 = (c.pos as Vector3) - own_xf.origin
		var flat := Vector2(rel.dot(right), -rel.dot(fwd)) / rng
		if flat.length() > 1.0:
			continue
		res.append({"x": flat.x, "y": flat.y, "hostile": c.hostile, "dz": rel.y})
	return res


func _draw() -> void:
	var c := Vector2(R + 8, R + 8)
	draw_circle(c, R, Color(HudStyle.BG, 0.78))
	draw_arc(c, R, 0, TAU, 64, Color(HudStyle.VALUE, 0.18), 1.5, true)
	for k in [1.0 / 3.0, 2.0 / 3.0]:
		draw_arc(c, R * k, 0, TAU, 48, Color(HudStyle.VALUE, 0.07), 1.0, true)
	draw_line(c + Vector2(0, -R), c + Vector2(0, R), Color(HudStyle.VALUE, 0.06), 1.0)
	draw_line(c + Vector2(-R, 0), c + Vector2(R, 0), Color(HudStyle.VALUE, 0.06), 1.0)
	# eigenes Flugzeug
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(5, 5),
			c + Vector2(0, 2), c + Vector2(-5, 5)]), HudStyle.ACCENT)
	for b in blips:
		var p := c + Vector2(b.x, b.y) * R
		var col := HudStyle.ENEMY if b.hostile else HudStyle.FRIEND
		draw_circle(p, 4.0, col)
		if absf(b.dz) > 150.0:
			var dy := -7.0 if b.dz > 0 else 7.0
			draw_line(p + Vector2(0, dy * 0.6), p + Vector2(0, dy * 1.4), col, 2.0)
	HudStyle.text(self, c + Vector2(R - 4, R - 2), "3 km", 11, HudStyle.DIM, false, 2)
