class_name DamageFx
extends RefCounted
## Partikel-Bausteine für Schadenseffekte (Paket 11). Headless: null.


## Rauchsäule: dark = Brand (schwarz), sonst Öl (grau).
static func make_smoke(dark: bool) -> GPUParticles3D:
	if DisplayServer.get_name() == "headless":
		return null
	var p := GPUParticles3D.new()
	p.amount = 64
	p.lifetime = 3.0
	p.emitting = false
	var m := ParticleProcessMaterial.new()
	m.direction = Vector3(0, 1, 0)
	m.spread = 15.0
	m.initial_velocity_min = 1.0
	m.initial_velocity_max = 3.0
	m.gravity = Vector3(0, 1.0, 0)
	m.scale_min = 1.0
	m.scale_max = 3.0
	var c := Color(0.06, 0.06, 0.06, 0.8) if dark else Color(0.45, 0.45, 0.45, 0.6)
	m.color = c
	p.process_material = m
	var q := QuadMesh.new()
	q.size = Vector2(1.5, 1.5)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	q.material = mat
	p.draw_pass_1 = q
	return p
