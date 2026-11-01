class_name ProjectileSystem
extends Node
## Alle Geschosse der Welt als Struct-of-Arrays im Ringpuffer (Plan M2 §2), keine Nodes.
## Genau eine Instanz pro Welt; sie meldet sich als ProjectileSystem.current an.
##
## Ablauf je Physik-Tick (läuft vor allen anderen Nodes, process_physics_priority):
##  1. Zielstände erfassen (Transform jetzt/vorher je registriertem Ziel).
##  2. Jedes Geschoss: Ballistik (wie Ballistics.advance), Segment p0 → p1.
##  3. Treffer: Begrenzungskugel (bewegt), dann Segment ins Zielsystem – p0 mit dem
##     Ziel-Transform des Vortick, p1 mit dem aktuellen (= Abzug der Zielbewegung inkl.
##     Drehung) – gegen HitboxSet.intersect_segment(); Boden über WorldGround.height_at(),
##     Physik-Raycast nur bodennah (Gebäude, Fahrzeuge, Wracks).
## Ein Geschoss, das im Tick T gespawnt wird, beginnt im Tick T+1 zu fliegen; sein Startpunkt
## gehört zum Zustand von Tick T (Schütze liest in T seinen Transform vor dem Physik-Schritt).
##
## Lese-Schnittstelle für Effekte/HUD (WeaponFx, nur lesen): capacity(), is_active(i),
## is_tracer(i), position(i), prev_position(i), velocity(i), age(i), shooter_of(i),
## weapon_of(i), active_slots(), tracer_slots() sowie die Signale spawned/impact.

enum Impact { EXPIRED, GROUND, WORLD, TARGET }

const CAPACITY := 2048
## Unterhalb dieser Höhe über WorldGround zusätzlich Physik-Raycast (m).
const RAY_HEIGHT := 60.0
const F_ACTIVE := 1
const F_TRACER := 2
const F_FRESH := 4

## Neues Geschoss im Slot (für Effekte, z. B. Mündungsfeuer/Leuchtspur).
signal spawned(slot: int)
## Geschoss endet: Ort, Geschwindigkeit, Art (Impact), getroffenes Ziel (oder null), Zone.
signal impact(slot: int, position: Vector3, velocity: Vector3, kind: int, target: Node, zone: int)

static var current: ProjectileSystem = null
## Registrierte Ziele (weltübergreifend; ungültige werden beim Tick entfernt).
static var _targets: Array[Target] = []
static var _next_fake_id := -1

## Debug-Linien (nur mit Anzeige): Segmente des letzten Ticks.
var debug_draw := false
## Gebäude/Fahrzeuge per Physik-Raycast prüfen (bodennah).
var use_raycast := true
## Statistik
var hits_total := 0
var hits_rejected := 0
## Trefferprüfung (Server): jeder Treffer eines bekannten Schützen läuft als HitReport durch.
var validator := HitValidator.new()
var validate_hits := true
var last_step_usec := 0

var _pos := PackedVector3Array()
var _prev := PackedVector3Array()
var _vel := PackedVector3Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _k := PackedFloat32Array()
var _owner_id := PackedInt32Array()
var _shot := PackedInt32Array()
var _gun := PackedInt32Array()
var _wi := PackedInt32Array()
var _tick := PackedInt64Array()
var _flags := PackedByteArray()
var _owner: Array = []
var _weapons: Array[WeaponDef] = []
var _weapon_life := PackedFloat32Array()
var _head := 0
var _active := 0
var _debug_mesh: MeshInstance3D


## Trefferziel: Node3D plus Hitboxen (HitboxSet oder Objekt mit bounding_radius und
## intersect_segment). hitboxes = null → node.damage.hitboxes (Flugzeug).
class Target:
	var node: Node3D
	var hitboxes: Object
	var id := 0
	var prev := Transform3D()
	var has_prev := false
	## Verlauf (≈ 1 s) für den HitValidator.
	var history := TransformHistory.new()

	func boxes() -> Object:
		if hitboxes != null:
			return hitboxes
		var d = node.get("damage")
		return d.hitboxes if d != null else null


func _init() -> void:
	process_physics_priority = -1000
	_pos.resize(CAPACITY)
	_prev.resize(CAPACITY)
	_vel.resize(CAPACITY)
	_age.resize(CAPACITY)
	_life.resize(CAPACITY)
	_k.resize(CAPACITY)
	_owner_id.resize(CAPACITY)
	_shot.resize(CAPACITY)
	_gun.resize(CAPACITY)
	_wi.resize(CAPACITY)
	_tick.resize(CAPACITY)
	_flags.resize(CAPACITY)
	_owner.resize(CAPACITY)


func _enter_tree() -> void:
	current = self
	HitValidator.current = validator


func _exit_tree() -> void:
	if current == self:
		current = null
	if HitValidator.current == validator:
		HitValidator.current = null


# --- Ziele ---------------------------------------------------------------------

## Ziel anmelden (WeaponSystem meldet sein Flugzeug an; Tests eigene Boxen).
static func register_target(node: Node3D, hitboxes: Object = null) -> void:
	for t in _targets:
		if t.node == node:
			t.hitboxes = hitboxes
			t.id = id_of(node)
			return
	var t := Target.new()
	t.node = node
	t.hitboxes = hitboxes
	t.id = id_of(node)
	_targets.append(t)


## Kennung eines Schützen/Ziels: entity_id (Flugzeug) oder eine feste negative Ersatz-ID
## (Testboxen, Bodenziele ohne entity_id).
static func id_of(node: Object) -> int:
	if node == null or not is_instance_valid(node):
		return 0
	var id := CombatEvents.entity_id(node)
	if id > 0:
		return id
	if not node.has_meta(&"_ps_id"):
		_next_fake_id -= 1
		node.set_meta(&"_ps_id", _next_fake_id)
	return node.get_meta(&"_ps_id")


static func target_by_id(id: int) -> Target:
	for t in _targets:
		if t.id == id and t.node != null and is_instance_valid(t.node):
			return t
	return null


static func unregister_target(node: Node3D) -> void:
	for i in range(_targets.size() - 1, -1, -1):
		if _targets[i].node == node:
			_targets.remove_at(i)


## Alle Ziele vergessen (Testläufer/Neustart einer Welt).
static func reset_targets() -> void:
	_targets.clear()


static func targets() -> Array[Target]:
	return _targets


## Floating Origin (Paket 13/14): alle Geschoss- und Zielverläufe um -delta verschieben.
## Der OriginShifter ruft diese Methode statt den Knoten zu bewegen.
func shift_origin(delta: Vector3) -> void:
	for i in CAPACITY:
		if _flags[i] & F_ACTIVE:
			_pos[i] -= delta
			_prev[i] -= delta
	for t in _targets:
		t.prev.origin -= delta
		t.history.shift_origin(delta)
	for c in get_children():
		if c is Node3D:
			(c as Node3D).global_position -= delta


# --- Erzeugen ------------------------------------------------------------------

## Geschoss erzeugen (nur Server). tracer: -1 = aus shot_id und weapon.tracer_every.
## Rückgabe: Slot-Index oder -1.
func spawn(shooter: Node3D, gun_index: int, shot_id: int, pos: Vector3,
		vel: Vector3, weapon: Resource, tracer := -1) -> int:
	var w := weapon as WeaponDef
	if w == null:
		return -1
	var wi := _weapons.find(w)
	if wi < 0:
		wi = _weapons.size()
		_weapons.append(w)
		_weapon_life.append(w.lifetime())
	var i := _head
	_head = (_head + 1) % CAPACITY
	if _flags[i] & F_ACTIVE:
		_emit_end(i, _pos[i], Impact.EXPIRED, null, -1)
	else:
		_active += 1
	if tracer < 0:
		tracer = 1 if w.tracer_every > 0 and shot_id % w.tracer_every == 0 else 0
	_pos[i] = pos
	_prev[i] = pos
	_vel[i] = vel
	_age[i] = 0.0
	_life[i] = _weapon_life[wi]
	_k[i] = w.ballistic_k
	_owner_id[i] = id_of(shooter)
	_owner[i] = shooter
	_shot[i] = shot_id
	_gun[i] = gun_index
	_wi[i] = wi
	_tick[i] = Engine.get_physics_frames()
	_flags[i] = F_ACTIVE | F_FRESH | (F_TRACER if tracer > 0 else 0)
	if validator != null:
		validator.record_shot(shooter, gun_index, shot_id, _tick[i], pos, vel, w)
	spawned.emit(i)
	return i


func active_count() -> int:
	return _active


func clear() -> void:
	_flags.fill(0)
	_owner.fill(null)
	_active = 0
	_head = 0


# --- Lesen (Effekte, HUD, Tests) -------------------------------------------------

func capacity() -> int:
	return CAPACITY


func is_active(i: int) -> bool:
	return _flags[i] & F_ACTIVE != 0


func is_tracer(i: int) -> bool:
	return _flags[i] & F_TRACER != 0


func position(i: int) -> Vector3:
	return _pos[i]


## Position zu Beginn des letzten Ticks (für Leuchtspur-Streifen).
func prev_position(i: int) -> Vector3:
	return _prev[i]


func velocity(i: int) -> Vector3:
	return _vel[i]


func age(i: int) -> float:
	return _age[i]


func shot_id_of(i: int) -> int:
	return _shot[i]


func gun_of(i: int) -> int:
	return _gun[i]


func shooter_of(i: int) -> Node:
	var s = _owner[i]
	return s if s != null and is_instance_valid(s) else null


func weapon_of(i: int) -> WeaponDef:
	return _weapons[_wi[i]]


func active_slots() -> PackedInt32Array:
	var res := PackedInt32Array()
	for i in CAPACITY:
		if _flags[i] & F_ACTIVE:
			res.append(i)
	return res


func tracer_slots() -> PackedInt32Array:
	var res := PackedInt32Array()
	for i in CAPACITY:
		if _flags[i] & (F_ACTIVE | F_TRACER) == (F_ACTIVE | F_TRACER):
			res.append(i)
	return res


# --- Simulation ------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	step(dt, Engine.get_physics_frames())


## Ein Tick. Öffentlich, damit Tests ohne Szenenbaum takten können.
func step(dt: float, tick: int) -> void:
	var t_start := Time.get_ticks_usec()
	var server := Authority.is_server()
	# 1. Ziele
	var tn: Array[Target] = []
	var tc := PackedVector3Array()
	var tr := PackedFloat32Array()
	var tid := PackedInt32Array()
	var inv_prev: Array[Transform3D] = []
	var inv_now: Array[Transform3D] = []
	var vp := get_viewport() if is_inside_tree() else null
	for j in range(_targets.size() - 1, -1, -1):
		var t := _targets[j]
		if t.node == null or not is_instance_valid(t.node):
			_targets.remove_at(j)
			continue
		if not t.node.is_inside_tree() or (vp != null and t.node.get_viewport() != vp):
			t.has_prev = false
			continue
		# entity_id kann sich nach der Anmeldung ändern (Tests, Netz, Respawn).
		t.id = id_of(t.node)
		var boxes := t.boxes()
		var xf := t.node.global_transform
		var pv := t.prev if t.has_prev else xf
		t.prev = xf
		t.has_prev = true
		t.history.record(tick, xf)
		if boxes == null:
			continue
		tn.append(t)
		tc.append((pv.origin + xf.origin) * 0.5)
		tr.append(float(boxes.bounding_radius) + pv.origin.distance_to(xf.origin) * 0.5)
		tid.append(t.id)
		inv_prev.append(pv.affine_inverse())
		inv_now.append(xf.affine_inverse())
	var nt := tn.size()
	# 2. Geschosse
	var h := dt / Ballistics.SUBSTEPS
	var g := Ballistics.GRAVITY
	var space: PhysicsDirectSpaceState3D = null
	var ray: PhysicsRayQueryParameters3D = null
	for i in CAPACITY:
		var fl := _flags[i]
		if fl & F_ACTIVE == 0:
			continue
		if fl & F_FRESH:
			_flags[i] = fl & ~F_FRESH
			if _tick[i] >= tick:
				continue
		var p0 := _pos[i]
		var v := _vel[i]
		var k := _k[i]
		v += (g - v * (k * v.length())) * h
		var p1 := p0 + v * h
		v += (g - v * (k * v.length())) * h
		p1 += v * h
		_prev[i] = p0
		_pos[i] = p1
		_vel[i] = v
		var a := _age[i] + dt
		_age[i] = a
		# Ziele
		var best_t := 2.0
		var best_j := -1
		var best_hit := {}
		var seg := p1 - p0
		var seg_len := seg.length()
		var own := _owner_id[i]
		for j in nt:
			if tid[j] == own:
				continue
			var c := tc[j]
			var lim := tr[j] + seg_len
			if (p1 - c).length_squared() > lim * lim:
				continue
			var f := clampf((c - p0).dot(seg) / maxf(seg_len * seg_len, 1e-9), 0.0, 1.0)
			if (p0 + seg * f - c).length_squared() > tr[j] * tr[j]:
				continue
			var hit: Dictionary = tn[j].boxes().intersect_segment(inv_prev[j] * p0, inv_now[j] * p1)
			if not hit.is_empty() and float(hit.t) < best_t:
				best_t = hit.t
				best_j = j
				best_hit = hit
		# Boden
		var gy := WorldGround.height_at(p1.x, p1.z)
		var ground_t := 2.0
		if p1.y <= gy:
			var gy0 := WorldGround.height_at(p0.x, p0.z)
			ground_t = clampf((p0.y - gy0) / maxf((p0.y - gy0) - (p1.y - gy), 1e-6), 0.0, 1.0)
		var world_t := 2.0
		var world_pt := Vector3.ZERO
		if use_raycast and p1.y - gy < RAY_HEIGHT and vp != null:
			if space == null:
				space = vp.find_world_3d().direct_space_state
				ray = PhysicsRayQueryParameters3D.new()
				ray.collision_mask = Layers.MASK_PROJECTILE_RAY
			ray.from = p0
			ray.to = p1
			var rr := space.intersect_ray(ray)
			if not rr.is_empty():
				world_pt = rr.position
				world_t = p0.distance_to(world_pt) / maxf(seg_len, 1e-6)
		if best_j >= 0 and best_t <= ground_t and best_t <= world_t:
			_hit_target(i, tn[best_j], best_hit, p0.lerp(p1, best_t), server, tick)
		elif ground_t <= 1.0 and ground_t <= world_t:
			_end(i, p0.lerp(p1, ground_t), Impact.GROUND)
		elif world_t <= 1.0:
			_end(i, world_pt, Impact.WORLD)
		elif a >= _life[i]:
			_end(i, p1, Impact.EXPIRED)
	if debug_draw:
		_draw_debug()
	last_step_usec = Time.get_ticks_usec() - t_start


func _hit_target(i: int, t: Target, hit: Dictionary, world_point: Vector3, server: bool,
		tick_now: int) -> void:
	var zone := int(hit.get("zone", -1))
	var shooter := shooter_of(i)
	if server and validate_hits and validator != null and validator.knows_shooter(_owner_id[i]):
		var r := HitValidator.HitReport.new()
		r.shooter_id = _owner_id[i]
		r.shot_id = _shot[i]
		r.target_id = t.id
		r.zone = zone
		r.tick = tick_now
		r.local_point = hit.get("point", Vector3.ZERO)
		if validator.validate(r, tick_now) != HitValidator.Result.OK:
			hits_rejected += 1
			_end(i, world_point, Impact.TARGET, t.node, zone)
			return
	var w := _weapons[_wi[i]]
	var dmg := w.damage
	var tn = t.node.get("nation_id")
	var sn = shooter.get("nation_id") if shooter != null else null
	if tn is int and sn is int and not Nations.is_hostile(sn, tn) \
			and not MatchRules.friendly_fire_damage:
		dmg = 0.0
	hits_total += 1
	if server and dmg > 0.0:
		var lp: Vector3 = hit.get("point", Vector3.ZERO)
		var dm = t.node.get("damage")
		if dm != null and dm.has_method("apply_hit"):
			dm.apply_hit(zone, dmg, shooter, lp)
		elif t.node.has_method("apply_hit"):
			t.node.apply_hit(zone, dmg, shooter, lp)
	CombatEvents.bus().hit_confirmed.emit(shooter, t.node, zone, dmg)
	_end(i, world_point, Impact.TARGET, t.node, zone)


func _end(i: int, p: Vector3, kind: int, target: Node = null, zone := -1) -> void:
	_pos[i] = p
	_flags[i] = 0
	_owner[i] = null
	_active -= 1
	impact.emit(i, p, _vel[i], kind, target, zone)


func _emit_end(i: int, p: Vector3, kind: int, target: Node, zone: int) -> void:
	impact.emit(i, p, _vel[i], kind, target, zone)


func _draw_debug() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if _debug_mesh == null:
		_debug_mesh = MeshInstance3D.new()
		_debug_mesh.mesh = ImmediateMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		_debug_mesh.material_override = m
		add_child(_debug_mesh)
	var im := _debug_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	if _active == 0:
		return
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in CAPACITY:
		if _flags[i] & F_ACTIVE:
			im.surface_set_color(Color.ORANGE if _flags[i] & F_TRACER else Color.GRAY)
			im.surface_add_vertex(_prev[i])
			im.surface_add_vertex(_pos[i])
	im.surface_end()
