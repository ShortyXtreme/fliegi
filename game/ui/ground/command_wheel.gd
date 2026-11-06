class_name CommandWheel
extends Control
## Befehlsrad (Tab bzw. LB halten): 8 Befehle aus GroundCrewBrain.COMMAND_LABELS rund um die
## Mitte, in der Mitte die Zielmaschine (Mausrad / Steuerkreuz ←→ wechselt). Auswahl per
## Mausbewegung oder rechtem Stick, Loslassen löst den Befehl aus (Signal command_chosen).

signal command_chosen(cmd: int, target: Node)

const R_OUT := 215.0
const R_IN := 82.0
const SELECT_DEADZONE := 28.0      # Maus: Mindestauslenkung (px, 1080p)
const STICK_DEADZONE := 0.45
const MAX_VEC := 120.0

var is_open := false
var targets: Array = []
var target_index := 0
var selected := -1
var pad := false
var _vec := Vector2.ZERO


func _init() -> void:
	name = "CommandWheel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


static func labels() -> Array:
	return GroundCrewBrain.COMMAND_LABELS


static func count() -> int:
	return GroundCrewBrain.COMMAND_LABELS.size()


## Segment für eine Richtung (x rechts, y unten wie im Bildschirm); 0 = oben, im Uhrzeigersinn.
static func segment_for(v: Vector2, n: int = 8) -> int:
	var ang := fposmod(atan2(v.x, -v.y), TAU)
	return int(round(ang / (TAU / n))) % n


func open_wheel(t: Array, preferred: Node = null) -> void:
	targets = t.filter(func(x): return x != null and is_instance_valid(x))
	target_index = maxi(targets.find(preferred), 0)
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


func feed_mouse(rel: Vector2) -> void:
	_vec = (_vec + rel).limit_length(MAX_VEC)
	selected = segment_for(_vec, count()) if _vec.length() >= SELECT_DEADZONE else -1
	queue_redraw()


func feed_stick(v: Vector2) -> void:
	if v.length() >= STICK_DEADZONE:
		selected = segment_for(v, count())
		_vec = v * MAX_VEC
		queue_redraw()


## Schließt das Rad; mit commit und gültiger Auswahl wird command_chosen gesendet. Rückgabe: Befehl oder -1.
func close_wheel(commit := true) -> int:
	var cmd := selected if commit else -1
	is_open = false
	visible = false
	selected = -1
	if cmd >= 0:
		command_chosen.emit(cmd, target())
	return cmd


func _draw() -> void:
	if not is_open:
		return
	var n := count()
	var seg := TAU / n
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
		var words: PackedStringArray = String(labels()[i]).split(" ")
		var lines: Array = []
		if words.size() > 1 and HudStyle.text_width(labels()[i], 16, true) > 104:
			var cut := 1 if words.size() >= 3 else words.size() - 1
			lines = [" ".join(words.slice(0, cut)), " ".join(words.slice(cut))]
		else:
			lines = [labels()[i]]
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
		HudStyle.text(self, Vector2(0, 24), "◀ %s ▶" % ("Kreuz" if pad else "Mausrad"), 12, HudStyle.LABEL, false, 1)
	# Fußzeile: Tasten stehen in der Tasten-Leiste (M3.2)
