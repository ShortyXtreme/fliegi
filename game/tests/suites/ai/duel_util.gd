extends RefCounted
## Gemeinsame Duell-Helfer für die KI-Tests. Seit Paket 14 mit echten Hitboxen
## (HitboxSet aus den GLB-Markern) und echtem Schadensmodell; KILL_HITS bleibt nur als
## Kennzahl für Altvergleiche.

const KILL_HITS := 20
const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"


## Echtes Schadensmodell vorhanden (Agent B)? Dann keine Ersatz-Hitboxen.
static func damage_available() -> bool:
	return ResourceLoader.exists("res://vehicles/aircraft/damage/damage_profile_t1.tres")


static func spawn(world: Node3D, pos: Vector3, fwd: Vector3, nation: int, eid: int,
		speed := 120.0) -> Aircraft:
	var a := Aircraft.create(load(FIGHTER), false)
	a.nation_id = nation
	a.entity_id = eid
	world.add_child(a)
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
