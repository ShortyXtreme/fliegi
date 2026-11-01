class_name HitDebugOverlay
extends Control
## Treffer-Debug-Modus (M2.1, F3 / Xbox L3): zeichnet die Daten aus HitDebug.
##  - eigene Treffer: Markierung an der Trefferstelle („Motor −10“), Liste „Meine Treffer“
##  - erhaltene Treffer: Liste „Getroffen von“, Richtungspfeile am Bildschirmrand
##  - Zonen-HP (Zahl) des eigenen Flugzeugs und des anvisierten Ziels
##  - F4 Hitboxen als Drahtgitter, F5 Geschossbahnen aller Schüsse, F6 Treffer anderer
##  - abgelehnte Treffer (HitValidator) rot mit Grund
## Platz: links unter dem Radar, rechts unter dem Kill-Feed – nie über Flug-Panel/Skizze.

const LEFT_W := 340.0
const RIGHT_W := 420.0
const TOP_Y := 236.0
const ROW := 19.0

var hud: Hud
var data: HitDebug
var show_hitboxes := true
var show_tracers := false

var _mesh := ImmediateMesh.new()
var _mi := MeshInstance3D.new()
var _s := 1.0


func _init() -> void:
	name = "HitDebugOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_mi.mesh = _mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	_mi.material_override = m
	_mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _ready() -> void:
	add_child(_mi)


func set_active(on: bool) -> void:
	visible = on
	_mi.visible = on


## Ziel für die Zonen-HP rechts: angezeigtes Vorhalt-Ziel, sonst zuletzt selbst getroffen.
func current_target() -> Node:
	if hud != null and hud.combat != null and hud.combat.overlay != null:
		var lt: Dictionary = hud.combat.overlay.lead_target
		if not lt.is_empty() and is_instance_valid(lt.get("node")):
			return lt.node
	if data != null:
		var m := data.mine(1)
		if not m.is_empty() and is_instance_valid(m[0].target):
			return m[0].target
	return null


func _process(_dt: float) -> void:
	if not visible:
		return
	_s = HudStyle.ui_scale(get_viewport_rect().size)
	_draw_3d()
	queue_redraw()


# --- 3D: Hitboxen und Bahnen ------------------------------------------------------

func _draw_3d() -> void:
	_mesh.clear_surfaces()
	var lines := 0
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	if show_hitboxes:
		for t in ProjectileSystem.targets():
			var n := t.node
			if n == null or not is_instance_valid(n) or not n.is_inside_tree():
				continue
			var hb = t.boxes()
			if not hb is HitboxSet:
				continue
			var xf := n.get_global_transform_interpolated()
			for k in hb.zones.size():
				var col := _zone_col(n, hb.zones[k], hb.damage_mul[k])
				_box(xf, hb.centers[k], hb.half_extents[k], col)
				lines += 12
	if show_tracers and ProjectileSystem.current != null:
		var ps := ProjectileSystem.current
		for i in ps.active_slots():
			var own: bool = data != null and ps.shooter_of(i) == data.own
			var c := Color(1.0, 0.9, 0.4, 0.8) if own else Color(1.0, 0.5, 0.4, 0.6)
			_mesh.surface_set_color(c)
			_mesh.surface_add_vertex(ps.position(i) - ps.velocity(i) * 0.05)
			_mesh.surface_set_color(c)
			_mesh.surface_add_vertex(ps.position(i))
			lines += 1
	if lines == 0:
		_mesh.surface_set_color(Color(0, 0, 0, 0))
		_mesh.surface_add_vertex(Vector3.ZERO)
		_mesh.surface_add_vertex(Vector3.ZERO)
	_mesh.surface_end()


func _zone_col(n: Node, zone: int, mul: float) -> Color:
	var d = n.get("damage")
	var f: float = d.hp_fraction(zone) if d is DamageModel else 1.0
	var c := WeaponPanel.zone_color(f)
	c.a = 0.85 if mul >= 0.99 else 0.35
	return c


func _box(xf: Transform3D, c: Vector3, he: Vector3, col: Color) -> void:
	var p := []
	for k in 8:
		p.append(xf * (c + Vector3(he.x * (1 if k & 1 else -1), he.y * (1 if k & 2 else -1),
				he.z * (1 if k & 4 else -1))))
	for e in [[0, 1], [2, 3], [4, 5], [6, 7], [0, 2], [1, 3], [4, 6], [5, 7], [0, 4], [1, 5], [2, 6], [3, 7]]:
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(p[e[0]])
		_mesh.surface_set_color(col)
		_mesh.surface_add_vertex(p[e[1]])


# --- 2D ---------------------------------------------------------------------------

func _draw() -> void:
	if data == null:
		return
	var cam := get_viewport().get_camera_3d()
	var vs := get_viewport_rect().size
	_draw_header(vs)
	if cam != null:
		_draw_markers(cam)
		_draw_rejected(cam)
		_draw_arrows(cam, vs)
	_draw_left()
	_draw_right(vs)


func _t(p: Vector2, s: String, size: float, col: Color, bold := false, align := 0) -> float:
	return HudStyle.text(self, p, s, size * _s, col, bold, align)


func _draw_header(vs: Vector2) -> void:
	var on := func(b: bool) -> String: return "an" if b else "aus"
	var s := "TREFFER-DEBUG   F4 Hitboxen %s · F5 Bahnen %s · F6 andere %s · Shift+F3 Kräfte" % [
		on.call(show_hitboxes), on.call(show_tracers), on.call(data.show_others)]
	var w := HudStyle.text_width(s, 12 * _s)
	var r := Rect2(vs.x * 0.5 - w * 0.5 - 12 * _s, 92 * _s, w + 24 * _s, 24 * _s)
	HudStyle.draw_panel(self, r, 8)
	_t(Vector2(vs.x * 0.5, r.position.y + 17 * _s), s, 12, HudStyle.ACCENT, true, 1)


func _draw_markers(cam: Camera3D) -> void:
	for m in data.markers():
		var tn: Node3D = m.target
		var wp: Vector3 = tn.get_global_transform_interpolated() * (m.local_point as Vector3)
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var a: float = 1.0 - float(m.age) / HitDebug.MARKER_TIME
		var col := Color(1.0, 0.86, 0.3, a)
		draw_arc(sp, 7 * _s, 0, TAU, 20, col, 2.0 * _s, true)
		draw_line(sp + Vector2(-11, 0) * _s, sp + Vector2(-4, 0) * _s, col, 2.0 * _s)
		draw_line(sp + Vector2(11, 0) * _s, sp + Vector2(4, 0) * _s, col, 2.0 * _s)
		_t(sp + Vector2(12, -10 - float(m.age) * 14.0) * _s, m.text, 14, col, true)


func _draw_rejected(cam: Camera3D) -> void:
	for e in data.rejected_recent():
		var wp: Vector3 = e.world_point
		if cam.is_position_behind(wp):
			continue
		var sp := cam.unproject_position(wp)
		var col := Color(HudStyle.WARNING, 1.0 - (data.time - float(e.t)) / HitDebug.REJECT_TIME)
		draw_line(sp + Vector2(-6, -6) * _s, sp + Vector2(6, 6) * _s, col, 2.0 * _s)
		draw_line(sp + Vector2(-6, 6) * _s, sp + Vector2(6, -6) * _s, col, 2.0 * _s)
		_t(sp + Vector2(10, 4) * _s, "abgelehnt: %s" % e.reason, 12, col)


func _draw_arrows(cam: Camera3D, vs: Vector2) -> void:
	var c := vs * 0.5
	var rad := minf(vs.x, vs.y) * 0.34
	var b := cam.global_transform.basis
	for h in data.incoming():
		var d: Vector3 = h.dir
		var x := d.dot(b.x)
		var y := -d.dot(b.y)
		var z := -d.dot(b.z)
		var v := Vector2(x, y)
		if v.length() < 0.001:
			v = Vector2(0, 1 if z < 0 else -1)
		var ang := v.angle()
		var a: float = 1.0 - float(h.age) / HitDebug.ARROW_TIME
		var col := Color(HudStyle.WARNING, a)
		var tip := c + Vector2.from_angle(ang) * (rad - 26 * _s)
		var base := c + Vector2.from_angle(ang) * rad
		var side := Vector2.from_angle(ang + PI * 0.5) * 13 * _s
		draw_colored_polygon(PackedVector2Array([tip, base + side, base - side]), col)
		var lp := c + Vector2.from_angle(ang) * (rad - 44 * _s)
		_t(lp + Vector2(0, 5 * _s), "%s%s" % [h.shooter_name, " (hinten)" if z < 0.0 else ""], 12, col,
				true, 1)


func _panel(r: Rect2) -> void:
	HudStyle.draw_panel(self, Rect2(r.position * Vector2.ONE, r.size), 10)


func _zone_table(x: float, y: float, w: float, a: Node, title: String) -> float:
	_t(Vector2(x, y), title, 11, HudStyle.LABEL, true)
	y += ROW * _s
	var rows := HitDebug.zone_hp(a)
	if rows.is_empty():
		_t(Vector2(x, y), "–", 13, HudStyle.DIM)
		return y + ROW * _s
	var col_w := w * 0.5
	for k in rows.size():
		var r: Dictionary = rows[k]
		var cx := x + (k % 2) * col_w
		var f: float = r.hp / maxf(r.max, 1.0)
		_t(Vector2(cx, y), r.name, 13, HudStyle.LABEL)
		_t(Vector2(cx + col_w - 14 * _s, y), "%d/%d" % [int(ceil(r.hp)), int(r.max)], 13,
				WeaponPanel.zone_color(f), true, 2)
		if k % 2 == 1 or k == rows.size() - 1:
			y += ROW * _s
	return y


func _draw_left() -> void:
	var x := 24.0 * _s
	var w := LEFT_W * _s
	var y0 := TOP_Y * _s
	var rec := data.received(8)
	var h := (26 + 5 * ROW + 10 + (1 + maxf(rec.size(), 1)) * ROW) * _s
	_panel(Rect2(x, y0, w, h))
	var px := x + 14 * _s
	var y := y0 + 22 * _s
	y = _zone_table(px, y, w - 28 * _s, data.own, "EIGENES FLUGZEUG – ZONEN-HP")
	y += 10 * _s
	_t(Vector2(px, y), "GETROFFEN VON", 11, HudStyle.LABEL, true)
	y += ROW * _s
	if rec.is_empty():
		_t(Vector2(px, y), "noch keine Treffer", 13, HudStyle.DIM)
	for e in rec:
		var age := data.time - float(e.t)
		var col := HudStyle.WARNING if age < 2.0 else HudStyle.VALUE
		_t(Vector2(px, y), e.shooter_name, 13, col, true)
		_t(Vector2(px + 92 * _s, y), e.zone_name, 13, HudStyle.VALUE)
		_t(Vector2(px + 190 * _s, y), "−%d" % int(round(e.damage)), 13, col, true)
		_t(Vector2(px + w - 28 * _s, y), "%.0f m · %s" % [e.distance, _ago(age)], 12, HudStyle.DIM,
				false, 2)
		y += ROW * _s


func _draw_right(vs: Vector2) -> void:
	var w := RIGHT_W * _s
	var x := vs.x - 24 * _s - w
	var y0 := TOP_Y * _s
	var mine := data.mine(8)
	var oth := data.others(5) if data.show_others else []
	var h := (26 + 5 * ROW + 10 + (1 + maxf(mine.size(), 1)) * ROW) * _s
	if data.show_others:
		h += (6 + (1 + maxf(oth.size(), 1)) * ROW) * _s
	_panel(Rect2(x, y0, w, h))
	var px := x + 14 * _s
	var y := y0 + 22 * _s
	var tg := current_target()
	y = _zone_table(px, y, w - 28 * _s, tg, "ZIEL %s – ZONEN-HP" % HitDebug.name_of(tg).to_upper() \
			if tg != null else "ZIEL – ZONEN-HP")
	y += 10 * _s
	_t(Vector2(px, y), "MEINE TREFFER", 11, HudStyle.LABEL, true)
	_t(Vector2(px + w - 28 * _s, y), "abgelehnt gesamt %d" % data.rejected_total, 11,
			HudStyle.WARNING if data.rejected_total > 0 else HudStyle.DIM, false, 2)
	y += ROW * _s
	if mine.is_empty():
		_t(Vector2(px, y), "noch keine Treffer", 13, HudStyle.DIM)
		y += ROW * _s
	for e in mine:
		_row(px, y, w, e, HudStyle.CAUTION)
		y += ROW * _s
	if data.show_others:
		y += 6 * _s
		_t(Vector2(px, y), "TREFFER ANDERER", 11, HudStyle.LABEL, true)
		y += ROW * _s
		if oth.is_empty():
			_t(Vector2(px, y), "keine", 13, HudStyle.DIM)
		for e in oth:
			_row(px, y, w, e, HudStyle.FRIEND, true)
			y += ROW * _s


func _row(px: float, y: float, w: float, e: Dictionary, col: Color, with_shooter := false) -> void:
	var age := data.time - float(e.t)
	var name_s: String = ("%s → %s" % [e.shooter_name, e.target_name]) if with_shooter else e.target_name
	_t(Vector2(px, y), name_s, 13, col if age < 2.0 else HudStyle.VALUE, true)
	_t(Vector2(px + 150 * _s, y), e.zone_name, 13, HudStyle.VALUE)
	_t(Vector2(px + 240 * _s, y), "−%d" % int(round(e.damage)), 13, col, true)
	_t(Vector2(px + w - 28 * _s, y), "%.0f m · %s" % [e.distance, _ago(age)], 12, HudStyle.DIM,
			false, 2)


static func _ago(s: float) -> String:
	return "%.1f s" % s if s < 10.0 else "%d s" % int(s)
