class_name AircraftStatusPanel
extends Control
## Statuspanel Flugzeug (links unten am Boden): Name, Treibstoff l/% mit Sorte, MG-Munition L/R,
## Zonenskizze (WeaponPanel aus ui/combat), laufende Jobs mit Bearbeiter. Daten: GroundHudData.aircraft_status().

const W := 380.0
const PAD := 14.0
const JOB_H := 22.0

var data := {}
var _sketch: ZoneSketch


class ZoneSketch extends WeaponPanel:
	## Nur die Schadensskizze des Kampf-HUD (Draufsicht 110 × 112).
	func _draw() -> void:
		if not data.is_empty():
			_draw_sketch(Vector2.ZERO)


func _init() -> void:
	name = "AircraftStatusPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sketch = ZoneSketch.new()
	_sketch.position = Vector2(W - PAD - 106, 34)
	_sketch.scale = Vector2(0.96, 0.96)
	add_child(_sketch)


func panel_height() -> float:
	var jobs: Array = data.get("jobs", [])
	return 160.0 + (38.0 + jobs.size() * JOB_H if not jobs.is_empty() else 0.0)


func set_data(d: Dictionary, dt := 0.0) -> void:
	data = d
	_sketch.set_data({"zones": d.get("zones", PackedFloat32Array())}, dt)
	queue_redraw()


func _bar(r: Rect2, f: float, col: Color) -> void:
	draw_rect(r, Color(1, 1, 1, 0.08))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(f, 0, 1), r.size.y)), col)


func _draw() -> void:
	if data.is_empty():
		return
	var h := panel_height()
	HudStyle.draw_panel(self, Rect2(0, 0, W, h), 12)
	HudStyle.text(self, Vector2(PAD, 22), String(data.get("name", "")).to_upper(), 13, HudStyle.LABEL, true)
	var hl: float = data.get("health", 1.0)
	if hl < 0.999:
		HudStyle.text(self, Vector2(W - PAD, 22), "Schaden %d %%" % int(round((1.0 - hl) * 100)), 12,
				WeaponPanel.zone_color(hl), true, 2)
	# Treibstoff
	var x := PAD
	var bw := W - PAD * 2 - 122
	var ff: float = data.get("fuel_frac", 0.0)
	var fcol := HudStyle.VALUE if ff >= 0.25 else (HudStyle.CAUTION if ff > 0.1 else HudStyle.WARNING)
	HudStyle.text(self, Vector2(x, 48), "TREIBSTOFF", 11, HudStyle.DIM)
	var lw := HudStyle.text(self, Vector2(x, 76), GroundHudData.liters(data.get("fuel_l", 0.0)), 24, fcol, true)
	HudStyle.text(self, Vector2(x + lw + 8, 76), "%d %%" % int(round(ff * 100)), 15, HudStyle.LABEL, true)
	var gm: float = data.get("grade_mix", 0.0)
	HudStyle.text(self, Vector2(x + bw, 76), String(data.get("grade", "")), 13,
			HudStyle.CAUTION if gm > 0.02 else HudStyle.LABEL, false, 2)
	_bar(Rect2(x, 84, bw, 5), ff, Color(fcol, 0.8))
	# Munition L/R
	HudStyle.text(self, Vector2(x, 112), "MG-MUNITION", 11, HudStyle.DIM)
	var guns: Array = data.get("guns", [])
	var gw := bw / maxf(guns.size(), 1)
	for i in guns.size():
		var g: Dictionary = guns[i]
		var gx := x + i * gw
		var frac := float(g.ammo) / maxf(float(g.cap), 1.0)
		var col := HudStyle.VALUE if frac >= 0.2 else (HudStyle.CAUTION if g.ammo > 0 else HudStyle.WARNING)
		HudStyle.text(self, Vector2(gx, 138), String(g.label), 13, HudStyle.LABEL, true)
		HudStyle.text(self, Vector2(gx + 18, 138), HudStyle.thousands(g.ammo) if g.ammo > 0 else "LEER", 20, col, true)
		_bar(Rect2(gx, 146, gw - 12, 4), frac, Color(col, 0.8))
	if guns.is_empty():
		HudStyle.text(self, Vector2(x, 138), "keine MG", 14, HudStyle.DIM)
	# Jobs
	var jobs: Array = data.get("jobs", [])
	if jobs.is_empty():
		return
	var y := 168.0
	draw_line(Vector2(PAD, y), Vector2(W - PAD, y), Color(1, 1, 1, 0.08), 1.0)
	HudStyle.text(self, Vector2(PAD, y + 16), "ARBEITEN", 11, HudStyle.DIM)
	y += 18.0
	for j in jobs:
		y += JOB_H
		var blocked: String = j.get("blocked", "")
		var tcol := HudStyle.WARNING if blocked != "" else HudStyle.VALUE
		var tw := HudStyle.text(self, Vector2(PAD, y), String(j.text), 14, tcol, true)
		HudStyle.text(self, Vector2(PAD + tw + 6, y), "· " + (blocked if blocked != "" else String(j.step)), 13,
				HudStyle.WARNING if blocked != "" else HudStyle.LABEL)
		var wcol := HudStyle.ACCENT if j.get("mine", false) else (HudStyle.DIM if j.worker == "frei" else HudStyle.FRIEND)
		HudStyle.text(self, Vector2(W - PAD, y), String(j.worker), 13, wcol, true, 2)
		_bar(Rect2(PAD, y + 4, W - PAD * 2, 2), float(j.progress), Color(HudStyle.ACCENT, 0.6))
