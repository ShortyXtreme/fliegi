class_name CommandWheel
extends Control
## Befehlsrad (Tab bzw. LB halten), M3.5 mit Ebenen: „Fahrzeuge“ (Tankwagen/Munitionswagen
## kommen bzw. zurück), je Mechaniker eine Ebene (Tanken, Aufmunitionieren, Reparieren, Voll
## abfertigen …) und „Alle Mechaniker“. Oben die Ebenen-Reiter (Mausrad bzw. Steuerkreuz ↑↓ / RB
## wechselt), in der Mitte die Zielmaschine (Rechtsklick bzw. Steuerkreuz ←→ wechselt). Auswahl per
## Mausbewegung oder rechtem Stick, Loslassen löst den Befehl aus (Signal command_chosen).

signal command_chosen(cmd: int, target: Node, crew: Node)

const R_OUT := 215.0
const R_IN := 82.0
const SELECT_DEADZONE := 28.0      # Maus: Mindestauslenkung (px, 1080p)
const STICK_DEADZONE := 0.45
const MAX_VEC := 120.0
const TAB_Y := -R_OUT - 46.0

var is_open := false
var targets: Array = []
var target_index := 0
## Ebenen: [{title, crew (GroundCrewBrain oder null), entries: [{id, label}]}]
var pages: Array = []
var page := 0
var selected := -1
var pad := false
var _vec := Vector2.ZERO


func _init() -> void:
	name = "CommandWheel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	pages = default_pages([])


## Ebenen für eine Mannschaft (Liste von GroundCrewBrain): Fahrzeuge, je Mechaniker, alle.
static func default_pages(crews: Array) -> Array:
	var out := [{title = "Fahrzeuge", crew = null, entries = GroundCrewBrain.wheel_entries(0)}]
	for c in crews:
		if c != null and is_instance_valid(c):
			var n: String = c.crew_name() if c.has_method("crew_name") else String(c.name)
			out.append({title = n, crew = c, entries = GroundCrewBrain.wheel_entries(1)})
	out.append({title = "Alle Mechaniker" if crews.size() > 1 else "Mechaniker", crew = null,
		entries = GroundCrewBrain.wheel_entries(1)})
	return out


func entries() -> Array:
	return pages[clampi(page, 0, pages.size() - 1)].entries if not pages.is_empty() else []


func labels() -> Array:
	return entries().map(func(e): return e.label)


func count() -> int:
	return entries().size()


func page_crew() -> Node:
	if pages.is_empty():
		return null
	var c = pages[clampi(page, 0, pages.size() - 1)].crew
	return c if c != null and is_instance_valid(c) else null


## Segment für eine Richtung (x rechts, y unten wie im Bildschirm); 0 = oben, im Uhrzeigersinn.
static func segment_for(v: Vector2, n: int = 8) -> int:
	var ang := fposmod(atan2(v.x, -v.y), TAU)
	return int(round(ang / (TAU / n))) % n


func open_wheel(t: Array, preferred: Node = null, new_pages: Array = []) -> void:
	targets = t.filter(func(x): return x != null and is_instance_valid(x))
	target_index = maxi(targets.find(preferred), 0)
	if not new_pages.is_empty():
		var old_title: String = pages[page].title if page < pages.size() else ""
		pages = new_pages
		page = 0
		for i in pages.size():
			if pages[i].title == old_title:
				page = i
	selected = -1
	_vec = Vector2.ZERO
	is_open = true
	visible = true
	queue_redraw()


func target() -> Node:
	if targets.is_empty():
		return null
	return targets[clampi(target_index, 0, targets.size() - 1)]


func cycle_target(d: int) -> void:
	if targets.size() > 1:
		target_index = posmod(target_index + d, targets.size())
		queue_redraw()


func cycle_page(d: int) -> void:
	if pages.size() > 1:
		page = posmod(page + d, pages.size())
		selected = segment_for(_vec, count()) if _vec.length() >= SELECT_DEADZONE else -1
		queue_redraw()


func feed_mouse(rel: Vector2) -> void:
	_vec = (_vec + rel).limit_length(MAX_VEC)
	selected = segment_for(_vec, count()) if _vec.length() >= SELECT_DEADZONE else -1
	queue_redraw()


func feed_stick(v: Vector2) -> void:
	if v.length() >= STICK_DEADZONE:
		selected = segment_for(v, count())
		_vec = v * MAX_VEC
		queue_redraw()


## Befehl des gewählten Segments (oder -1).
func selected_command() -> int:
	var e := entries()
	return int(e[selected].id) if selected >= 0 and selected < e.size() else -1


## Schließt das Rad; mit commit und gültiger Auswahl wird command_chosen gesendet. Rückgabe: Befehl oder -1.
func close_wheel(commit := true) -> int:
	var cmd := selected_command() if commit else -1
	is_open = false
	visible = false
	selected = -1
	if cmd >= 0:
		command_chosen.emit(cmd, target(), page_crew())
	return cmd


func _draw() -> void:
	if not is_open:
		return
	var n := count()
	if n == 0:
		return
	var seg := TAU / n
	var labs := labels()
	# Ebenen-Reiter oben
	_draw_tabs()
	# Hintergrund-Ring
	draw_circle(Vector2.ZERO, R_OUT + 6, Color(HudStyle.BG, 0.86))
	draw_arc(Vector2.ZERO, R_OUT + 6, 0, TAU, 96, HudStyle.BG_EDGE, 1.5, true)
	for i in n:
		var a0 := -PI * 0.5 + (i - 0.5) * seg + 0.012
		var a1 := a0 + seg - 0.024
		var col := Color(HudStyle.VALUE, 0.07)
		if i == selected:
			col = Color(HudStyle.ACCENT, 0.9)
		var pts := PackedVector2Array()
		for k in 13:
			var a := lerpf(a0, a1, k / 12.0)
			pts.append(Vector2(cos(a), sin(a)) * R_OUT)
		for k in 13:
			var a := lerpf(a1, a0, k / 12.0)
			pts.append(Vector2(cos(a), sin(a)) * (R_IN + 4))
		draw_colored_polygon(pts, col)
		var mid := -PI * 0.5 + i * seg
		var p := Vector2(cos(mid), sin(mid)) * (R_IN + R_OUT) * 0.5
		var words: PackedStringArray = String(labs[i]).split(" ")
		var lines: Array = []
		if words.size() > 1 and HudStyle.text_width(labs[i], 16, true) > 104:
			var cut := 1 if words.size() >= 3 else words.size() - 1
			lines = [" ".join(words.slice(0, cut)), " ".join(words.slice(cut))]
		elif HudStyle.text_width(labs[i], 16, true) > 118 and String(labs[i]).length() > 12:
			var w: String = labs[i]           # langes Einzelwort: an der Wortfuge trennen
			var cut := w.length() / 2
			lines = [w.substr(0, cut) + "-", w.substr(cut)]
		else:
			lines = [labs[i]]
		var tc := HudStyle.KEY_TEXT if i == selected else Color(HudStyle.VALUE, 0.85)
		var y0 := p.y + 6 - (lines.size() - 1) * 9.0
		for li in lines.size():
			HudStyle.text(self, Vector2(p.x, y0 + li * 19.0), lines[li], 16, tc, i == selected, 1)
	# Zeiger
	if _vec.length() > 4.0:
		var dir := _vec.normalized()
		draw_line(dir * (R_IN - 10), dir * (R_IN + 2), HudStyle.ACCENT, 3.0, true)
	# Mitte: Zielmaschine
	draw_circle(Vector2.ZERO, R_IN, Color(HudStyle.BG, 0.92))
	draw_arc(Vector2.ZERO, R_IN, 0, TAU, 48, HudStyle.BG_EDGE, 1.5, true)
	HudStyle.heading(self, Vector2(0, -22), "Ziel", 10, HudStyle.DIM, 1)
	var t := target()
	HudStyle.text(self, Vector2(0, 2), GroundHudData.aircraft_name(t) if t != null else "keins", 17,
			HudStyle.VALUE if t != null else HudStyle.DIM, true, 1)
	if targets.size() > 1:
		HudStyle.text(self, Vector2(0, 24), "◀ %s ▶" % ("Kreuz" if pad else "Rechtsklick"), 12, HudStyle.LABEL, false, 1)
	# Zustand des Mechanikers dieser Ebene
	var c := page_crew()
	if c != null and c.has_method("status"):
		var st: Dictionary = c.status()
		var s := String(st.text)
		if float(st.progress) >= 0.0:
			s += " – %d %%" % int(round(float(st.progress) * 100.0))
		HudStyle.text(self, Vector2(0, R_OUT + 34), s, 15, HudStyle.LABEL, false, 1)


func _draw_tabs() -> void:
	if pages.size() <= 1:
		return
	var gap := 10.0
	var widths: Array = []
	var total := 0.0
	for pg in pages:
		var w := HudStyle.text_width(String(pg.title).to_upper(), 12, true) + HudStyle.HEADING_SPACING * String(pg.title).length() + 24.0
		widths.append(w)
		total += w + gap
	total -= gap
	var x := -total * 0.5
	for i in pages.size():
		var r := Rect2(x, TAB_Y - 16, widths[i], 30)
		var sb := StyleBoxFlat.new()
		var cur := i == page
		sb.bg_color = Color(HudStyle.ACCENT, 0.85) if cur else Color(HudStyle.BG, 0.86)
		sb.border_color = HudStyle.BG_EDGE
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(HudStyle.RADIUS)
		draw_style_box(sb, r)
		HudStyle.heading(self, Vector2(r.position.x + r.size.x * 0.5, TAB_Y + 4), String(pages[i].title), 12,
				HudStyle.KEY_TEXT if cur else HudStyle.LABEL, 1)
		x += widths[i] + gap
	HudStyle.text(self, Vector2(0, TAB_Y - 26), "Ebene: %s" % ("Kreuz ↑↓ / RB" if pad else "Mausrad"), 13,
			HudStyle.LABEL, false, 1)
