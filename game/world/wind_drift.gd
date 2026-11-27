class_name WindDrift
extends Node
## M3.8: lässt ein Partikelsystem (Rauch, Staub, Gischt; local_coords = false) mit dem Wind
## treiben: die waagerechte „Schwerkraft“ des ParticleProcessMaterial folgt dem Wind am Emitter
## (Weather, alle 0,5 s nachgeführt). k: Anteil (Beschleunigung ≈ Wind · k), base: waagerechter
## Anteil ohne Wind.

var particles: GPUParticles3D
var k := 0.3
var base := Vector3.ZERO
var _vert := 0.0
var _t := 0.0


static func attach(p: GPUParticles3D, factor := 0.3, base_h := Vector3.ZERO) -> WindDrift:
	if p == null or not (p.process_material is ParticleProcessMaterial):
		return null
	var d := WindDrift.new()
	d.name = "WindDrift"
	d.particles = p
	d.k = factor
	d.base = base_h
	d._vert = (p.process_material as ParticleProcessMaterial).gravity.y
	p.add_child(d)
	d.update()
	return d


## Waagerechte Beschleunigung für den Wind w (m/s).
static func drift_accel(w: Vector3, factor: float, base_h := Vector3.ZERO) -> Vector3:
	if w.length() < 0.2:
		return base_h
	return Vector3(w.x, 0.0, w.z) * factor


func _process(dt: float) -> void:
	_t += dt
	if _t >= 0.5:
		_t = 0.0
		update()


func update() -> void:
	if particles == null or not is_instance_valid(particles) or not particles.is_inside_tree():
		return
	var w := Weather.wind_at(particles.global_position + Vector3(0, 8.0, 0))
	var a := drift_accel(w, k, base)
	(particles.process_material as ParticleProcessMaterial).gravity = Vector3(a.x, _vert, a.z)
