class_name KeyBar
extends Control
## Tasten-Leiste (M3.2) am unteren Bildrand, Mitte: die 3–6 gerade sinnvollen Aktionen als
## Tastensymbole (Tastatur/Maus bzw. Xbox, je nach zuletzt benutztem Gerät, KeyGlyphs.pad).
## entries_for(state) wählt die Einträge je Kontext; set_entries() zeichnet sie.

const H := 40.0
const CAP_H := 26.0
const GAP := 26.0

## [[aktion: StringName oder Angabe-Text, Beschriftung], …]
var entries: Array = []
var use_pad := false


func _init() -> void:
	name = "KeyBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_entries(e: Array, p: bool) -> void:
	if e != entries or p != use_pad:
		entries = e
		use_pad = p
		queue_redraw()
	visible = not e.is_empty()


## Aktionen je Situation. state: ctx, wheel_open, near_aircraft, carrying, hint_key (Taste, die der
## Interaktionshinweis gerade zeigt), on_ground, speed_kmh, parking_brake, gear_down, agl,
## eject_possible, combat, mouse_free, exit_possible.
static func entries_for(st: Dictionary) -> Array:
	var out: Array = []
	var ctx: int = st.get("ctx", InputBindings.Context.FLIGHT)
	if st.get("wheel_open", false):
		return [["Maus / rechter Stick", "Befehl wählen"], ["Mausrad / Kreuz ← →", "Maschine wechseln"],
			[&"crew_wheel", "loslassen: geben"]]
	match ctx:
		InputBindings.Context.CREW:
			if st.get("carrying", false):
				out.append([&"crew_drop", "Ablegen"])
			if st.get("near_aircraft", false):
				out.append([&"crew_enter", "Einsteigen"])
			else:
				out.append([&"crew_sprint", "Sprinten"])
			out.append([&"crew_wheel", "Befehle"])
			out.append([&"crew_view_toggle", "Ansicht"])
		InputBindings.Context.DRIVE:
			out.append([&"drive_handbrake", "Handbremse"])
			out.append([&"eject_hold", "Aussteigen (halten)"])
			out.append([&"crew_wheel", "Befehle"])
			out.append([&"camera_next", "Kamera"])
		_:
			if st.get("on_ground", false):
				if st.get("parking_brake", false):
					out.append([&"throttle_up", "Gas geben"])
				if st.get("speed_kmh", 0.0) < 5.0:
					out.append([&"eject_hold", "Aussteigen (halten)"])
				else:
					out.append([&"brakes", "Bremsen"])
			else:
				if st.get("combat", false):
					out.append([&"fire_primary", "Feuer"])
					out.append([&"zoom_hold", "Zielzoom"])
				if st.get("eject_possible", false):
					out.append([&"eject_hold", "Notausstieg (halten)"])
				elif st.get("gear_down", false) and st.get("agl", 0.0) > 40.0:
					out.append([&"gear_toggle", "Fahrwerk einfahren"])
				elif not st.get("gear_down", false) and st.get("agl", 999.0) < 150.0:
					out.append([&"gear_toggle", "Fahrwerk ausfahren"])
			out.append([&"camera_next", "Kamera"])
			if st.get("mouse_free", false) and not st.get("pad", false):
				out.append(["Linksklick", "Maus fangen"])
	out.append([&"help_toggle", "Hilfe"])
	return out


func bar_width() -> float:
	var w := 0.0
	for e in entries:
		w += _spec_w(e) + 8.0 + HudStyle.text_width(String(e[1]), 19, true) + GAP
	return maxf(w - GAP + 32.0, 0.0)


func _spec(e: Array) -> String:
	if e[0] is StringName:
		var t := KeyGlyphs.token(e[0], use_pad)
		if t == "" and use_pad:
			t = KeyGlyphs.token(e[0], false)
		return t
	return String(e[0])


func _spec_pad(e: Array) -> bool:
	if e[0] is StringName:
		return use_pad and KeyGlyphs.token(e[0], true) != ""
	return use_pad and String(e[0]).contains(" / ")


func _spec_w(e: Array) -> float:
	var s := _spec(e)
	if e[0] is String and String(e[0]).contains(" / "):
		# Alternativen Maus / Pad: nur die zum Gerät passende Hälfte zeigen
		var parts := String(e[0]).split(" / ")
		s = parts[1] if use_pad else parts[0]
	return KeyGlyphs.spec_width(s, CAP_H, _spec_pad(e))


func _draw() -> void:
	if entries.is_empty():
		return
	var w := bar_width()
	var x := -w * 0.5
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(HudStyle.BG, HudStyle.BG.a * 0.85)
	sb.set_corner_radius_all(int(H * 0.5))
	sb.border_color = Color(HudStyle.BG_EDGE, HudStyle.BG_EDGE.a * 0.8)
	sb.set_border_width_all(1)
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(x, -H * 0.5, w, H))
	x += 16.0
	for e in entries:
		var s := _spec(e)
		if e[0] is String and String(e[0]).contains(" / "):
			var parts := String(e[0]).split(" / ")
			s = parts[1] if use_pad else parts[0]
		x += KeyGlyphs.draw_spec(self, Vector2(x, 0), s, CAP_H, _spec_pad(e))
		x += 8.0
		x += HudStyle.text(self, Vector2(x, 7), String(e[1]), 19, HudStyle.VALUE, true)
		x += GAP
