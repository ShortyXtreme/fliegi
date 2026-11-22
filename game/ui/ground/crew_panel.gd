class_name CrewPanel
extends Control
## M3.5: Mannschafts-Panel (links, über dem Statuspanel): je KI-Mechaniker eine Zeile
## „Mechaniker A · tankt – 60 %“ mit Balken, darunter die letzte Funkmeldung (8 s).
## Daten: gather(brains, dispatch).

const W := 380.0
const PAD := 14.0
const ROW_H := 24.0
const REPORT_SHOW := 8.0

var data := {}
var _report := ""
var _report_t := 0.0


func _init() -> void:
	name = "CrewPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## {rows: [{name, text, progress}], report: String}
static func gather(brains: Array, dispatch: Node) -> Dictionary:
	var rows := []
	for b in brains:
		if b == null or not is_instance_valid(b) or not b.has_method("status"):
			continue
		var st: Dictionary = b.status()
		rows.append({name = b.crew_name(), text = String(st.text), progress = float(st.progress)})
	var rep := ""
	if dispatch != null and is_instance_valid(dispatch):
		var r = dispatch.get("reports")
		if r is Array and not (r as Array).is_empty():
			rep = String(r[-1])
	return {rows = rows, report = rep}


## Zeile als Text („Mechaniker A: tankt – 60 %“).
static func row_text(r: Dictionary) -> String:
	var s := "%s: %s" % [r.name, r.text]
	if float(r.progress) >= 0.0:
		s += " – %d %%" % int(round(float(r.progress) * 100.0))
	return s


func panel_height() -> float:
	var rows: Array = data.get("rows", [])
	return 30.0 + rows.size() * ROW_H + (22.0 if _report_t > 0.0 else 0.0)


func set_data(d: Dictionary, dt := 0.0) -> void:
	var rep: String = d.get("report", "")
	if rep != "" and rep != _report:
		_report_t = REPORT_SHOW
	_report = rep
	_report_t = maxf(_report_t - dt, 0.0)
	data = d
	queue_redraw()


func _draw() -> void:
	var rows: Array = data.get("rows", [])
	if rows.is_empty():
		return
	HudStyle.draw_panel(self, Rect2(0, 0, W, panel_height()), 10)
	HudStyle.heading(self, Vector2(PAD, 20), "MANNSCHAFT", 10)
	var y := 26.0
	for r in rows:
		y += ROW_H
		var nw := HudStyle.text(self, Vector2(PAD, y - 4), String(r.name), 14, HudStyle.LABEL, true)
		var busy: bool = r.text != "bereit" and r.text != "Pause"
		HudStyle.text(self, Vector2(PAD + nw + 8, y - 4), String(r.text), 14,
				HudStyle.VALUE if busy else HudStyle.DIM, false)
		var p: float = r.progress
		if p >= 0.0:
			HudStyle.text(self, Vector2(W - PAD, y - 4), "%d %%" % int(round(p * 100.0)), 14, HudStyle.VALUE, true, 2)
			var bar := Rect2(PAD, y + 1, W - PAD * 2, 2)
			draw_rect(bar, Color(HudStyle.VALUE, 0.08))
			draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(p, 0, 1), 2)), Color(HudStyle.ACCENT, 0.7))
	if _report_t > 0.0:
		var a := clampf(_report_t, 0.0, 1.0)
		HudStyle.text(self, Vector2(PAD, y + 20), "Funk · " + _report, 12, Color(HudStyle.ACCENT, a), false)
