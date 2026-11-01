class_name Wreck
extends Node3D
## Wrack-Platzhalter (Paket 6): bleibt an der Absturzstelle liegen, bis die Lebenszeit
## (MatchRules.wreck_lifetime ab Absturz) abgelaufen ist. Headless ohne Mesh.

var lifetime := 30.0
var age := 0.0
var cause: int = CombatEvents.Cause.UNKNOWN


static func spawn_at(parent: Node, xf: Transform3D, life: float, burning := false) -> Wreck:
	var w := Wreck.new()
	w.name = "Wreck"
	w.lifetime = life
	parent.add_child(w)
	w.global_transform = xf
	if DisplayServer.get_name() != "headless":
		w._build_visual(burning)
	return w


func _build_visual(burning: bool) -> void:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(9.0, 0.8, 7.0)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.07)
	mat.roughness = 1.0
	m.material_override = mat
	add_child(m)
	var smoke := DamageFx.make_smoke(true)
	if smoke != null:
		smoke.position = Vector3(0, 1, 0)
		smoke.emitting = true
		smoke.amount_ratio = 1.0 if burning else 0.4
		add_child(smoke)


func _physics_process(dt: float) -> void:
	age += dt
	if age >= lifetime:
		queue_free()
