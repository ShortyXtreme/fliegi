class_name AirfieldOps
extends Node3D
## M3 Paket 14: Bodenbetrieb eines Flugplatzes (aus TerrainWorld.airfield_layout(i)).
## Legt an: Tanklager (FuelDepot) und Munitionsbunker (AmmoBunker) mit Modellen, Hangar,
## Bodenmarken an den Abstellplätzen, Tankwagen und Munitionswagen (Modelle aus
## assets/ground/), GroundCrewDispatch (Automatik) und CREW_COUNT KI-Mechaniker mit Figur
## (crew_model.tscn, AnimationTree) und GroundCrewBrain.

const CREW_COUNT := 2
const CREW_MODEL := "res://characters/crew/anim/crew_model.tscn"
const MODELS := "res://assets/ground/%s.glb"
const CREW_NAMES := ["Mechaniker A", "Mechaniker B", "Mechaniker C"]
## Gebäude-Öffnung (−Z im Modell) zeigt nach +X (zum Rollweg/Abstellplatz).
const FACE_EAST := -PI * 0.5
## M3.1: Hallen nebeneinander nach Norden (Abstand Mitte–Mitte, m).
const HANGAR_COUNT := 3
const HANGAR_SPACING := 48.0

var layout: AirfieldLayout
var board: JobBoard
var depot: FuelDepot
var bunker: AmmoBunker
var dispatch: GroundCrewDispatch
var truck: FuelTruck
var cart: AmmoCart
var crews: Array[CrewCharacter] = []
var brains: Array[GroundCrewBrain] = []
## Diagnose: Name -> Anzahl MeshInstance3D der geladenen Modelle.
var model_meshes := {}


static func load_model(n: String) -> Node3D:
	var p := MODELS % n
	if not ResourceLoader.exists(p):
		return null
	var ps := load(p) as PackedScene
	return ps.instantiate() as Node3D if ps != null else null


static func mesh_count(n: Node) -> int:
	return n.find_children("*", "MeshInstance3D", true, false).size() if n != null else 0


## Alles anlegen (Server). host = Game (Fahrzeuge/Figuren hängen dort, damit Floating
## Origin und Tests sie finden), player_aircraft = Spieler-Maschine (Priorität).
func setup(l: AirfieldLayout, b: JobBoard, host: Node, player_aircraft: Array = []) -> void:
	layout = l
	board = b
	name = "AirfieldOps%d" % l.airfield_index
	depot = FuelDepot.new()
	bunker = AmmoBunker.new()
	_buildings()
	dispatch = GroundCrewDispatch.new()
	dispatch.name = "Dispatch%d" % l.airfield_index
	dispatch.board = b
	dispatch.depot = depot
	dispatch.store = bunker
	dispatch.watch_root = host
	dispatch.player_aircraft = player_aircraft
	dispatch.setup_from_layout(l)
	add_child(dispatch)
	_vehicles(host)
	for k in CREW_COUNT:
		_crew(host, k)


func _ground(p: Vector3) -> Vector3:
	return Vector3(p.x, WorldGround.height_at(p.x, p.z), p.z)


func _put(model: Node3D, key: String, pos: Vector3, yaw: float) -> Node3D:
	if model == null:
		model_meshes[key] = 0
		return null
	model.name = key
	add_child(model)
	model.global_transform = Transform3D(Basis(Vector3.UP, yaw), _ground(pos))
	model_meshes[key] = mesh_count(model)
	return model


func _buildings() -> void:
	var fd := _put(load_model("fuel_depot"), "fuel_depot", layout.to_scene(layout.fuel_depot), FACE_EAST)
	var ab := _put(load_model("ammo_bunker"), "ammo_bunker", layout.to_scene(layout.ammo_bunker), FACE_EAST)
	# M3.1: Gebäude als Hindernisse der Wegsuche (Personal und Wagen) und mit Kollision
	for m in [fd, ab]:
		if m != null:
			GroundNav.register_model(m)
			_solid(m)
	# M3.1: alle Hallen als Modell (vorher Halle 1/2 und Turm graue Platzhalter in TerrainWorld)
	for k in HANGAR_COUNT:
		var key := "hangar" if k == 0 else "hangar_%d" % k
		var h := _put(load_model("hangar"), key, layout.to_scene(layout.hangar + Vector3(0, 0, -HANGAR_SPACING * k)), FACE_EAST)
		if h == null:
			continue
		GroundNav.register_model(h)
		# Kollision: Rück- und Seitenwände, Dach (Tor offen zum Rollweg)
		var body := StaticBody3D.new()
		body.collision_layer = Layers.WORLD
		body.collision_mask = 0
		h.add_child(body)
		for w in [[Vector3(24.0, 8.0, 0.6), Vector3(0, 4, 9.0)], [Vector3(0.6, 8.0, 24.0), Vector3(-12.0, 4, -3.0)],
				[Vector3(0.6, 8.0, 24.0), Vector3(12.0, 4, -3.0)], [Vector3(24.6, 0.6, 24.3), Vector3(0, 8.3, -2.85)]]:
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = w[0]
			cs.shape = bs
			cs.position = w[1]
			body.add_child(cs)
	for i in layout.parking_count():
		var m := load_model("parking_mark")
		if m == null:
			break
		var xf := layout.parking_transform(i)
		add_child(m)
		m.name = "parking_mark_%d" % i
		m.global_transform = Transform3D(xf.basis, _ground(xf.origin) + Vector3(0, 0.03, 0))
		model_meshes["parking_mark"] = mesh_count(m)


## Kollisionsbox um das Modell (Tanklager, Bunker), etwas kleiner als die Umrisse.
func _solid(m: Node3D) -> void:
	var bb := GroundNav.model_aabb(m)
	var body := StaticBody3D.new()
	body.collision_layer = Layers.WORLD
	body.collision_mask = 0
	m.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(maxf(bb.size.x - 0.4, 0.5), bb.size.y, maxf(bb.size.z - 0.4, 0.5))
	cs.shape = bs
	cs.position = bb.get_center()
	body.add_child(cs)


func _vehicles(host: Node) -> void:
	var r := MatchRules.ground_realism
	var auth := r == MatchRules.GroundRealism.AUTHENTISCH
	truck = FuelTruck.create(0.0 if auth else FuelTruck.TANK_CAPACITY)
	truck.name = "FuelTruck%d" % layout.airfield_index
	truck.nation_id = layout.nation_id
	# Mengen-Erhalt: der Wagen-Inhalt kommt aus dem Lager.
	if not auth:
		depot.draw(FuelSystem.GRADE_AVIATION, FuelTruck.TANK_CAPACITY)
	truck.depot = depot
	host.add_child(truck)
	var tm := load_model("fuel_truck")
	model_meshes["fuel_truck"] = mesh_count(tm)
	if tm != null:
		truck.apply_model(tm)
	var vs := layout.vehicle_spawns
	var tp := layout.to_scene(vs[0]) if vs.size() > 0 else dispatch.depot_pos + Vector3(10, 0, 0)
	truck.place(_ground(tp), 0.0)
	cart = AmmoCart.new()
	cart.name = "AmmoCart%d" % layout.airfield_index
	cart.nation_id = layout.nation_id
	cart.realism = r
	# Mengen-Erhalt: die 6 Kisten auf dem Wagen kommen aus dem Bunker.
	var have := cart.store.available(AmmoBunker.AMMO_792)
	cart.store.request(AmmoBunker.AMMO_792, have)
	cart.store.give_back(AmmoBunker.AMMO_792, bunker.request(AmmoBunker.AMMO_792, have))
	host.add_child(cart)
	var cm := load_model("ammo_cart")
	model_meshes["ammo_cart"] = mesh_count(cm)
	if cm != null:
		cart.apply_model(cm)
	var cp := layout.to_scene(vs[1]) if vs.size() > 1 else tp + Vector3(0, 0, -12)
	cart.place(_ground(cp), 0.0)
	dispatch.fuel_truck = truck
	dispatch.ammo_cart = cart


func _crew(host: Node, k: int) -> void:
	var ch := CrewCharacter.new()
	ch.name = CREW_NAMES[k % CREW_NAMES.size()] if layout.nation_id == Nations.BLUE \
		else "Rot-Mechaniker %d" % (k + 1)
	ch.nation_id = layout.nation_id
	# KI-Personal ohne Wegsuche: nicht an Wagen/Flugzeugen hängen bleiben (Spielerfigur kollidiert).
	ch.collision_mask &= ~(Layers.GROUND_VEHICLE | Layers.AIRCRAFT)
	host.add_child(ch)
	if ResourceLoader.exists(CREW_MODEL):
		var m := (load(CREW_MODEL) as PackedScene).instantiate() as Node3D
		model_meshes["crew"] = ch.apply_model(m)
	var p := layout.to_scene(layout.crew_spawn) + Vector3(0, 0, k * 2.5)
	ch.global_position = _ground(p)
	var br := GroundCrewBrain.new()
	br.name = "Brain"
	br.dispatch = dispatch
	br.board = board
	br.sim_pos = ch.global_position
	# Die Figur schaltet sich im Fahrzeug ab (PROCESS_MODE_DISABLED); das Gehirn muss weiterlaufen.
	br.process_mode = Node.PROCESS_MODE_PAUSABLE
	ch.add_child(br)
	ch.crew_seat.possess(br)
	crews.append(ch)
	brains.append(br)
	dispatch.crews.append(br)


## Diagnosezeile (Log/Selbsttest).
func diagnostics() -> String:
	var anim := 0
	if not crews.is_empty() and crews[0].anim_tree != null:
		var ap := crews[0].anim_tree.get_node_or_null(crews[0].anim_tree.anim_player) as AnimationPlayer
		anim = ap.get_animation_list().size() if ap != null else 0
	return "Platz %d (%s): Layout %s, Abstellplätze %d, Lager %.0f l Flugbenzin/%.0f l Ersatz, Bunker %d Schuss, Tankwagen %.0f l, Munitionswagen %d Schuss, Personal %d, Animationen %d, Modelle %s" % [
		layout.airfield_index, Nations.NAMES[layout.nation_id] if Nations.is_valid(layout.nation_id) else "-",
		"Datei" if layout.resource_path != "" or layout.parking_in_nodes.size() > 0 else "Ersatz",
		layout.parking_count(), depot.available(FuelSystem.GRADE_AVIATION), depot.available(FuelSystem.GRADE_ERSATZ),
		bunker.available(AmmoBunker.AMMO_792), truck.tank.total(), cart.store.available(AmmoBunker.AMMO_792),
		crews.size(), anim, str(model_meshes)]


func animation_count() -> int:
	if crews.is_empty() or crews[0].anim_tree == null:
		return 0
	var ap := crews[0].anim_tree.get_node_or_null(crews[0].anim_tree.anim_player) as AnimationPlayer
	return ap.get_animation_list().size() if ap != null else 0
