class_name CompassBand
extends Control
## Kompassband oben Mitte (Nord = −Z). Rote Dreiecke = Peilung erkannter Feinde.

const W := 560.0
const H := 46.0
const PX_PER_DEG := 4.0
const NAMES := {0: "N", 45: "NO", 90: "O", 135: "SO", 180: "S", 225: "SW", 270: "W", 315: "NW"}

var heading := 0.0
## Peilungen (Grad) erkannter Feinde.
var enemy_bearings := PackedFloat32Array()


func _init() -> void:
	name = "CompassBand"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var cx := W * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(HudStyle.BG, 0.78)
	sb.set_corner_radius_all(8)
	draw_style_box(sb, Rect2(0, 0, W, H))
	var half := cx / PX_PER_DEG
	var first := int(floor((heading - half) / 5.0)) * 5
	var last := int(ceil((heading + half) / 5.0)) * 5
	for d in range(first, last + 1, 5):
		var x := cx + (d - heading) * PX_PER_DEG
		if x < 8 or x > W - 8:
			continue
		var dd := posmod(d, 360)
		var fade := 1.0 - pow(absf(x - cx) / cx, 3.0)
		if NAMES.has(dd):
			var big := dd % 90 == 0
			HudStyle.text(self, Vector2(x, 22), NAMES[dd], 16 if big else 13,
					Color(HudStyle.VALUE if big else HudStyle.LABEL, fade), true, 1)
			draw_line(Vector2(x, H - 12), Vector2(x, H - 2), Color(HudStyle.VALUE, 0.75 * fade), 2.0)
		elif dd % 15 == 0:
			HudStyle.text(self, Vector2(x, 21), str(dd), 12, Color(HudStyle.DIM, fade),
					false, 1)
			draw_line(Vector2(x, H - 10), Vector2(x, H - 2), Color(HudStyle.VALUE, 0.5 * fade), 1.5)
		else:
			draw_line(Vector2(x, H - 6), Vector2(x, H - 2), Color(HudStyle.VALUE, 0.35 * fade), 1.0)
	for b in enemy_bearings:
		var diff := wrapf(b - heading, -180.0, 180.0)
		var x := clampf(cx + diff * PX_PER_DEG, 10, W - 10)
		var a := 0.95 if absf(diff) < half else 0.5
		draw_colored_polygon(PackedVector2Array([Vector2(x, H - 9), Vector2(x - 5, H + 1),
				Vector2(x + 5, H + 1)]), Color(HudStyle.ENEMY, a))
	# Kursanzeige in der Mitte
	var txt := "%03d°" % (int(round(heading)) % 360)
	var tw := HudStyle.text_width(txt, 16, true) + 14
	var box := Rect2(cx - tw * 0.5, H + 4, tw, 22)
	var bb := StyleBoxFlat.new()
	bb.bg_color = Color(HudStyle.BG, 0.75)
	bb.set_corner_radius_all(5)
	bb.border_color = Color(HudStyle.ACCENT, 0.55)
	bb.set_border_width_all(1)
	draw_style_box(bb, box)
	HudStyle.text(self, Vector2(cx, H + 21), txt, 16, HudStyle.VALUE, true, 1)
	draw_colored_polygon(PackedVector2Array([Vector2(cx, H - 1), Vector2(cx - 5, H + 4),
			Vector2(cx + 5, H + 4)]), HudStyle.ACCENT)
