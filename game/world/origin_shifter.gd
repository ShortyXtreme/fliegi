class_name OriginShifter
extends Node
## Floating Origin (Paket 13). Liegt der Fokus (Kamera oder Spielerflugzeug) weiter als
## `threshold` vom Szenen-Ursprung entfernt, verschiebt der Shifter alle Node3D-Kinder der
## `roots` um ganze Meter zurück und führt WorldOrigin.offset nach. Gameplay, Netz und
## Ereignisse rechnen absolut: WorldOrigin.to_abs(szene) / to_local(absolut).
##
## Schalter: `enabled` (Standard aus, Projekt-weit über OriginShifter.default_enabled oder
## die Umgebungsvariable FLOATING_ORIGIN=1). In M2 entscheidet die Zitter-Messung.
##
## Verschoben werden: Node3D-Kinder der roots (Gelände, Flugzeuge, Kamera, Effekte) per
## global_position (RigidBodies werden teleportiert, Geschwindigkeit bleibt), danach
## reset_physics_interpolation(). Knoten mit Methode shift_origin(delta: Vector3) (z. B.
## ein ProjectileSystem mit eigenen Positions-Arrays) verschieben sich selbst; Knoten in
## der Gruppe "origin_shift_skip" bleiben unberührt.
## Rundung auf ganze Meter: x - d ist für ganzzahliges d bei |x| ≥ |x - d| exakt, die
## Verschiebung selbst verliert also keine Genauigkeit.

signal shifted(delta: Vector3)

static var default_enabled := false

@export var enabled := false
## Abstand (horizontal), ab dem verschoben wird.
@export var threshold := 4000.0
## Auch vertikal verschieben (Standard aus: Höhen bleiben lesbar, ±20 km reichen nicht hoch).
@export var shift_y := false
## Knoten, deren Node3D-Kinder verschoben werden. Leer = Eltern-Knoten des Shifters.
@export var roots: Array[Node] = []
## Bezugspunkt (Kamera oder Spielerflugzeug). Leer = aktive Kamera des Viewports.
@export var focus: Node3D

var shift_count := 0


func _init() -> void:
	enabled = default_enabled or OS.get_environment("FLOATING_ORIGIN") == "1"


func _enter_tree() -> void:
	WorldOrigin.offset = Vector3.ZERO


func _exit_tree() -> void:
	WorldOrigin.offset = Vector3.ZERO


func _physics_process(_dt: float) -> void:
	if enabled:
		check()


## Prüft den Fokus und verschiebt bei Bedarf. Gibt die Verschiebung zurück (oder ZERO).
func check() -> Vector3:
	var f := _focus()
	if f == null:
		return Vector3.ZERO
	var p := f.global_position
	var h := Vector2(p.x, p.z).length()
	if h < threshold and not (shift_y and absf(p.y) > threshold):
		return Vector3.ZERO
	var d := Vector3(roundf(p.x), roundf(p.y) if shift_y else 0.0, roundf(p.z))
	shift(d)
	return d


## Verschiebt die Darstellung so, dass der Szenenpunkt `delta` zum neuen Ursprung wird.
func shift(delta: Vector3) -> void:
	if delta == Vector3.ZERO:
		return
	var rs: Array = roots if not roots.is_empty() else [get_parent()]
	for r in rs:
		if r == null:
			continue
		for c in r.get_children():
			_shift_node(c, delta)
	WorldOrigin.offset += delta
	shift_count += 1
	shifted.emit(delta)


func _shift_node(n: Node, delta: Vector3) -> void:
	if n == self or n.is_in_group("origin_shift_skip"):
		return
	if n.has_method("shift_origin"):
		n.shift_origin(delta)
		return
	if n is Node3D:
		var n3 := n as Node3D
		n3.global_position -= delta
		n3.reset_physics_interpolation()
		return
	# Nicht-räumliche Knoten (z. B. Controller, Systeme) können räumliche Kinder haben
	for c in n.get_children():
		_shift_node(c, delta)


func _focus() -> Node3D:
	if focus != null and is_instance_valid(focus):
		return focus
	var vp := get_viewport()
	return vp.get_camera_3d() if vp else null
