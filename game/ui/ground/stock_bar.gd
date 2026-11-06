class_name StockBar
extends Control
## Lagerleiste oben Mitte: Benzin, Ersatz, Munition des eigenen Platzes. Daten: GroundHudData.stock().

const W := 600.0
const H := 46.0

var data := {}


func _init() -> void:
	name = "StockBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(d: Dictionary) -> void:
	data = d
	queue_redraw()


func _cell(x: float, w: float, label: String, value: float, cap: float, unit: String) -> void:
	HudStyle.text(self, Vector2(x, 19), label, 11, HudStyle.DIM)
	var f := value / maxf(cap, 1.0) if cap > 0 else 1.0
	var col := HudStyle.VALUE
	if value <= 0.0:
		col = HudStyle.WARNING
	elif f < 0.15:
		col = HudStyle.CAUTION
	var s := "–" if value < 0 else HudStyle.thousands(value) + unit
	HudStyle.text(self, Vector2(x + w - 12, 21), s, 17, col if value >= 0 else HudStyle.DIM, true, 2)
	var r := Rect2(x, 31, w - 12, 4)
	draw_rect(r, Color(HudStyle.VALUE, 0.08))
	if value > 0 and cap > 0:
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0, 1), r.size.y)), Color(col, 0.75))


func _draw() -> void:
	if data.is_empty():
		return
	HudStyle.draw_panel(self, Rect2(0, 0, W, H), 10)
	var cw := (W - 24.0) / 3.0
	_cell(16, cw, "BENZIN", data.aviation, data.aviation_cap, " l")
	_cell(16 + cw, cw, "ERSATZ", data.ersatz, data.ersatz_cap, " l")
	_cell(16 + cw * 2, cw, "MUNITION 7,92", float(data.ammo), float(data.ammo_cap), "")
	for i in [1, 2]:
		draw_line(Vector2(8 + cw * i, 10), Vector2(8 + cw * i, H - 10), Color(HudStyle.VALUE, 0.08), 1.0)
