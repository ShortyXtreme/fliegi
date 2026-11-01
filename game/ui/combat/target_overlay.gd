class_name TargetOverlay
extends Control
## Bildschirmmitte: Feindmarker (Klammern + Entfernung), Randpfeile für Ziele außerhalb
## des Bildes, Vorhaltepunkt (Arcade), Trefferanzeige (weiß = Treffer, rot = Abschuss)
## und der Hinweis zum Notausstieg.

const HIT_TIME := 0.3
const KILL_TIME := 0.9
const LOCK_TIME := 2.5

var s := 1.0
var cam: Camera3D
var own: Node3D
var contacts: Array = []
var lead := {}
var lead_target := {}
## Trefferanzeige: Restzeit (s); > 0 = sichtbar.
var hit_t := 0.0
var kill_t := 0.0
## Notausstieg: Halte-Fortschritt 0..1, „gesperrt“-Restzeit, möglich (schwerer Schaden).
var eject_progress := 0.0
var eject_locked_t := 0.0
var eject_possible := false


func _init() -> void:
	name = "TargetOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func on_hit() -> void:
	hit_t = HIT_TIME


func on_kill() -> void:
	kill_t = KILL_TIME
	hit_t = 0.0


func on_eject_denied() -> void:
	eject_locked_t = LOCK_TIME


func tick(dt: float) -> void:
	hit_t = maxf(hit_t - dt, 0.0)
	kill_t = maxf(kill_t - dt, 0.0)
	eject_locked_t = maxf(eject_locked_t - dt, 0.0)
	queue_redraw()


func _gun_cross() -> Vector2:
	var vs := get_viewport_rect().size
	if cam == null or own == null:
		return vs * 0.5
	var xf := own.get_global_transform_interpolated()
	var nose := xf.origin - xf.basis.z * 500.0
	return vs * 0.5 if cam.is_position_behind(nose) else cam.unproject_position(nose)


func _draw() -> void:
	var vs := get_viewport_rect().size
	if cam != null and own != null:
		var focal := vs.y * 0.5 / tan(deg_to_rad(cam.fov) * 0.5)
		for c in contacts:
			if c.hostile and c.spotted:
				_draw_contact(c, vs, focal)
		if not lead.is_empty() and not lead_target.is_empty():
			_draw_lead(vs)
	_draw_hit()
	_draw_eject(vs)


func _draw_contact(c: Dictionary, vs: Vector2, focal: float) -> void:
	var p: Vector3 = c.pos
	var col := HudStyle.ENEMY
	var inset := 56.0 * s
	var on_screen := false
	var sp := Vector2.ZERO
	if not cam.is_position_behind(p):
		sp = cam.unproject_position(p)
		on_screen = Rect2(Vector2(inset, inset), vs - Vector2(inset, inset) * 2).has_point(sp)
	if on_screen:
		var half := clampf(11.0 / maxf(c.dist, 1.0) * focal * 0.5, 13.0 * s, 56.0 * s)
		var k := half * 0.45
		var w := 2.0 * s
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := sp + Vector2(sx * half, sy * half)
				draw_line(corner, corner - Vector2(sx * k, 0), col, w, true)
				draw_line(corner, corner - Vector2(0, sy * k), col, w, true)
		var is_lead: bool = not lead_target.is_empty() and lead_target.node == c.node
		HudStyle.text(self, sp + Vector2(0, half + 18 * s), HudStyle.distance(c.dist),
				(15.0 if is_lead else 13.0) * s, Color(col, 0.95), is_lead, 1)
		return
	# Randpfeil: Richtung im Kamerabild (auch für Ziele hinter der Kamera)
	var local := cam.global_transform.affine_inverse() * p
	var d2 := Vector2(local.x, -local.y)
	if d2.length() < 0.001:
		d2 = Vector2(0, 1)
	d2 = d2.normalized()
	var center := vs * 0.5
	var ext := center - Vector2(inset, inset)
	var t := minf(ext.x / maxf(absf(d2.x), 1e-4), ext.y / maxf(absf(d2.y), 1e-4))
	var tip := center + d2 * t
	var n := Vector2(-d2.y, d2.x)
	var a := 20.0 * s
	var poly := PackedVector2Array([tip, tip - d2 * a + n * a * 0.62, tip - d2 * a * 0.68,
			tip - d2 * a - n * a * 0.62])
	var outline := poly.duplicate()
	outline.append(poly[0])
	draw_colored_polygon(poly, Color(col, 0.92))
	draw_polyline(outline, Color(0, 0, 0, 0.35), 1.0, true)
	var lp := tip - d2 * (a + 30 * s)
	HudStyle.text(self, lp + Vector2(0, 5 * s), HudStyle.distance(c.dist), 13.0 * s,
			Color(col, 0.95), true, 1)


func _draw_lead(vs: Vector2) -> void:
	var pt: Vector3 = lead.screen_point
	if cam.is_position_behind(pt) or cam.is_position_behind(lead_target.pos):
		return
	var sp := cam.unproject_position(pt)
	var tp := cam.unproject_position(lead_target.pos)
	if not get_viewport_rect().grow(-10).has_point(sp):
		return
	var col := Color(1.0, 0.9, 0.55, 0.95)
	var r := 9.0 * s
	if sp.distance_to(tp) > r * 2.5:
		draw_line(tp + (sp - tp).normalized() * 18 * s, sp - (sp - tp).normalized() * r,
				Color(col, 0.35), 1.0 * s, true)
	draw_arc(sp, r, 0, TAU, 28, col, 2.0 * s, true)
	draw_circle(sp, 2.2 * s, col)


func _draw_hit() -> void:
	if hit_t <= 0.0 and kill_t <= 0.0:
		return
	var c := _gun_cross()
	var kill := kill_t > 0.0
	var f: float = kill_t / KILL_TIME if kill else hit_t / HIT_TIME
	var col := Color(HudStyle.WARNING, f) if kill else Color(1, 1, 1, f)
	var r0 := (14.0 if kill else 12.0) * s
	var r1 := r0 + (14.0 if kill else 9.0) * s
	for k in 4:
		var d := Vector2.from_angle(PI * 0.25 + k * PI * 0.5)
		draw_line(c + d * r0, c + d * r1, col, (3.0 if kill else 2.2) * s, true)


func _draw_eject(vs: Vector2) -> void:
	var y := vs.y * 0.25
	var x := vs.x * 0.5
	if eject_progress > 0.0:
		var txt := "NOTAUSSTIEG"
		HudStyle.text(self, Vector2(x, y), txt, 22 * s, HudStyle.CAUTION, true, 1)
		var bw := 220.0 * s
		var r := Rect2(x - bw * 0.5, y + 10 * s, bw, 6 * s)
		draw_rect(r, Color(1, 1, 1, 0.15))
		draw_rect(Rect2(r.position, Vector2(bw * clampf(eject_progress, 0, 1), r.size.y)),
				HudStyle.CAUTION)
	elif eject_locked_t > 0.0:
		var a := minf(eject_locked_t / 0.4, 1.0)
		HudStyle.text(self, Vector2(x, y), "Notausstieg gesperrt", 22 * s,
				Color(HudStyle.WARNING, a), true, 1)
		HudStyle.text(self, Vector2(x, y + 22 * s), "nur bei schwerem Schaden", 14 * s,
				Color(HudStyle.LABEL, a), false, 1)
	elif eject_possible:
		HudStyle.text(self, Vector2(x, y), "Notausstieg möglich  [J halten]", 17 * s,
				Color(HudStyle.CAUTION, 0.9), true, 1)
