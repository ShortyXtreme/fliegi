class_name CarryItem
extends Node3D
## M3 (Paket 5, Strang H): tragbarer Gegenstand (Kiste, Schlauchende, Kanister, Werkzeug).
## Liegt er frei, bietet er die Aktion „Aufheben“ (Interactable-Kind pickup). Die Figur
## trägt ihn am Marker carry; Gehtempo × speed_mul, Sprint nur mit can_sprint.
## Inhalt: store (AmmoStore, Kiste), liters/grade (Kanister), tether (FuelHose beim Schlauch).

signal picked_up(character: Node)
signal dropped(character: Node)

const CRATE := &"crate"
const HOSE := &"hose"
const CANISTER := &"canister"
const TOOL := &"tool"
const KINDS: Array[StringName] = [CRATE, HOSE, CANISTER, TOOL]
## Gehtempo-Faktor je Last (Standard). Authentisch: Kiste 25 kg -> AUTHENTIC_CRATE_MUL.
const SPEED_MUL := {&"crate": 0.8, &"hose": 0.85, &"canister": 0.75, &"tool": 0.95}
const CAN_SPRINT := {&"crate": false, &"hose": false, &"canister": false, &"tool": true}
const MASS_KG := {&"crate": 18.0, &"hose": 6.0, &"canister": 22.0, &"tool": 8.0}
const LABELS := {&"crate": "Kiste", &"hose": "Schlauch", &"canister": "Kanister", &"tool": "Werkzeug"}
const AUTHENTIC_CRATE_MUL := 0.65

var kind: StringName = CRATE
var speed_mul := 0.8
var can_sprint := false
var mass_kg := 18.0
## Figur, die den Gegenstand trägt (oder null).
var holder: Node = null
## Gesperrt (z. B. Schlauch angekoppelt): kein Aufheben.
var locked := false
## Kiste: Munitionsvorrat (RearmJob.store). Kanister: Liter und Sorte.
var store: AmmoStore = null
var liters := 0.0
var grade: StringName = &"aviation"
## Schlauchende: FuelHose, begrenzt die Position der Figur.
var tether: Object = null
var pickup: Interactable


static func make(k: StringName) -> CarryItem:
	var it := CarryItem.new()
	it.setup(k)
	return it


func setup(k: StringName) -> void:
	kind = k
	speed_mul = SPEED_MUL.get(k, 1.0)
	can_sprint = CAN_SPRINT.get(k, true)
	mass_kg = MASS_KG.get(k, 5.0)
	name = String(LABELS.get(k, "Item"))
	if pickup == null:
		pickup = Interactable.new()
		pickup.name = "Pickup"
		pickup.target = self
		pickup.marker = "item_" + String(k)
		pickup.position.y = 0.25
		add_child(pickup)
		pickup.add_action(&"pick_up", "%s aufheben" % LABELS.get(k, "Gegenstand"), 0.0, &"", _can_pick)
		pickup.performed.connect(_on_pickup)
	_build_visual()


func _can_pick(character: Node) -> bool:
	return holder == null and not locked and character != null and character.get("carried") == null


func _on_pickup(id: StringName, character: Node) -> void:
	if id == &"pick_up" and character.has_method("pick_up"):
		character.call("pick_up", self)


## Last nach Realismus-Stufe (Authentisch: Kiste 25 kg, -35 %).
func apply_realism(r: int) -> void:
	if kind == CRATE and r == MatchRules.GroundRealism.AUTHENTISCH:
		speed_mul = AUTHENTIC_CRATE_MUL
		mass_kg = 25.0


## Position der Figur begrenzen (Schlauch); sonst unverändert.
func constrain(p: Vector3) -> Vector3:
	if tether != null and tether.has_method("constrain"):
		return tether.call("constrain", p)
	return p


func on_picked(character: Node) -> void:
	holder = character
	pickup.enabled = false
	picked_up.emit(character)


func on_dropped(character: Node) -> void:
	holder = null
	pickup.enabled = not locked
	dropped.emit(character)


func set_locked(on: bool) -> void:
	locked = on
	pickup.enabled = not on and holder == null


func _build_visual() -> void:
	var old := get_node_or_null("Visual")
	if old != null:
		old.free()
	var m := MeshInstance3D.new()
	m.name = "Visual"
	var mat := StandardMaterial3D.new()
	match kind:
		CRATE:
			var b := BoxMesh.new()
			b.size = Vector3(0.6, 0.3, 0.35)
			m.mesh = b
			mat.albedo_color = Color(0.36, 0.4, 0.24)
			m.position.y = 0.15
		CANISTER:
			var b := BoxMesh.new()
			b.size = Vector3(0.18, 0.45, 0.34)
			m.mesh = b
			mat.albedo_color = Color(0.25, 0.32, 0.2)
			m.position.y = 0.22
		TOOL:
			var b := BoxMesh.new()
			b.size = Vector3(0.45, 0.2, 0.2)
			m.mesh = b
			mat.albedo_color = Color(0.55, 0.12, 0.1)
			m.position.y = 0.1
		_:
			var c := CylinderMesh.new()
			c.top_radius = 0.05
			c.bottom_radius = 0.05
			c.height = 0.3
			m.mesh = c
			m.rotation.x = PI / 2
			mat.albedo_color = Color(0.6, 0.55, 0.2)
			m.position.y = 0.05
	m.material_override = mat
	add_child(m)
