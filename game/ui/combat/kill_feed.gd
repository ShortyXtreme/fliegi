class_name KillFeed
extends Control
## Kill-Feed oben rechts: höchstens 5 Einträge, je 6 s sichtbar (am Ende ausblenden).

const MAX_ENTRIES := 5
const LIFETIME := 6.0
const W := 420.0
const CAUSE_TEXT := {
	CombatEvents.Cause.UNKNOWN: "",
	CombatEvents.Cause.WING_BROKEN: "Flügelbruch",
	CombatEvents.Cause.PILOT_KILLED: "Pilot getroffen",
	CombatEvents.Cause.EJECTED: "ausgestiegen",
	CombatEvents.Cause.CRASH: "Absturz",
	CombatEvents.Cause.ENGINE: "Motor",
	CombatEvents.Cause.FIRE: "Brand",
	CombatEvents.Cause.FRIENDLY: "Eigenbeschuss",
}

## Einträge: {left, left_col, mid, right, right_col, note, t}
var entries: Array = []


func _init() -> void:
	name = "KillFeed"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func _col(n: Node, own: Node) -> Color:
	if n == null or not is_instance_valid(n):
		return HudStyle.LABEL
	if n == own:
		return HudStyle.ACCENT
	var nat = n.get("nation_id")
	if nat == null or own == null or own.get("nation_id") == null:
		return HudStyle.VALUE
	return HudStyle.ENEMY if Nations.is_hostile(own.nation_id, nat) else HudStyle.FRIEND


func add_kill(victim: Node, killer: Node, cause: int, own: Node) -> void:
	var e := {"t": 0.0, "note": CAUSE_TEXT.get(cause, "")}
	if killer != null and is_instance_valid(killer) and killer != victim:
		e.left = HudContacts.display_name(killer, own)
		e.left_col = _col(killer, own)
		e.mid = "×"
	else:
		e.left = ""
		e.left_col = HudStyle.LABEL
		e.mid = ""
	e.right = HudContacts.display_name(victim, own)
	e.right_col = _col(victim, own)
	if e.left == "":
		e.note = "abgeschossen" if e.note == "" else e.note
	_push(e)


func add_text(who: Node, text: String, own: Node) -> void:
	_push({"t": 0.0, "left": HudContacts.display_name(who, own), "left_col": _col(who, own),
			"mid": "", "right": "", "right_col": HudStyle.LABEL, "note": text})


func _push(e: Dictionary) -> void:
	entries.append(e)
	while entries.size() > MAX_ENTRIES:
		entries.pop_front()
	queue_redraw()


func tick(dt: float) -> void:
	for e in entries:
		e.t += dt
	entries = entries.filter(func(e): return e.t < LIFETIME)
	queue_redraw()


func _draw() -> void:
	var y := 0.0
	for e in entries:
		var a := clampf((LIFETIME - e.t) / 0.6, 0.0, 1.0) * clampf(e.t / 0.15, 0.2, 1.0)
		var sz := 15.0
		var parts := []   # [Text, Farbe, fett]
		if e.left != "":
			parts.append([e.left, e.left_col, true])
		if e.mid != "":
			parts.append([e.mid, HudStyle.LABEL, false])
		if e.right != "":
			parts.append([e.right, e.right_col, true])
		if e.note != "":
			parts.append([e.note, HudStyle.DIM, false])
		var total := 0.0
		for p in parts:
			total += HudStyle.text_width(p[0], sz, p[2]) + 8.0
		total += 14.0
		var r := Rect2(W - total, y, total, 28)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(HudStyle.BG, HudStyle.BG.a * a)
		sb.set_corner_radius_all(6)
		draw_style_box(sb, r)
		var x := r.position.x + 10.0
		for p in parts:
			x += HudStyle.text(self, Vector2(x, y + 19), p[0], sz, Color(p[1], a), p[2]) + 8.0
		y += 32.0
