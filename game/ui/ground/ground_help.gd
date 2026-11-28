class_name GroundHelp
extends Control
## F1-Hilfe (M3.2): Tafel je Kontext (Flug / zu Fuß / Fahren) mit Gruppen und Tastensymbolen,
## Tastatur/Maus und Controller nebeneinander; die Spalte des zuletzt benutzten Geräts ist
## hervorgehoben. Wird für den Flug (Hud._help) und am Boden (GroundHud.help) benutzt und
## setzt sich selbst in die Bildschirmmitte.
## groups(ctx)/help_rows(ctx) sind statisch (Tests, spätere Tutorial-Texte).

const W := 1120.0
const PAD := 28.0
const COL_W := 520.0
const ROW := 35.0
const CAP_H := 26.0
const HEAD := 92.0
const GROUP_HEAD := 34.0
const KB_X := 236.0
const PAD_X := 412.0

var context: int = InputBindings.Context.CREW


func _init() -> void:
	name = "GroundHelp"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	z_index = 20   # über Zielmarkern und Hinweisen


## Gruppen: [Titel, Spalte 0/1, [[Aktion, Tastatur, Pad], …]].
## M3.5: Tasten aus der aktuellen Belegung (InputMap, Einstellungen › Tastenbelegung).
static func k(acts, sep := " ") -> String:
	var list: Array = acts if acts is Array else [acts]
	var out := PackedStringArray()
	for a in list:
		var t := KeyGlyphs.token(a, false)
		if t != "" and not out.has(t):
			out.append(t)
	return sep.join(out)


static func p(acts, sep := " ") -> String:
	var list: Array = acts if acts is Array else [acts]
	var out := PackedStringArray()
	for a in list:
		var t := KeyGlyphs.token(a, true)
		if t != "" and not out.has(t):
			out.append(t)
	return sep.join(out)


static func groups(ctx: int) -> Array:
	var general := ["Allgemein", 1, [["Hilfe ein / aus", k(&"help_toggle"), p(&"help_toggle")],
		["Pausenmenü / Maus frei", k(&"release_mouse"), p(&"release_mouse")],
		["Feedback speichern", k(Feedback.ACTION), Feedback.PAD_SPEC],
		["Tutorial: Schritt weiter / beenden", k([&"tutorial_skip", &"tutorial_quit"], " / "), ""]]]
	var radio := ["Funkgerät", 1, [["Funkgerät öffnen / schließen", k(&"crew_wheel"), p(&"crew_wheel")],
		["Kanal 1–4 wählen", k([&"radio_channel_1", &"radio_channel_4"], " – "), "Kreuz ↑↓ + A"],
		["Befehl 1–4", k([&"radio_cmd_1", &"radio_cmd_4"], " – "), p(&"radio_select")],
		["Zurück / Kanal wechseln", k([&"radio_back", &"radio_prev", &"radio_next"], " "), p([&"radio_back", &"radio_prev", &"radio_next"])]]]
	match ctx:
		InputBindings.Context.CREW:
			general[2].append(["Alarmstart (Debug)", k(&"alarm_debug"), ""])
			return [
				["Bewegen", 0, [["Gehen", k([&"crew_move_forward", &"crew_move_left", &"crew_move_back", &"crew_move_right"]), "linker Stick"],
					["Umsehen", "Maus", "rechter Stick"],
					["Sprinten", k(&"crew_sprint"), p(&"crew_sprint")], ["Ego / Third-Person", k(&"crew_view_toggle"), p(&"crew_view_toggle")]]],
				["Arbeiten", 0, [["Interagieren (halten)", k(&"crew_interact"), p(&"crew_interact")], ["Ablegen", k(&"crew_drop"), p(&"crew_drop")],
					["Einsteigen", k(&"crew_enter"), p(&"crew_enter")]]],
				radio, general]
		InputBindings.Context.DRIVE:
			return [
				["Fahren", 0, [["Gas", k(&"drive_throttle"), p(&"drive_throttle")], ["Bremse / rückwärts", k(&"drive_brake"), p(&"drive_brake")],
					["Lenken", k([&"drive_steer_left", &"drive_steer_right"]), "linker Stick"],
					["Handbremse", k(&"drive_handbrake"), p(&"drive_handbrake")], ["Kamera", k(&"camera_next"), p(&"camera_next")]]],
				["Arbeiten", 0, [["Interagieren", k(&"crew_interact"), p(&"crew_interact")],
					["Aussteigen (1 s halten)", k(&"eject_hold"), p(&"eject_hold")]]],
				radio, general]
		_:
			general[2].append_array([["Arcade / Realistisch", k(&"assist_toggle"), p(&"assist_toggle")],
				["Maus-Zielsteuerung", k(&"mouse_aim_toggle"), ""],
				["Neustart Piste / Luft", k([&"reset_runway", &"reset_air"], " / "), ""], ["Treffer-Debug", k(&"debug_toggle"), p(&"debug_toggle")]])
			return [
				["Fliegen", 0, [["Höhenruder", k([&"kb_pitch_down", &"kb_pitch_up"]), "linker Stick"],
					["Querruder", k([&"kb_roll_left", &"kb_roll_right"]), "linker Stick"],
					["Seitenruder", k([&"kb_yaw_left", &"kb_yaw_right"]), p([&"kb_yaw_left", &"kb_yaw_right"])],
					["Gas", k([&"throttle_up", &"throttle_down"], " / "), "Kreuz ↑ ↓"],
					["Motor an / aus", k(&"engine_toggle"), p(&"engine_toggle")],
					["Realistisch: Haupt · Pumpe · Zündung · Anlasser", k([&"master_toggle", &"fuel_pump_toggle", &"magneto_toggle", &"starter_hold"]), "X halten"],
					["Klappen", k(&"flaps_cycle"), p(&"flaps_cycle")], ["Fahrwerk", k(&"gear_toggle"), p(&"gear_toggle")],
					["Bremsen / Parkbremse", k(&"brakes"), p(&"brakes")]]],
				["Kamera", 0, [["Kamera wechseln", k(&"camera_next"), p(&"camera_next")],
					["Umsehen (halten)", k(&"mouse_look"), "rechter Stick"],
					["Zielzoom (halten)", k(&"zoom_hold"), p(&"zoom_hold")]]],
				["Kämpfen", 1, [["Feuer MG", k(&"fire_primary", " / "), p(&"fire_primary")],
					["Sekundärwaffe", k(&"fire_secondary", " / "), p(&"fire_secondary")],
					["Aussteigen / Notausstieg", k(&"eject_hold"), p(&"eject_hold")]]],
				general]


## Kurze Tipps unter der Tafel.
static func tips(ctx: int) -> Array:
	match ctx:
		InputBindings.Context.CREW:
			return ["Am Flugzeug: Interagieren halten = tanken, munitionieren, reparieren.",
				"Funkgerät: erst Kanal (Tankwart, Munition, Reparatur, Bodenpersonal), dann Befehl 1–4."]
		InputBindings.Context.DRIVE:
			return ["Tankwagen neben die Maschine fahren, aussteigen, Schlauch mit Interagieren nehmen."]
		_:
			return ["Beim Start ist die Parkbremse an – sie löst bei mehr als 10 % Gas.",
				"Rütteln + Stall-Warnung: Knüppel nachlassen. Nach der Landung am Abstellplatz aussteigen."]


## Zeilen [Aktion, Tastatur, Pad] aller Gruppen (flach).
static func help_rows(ctx: int) -> Array:
	var out: Array = []
	for g in groups(ctx):
		out.append_array(g[2])
	return out


static func title(ctx: int) -> String:
	return "STEUERUNG – %s" % String(InputBindings.CONTEXT_NAMES.get(ctx, "")).to_upper()


func _col_height(col: int) -> float:
	var h := 0.0
	for g in groups(context):
		if g[1] == col:
			h += GROUP_HEAD + (g[2] as Array).size() * ROW + 10.0
	return h


func panel_height() -> float:
	return HEAD + maxf(_col_height(0), _col_height(1)) + 24.0 + tips(context).size() * 24.0 + 20.0


func _process(_dt: float) -> void:
	if not visible:
		return
	var vs := get_viewport_rect().size
	var s := HudStyle.ui_scale(vs) * minf(1.0, (vs.x - 40.0) / (W * HudStyle.ui_scale(vs)))
	scale = Vector2(s, s)
	position = (vs - Vector2(W, panel_height()) * s) * 0.5
	queue_redraw()


func _draw() -> void:
	var h := panel_height()
	HudStyle.draw_panel(self, Rect2(0, 0, W, h))
	draw_rect(Rect2(1, 1, W - 2, h - 2), Color(HudStyle.BG, 0.6))   # Tafel deckender als Anzeigen
	# Kopf: Titel + Kontext-Reiter
	HudStyle.heading(self, Vector2(PAD, 40), "Steuerung", 22, HudStyle.VALUE)
	var x := PAD + HudStyle.text_width("STEUERUNG", 22, true) + 60.0
	for c in [InputBindings.Context.FLIGHT, InputBindings.Context.CREW, InputBindings.Context.DRIVE]:
		var name_s := String(InputBindings.CONTEXT_NAMES[c])
		var on: bool = c == context
		var tw := HudStyle.text_width(name_s.to_upper(), 13, true) + 30.0
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(HudStyle.ACCENT, 0.22) if on else Color(0, 0, 0, 0)
		sb.border_color = Color(HudStyle.ACCENT, 0.9) if on else Color(HudStyle.BG_EDGE, 0.5)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(3)
		draw_style_box(sb, Rect2(x, 18, tw, 28))
		HudStyle.heading(self, Vector2(x + 15, 37), name_s, 13, HudStyle.ACCENT if on else HudStyle.DIM)
		x += tw + 8.0
	var close_t := "schließen"
	var cx0 := W - PAD - HudStyle.text_width(close_t, 14) - 10.0 - KeyGlyphs.token_width("F1", CAP_H, false)
	cx0 += KeyGlyphs.draw_token(self, Vector2(cx0, 32), "F1", CAP_H, false) + 10.0
	HudStyle.text(self, Vector2(cx0, 37), close_t, 14, HudStyle.DIM)
	HudStyle.rule(self, Vector2(PAD, 62), Vector2(W - PAD, 62))
	# Spalten-Köpfe
	var kb_on := not KeyGlyphs.pad
	for col in 2:
		var cx := PAD + col * (COL_W + 24.0)
		HudStyle.heading(self, Vector2(cx + KB_X, 84), "Tastatur · Maus", 10, HudStyle.ACCENT if kb_on else HudStyle.DIM)
		HudStyle.heading(self, Vector2(cx + PAD_X, 84), "Controller", 10, HudStyle.DIM if kb_on else HudStyle.ACCENT)
	# Gruppen
	var y := [HEAD, HEAD]
	for g in groups(context):
		var col: int = g[1]
		var cx := PAD + col * (COL_W + 24.0)
		var gy: float = y[col] + 22.0
		HudStyle.heading(self, Vector2(cx, gy), String(g[0]), 13, HudStyle.ACCENT)
		HudStyle.rule(self, Vector2(cx + HudStyle.text_width(String(g[0]).to_upper(), 13, true) + 30, gy - 5),
				Vector2(cx + COL_W, gy - 5))
		var ry: float = y[col] + GROUP_HEAD + ROW * 0.5
		for r in g[2]:
			HudStyle.text(self, Vector2(cx, ry + 5), String(r[0]), 15, HudStyle.LABEL)
			if String(r[1]) != "":
				KeyGlyphs.draw_spec(self, Vector2(cx + KB_X, ry), String(r[1]), CAP_H, false, 1.0 if kb_on else 0.7)
			if String(r[2]) != "":
				KeyGlyphs.draw_spec(self, Vector2(cx + PAD_X, ry), String(r[2]), CAP_H, true, 0.7 if kb_on else 1.0)
			else:
				HudStyle.text(self, Vector2(cx + PAD_X + 8, ry + 5), "–", 15, HudStyle.DIM)
			ry += ROW
		y[col] = ry - ROW * 0.5 + 10.0
	# Tipps
	var ty := HEAD + maxf(_col_height(0), _col_height(1)) + 18.0
	HudStyle.rule(self, Vector2(PAD, ty - 4), Vector2(W - PAD, ty - 4))
	for t in tips(context):
		ty += 24.0
		HudStyle.text(self, Vector2(PAD, ty), "›  " + String(t), 14, HudStyle.DIM)
