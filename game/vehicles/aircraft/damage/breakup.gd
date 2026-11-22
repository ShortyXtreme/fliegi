class_name AircraftBreakup
extends Node
## M3.5: Teile abtrennen. Liest nur den Schadenszustand (hp, läuft auch auf Clients):
## Flügel links/rechts 0 HP -> Flügel ab, Leitwerk 0 HP -> Höhenleitwerk + Ruder ab.
## Das Teil wird im Spielmodell ausgeblendet und als Debris (RigidBody3D) mit der Bewegung des
## Flugzeugs (plus Abriss-Impuls) in die Welt gesetzt. Die Aerodynamik der Flächen entfernt
## DamageModel._apply_modifiers (Auftrieb/Widerstand 0) -> Rollen/Trudeln.
## Neustart (DamageModel.was_reset) blendet alles wieder ein.

signal part_detached(part: String, debris: Debris)

const Z := DamageModel.Zone
## Teil -> [Zone, Rig-Knoten, Ersatz-Box (Mitte, Größe; Flugzeug-Koordinaten), Masse kg]
const PARTS := {
	"wing_L": [Z.WING_L, ["wing_L"], Vector3(-2.8, -0.15, 0.55), Vector3(5.0, 0.35, 1.9), 160.0],
	"wing_R": [Z.WING_R, ["wing_R"], Vector3(2.8, -0.15, 0.55), Vector3(5.0, 0.35, 1.9), 160.0],
	"tail": [Z.TAIL, ["stabilizer", "elevator", "rudder"], Vector3(0.0, 0.35, 5.45), Vector3(3.6, 0.5, 1.3), 45.0],
}

var aircraft: Aircraft
## Teil -> true, wenn abgetrennt
var detached := {}
var _hidden: Array = []


func setup(a: Aircraft) -> void:
	aircraft = a
	name = "Breakup"
	a.damage.was_reset.connect(restore)


func is_detached(part: String) -> bool:
	return detached.get(part, false)


func _physics_process(_dt: float) -> void:
	if aircraft == null or aircraft.damage == null:
		return
	var hp: PackedFloat32Array = aircraft.damage.hp
	for p in PARTS:
		if not detached.get(p, false) and hp[PARTS[p][0]] <= 0.0:
			detach(p)


## Teil abtrennen (idempotent). Rückgabe: erzeugtes Trümmerteil oder null.
func detach(p: String) -> Debris:
	if detached.get(p, false) or not PARTS.has(p) or not aircraft.is_inside_tree():
		return null
	detached[p] = true
	var spec: Array = PARTS[p]
	var axf := aircraft.global_transform
	var center: Vector3 = spec[2]
	var size: Vector3 = spec[3]
	var vis_root: Node3D = null
	var vis := aircraft.visual
	if vis != null and vis.using_rig and vis.model_root != null:
		# Darstellung: Knoten kopieren (Weltlage), Original ausblenden
		var nodes: Array = []
		for nm in spec[1]:
			var n := vis.model_root.find_child(nm, true, false) as Node3D
			if n != null and n.visible:
				nodes.append(n)
		if not nodes.is_empty():
			var aabb := AABB()
			var first := true
			for n in nodes:
				for mi in ([n] if n is MeshInstance3D else []) + n.find_children("*", "MeshInstance3D", true, false):
					var lx := axf.affine_inverse() * (mi as MeshInstance3D).global_transform
					var bb := lx * (mi as MeshInstance3D).get_aabb()
					aabb = bb if first else aabb.merge(bb)
					first = false
			if not first:
				center = aabb.get_center()
				size = aabb.size.clamp(Vector3.ONE * 0.3, Vector3.ONE * 8.0)
			vis_root = Node3D.new()
			vis_root.name = "Part_" + p
			for n in nodes:
				var c := n.duplicate() as Node3D
				c.transform = (axf * Transform3D(Basis(), center)).affine_inverse() * n.global_transform
				vis_root.add_child(c)
				n.visible = false
				_hidden.append(n)
	var xf := axf * Transform3D(Basis(), center)
	var r := axf.basis * center
	var side := signf(center.x)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([aircraft.entity_id, p, aircraft.damage.elapsed])
	var kick := axf.basis * Vector3(side * 5.0, 3.0, 2.0 if p == "tail" else 0.0)
	var vel := aircraft.linear_velocity + aircraft.angular_velocity.cross(r) + kick
	var ang := aircraft.angular_velocity + axf.basis * Vector3(rng.randf_range(-2, 2), rng.randf_range(-1, 1), side * rng.randf_range(2.0, 5.0))
	var smoke: bool = aircraft.damage.is_burning(spec[0]) or (p != "tail" and aircraft.damage.is_burning(Z.FUEL_L if side < 0.0 else Z.FUEL_R))
	var d := Debris.spawn(aircraft.get_parent(), xf, size, spec[4], vel, ang, vis_root,
		Transform3D.IDENTITY, smoke, p)
	part_detached.emit(p, d)
	return d


## Nach Neustart: alle ausgeblendeten Teile wieder zeigen (Trümmer bleiben in der Welt).
func restore() -> void:
	for n in _hidden:
		if is_instance_valid(n):
			(n as Node3D).visible = true
	_hidden.clear()
	detached.clear()
