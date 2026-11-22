class_name MenuList
extends Control
## Menüliste im Tier-I-Theme (M3.2): Einträge als Schaltflächen oder Optionen (◀ Wert ▶).
## Bedienung: Maus (Zeigen/Klicken), Tastatur (Pfeile, Enter, Esc) und Controller
## (Stick/Steuerkreuz, A, B) über die eingebauten ui_*-Aktionen. Zeichnet selbst (HudStyle).

signal activated(id: String)
signal option_changed(id: String, delta: int)
signal cancelled

const W := 460.0
const ROW := 54.0
const HEAD := 70.0

## [{id, label, note (optional), option: bool, value (Text), slider: float 0..1 (optional)}]
var items: Array = []
var focus := 0
var title := ""
var active := true
## M3.4: Breite, Zeilenhöhe und Beschriftungsspalte je Seite (Einstellungen breiter, Regler rechts).
var w := W
var row := ROW
var label_w := 0.0          ## 0 = ganze Breite (Hauptmenü); sonst feste Spalte für Beschriftungen
## Höchstzahl sichtbarer Zeilen (0 = alle); bei mehr wird mitgescrollt.
var max_rows := 0
var scroll := 0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_items(t: String, list: Array, f := 0, width := W, row_h := ROW, lw := 0.0) -> void:
	title = t
	items = list
	w = width
	row = row_h
	label_w = lw
	focus = clampi(f, 0, maxi(list.size() - 1, 0))
	_update_size()
	queue_redraw()


func visible_rows() -> int:
	return items.size() if max_rows <= 0 else mini(items.size(), max_rows)


func _update_size() -> void:
	var n := visible_rows()
	scroll = clampi(scroll, maxi(focus - n + 1, 0), mini(focus, maxi(items.size() - n, 0)))
	size = Vector2(w, HEAD + n * row + (14.0 if n < items.size() else 0.0))


func set_max_rows(n: int) -> void:
	if n != max_rows:
		max_rows = n
		_update_size()


func current_id() -> String:
	return String(items[focus].id) if focus < items.size() else ""


## Navigation (auch für Tests): "up", "down", "left", "right", "accept", "cancel".
func nav(cmd: String) -> void:
	if items.is_empty():
		return
	match cmd:
		"up", "down":
			var d := -1 if cmd == "up" else 1
			for _k in items.size():
				focus = posmod(focus + d, items.size())
				if not items[focus].get("header", false):
					break
		"left", "right":
			if items[focus].get("option", false):
				option_changed.emit(current_id(), -1 if cmd == "left" else 1)
		"accept":
			if items[focus].get("option", false):
				option_changed.emit(current_id(), 1)
			else:
				activated.emit(current_id())
		"cancel": cancelled.emit()
	_update_size()
	# M3.3: Menü-Klänge
	GameAudio.ui(self, "ui_confirm" if cmd == "accept" else "ui_click")
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not active or not is_visible_in_tree():
		return
	for pair in [["ui_up", "up"], ["ui_down", "down"], ["ui_left", "left"], ["ui_right", "right"],
			["ui_accept", "accept"], ["ui_cancel", "cancel"]]:
		if event.is_action_pressed(pair[0], true):
			get_viewport().set_input_as_handled()
			nav(pair[1])
			return


func _gui_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		var i := _row_at(event.position)
		if i >= 0 and i != focus and not items[i].get("header", false):
			focus = i
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		scroll = clampi(scroll + (1 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1), 0,
			maxi(items.size() - visible_rows(), 0))
		focus = clampi(focus, scroll, scroll + visible_rows() - 1)
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _row_at(event.position)
		if i >= 0 and not items[i].get("header", false):
			focus = i
			if items[i].get("option", false):
				option_changed.emit(current_id(), -1 if event.position.x < _value_mid() else 1)
				queue_redraw()
			else:
				nav("accept")


func _row_at(p: Vector2) -> int:
	var i := int(floor((p.y - HEAD) / row))
	if i < 0 or i >= visible_rows() or p.x < 0 or p.x > w:
		return -1
	return i + scroll


## Spalte der Werte/Regler (rechts neben der Beschriftungsspalte).
func value_rect(y := 0.0) -> Rect2:
	var x0 := 28.0 + label_w + 16.0
	return Rect2(x0, y, w - 24.0 - x0, row)


func _value_mid() -> float:
	var r := value_rect()
	return r.position.x + r.size.x * 0.5 if label_w > 0.0 else w * 0.55


## Schriftgröße, mit der s in max_w passt (höchstens size, mindestens 60 %).
static func fit_size(s: String, size: float, max_w: float, bold := true) -> float:
	var fs := size
	while fs > size * 0.6 and HudStyle.text_width(s, fs, bold) > max_w:
		fs -= 1.0
	return fs


func _draw() -> void:
	HudStyle.draw_panel(self, Rect2(0, 0, w, size.y))
	draw_rect(Rect2(1, 1, w - 2, size.y - 2), Color(HudStyle.BG, 0.55))
	HudStyle.heading(self, Vector2(24, 40), title, 13, HudStyle.ACCENT)
	HudStyle.rule(self, Vector2(24, 56), Vector2(w - 24, 56))
	var big := row >= 50.0
	var lsize := 22.0 if big else 19.0
	for k in visible_rows():
		var i := k + scroll
		var it: Dictionary = items[i]
		var y := HEAD + k * row
		var on := i == focus
		var mid := y + row * 0.5
		if it.get("header", false):
			# M3.5: Gruppenüberschrift (Tastenbelegung)
			HudStyle.heading(self, Vector2(28, mid + 8), String(it.label), 12, HudStyle.ACCENT)
			HudStyle.rule(self, Vector2(28 + HudStyle.text_width(String(it.label).to_upper(), 12, true) \
				+ HudStyle.HEADING_SPACING * String(it.label).length() + 14, mid + 4), Vector2(w - 24, mid + 4))
			continue
		if on:
			draw_rect(Rect2(8, y + 3, w - 16, row - 6), Color(HudStyle.ACCENT, 0.18))
			draw_rect(Rect2(8, y + 3, 4, row - 6), HudStyle.ACCENT)
		var col := HudStyle.VALUE if on else HudStyle.LABEL
		var is_opt: bool = it.get("option", false)
		var is_key: bool = it.get("keybind", false)
		var lw := label_w if (label_w > 0.0 and (is_opt or is_key)) else w - 52.0
		var fs := fit_size(String(it.label), lsize, lw)
		HudStyle.text(self, Vector2(28, mid + fs * 0.36), String(it.label), fs, col, true)
		if is_opt:
			_draw_value(it, value_rect(y), on)
		elif is_key:
			# M3.5: Tastenbelegung – Taste in der Wertspalte (rechtsbündig, passt sich der Breite an)
			var r := value_rect(y)
			var v := String(it.get("value", ""))
			var vcol := HudStyle.CAUTION if it.get("waiting", false) else (HudStyle.VALUE if on else HudStyle.LABEL)
			var vfs := fit_size(v, 17.0, r.size.x - 8.0)
			HudStyle.text(self, Vector2(r.end.x, mid + vfs * 0.36), v, vfs, vcol, true, 2)
		elif String(it.get("note", "")) != "":
			HudStyle.text(self, Vector2(w - 24, mid + 5), String(it.note), 14, HudStyle.DIM, false, 2)
	# Scroll-Hinweis
	if visible_rows() < items.size():
		var yb := HEAD + visible_rows() * row
		var txt := "%s%d / %d%s" % ["▲ " if scroll > 0 else "", focus + 1, items.size(),
			" ▼" if scroll + visible_rows() < items.size() else ""]
		HudStyle.text(self, Vector2(w * 0.5, yb + 10), txt, 12, HudStyle.DIM, false, 1)


func _draw_value(it: Dictionary, r: Rect2, on: bool) -> void:
	var mid := r.position.y + r.size.y * 0.5
	var acc := HudStyle.ACCENT if on else HudStyle.DIM
	var v := String(it.get("value", ""))
	if label_w <= 0.0:   # alte Darstellung (rechtsbündig)
		HudStyle.text(self, Vector2(w - 24, mid + 8), "◀  %s  ▶" % v if on else v, 17, acc, true, 2)
		return
	if it.has("slider"):
		# Regler: Balken links in der Wertspalte, Prozentwert rechts (feste Breite)
		var vw := 62.0
		var bx := r.position.x + 18.0
		var bw := r.size.x - vw - 36.0
		var f := clampf(float(it.slider), 0.0, 1.0)
		draw_rect(Rect2(bx, mid - 3, bw, 6), Color(HudStyle.DIM, 0.45))
		draw_rect(Rect2(bx, mid - 3, bw * f, 6), acc)
		draw_rect(Rect2(bx + bw * f - 5, mid - 11, 10, 22), HudStyle.VALUE if on else HudStyle.LABEL)
		if on:
			HudStyle.text(self, Vector2(r.position.x, mid + 6), "◀", 14, acc, true)
			HudStyle.text(self, Vector2(bx + bw + 6, mid + 6), "▶", 14, acc, true)
		HudStyle.text(self, Vector2(r.end.x, mid + 7), v, 18, acc, true, 2)
		return
	var fs := fit_size(v, 18.0, r.size.x - 56.0)
	var cx := r.position.x + r.size.x * 0.5
	if on:
		HudStyle.text(self, Vector2(r.position.x, mid + 6), "◀", 14, acc, true)
		HudStyle.text(self, Vector2(r.end.x, mid + 6), "▶", 14, acc, true, 2)
	HudStyle.text(self, Vector2(cx, mid + fs * 0.36), v, fs, acc, true, 1)
