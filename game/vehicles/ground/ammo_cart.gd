class_name AmmoCart
extends GroundVehicle
## M3 (Paket 6, Strang H): Munitionswagen (Lkw) mit 6 Kisten (Marker crate_slot_1..6).
## store (AmmoBunker) ist der Vorrat; eine Kiste trägt bis zu ROUNDS_PER_CRATE Schuss als
## eigenen Vorrat (CarryItem.store, für RearmJob/load_gun). crates = Kisten auf dem Wagen.
## take_crate()/return_crate() nehmen bzw. legen zurück (Rest geht in store), fill_from()
## füllt am Bunker nach. Mengen-Erhalt: Schuss wandern nur zwischen Vorräten.

signal crates_changed(n: int)

const CRATE_SLOTS := 6
const ROUNDS_PER_CRATE := 500
const CAPACITY := CRATE_SLOTS * ROUNDS_PER_CRATE
const FILL_RANGE := 10.0
const AMMO := &"7.92"

var crates := CRATE_SLOTS
var store := AmmoBunker.new({AmmoBunker.AMMO_792: CRATE_SLOTS * ROUNDS_PER_CRATE})
var slot_points: Array[Interactable] = []
var _crate_meshes: Array[MeshInstance3D] = []
var realism: int = MatchRules.GroundRealism.STANDARD


func _configure() -> void:
	body_length = 5.6
	for i in CRATE_SLOTS:
		var row := i / 2
		var side := -1.0 if i % 2 == 0 else 1.0
		markers[ServiceMarkers.crate_slot(i + 1)] = Vector3(side * 0.45, 1.25, 0.4 + row * 0.75)


func _ready() -> void:
	super()
	for i in CRATE_SLOTS:
		var it := Interactable.new()
		it.name = "CrateSlot%d" % (i + 1)
		it.marker = ServiceMarkers.crate_slot(i + 1)
		it.target = self
		add_child(it)
		# Kisten von der Ladekante (Heck) aus erreichbar
		var m := marker_point(it.marker)
		it.position = Vector3(m.x * 2.2, 1.0, body_length * 0.5 + 0.2 - (2 - i / 2) * 0.05)
		it.add_action(&"crate_take", "Kiste nehmen", 0.0, &"",
			func(c): return c.get("carried") == null and crates > 0)
		it.add_action(&"crate_return", "Kiste zurücklegen", 0.0, CarryItem.CRATE,
			func(c): return c.get("carried") is CarryItem and store.available(AMMO) < CAPACITY)
		it.performed.connect(_on_slot.bind(it))
		slot_points.append(it)
	store.changed.connect(_update_crates)
	_update_crates()


func _on_slot(id: StringName, character: Node, _it: Interactable) -> void:
	if id == &"crate_take":
		var crate := take_crate()
		if crate != null and not character.call("pick_up", crate):
			return_crate(crate)
	elif id == &"crate_return":
		var item = character.get("carried")
		if item is CarryItem and item.kind == CarryItem.CRATE:
			var c: CarryItem = character.call("release_item")
			return_crate(c)
			if is_instance_valid(c) and not c.is_queued_for_deletion():
				character.call("pick_up", c)   # Wagen voll: Rest bleibt in der Hand


## Nur Server: Kiste vom Wagen nehmen (bis zu ROUNDS_PER_CRATE Schuss). null = leer.
func take_crate() -> CarryItem:
	if not Authority.is_server() or crates <= 0:
		return null
	var n := store.request(AMMO, ROUNDS_PER_CRATE)
	if n <= 0:
		return null
	var c := CarryItem.make(CarryItem.CRATE)
	c.store = AmmoBunker.new({AMMO: n})
	c.apply_realism(realism)
	return c


## Nur Server: Kiste zurücklegen, Restmunition geht in store. Die Kiste wird freigegeben.
func return_crate(c: CarryItem) -> bool:
	if not Authority.is_server() or c == null or c.kind != CarryItem.CRATE:
		return false
	var rest := c.store.available(AMMO) if c.store != null else 0
	if rest > 0:
		var put := mini(rest, CAPACITY - store.available(AMMO))
		c.store.request(AMMO, put)
		store.give_back(AMMO, put)
	if c.store == null or c.store.available(AMMO) == 0:
		if c.get_parent() != null:
			c.get_parent().remove_child(c)
		c.queue_free()
	_update_crates()
	return true


func in_fill_range(src: Object) -> bool:
	var p = src.get("position") if src != null else null
	if not p is Vector3:
		return false
	return Vector2(global_position.x - p.x, global_position.z - p.z).length() <= FILL_RANGE + body_length * 0.5


## Nur Server: am Bunker bis zur Kapazität nachfüllen. Rückgabe: übernommene Schuss.
func fill_from(bunker: AmmoStore, n := CAPACITY) -> int:
	if not Authority.is_server() or bunker == null or not in_fill_range(bunker):
		return 0
	var want := mini(n, CAPACITY - store.available(AMMO))
	var got := bunker.request(AMMO, want) if want > 0 else 0
	if got > 0:
		store.give_back(AMMO, got)
	return got


func _update_crates() -> void:
	var n := mini(CRATE_SLOTS, ceili(store.available(AMMO) / float(ROUNDS_PER_CRATE)))
	for i in _crate_meshes.size():
		_crate_meshes[i].visible = i < n
	if n != crates:
		crates = n
		crates_changed.emit(n)


func _build_visual() -> void:
	super()
	_box(Vector3(track + 0.2, 0.1, 2.6), Vector3(0, 1.0, 1.15), Color(0.3, 0.24, 0.16))
	for i in CRATE_SLOTS:
		var m := _box(Vector3(0.6, 0.3, 0.35), markers[ServiceMarkers.crate_slot(i + 1)] - Vector3(0, 0.1, 0),
			Color(0.36, 0.4, 0.24))
		_crate_meshes.append(m)
