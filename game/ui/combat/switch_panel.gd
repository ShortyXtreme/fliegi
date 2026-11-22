class_name SwitchPanel
extends Control
## M3.5: Schalterpanel (Tier I, Messing/Oliv) neben dem Flug-Panel: Hauptschalter, Kraftstoffpumpe,
## Zündung, Gemisch, Anlasser als Kippschalter mit der aktuellen Taste darunter, Motorlampe und die
## letzte Meldung („Motor springt nicht an: Zündung aus“). Sichtbar im Modus Realistisch (am Boden oder
## bei stehendem Motor), im Arcade-Modus nur bei stehendem Motor (dann eine Zeile mit der Motortaste).
## Daten: gather(EngineControl, realistic). CombatHud setzt position/scale.

const W := 340.0
const H_REAL := 146.0
const H_ARCADE := 58.0
const OLIVE := Color(0.20, 0.23, 0.14, 0.9)
const BRASS := Color(0.80, 0.64, 0.32)

var data := {}
var _blink := 0.0


func _init() -> void:
	name = "SwitchPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


static func gather(ec: EngineControl, realistic: bool, on_ground: bool) -> Dictionary:
	if ec == null:
		return {"show": false}
	var st := ec.state()
	st.realistic = realistic
	st.show = (realistic and (on_ground or not ec.is_running())) or (not realistic and not ec.is_running())
	st.next = ec.next_switch_label()
	return st


func panel_height() -> float:
	return H_REAL if data.get("realistic", false) else H_ARCADE


func set_data(d: Dictionary, msg: String, dt: float) -> void:
	data = d
	data.msg = msg
	_blink += dt
	visible = d.get("show", false)
	queue_redraw()


func _switch(x: float, label: String, on: bool, action: StringName, button := false) -> void:
	var cx := x + 26.0
	# Grundplatte und Kippschalter
	draw_circle(Vector2(cx, 52), 13.0, Color(0.08, 0.08, 0.06, 0.95))
	draw_arc(Vector2(cx, 52), 13.0, 0, TAU, 24, Color(BRASS, 0.9), 1.5, true)
	if button:
		draw_circle(Vector2(cx, 52), 8.0 if on else 9.5, Color(0.75, 0.2, 0.15) if on else Color(0.55, 0.14, 0.1))
	else:
		var tip := Vector2(cx, 52 + (-15.0 if on else 15.0))
		draw_line(Vector2(cx, 52), tip, Color(0.85, 0.85, 0.82), 4.0, true)
		draw_circle(tip, 3.5, Color(0.92, 0.92, 0.9))
	HudStyle.text(self, Vector2(cx, 33), "AN" if not button else "", 9, HudStyle.DIM, false, 1)
	HudStyle.heading(self, Vector2(cx, 88), label, 9, HudStyle.ACCENT if on else HudStyle.LABEL, 1)
	var k := KeyGlyphs.token(action, KeyGlyphs.pad and false)
	if k != "":
		var kw := KeyGlyphs.token_width(k, 20, false)
		KeyGlyphs.draw_token(self, Vector2(cx - kw * 0.5, 110), k, 20, false)


func _draw() -> void:
	if data.is_empty() or not data.get("show", false):
		return
	var h := panel_height()
	var sb := StyleBoxFlat.new()
	sb.bg_color = OLIVE
	sb.border_color = Color(BRASS, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(HudStyle.RADIUS + 1)
	draw_style_box(sb, Rect2(0, 0, W, h))
	var phase: int = data.get("phase", 0)
	var lamp := HudStyle.OK if phase == EngineControl.Phase.RUNNING else \
		(HudStyle.CAUTION if phase in [EngineControl.Phase.SPINUP, EngineControl.Phase.CRANK] else Color(0.3, 0.1, 0.08))
	if not data.get("realistic", false):
		draw_circle(Vector2(18, 22), 6.0, lamp)
		HudStyle.heading(self, Vector2(32, 26), "Motor %s" % String(data.get("phase_name", "")), 11, BRASS)
		var k := KeyGlyphs.token(&"engine_toggle", KeyGlyphs.pad)
		var t := "Motor anlassen" if phase == EngineControl.Phase.OFF else "…"
		var kw := KeyGlyphs.draw_token(self, Vector2(18, 45), k, 22, KeyGlyphs.pad)
		HudStyle.text(self, Vector2(26 + kw, 50), t, 14, HudStyle.VALUE, true)
		if String(data.get("msg", "")) != "":
			HudStyle.text(self, Vector2(W - 10, 50), String(data.msg), 11, HudStyle.CAUTION, false, 2)
		return
	HudStyle.heading(self, Vector2(12, 20), "Motor · Elektrik", 10, BRASS)
	draw_circle(Vector2(W - 18, 15), 5.5, lamp)
	HudStyle.text(self, Vector2(W - 30, 20), String(data.get("phase_name", "")), 10, HudStyle.LABEL, false, 2)
	var x := 6.0
	_switch(x, "Haupt", data.master, &"master_toggle")
	_switch(x + 64, "Pumpe", data.fuel_pump, &"fuel_pump_toggle")
	_switch(x + 128, "Zündung", data.magnetos, &"magneto_toggle")
	_switch(x + 192, "Gemisch", data.mixture, &"engine_toggle")
	_switch(x + 256, "Anlasser", data.starter, &"starter_hold", true)
	# Schwungrad-Anzeige ist ein Instrument (Drehzahl des Anlassers), keine Aufgabe
	var msg := String(data.get("msg", ""))
	if msg == "" and String(data.get("next", "")) != "" and phase == EngineControl.Phase.OFF:
		msg = "Als Nächstes: %s" % data.next
	if msg != "":
		HudStyle.text(self, Vector2(W * 0.5, h - 6), msg, 11, HudStyle.CAUTION if msg.contains("nicht") else HudStyle.LABEL, false, 1)
