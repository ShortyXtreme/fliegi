class_name AlertStack
extends Control
## Meldungszone oben Mitte (M3.2): Flugwarnungen aus FlightPanel.gather (Stufe 1 Vorsicht,
## Stufe 2 Warnung), zentriert untereinander. Stufe-0-Hinweise (Parkbremse, Bremse) zeigt das
## Flug-Panel als kleines Schild. Warnfarben nur hier – sparsam.

var warnings: Array = []
var _blink := 0.0


func _init() -> void:
	name = "AlertStack"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_warnings(w: Array, dt: float) -> void:
	_blink += dt
	var out: Array = []
	for e in w:
		if int(e[1]) >= 1:
			out.append(e)
	warnings = out
	queue_redraw()


func _draw() -> void:
	var y := 0.0
	for e in warnings:
		var lvl: int = e[1]
		if e[2] and fmod(_blink, 0.6) > 0.42:
			y += 44.0
			continue
		var col: Color = HudStyle.WARNING if lvl >= 2 else HudStyle.CAUTION
		var sz := 20.0 if lvl >= 2 else 17.0
		var tw := HudStyle.text_width(String(e[0]).to_upper(), sz, true) + HudStyle.HEADING_SPACING * String(e[0]).length()
		var r := Rect2(-tw * 0.5 - 22, y, tw + 44, 36)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.05, 0.03, 0.78) if lvl >= 2 else Color(HudStyle.BG, 0.78)
		sb.border_color = Color(col, 0.9)
		sb.set_border_width_all(1)
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.set_corner_radius_all(HudStyle.RADIUS)
		draw_style_box(sb, r)
		HudStyle.heading(self, Vector2(0, y + 25), String(e[0]), sz, col, 1)
		y += 44.0
