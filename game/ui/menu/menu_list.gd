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

## [{id, label, note (optional), option: bool, value (Text)}]
var items: Array = []
var focus := 0
var title := ""
var active := true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE


func set_items(t: String, list: Array, f := 0) -> void:
	title = t
	items = list
	focus = clampi(f, 0, maxi(list.size() - 1, 0))
	size = Vector2(W, 70.0 + list.size() * ROW)
	queue_redraw()


func current_id() -> String:
	return String(items[focus].id) if focus < items.size() else ""


## Navigation (auch für Tests): "up", "down", "left", "right", "accept", "cancel".
func nav(cmd: String) -> void:
	if items.is_empty():
		return
	match cmd:
		"up": focus = posmod(focus - 1, items.size())
		"down": focus = posmod(focus + 1, items.size())
		"left", "right":
			if items[focus].get("option", false):
				option_changed.emit(current_id(), -1 if cmd == "left" else 1)
		"accept":
			if items[focus].get("option", false):
				option_changed.emit(current_id(), 1)
			else:
				activated.emit(current_id())
		"cancel": cancelled.emit()
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
		if i >= 0 and i != focus:
			focus = i
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _row_at(event.position)
		if i >= 0:
			focus = i
			if items[i].get("option", false):
				option_changed.emit(current_id(), -1 if event.position.x < W * 0.55 else 1)
				queue_redraw()
			else:
				nav("accept")


func _row_at(p: Vector2) -> int:
	var i := int(floor((p.y - 70.0) / ROW))
	return i if i >= 0 and i < items.size() and p.x >= 0 and p.x <= W else -1


func _draw() -> void:
	HudStyle.draw_panel(self, Rect2(0, 0, W, size.y))
	draw_rect(Rect2(1, 1, W - 2, size.y - 2), Color(HudStyle.BG, 0.55))
	HudStyle.heading(self, Vector2(24, 40), title, 13, HudStyle.ACCENT)
	HudStyle.rule(self, Vector2(24, 56), Vector2(W - 24, 56))
	for i in items.size():
		var it: Dictionary = items[i]
		var y := 70.0 + i * ROW
		var on := i == focus
		if on:
			draw_rect(Rect2(8, y + 4, W - 16, ROW - 8), Color(HudStyle.ACCENT, 0.18))
			draw_rect(Rect2(8, y + 4, 4, ROW - 8), HudStyle.ACCENT)
		var col := HudStyle.VALUE if on else HudStyle.LABEL
		HudStyle.text(self, Vector2(28, y + 36), String(it.label), 22, col, true)
		if it.get("option", false):
			var v := "◀  %s  ▶" % String(it.get("value", "")) if on else String(it.get("value", ""))
			HudStyle.text(self, Vector2(W - 24, y + 35), v, 17, HudStyle.ACCENT if on else HudStyle.DIM, true, 2)
		elif String(it.get("note", "")) != "":
			HudStyle.text(self, Vector2(W - 24, y + 34), String(it.note), 14, HudStyle.DIM, false, 2)
