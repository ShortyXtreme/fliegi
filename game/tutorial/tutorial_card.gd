class_name TutorialCard
extends Control
## Tutorial-Karte (M3.2): rechts in Bildschirmmitte. Schritt n/7, Titel, kurzer Text, Aufgabenliste
## (erledigt/offen), Fußzeile mit Tastensymbolen zum Überspringen/Beenden. Die Tasten des Schritts
## zeigt die normale Tasten-Leiste (GroundHud.key_override).

const W := 400.0
const PAD := 18.0
const TEXT_SIZE := 15
const LINE := 21.0

var idx := 0
var total := 7
var title := ""
var body := ""
var tasks: Array = []
var done: Array = []
var step_t := 0.0
## M3.3: Fortschritt „View halten“ (0..1) und zuletzt gezeichnetes Gerät.
var hold := 0.0:
	set(v):
		if v != hold:
			hold = v
			queue_redraw()
var _pad := false


func _init() -> void:
	name = "TutorialCard"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 5


func set_step(i: int, n: int, t: String, b: String, task_labels: Array, d: Array) -> void:
	idx = i
	total = n
	title = t
	body = b
	tasks = task_labels
	done = d.duplicate()
	queue_redraw()


func _lines() -> PackedStringArray:
	var f := HudStyle.font(false)
	var out := PackedStringArray()
	var cur := ""
	for w in body.split(" "):
		var cand := w if cur == "" else cur + " " + w
		if f.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, TEXT_SIZE).x > W - PAD * 2:
			out.append(cur)
			cur = w
		else:
			cur = cand
	if cur != "":
		out.append(cur)
	return out


func panel_height() -> float:
	return 74.0 + _lines().size() * LINE + 14.0 + tasks.size() * 28.0 + 66.0


func _process(_dt: float) -> void:
	var vs := get_viewport_rect().size
	var s := HudStyle.ui_scale(vs)
	scale = Vector2(s, s)
	position = Vector2(vs.x - (24.0 + W) * s, vs.y * 0.24)
	queue_redraw()


func _draw() -> void:
	var h := panel_height()
	HudStyle.draw_panel(self, Rect2(0, 0, W, h))
	draw_rect(Rect2(0, 0, 4, h), HudStyle.ACCENT)
	HudStyle.heading(self, Vector2(PAD, 26), "Tutorial · Schritt %d / %d" % [idx + 1, total], 10, HudStyle.ACCENT)
	# Fortschrittspunkte
	for k in total:
		var c := Vector2(W - PAD - (total - 1 - k) * 14.0, 22)
		draw_circle(c, 4.0, HudStyle.ACCENT if k <= idx else Color(HudStyle.VALUE, 0.18))
	HudStyle.text(self, Vector2(PAD, 58), title, 26, HudStyle.VALUE, true)
	var y := 84.0
	for l in _lines():
		HudStyle.text(self, Vector2(PAD, y), l, TEXT_SIZE, HudStyle.LABEL)
		y += LINE
	y += 8.0
	HudStyle.rule(self, Vector2(PAD, y), Vector2(W - PAD, y))
	y += 8.0
	var first_open := done.find(false)
	for k in tasks.size():
		y += 28.0
		var ok: bool = k < done.size() and done[k]
		var cur := k == first_open
		var c := Vector2(PAD + 9, y - 6)
		if ok:
			draw_circle(c, 9.0, HudStyle.OK)
			draw_polyline(PackedVector2Array([c + Vector2(-4, 0), c + Vector2(-1, 3.5), c + Vector2(4.5, -3.5)]),
					HudStyle.KEY_TEXT, 2.0, true)
		else:
			draw_arc(c, 8.5, 0, TAU, 32, HudStyle.ACCENT if cur else Color(HudStyle.LABEL, 0.5), 1.5, true)
		var col := HudStyle.DIM if ok else (HudStyle.VALUE if cur else HudStyle.LABEL)
		HudStyle.text(self, Vector2(PAD + 28, y), String(tasks[k]), 16, col, cur)
	y += 30.0
	var x := PAD
	_pad = KeyGlyphs.pad
	if _pad:
		# M3.3: Controller – View halten = überspringen (mit Füllbalken), Menu → Pausenmenü
		var w := KeyGlyphs.draw_spec(self, Vector2(x, y), "View", 22, true)
		if hold > 0.0:
			draw_rect(Rect2(x, y + 25, w * hold, 3), HudStyle.ACCENT)
		x += w + 8
		x += HudStyle.text(self, Vector2(x, y + 5), "halten: überspringen", 13, HudStyle.DIM) + 18
		x += KeyGlyphs.draw_spec(self, Vector2(x, y), "Menu", 22, true) + 8
		HudStyle.text(self, Vector2(x, y + 5), "Pause › Tutorial beenden", 13, HudStyle.DIM)
		return
	x += KeyGlyphs.draw_spec(self, Vector2(x, y), KeyGlyphs.token(&"tutorial_skip", false), 22, false) + 8
	x += HudStyle.text(self, Vector2(x, y + 5), "Schritt überspringen", 13, HudStyle.DIM) + 18
	x += KeyGlyphs.draw_spec(self, Vector2(x, y), KeyGlyphs.token(&"tutorial_quit", false), 22, false) + 8
	HudStyle.text(self, Vector2(x, y + 5), "Tutorial beenden", 13, HudStyle.DIM)

