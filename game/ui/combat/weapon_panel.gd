class_name WeaponPanel
extends Control
## Rechts unten: Schadensskizze (Draufsicht, Zonen nach DamageModel.Zone eingefärbt)
## und Munitionszähler je Waffengruppe, mit Überhitzung/Ladehemmung, wenn aktiv.

const W := 330.0
const H := 150.0
const PAD := 14.0
const FLASH_TIME := 0.9

var data := {}
var _prev := PackedFloat32Array()
var _flash := PackedFloat32Array()


func _init() -> void:
	name = "WeaponPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Reine Datensammlung: {groups: [{name, ammo, max, heat, heat_active, jammed}], zones: [hp 0..1]}.
static func gather(aircraft: Node) -> Dictionary:
	var d := {"groups": [], "zones": PackedFloat32Array()}
	var w = aircraft.get("weapons")
	if w != null:
		for g in [WeaponSystem.Group.PRIMARY, WeaponSystem.Group.SECONDARY]:
			if not w.has_weapons(g):
				continue
			var wd: WeaponDef = w.weapon_of_group(g)
			var heat_active := wd != null and wd.heat_per_shot > 0.0
			d.groups.append({"name": wd.display_name if wd else "Waffe",
				"ammo": w.ammo(g), "max": w.ammo_max(g), "heat": w.heat_level(g) if heat_active else 0.0,
				"heat_active": heat_active, "jammed": w.is_jammed(g)})
	var dm = aircraft.get("damage")
	if dm != null:
		for z in DamageModel.Zone.COUNT:
			d.zones.append(dm.hp_fraction(z))
		d["health"] = dm.health_fraction()
	return d


func set_data(d: Dictionary, dt: float) -> void:
	var z: PackedFloat32Array = d.get("zones", PackedFloat32Array())
	if _flash.size() != z.size():
		_flash.resize(z.size())
		_flash.fill(0.0)
		_prev = z.duplicate()
	for i in z.size():
		_flash[i] = maxf(_flash[i] - dt, 0.0)
		if z[i] < _prev[i] - 0.001:
			_flash[i] = FLASH_TIME
	_prev = z.duplicate()
	data = d
	queue_redraw()


func _zone_col(i: int) -> Color:
	var z: PackedFloat32Array = data.get("zones", PackedFloat32Array())
	var f := z[i] if i < z.size() else 1.0
	var c := zone_color(f)
	c.a = 0.85
	if i < _flash.size() and _flash[i] > 0.0:
		c = c.lerp(Color.WHITE, _flash[i] / FLASH_TIME)
	return c


## M2.1: stufenloser Farbverlauf grün → gelb (50 %) → rot. Vorher erst unter 66 % gelb –
## einzelne Treffer (10 HP bei 120–200 HP je Zone) waren in der Skizze nicht zu sehen.
static func zone_color(f: float) -> Color:
	if f <= 0.001:
		return HudStyle.health_color(0.0)
	if f >= 0.999:
		return HudStyle.OK
	# leicht beschädigt sofort sichtbar: Startsprung um 15 % Richtung Gelb
	if f >= 0.5:
		return HudStyle.OK.lerp(HudStyle.CAUTION, 0.15 + 0.85 * (1.0 - f) / 0.5)
	return HudStyle.CAUTION.lerp(HudStyle.WARNING, (0.5 - f) / 0.5)


static func _rect(x: float, y: float, w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])


func _draw_sketch(o: Vector2) -> void:
	# Draufsicht 110 × 120, Nase oben
	var Z := DamageModel.Zone
	var shapes := [
		[Z.ENGINE, _rect(49, 0, 12, 22)],
		[Z.COCKPIT, _rect(50, 24, 10, 16)],
		[Z.FUEL_L, _rect(30, 40, 19, 15)],
		[Z.FUEL_R, _rect(61, 40, 19, 15)],
		[Z.WING_L, PackedVector2Array([Vector2(2, 47), Vector2(28, 40), Vector2(28, 56), Vector2(4, 56)])],
		[Z.WING_R, PackedVector2Array([Vector2(82, 40), Vector2(108, 47), Vector2(106, 56), Vector2(82, 56)])],
		[Z.TAIL, PackedVector2Array([Vector2(52, 90), Vector2(58, 90), Vector2(58, 100), Vector2(76, 104),
			Vector2(76, 111), Vector2(34, 111), Vector2(34, 104), Vector2(52, 100)])],
	]
	# Rumpf (neutral)
	var body := _rect(51, 42, 8, 48)
	var off := PackedVector2Array()
	for p in body:
		off.append(o + p)
	draw_colored_polygon(off, Color(HudStyle.VALUE, 0.16))
	for sh in shapes:
		var pts := PackedVector2Array()
		for p in sh[1]:
			pts.append(o + p)
		draw_colored_polygon(pts, _zone_col(sh[0]))
		pts.append(pts[0])
		draw_polyline(pts, Color(0, 0, 0, 0.45), 1.0, true)


func _draw() -> void:
	if data.is_empty():
		return
	HudStyle.draw_panel(self, Rect2(0, 0, W, H), 12)
	draw_set_transform(Vector2(PAD - 2, 26), 0.0, Vector2(1.1, 1.0))
	_draw_sketch(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO)
	var lw := HudStyle.heading(self, Vector2(PAD, 18), "SCHADEN", 10)
	var hl: float = data.get("health", 1.0)
	if hl < 0.999:
		HudStyle.text(self, Vector2(PAD + lw + 8, 18), "%d %%" % int(round((1.0 - hl) * 100.0)), 11,
				zone_color(hl), true)
	var x0 := 140.0
	var y := 30.0
	var groups: Array = data.get("groups", [])
	if groups.is_empty():
		HudStyle.text(self, Vector2(x0, 40), "keine Waffen", 13, HudStyle.DIM)
	for g in groups:
		HudStyle.text(self, Vector2(x0, y - 4), String(g.name).to_upper(), 11, HudStyle.LABEL)
		var frac: float = float(g.ammo) / maxf(float(g.max), 1.0)
		var col := HudStyle.VALUE
		if g.ammo <= 0:
			col = HudStyle.WARNING
		elif frac < 0.2:
			col = HudStyle.CAUTION
		var aw := HudStyle.text(self, Vector2(x0, y + 30), HudStyle.thousands(g.ammo) if g.ammo > 0 else "LEER",
				32, col, true)
		HudStyle.text(self, Vector2(x0 + aw + 6, y + 30), "/ %s" % HudStyle.thousands(g.max), 13,
				HudStyle.DIM)
		var bar := Rect2(x0, y + 38, W - PAD - x0, 5)
		draw_rect(bar, Color(HudStyle.VALUE, 0.08))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(frac, 0, 1), bar.size.y)), Color(col, 0.8))
		y += 52.0
		if g.heat_active:
			var h: float = clampf(g.heat, 0.0, 1.0)
			var hcol := HudStyle.ACCENT if h < 0.6 else (HudStyle.CAUTION if h < 0.9 else HudStyle.WARNING)
			HudStyle.heading(self, Vector2(x0, y + 4), "HITZE", 10)
			var hb := Rect2(x0 + 44, y - 4, W - PAD - x0 - 44, 6)
			draw_rect(hb, Color(HudStyle.VALUE, 0.08))
			draw_rect(Rect2(hb.position, Vector2(hb.size.x * h, hb.size.y)), hcol)
			y += 16.0
		if g.jammed:
			HudStyle.text(self, Vector2(x0, y + 6), "LADEHEMMUNG", 14, HudStyle.WARNING, true)
			y += 20.0
