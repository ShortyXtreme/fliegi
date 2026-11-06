class_name KeyGlyphs
extends RefCounted
## Tastensymbole (M3.2): kleine gezeichnete Tastenkappen für Tastatur/Maus und Xbox-Symbole
## (A/B/X/Y, LB/RB/LT/RT, Steuerkreuz, Sticks). Keine Fremd-Icons.
## Gerät: zuletzt benutzte Eingabe (note_input), Belegung aus InputMap (token()).
## Mehrfach-Angaben als Text: "W A S D", "Shift / Strg", "Kreuz ↑ ↓", "linker Stick".

## Zuletzt benutzt: Gamepad?
static var pad := false

const PAD_FACE := {"A": Color(0.42, 0.60, 0.30), "B": Color(0.70, 0.28, 0.22),
	"X": Color(0.30, 0.46, 0.68), "Y": Color(0.80, 0.62, 0.22)}
const KEY_NAMES := {KEY_SHIFT: "Shift", KEY_CTRL: "Strg", KEY_SPACE: "Leertaste", KEY_TAB: "Tab",
	KEY_ESCAPE: "Esc", KEY_ALT: "Alt", KEY_UP: "↑", KEY_DOWN: "↓", KEY_LEFT: "←", KEY_RIGHT: "→"}
const MOUSE_NAMES := {MOUSE_BUTTON_LEFT: "Linksklick", MOUSE_BUTTON_RIGHT: "RMT",
	MOUSE_BUTTON_MIDDLE: "MMT", MOUSE_BUTTON_WHEEL_UP: "Mausrad", MOUSE_BUTTON_WHEEL_DOWN: "Mausrad",
	MOUSE_BUTTON_XBUTTON1: "M4"}
const JOY_NAMES := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y",
	JOY_BUTTON_LEFT_SHOULDER: "LB", JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_BACK: "View", JOY_BUTTON_START: "Menu",
	JOY_BUTTON_DPAD_UP: "Kreuz ↑", JOY_BUTTON_DPAD_DOWN: "Kreuz ↓", JOY_BUTTON_DPAD_LEFT: "Kreuz ←",
	JOY_BUTTON_DPAD_RIGHT: "Kreuz →", JOY_BUTTON_MISC1: "Share"}
const MOUSE_TOKENS := ["Maus", "Linksklick", "RMT", "MMT", "Mausrad", "M4"]


## Gerätewechsel erkennen (aus _input der HUD-Wurzel aufrufen).
static func note_input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.3):
		pad = true
	elif event is InputEventKey or event is InputEventMouseButton:
		pad = false


## Symbol-Text der Aktion für Tastatur/Maus (use_pad false) bzw. Gamepad; "" = nicht belegt.
static func token(action: StringName, use_pad: bool) -> String:
	if not InputMap.has_action(action):
		return ""
	for ev in InputMap.action_get_events(action):
		var t := event_token(ev)
		if t != "" and _is_pad_event(ev) == use_pad:
			return t
	return ""


static func _is_pad_event(ev: InputEvent) -> bool:
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion


static func event_token(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
		return KEY_NAMES.get(k, OS.get_keycode_string(k))
	if ev is InputEventMouseButton:
		return MOUSE_NAMES.get(ev.button_index, "Maus")
	if ev is InputEventJoypadButton:
		return JOY_NAMES.get(ev.button_index, "")
	if ev is InputEventJoypadMotion:
		match ev.axis:
			JOY_AXIS_TRIGGER_RIGHT: return "RT"
			JOY_AXIS_TRIGGER_LEFT: return "LT"
			JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y: return "linker Stick"
			JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y: return "rechter Stick"
	return ""


# --- Zeichnen ------------------------------------------------------------------------------

## Zerlegt eine Angabe in Gruppen (Alternativen, getrennt durch " / ") aus Einzelsymbolen.
static func parse(spec: String) -> Array:
	var groups: Array = []
	for g in spec.split(" / ", false):
		var toks: Array = []
		var s := g.strip_edges()
		if s.begins_with("Kreuz") or s.ends_with("Stick"):
			toks.append(s)
		else:
			for t in s.split(" ", false):
				toks.append(t)
		groups.append(toks)
	return groups


## Breite einer ganzen Angabe.
static func spec_width(spec: String, h: float, is_pad: bool) -> float:
	var w := 0.0
	var groups := parse(spec)
	for gi in groups.size():
		if gi > 0:
			w += h * 0.7
		for ti in groups[gi].size():
			if ti > 0:
				w += h * 0.18
			w += token_width(groups[gi][ti], h, is_pad)
	return w


## Zeichnet eine Angabe ab pos (links, vertikale Mitte). Rückgabe: Breite.
static func draw_spec(ci: CanvasItem, pos: Vector2, spec: String, h: float, is_pad: bool, alpha := 1.0) -> float:
	var x := pos.x
	var groups := parse(spec)
	for gi in groups.size():
		if gi > 0:
			HudStyle.text(ci, Vector2(x + h * 0.35, pos.y + h * 0.2), "/", h * 0.55, Color(HudStyle.DIM, HudStyle.DIM.a * alpha), false, 1)
			x += h * 0.7
		for ti in groups[gi].size():
			if ti > 0:
				x += h * 0.18
			x += draw_token(ci, Vector2(x, pos.y), groups[gi][ti], h, is_pad, alpha)
	return x - pos.x


static func token_width(t: String, h: float, is_pad: bool) -> float:
	if is_pad:
		if PAD_FACE.has(t) or t in ["L3", "R3", "linker Stick", "rechter Stick"] or t.begins_with("Kreuz"):
			return h
		return maxf(HudStyle.text_width(t, h * 0.48, true) + h * 0.6, h * 1.25)
	if t in MOUSE_TOKENS:
		return h * 0.78
	return maxf(HudStyle.text_width(t, h * 0.52, true) + h * 0.55, h)


## Einzelnes Symbol; pos = links, vertikale Mitte. Rückgabe: Breite.
static func draw_token(ci: CanvasItem, pos: Vector2, t: String, h: float, is_pad: bool, alpha := 1.0) -> float:
	var w := token_width(t, h, is_pad)
	var c := pos + Vector2(w * 0.5, 0)
	var r := h * 0.5
	if is_pad and PAD_FACE.has(t):
		ci.draw_circle(c, r, Color(0, 0, 0, 0.35 * alpha))
		ci.draw_circle(c, r - 1.5, Color(PAD_FACE[t], 0.95 * alpha))
		ci.draw_arc(c, r - 1.5, 0, TAU, 32, Color(1, 1, 1, 0.25 * alpha), 1.0, true)
		_centered(ci, c, t, h * 0.56, Color(HudStyle.VALUE, alpha))
	elif is_pad and t.begins_with("Kreuz"):
		_dpad(ci, c, r, t.substr(5).strip_edges(), alpha)
	elif is_pad and t in ["L3", "R3", "linker Stick", "rechter Stick"]:
		ci.draw_circle(c, r, Color(0.16, 0.15, 0.13, 0.92 * alpha))
		ci.draw_arc(c, r - 1, 0, TAU, 32, Color(HudStyle.KEY_FACE, 0.8 * alpha), 1.5, true)
		ci.draw_arc(c, r * 0.62, 0, TAU, 24, Color(HudStyle.KEY_FACE, 0.35 * alpha), 1.0, true)
		_centered(ci, c, "L" if t.begins_with("L") or t.begins_with("l") else "R", h * 0.5,
				Color(HudStyle.KEY_FACE, alpha))
		if t.ends_with("3"):
			ci.draw_circle(c + Vector2(r * 0.72, r * 0.72), r * 0.2, Color(HudStyle.ACCENT, alpha))
	elif is_pad:
		# Schulter/Trigger/Menü: dunkle Kappe mit heller Kante
		var rect := Rect2(pos.x, pos.y - r, w, h)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.15, 0.13, 0.92 * alpha)
		sb.border_color = Color(HudStyle.KEY_FACE, 0.8 * alpha)
		sb.set_border_width_all(1)
		var rad := int(h * 0.5) if t.ends_with("T") else int(h * 0.22)
		sb.corner_radius_top_left = rad
		sb.corner_radius_top_right = rad
		sb.corner_radius_bottom_left = int(h * 0.18)
		sb.corner_radius_bottom_right = int(h * 0.18)
		sb.anti_aliasing = true
		ci.draw_style_box(sb, rect)
		_centered(ci, c, t, h * 0.48, Color(HudStyle.KEY_FACE, alpha))
	elif t in MOUSE_TOKENS:
		_mouse(ci, c, w, h, t, alpha)
	else:
		# Tastenkappe: Elfenbein, Messingkante, dunklere Unterkante
		var rect := Rect2(pos.x, pos.y - r, w, h)
		var base := StyleBoxFlat.new()
		base.bg_color = Color(HudStyle.KEY_EDGE, 0.95 * alpha)
		base.set_corner_radius_all(int(h * 0.18))
		base.anti_aliasing = true
		ci.draw_style_box(base, rect)
		var face := StyleBoxFlat.new()
		face.bg_color = Color(HudStyle.KEY_FACE, 0.96 * alpha)
		face.set_corner_radius_all(int(h * 0.16))
		face.anti_aliasing = true
		ci.draw_style_box(face, Rect2(rect.position + Vector2(1, 1), rect.size - Vector2(2, h * 0.14 + 1)))
		_centered(ci, c - Vector2(0, h * 0.06), t, h * 0.52, Color(HudStyle.KEY_TEXT, alpha))
	return w


static func _centered(ci: CanvasItem, c: Vector2, s: String, size: float, col: Color) -> void:
	var f := HudStyle.font(true)
	var fs := int(round(size))
	var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	# Versalhöhe ≈ 0,72 × Schriftgröße (Inter): Grundlinie so, dass Großbuchstaben mittig sitzen
	ci.draw_string(f, Vector2(c.x - sz.x * 0.5, c.y + size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


static func _dpad(ci: CanvasItem, c: Vector2, r: float, arrows: String, alpha: float) -> void:
	var a := r * 0.4
	var dark := Color(0.16, 0.15, 0.13, 0.92 * alpha)
	var edge := Color(HudStyle.KEY_FACE, 0.75 * alpha)
	var hi := Color(HudStyle.ACCENT, alpha)
	var dim := Color(HudStyle.KEY_FACE, 0.3 * alpha)
	ci.draw_rect(Rect2(c.x - a, c.y - r, a * 2, r * 2), dark)
	ci.draw_rect(Rect2(c.x - r, c.y - a, r * 2, a * 2), dark)
	# Umriss des Kreuzes
	var o := PackedVector2Array([Vector2(-a, -r), Vector2(a, -r), Vector2(a, -a), Vector2(r, -a), Vector2(r, a),
		Vector2(a, a), Vector2(a, r), Vector2(-a, r), Vector2(-a, a), Vector2(-r, a), Vector2(-r, -a),
		Vector2(-a, -a), Vector2(-a, -r)])
	for i in o.size():
		o[i] += c
	ci.draw_polyline(o, edge, 1.0, true)
	# Pfeilspitzen: gewählte Richtungen in Messing, übrige schwach
	var tip := r * 0.82
	var base := r * 0.42
	var w := a * 0.75
	for k in [["↑", Vector2(0, -1)], ["↓", Vector2(0, 1)], ["←", Vector2(-1, 0)], ["→", Vector2(1, 0)]]:
		var d: Vector2 = k[1]
		var n := Vector2(-d.y, d.x)
		var tri := PackedVector2Array([c + d * tip, c + d * base + n * w, c + d * base - n * w])
		ci.draw_colored_polygon(tri, hi if arrows.contains(k[0]) else dim)


static func _mouse(ci: CanvasItem, c: Vector2, w: float, h: float, t: String, alpha: float) -> void:
	var rect := Rect2(c.x - w * 0.42, c.y - h * 0.5, w * 0.84, h)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(HudStyle.KEY_FACE, 0.92 * alpha)
	sb.set_corner_radius_all(int(w * 0.42))
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)
	var split_y := rect.position.y + h * 0.42
	ci.draw_line(Vector2(rect.position.x + 2, split_y), Vector2(rect.end.x - 2, split_y), Color(HudStyle.KEY_TEXT, 0.6 * alpha), 1.0)
	ci.draw_line(Vector2(c.x, rect.position.y + 2), Vector2(c.x, split_y), Color(HudStyle.KEY_TEXT, 0.6 * alpha), 1.0)
	var hi := Color(HudStyle.WARNING.darkened(0.1), alpha)
	var half := Vector2(rect.size.x * 0.5 - 2, split_y - rect.position.y - 3)
	match t:
		"Linksklick":
			ci.draw_rect(Rect2(rect.position + Vector2(2, 3), half), hi)
		"RMT":
			ci.draw_rect(Rect2(Vector2(c.x + 1, rect.position.y + 3), half), hi)
		"MMT", "Mausrad":
			ci.draw_rect(Rect2(c.x - 1.5, rect.position.y + 3, 3, half.y), Color(HudStyle.KEY_TEXT, alpha))
