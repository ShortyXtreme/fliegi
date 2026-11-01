class_name AircraftVisual
extends Node3D
## Darstellung eines Flugzeugs. Lädt AircraftData.model_path (importiertes .glb/.tscn
## oder zur Laufzeit per GLTFDocument), sonst wird ein Platzhalter aus Primitiven
## gebaut, der direkt aus den Aero-Flächen abgeleitet ist (Geometrie = Physik).
## Ruder und Propeller werden im Platzhalter animiert.
##
## Paket 11 (Agent B): Spielmodell fighter_t1_game.glb mit Rig (art/models/fighter_t1_rig.json).
## Ist die Datei vorhanden, wird sie statt model_path benutzt (Gegner/Rot: *_enemy.glb).
## Animiert: Querruder, Klappen, Höhen-/Seitenruder (inkl. klemmender Ruder aus den
## FlightModifiers), Fahrwerk, Spornrad, Räder, Propeller + Propellerscheibe, Haube, Pilot.
## Schadenseffekte (Rauch/Öl/Brand/Leck) über DamageFx.

var data: AircraftData
var model_root: Node3D
var using_placeholder := true
var _control_pivots: Array = []   # [pivot: Node3D, def: AeroSurfaceDef]
var _prop: Node3D
var _prop_angle := 0.0
var _gear_pivots: Array = []    # [pivot: Node3D, Klapprichtung (+1/-1)]
var _gear_shown := 1.0

## Spielmodell mit Rig (relativ zum Projektordner game/). Paket 14: in res:// übernehmen.
const RIG_MODEL := "../art/models/fighter_t1_game.glb"
const RIG_MODEL_ENEMY := "../art/models/fighter_t1_game_enemy.glb"
## Rig-Daten aus fighter_t1_rig.json (Achsen lokal, Grad).
const RIG := {
	"aileron_L": [Vector3.RIGHT, -20.0, 15.0], "aileron_R": [Vector3.RIGHT, -20.0, 15.0],
	"flap_L": [Vector3.RIGHT, 0.0, 40.0], "flap_R": [Vector3.RIGHT, 0.0, 40.0],
	"elevator": [Vector3.RIGHT, -25.0, 20.0], "rudder": [Vector3.UP, -25.0, 25.0],
	"tailwheel": [Vector3.UP, -35.0, 35.0],
	"gear_main_L": [Vector3.RIGHT, 0.0, 80.88], "gear_main_R": [Vector3.RIGHT, 0.0, 80.88],
	"wheel_main_L": [Vector3.RIGHT, 0.34], "wheel_main_R": [Vector3.RIGHT, 0.34],
	"wheel_tail": [Vector3.RIGHT, 0.115],
}
const CANOPY_OPEN_Z := -0.55
static var _rig_cache := {}

## true = Spielmodell mit Rig geladen.
var using_rig := false
## Teilname -> {"node": Node3D, "rest": Transform3D}
var rig_parts := {}
var fx: DamageFx
var _built := false
var _canopy_open := 0.0
var _wheel_angle := 0.0
var _aircraft: Node3D


func build(d: AircraftData) -> void:
	data = d
	_aircraft = get_parent() as Node3D
	# Nation steht erst fest, wenn das Flugzeug im Baum ist -> Aufbau dort.
	if is_inside_tree():
		_build_now()


func _ready() -> void:
	if data != null and not _built:
		_build_now()


func _build_now() -> void:
	_built = true
	var d := data
	_aircraft = get_parent() as Node3D
	var enemy: bool = _aircraft != null and _aircraft.get("nation_id") is int and _aircraft.nation_id != Nations.BLUE
	model_root = _load_rig_model(RIG_MODEL_ENEMY if enemy else RIG_MODEL)
	if model_root != null:
		using_placeholder = false
		using_rig = true
		model_root.rotation_degrees = Vector3(0, 180, 0)   # Rig: Nase +Z, Godot: Nase -Z
		add_child(model_root)
		_setup_rig()
		for n in model_root.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		_setup_fx()
		return
	model_root = _load_model(d.model_path)
	if model_root != null:
		using_placeholder = false
		model_root.position = d.model_offset
		model_root.rotation_degrees = d.model_rotation_deg
		model_root.scale = Vector3.ONE * d.model_scale
		add_child(model_root)
		if d.model_fit_span > 0.0:
			_fit_span(d.model_fit_span)
		_prop = _find_node_ci(model_root, "prop")
		_setup_gear_model()
		for n in model_root.find_children("*", "MeshInstance3D", true, false):
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		using_placeholder = true
		model_root = Node3D.new()
		model_root.name = "Placeholder"
		add_child(model_root)
		_build_placeholder()
	_setup_fx()


func _setup_fx() -> void:
	var dm = _aircraft.get("damage") if _aircraft != null else null
	if dm is DamageModel:
		fx = DamageFx.new()
		add_child(fx)
		fx.setup(dm)


## GLB einmal je Pfad laden (Laufzeit-Import ~2,5 s), danach duplizieren.
static func _load_rig_model(rel: String) -> Node3D:
	if not _rig_cache.has(rel):
		var abs_path := ProjectSettings.globalize_path("res://").path_join(rel).simplify_path()
		var scene: PackedScene = null
		if FileAccess.file_exists(abs_path):
			var doc := GLTFDocument.new()
			var st := GLTFState.new()
			if doc.append_from_file(abs_path, st) == OK:
				var root := doc.generate_scene(st)
				if root != null:
					for n in root.find_children("*", "", true, false):
						n.owner = root
					scene = PackedScene.new()
					if scene.pack(root) != OK:
						scene = null
					root.free()
		_rig_cache[rel] = scene
	var sc: PackedScene = _rig_cache[rel]
	return sc.instantiate() as Node3D if sc != null else null


func _setup_rig() -> void:
	for part in ["aileron_L", "aileron_R", "flap_L", "flap_R", "elevator", "rudder", "tailwheel",
			"gear_main_L", "gear_main_R", "wheel_main_L", "wheel_main_R", "wheel_tail",
			"propeller", "prop_disc", "prop_blades", "canopy", "pilot"]:
		var n := model_root.find_child(part, true, false) as Node3D
		if n != null:
			rig_parts[part] = {"node": n, "rest": n.transform}
	_prop = rig_parts.propeller.node if rig_parts.has("propeller") else null


## Teil um seine lokale Rig-Achse drehen (Grad, auf Rig-Grenzen begrenzt).
func _rig_rotate(part: String, deg: float) -> void:
	if not rig_parts.has(part):
		return
	var r: Array = RIG[part]
	var e: Dictionary = rig_parts[part]
	var a := clampf(deg, r[1], r[2])
	(e.node as Node3D).transform.basis = (e.rest as Transform3D).basis * Basis(r[0], deg_to_rad(a))


func _rig_spin(part: String, angle: float, axis: Vector3) -> void:
	if rig_parts.has(part):
		var e: Dictionary = rig_parts[part]
		(e.node as Node3D).transform.basis = (e.rest as Transform3D).basis * Basis(axis, angle)


## Ruderausschlag -1..1 -> Grad (positiv bis max, negativ bis min).
static func _deflect(v: float, r: Array) -> float:
	return v * r[2] if v >= 0.0 else -v * r[1]


## Effektives Ruderkommando wie im Flugmodell (klemmende/abgeschossene Ruder sichtbar).
func _surface_cmd(axis: int, side: int, cmd: float) -> float:
	var mods: FlightModifiers = _aircraft.flight.modifiers if _aircraft != null and _aircraft.get("flight") != null else null
	if mods == null or data == null:
		return cmd
	for i in data.surfaces.size():
		var s: AeroSurfaceDef = data.surfaces[i]
		if s.control_axis == axis and (side == 0 or signf(s.position.x) == side) and i < mods.lift.size():
			return mods.control_command(i, cmd * s.control_sign) * s.control_sign
	return cmd


func _update_rig(t: FlightTelemetry, dt: float) -> void:
	var c := t.commands
	if c != null:
		# Querruder: rechts rollen -> rechtes Querruder hoch (Hinterkante oben), linkes runter.
		# Godot +X = rechte Fläche = Rig wing_R (Rig -X).
		var ar := _surface_cmd(AeroSurfaceDef.ControlAxis.ROLL, 1, c.aileron)
		var al := _surface_cmd(AeroSurfaceDef.ControlAxis.ROLL, -1, c.aileron)
		_rig_rotate("aileron_L", _deflect(al, RIG.aileron_L))
		_rig_rotate("aileron_R", _deflect(-ar, RIG.aileron_R))
		var fl := clampf(c.flaps, 0.0, 1.0) * 40.0
		_rig_rotate("flap_L", fl)
		_rig_rotate("flap_R", fl)
		# Höhenruder: Nase hoch -> Hinterkante hoch (negativ)
		var el := _surface_cmd(AeroSurfaceDef.ControlAxis.PITCH, 0, c.elevator)
		_rig_rotate("elevator", _deflect(-el, RIG.elevator))
		# Seitenruder: Nase rechts -> Hinterkante rechts (positiv)
		var ru := _surface_cmd(AeroSurfaceDef.ControlAxis.YAW, 0, c.rudder)
		_rig_rotate("rudder", _deflect(ru, RIG.rudder))
		_rig_rotate("tailwheel", -ru * 35.0)
	# Fahrwerk (eingefahren = 80,88°), Räder drehen am Boden
	var u := 1.0 - t.gear_extension
	_rig_rotate("gear_main_L", 80.88 * u * u * (3.0 - 2.0 * u))
	_rig_rotate("gear_main_R", 80.88 * u * u * (3.0 - 2.0 * u))
	if t.wheels_in_contact > 0:
		_wheel_angle += t.airspeed * dt
	_rig_spin("wheel_main_L", _wheel_angle / 0.34, Vector3.RIGHT)
	_rig_spin("wheel_main_R", _wheel_angle / 0.34, Vector3.RIGHT)
	_rig_spin("wheel_tail", _wheel_angle / 0.115, Vector3.RIGHT)
	# Propeller: Drehzahl ~ Gas; ab hoher Drehzahl Scheibe statt Blätter
	_prop_angle = fmod(_prop_angle + dt * (6.0 + 140.0 * t.throttle_actual), TAU)
	_rig_spin("propeller", _prop_angle, Vector3.BACK)
	var disc := t.throttle_actual > 0.35
	if rig_parts.has("prop_disc"):
		rig_parts.prop_disc.node.visible = disc
	if rig_parts.has("prop_blades"):
		rig_parts.prop_blades.node.visible = not disc
	# Haube: am Boden langsam -> offen; Pilot ausgestiegen -> Haube und Pilot weg
	var dm = _aircraft.get("damage") if _aircraft != null else null
	var gone: bool = dm is DamageModel and dm.pilot_state == DamageModel.PilotState.EJECTED
	var want := 1.0 if t.on_ground and t.airspeed < 8.0 and t.throttle_actual < 0.3 else 0.0
	_canopy_open = move_toward(_canopy_open, want, dt * 0.8)
	if rig_parts.has("canopy"):
		var e: Dictionary = rig_parts.canopy
		e.node.position = (e.rest as Transform3D).origin + Vector3(0, 0, CANOPY_OPEN_Z * _canopy_open)
		e.node.visible = not gone and not _cockpit_view
	if rig_parts.has("pilot"):
		rig_parts.pilot.node.visible = not gone and not _cockpit_view


func _fit_span(span: float) -> void:
	var aabb := AABB()
	var first := true
	for n in model_root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var local_xf := global_transform.affine_inverse() * mi.global_transform if is_inside_tree() \
			else _relative_xf(mi)
		var box := local_xf * mi.get_aabb()
		aabb = box if first else aabb.merge(box)
		first = false
	if not first and aabb.size.x > 0.01:
		model_root.scale *= span / aabb.size.x


func _relative_xf(n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != self:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


static func _load_model(path: String) -> Node3D:
	if path.is_empty():
		return null
	if ResourceLoader.exists(path):
		var res = load(path)
		if res is PackedScene:
			return (res as PackedScene).instantiate() as Node3D
	# Laufzeit-Import (z. B. Datei liegt neu im Ordner, ist aber noch nicht importiert)
	var abs_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if FileAccess.file_exists(abs_path) and (abs_path.ends_with(".glb") or abs_path.ends_with(".gltf")):
		var doc := GLTFDocument.new()
		var st := GLTFState.new()
		if doc.append_from_file(abs_path, st) == OK:
			return doc.generate_scene(st) as Node3D
	return null


func _find_node_ci(n: Node, part: String) -> Node3D:
	if n.name.to_lower().contains(part) and n is Node3D:
		return n
	for c in n.get_children():
		var r := _find_node_ci(c, part)
		if r:
			return r
	return null


func _mat(c: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(mesh: Mesh, mat: Material, parent: Node3D, pos := Vector3.ZERO, rot_deg := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	parent.add_child(mi)
	return mi


func _build_placeholder() -> void:
	var body := _mat(data.body_color)
	var accent := _mat(data.accent_color)
	var dark := _mat(Color(0.12, 0.12, 0.13), 0.5, 0.3)
	var glass := _mat(Color(0.55, 0.75, 0.9, 0.45), 0.1)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Rumpf: zwei Kegelstümpfe + Motorhaube
	var front := CylinderMesh.new()
	front.top_radius = 0.62; front.bottom_radius = 0.55; front.height = 3.0
	_mesh(front, body, model_root, Vector3(0, 0.05, -1.4), Vector3(-90, 0, 0))
	var rear := CylinderMesh.new()
	rear.top_radius = 0.15; rear.bottom_radius = 0.62; rear.height = 5.0
	_mesh(rear, body, model_root, Vector3(0, 0.15, 2.6), Vector3(-90, 0, 0))
	var cowl := CylinderMesh.new()
	cowl.top_radius = 0.55; cowl.bottom_radius = 0.6; cowl.height = 0.6
	_mesh(cowl, accent, model_root, Vector3(0, 0.05, -3.0), Vector3(-90, 0, 0))
	var spinner := SphereMesh.new()
	spinner.radius = 0.32; spinner.height = 0.9
	_mesh(spinner, accent, model_root, data.propeller_position + Vector3(0, 0, -0.05), Vector3(90, 0, 0))
	var canopy := SphereMesh.new()
	canopy.radius = 0.45; canopy.height = 0.75
	var cmi := _mesh(canopy, glass, model_root, Vector3(0, 0.62, 0.7))
	cmi.set_meta("glass", true)
	cmi.scale = Vector3(1.0, 1.0, 2.4)

	# Propeller
	_prop = Node3D.new()
	_prop.name = "Propeller"
	_prop.position = data.propeller_position
	model_root.add_child(_prop)
	var blade := BoxMesh.new()
	blade.size = Vector3(0.22, 3.0, 0.06)
	_mesh(blade, dark, _prop)
	_mesh(blade, dark, _prop, Vector3.ZERO, Vector3(0, 0, 90))

	# Flächen aus den Aero-Definitionen
	for s in data.surfaces:
		_build_surface(s, body, accent)

	# Fahrwerk (einziehbare Räder hängen an einem Drehpunkt am Beinkopf)
	for w in data.wheels:
		var holder := model_root
		var base := w.position
		if w.retractable:
			var pivot := Node3D.new()
			pivot.name = "GearPivot_" + w.name
			pivot.position = w.position
			model_root.add_child(pivot)
			holder = pivot
			base = Vector3.ZERO
			_gear_pivots.append([pivot, -signf(w.position.x) if w.position.x != 0.0 else 1.0])
		var strut := CylinderMesh.new()
		strut.top_radius = 0.05; strut.bottom_radius = 0.05; strut.height = w.rest_length
		_mesh(strut, dark, holder, base + Vector3(0, -w.rest_length * 0.5, 0))
		var tire := CylinderMesh.new()
		tire.top_radius = w.radius; tire.bottom_radius = w.radius; tire.height = w.radius * 0.6
		_mesh(tire, dark, holder, base + Vector3(0, -w.rest_length + 0.1, 0), Vector3(0, 0, 90))

	# Hoheitszeichen (fiktiv): gelber Ring auf den Flügeln
	var roundel := CylinderMesh.new()
	roundel.top_radius = 0.45; roundel.bottom_radius = 0.45; roundel.height = 0.02
	for sx in [-1.0, 1.0]:
		_mesh(roundel, accent, model_root, Vector3(sx * 3.6, -0.18, 0.1))


func _build_surface(s: AeroSurfaceDef, body: Material, accent: Material) -> void:
	var holder := Node3D.new()
	holder.name = s.name
	holder.position = s.position
	holder.rotation_degrees = s.rotation_deg
	model_root.add_child(holder)
	var thick := clampf(s.chord * 0.1, 0.05, 0.22)
	var fixed_chord := s.chord * (1.0 - s.flap_fraction) if s.control_axis != AeroSurfaceDef.ControlAxis.NONE else s.chord
	# Druckpunkt liegt bei 1/4 Tiefe: Vorderkante = -chord/4
	var le := -s.chord * 0.25
	var box := BoxMesh.new()
	box.size = Vector3(s.span, thick, fixed_chord)
	_mesh(box, body, holder, Vector3(0, 0, le + fixed_chord * 0.5))
	if s.control_axis != AeroSurfaceDef.ControlAxis.NONE:
		var pivot := Node3D.new()
		pivot.position = Vector3(0, 0, le + fixed_chord)
		holder.add_child(pivot)
		var flap := BoxMesh.new()
		var fc := s.chord * s.flap_fraction
		flap.size = Vector3(s.span * 0.96, thick * 0.7, fc)
		_mesh(flap, accent if s.control_axis != AeroSurfaceDef.ControlAxis.FLAPS else body, pivot, Vector3(0, 0, fc * 0.5))
		_control_pivots.append([pivot, s])


## Cockpit-Ansicht: Kabinenglas (Mesh-Name "Canopy" bzw. Platzhalter) ausblenden,
## damit die Sicht von innen nicht getönt/verdeckt ist.
var _cockpit_view := false


func set_cockpit_view(on: bool) -> void:
	_cockpit_view = on
	if model_root == null:
		return
	for n in model_root.find_children("*", "MeshInstance3D", true, false):
		var nm := String(n.name).to_lower()
		if nm == "canopy" or nm.begins_with("canopy_glass") or n.get_meta("glass", false):
			(n as MeshInstance3D).visible = not on


func update_controls(t: FlightTelemetry, dt: float) -> void:
	if using_rig:
		_update_rig(t, dt)
		return
	if model_root == null:
		return
	if not is_equal_approx(_gear_shown, t.gear_extension):
		_gear_shown = t.gear_extension
		_apply_gear(_gear_shown)
	if _prop:
		_prop_angle += dt * (6.0 + 140.0 * t.throttle_actual)
		_prop.rotation.z = _prop_angle
	if t.commands == null:
		return
	for p in _control_pivots:
		var s: AeroSurfaceDef = p[1]
		var v := t.commands.axis_value(s.control_axis)
		# positiver Ausschlag = Hinterkante nach unten = Drehung um -X (lokal)
		(p[0] as Node3D).rotation.x = -deg_to_rad(s.max_deflection_deg) * v * s.control_sign


# --- Einziehfahrwerk -------------------------------------------------------------
## Teile des GLB, die zum Hauptfahrwerk gehören (Namensanfang, Groß-/Kleinschreibung egal).
const GEAR_PARTS := ["gearleg", "oleo", "fork", "axle", "hub", "maintire", "geardoor"]
const GEAR_FOLD_DEG := 88.0


## Hauptfahrwerk-Teile je Seite unter einen Drehpunkt am Beinkopf hängen.
func _setup_gear_model() -> void:
	var groups := {1: [], -1: []}
	var tops := {1: Vector3.ZERO, -1: Vector3.ZERO}
	var top_y := {1: -INF, -1: -INF}
	for n in model_root.find_children("*", "MeshInstance3D", true, false):
		var nm := String(n.name).to_lower()
		var hit := false
		for part in GEAR_PARTS:
			if nm.begins_with(part):
				hit = true
		if not hit:
			continue
		var mi := n as MeshInstance3D
		var xf := _xf_rel(mi, model_root)
		var box := xf * mi.get_aabb()
		var c := box.get_center()
		var side := 1 if c.x > 0.0 else -1
		groups[side].append([mi, xf])
		if nm.begins_with("gearleg") and box.end.y > top_y[side]:
			top_y[side] = box.end.y
			tops[side] = Vector3(c.x, box.end.y, c.z)
	for side in [1, -1]:
		if groups[side].is_empty():
			continue
		var pivot := Node3D.new()
		pivot.name = "GearPivot_%s" % ("P" if side > 0 else "N")
		pivot.position = tops[side] if top_y[side] > -INF else Vector3.ZERO
		model_root.add_child(pivot)
		for e in groups[side]:
			var mi: MeshInstance3D = e[0]
			var xf: Transform3D = e[1]
			mi.owner = null
			mi.get_parent().remove_child(mi)
			pivot.add_child(mi)
			mi.transform = pivot.transform.affine_inverse() * xf
		# Einklappen nach innen (Richtung Rumpfmitte) um die Längsachse des Modells
		_gear_pivots.append([pivot, -float(side)])


static func _xf_rel(n: Node3D, ancestor: Node) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p != null and p != ancestor:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf


## Fahrwerksstellung sofort übernehmen (Spawn/Neustart).
func snap_gear(ext: float) -> void:
	_gear_shown = ext
	if using_rig:
		var u := 1.0 - ext
		_rig_rotate("gear_main_L", 80.88 * u * u * (3.0 - 2.0 * u))
		_rig_rotate("gear_main_R", 80.88 * u * u * (3.0 - 2.0 * u))
		return
	_apply_gear(ext)


func _apply_gear(ext: float) -> void:
	# Klappweg: erst langsam (Verriegelung), dann gleichmäßig
	var u := 1.0 - ext
	var ang := deg_to_rad(GEAR_FOLD_DEG) * (u * u * (3.0 - 2.0 * u))
	for p in _gear_pivots:
		(p[0] as Node3D).rotation = Vector3(0, 0, ang * float(p[1]))
	var hidden := ext <= 0.001
	for p in _gear_pivots:
		(p[0] as Node3D).visible = not hidden
