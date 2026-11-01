extends RefCounted
## Gemeinsame Duell-Helfer für die KI-Tests (Ersatz-Trefferzähler bis das echte
## Schadensmodell verfügbar ist: Treffer über CombatEvents.hit_confirmed gezählt,
## "Ersatz-Abschuss" ab KILL_HITS Treffern).

const KILL_HITS := 20
const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"


## Ersatz-Hitboxen (Rumpf + Flügel aus AircraftData), solange HitboxSet ein Stub ist.
class ProxyHitboxes:
	var boxes := []   # [center, half, zone]
	var bounding_radius := 6.0

	func _init(d: AircraftData) -> void:
		boxes = [[d.fuselage_box_center, d.fuselage_box_size * 0.5, DamageModel.Zone.COCKPIT],
				[d.wing_box_center, d.wing_box_size * 0.5, DamageModel.Zone.WING_L]]
		bounding_radius = maxf(d.wing_box_size.x, d.fuselage_box_size.z) * 0.55

	func intersect_segment(p0: Vector3, p1: Vector3) -> Dictionary:
		var best := {}
		for bx in boxes:
			var r := _slab(p0 - bx[0], p1 - bx[0], bx[1])
			if r >= 0.0 and (best.is_empty() or r < best.t):
				var z: int = bx[2]
				var pt := p0 + (p1 - p0) * r
				if z == DamageModel.Zone.WING_L and pt.x > 0.0:
					z = DamageModel.Zone.WING_R
				best = {"zone": z, "t": r, "point": pt}
		return best

	static func _slab(p0: Vector3, p1: Vector3, half: Vector3) -> float:
		var d := p1 - p0
		var t0 := 0.0
		var t1 := 1.0
		for ax in 3:
			if absf(d[ax]) < 1e-9:
				if absf(p0[ax]) > half[ax]:
					return -1.0
				continue
			var a := (-half[ax] - p0[ax]) / d[ax]
			var b := (half[ax] - p0[ax]) / d[ax]
			t0 = maxf(t0, minf(a, b))
			t1 = minf(t1, maxf(a, b))
			if t0 > t1:
				return -1.0
		return t0


static func spawn(world: Node3D, pos: Vector3, fwd: Vector3, nation: int, eid: int,
		speed := 120.0) -> Aircraft:
	var a := Aircraft.create(load(FIGHTER), false)
	a.nation_id = nation
	a.entity_id = eid
	world.add_child(a)
	# Neu anmelden: die Ziel-ID wurde bei create() mit der alten entity_id vergeben.
	ProjectileSystem.unregister_target(a)
	ProjectileSystem.register_target(a, ProxyHitboxes.new(a.data))
	a.place(Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), pos), speed, 0.9, false)
	return a


static func brain(a: Aircraft, level := "erfahren", seed := 0) -> AIPilotBrain:
	var c := AIPilotBrain.new()
	c.difficulty = AIDifficulty.load_level(level)
	c.rng_seed = seed
	a.add_child(c)
	a.pilot_seat.possess(c)
	return c


## Wahrer Vorhaltfehler (mrad) von a auf b: mittlere Abweichung der Waffenrichtungen
## von der nötigen Abschussrichtung (LeadSolver mit wahren Zielwerten).
static func true_aim_error_mrad(a: Aircraft, b: Aircraft) -> float:
	var w := a.weapons.weapon_of_group()
	var r := LeadSolver.solve(a.global_position, a.linear_velocity, b.global_position,
			b.linear_velocity, w.muzzle_velocity, w.ballistic_k)
	var xf := a.global_transform
	var ms := a.weapons.mounts()
	var corr := Vector3.ZERO
	for gi in ms.size():
		var need := Ballistics.solve_direction(xf * ms[gi].position, r.intercept,
				w.muzzle_velocity, w.ballistic_k, a.linear_velocity, 1.0 / 60.0, 3)
		corr += need - xf.basis * a.weapons.aim_dirs[gi]
	return (corr / maxi(ms.size(), 1)).length() * 1000.0
