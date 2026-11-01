class_name LeadSolver
extends RefCounted
## Vorhalt für HUD (Arcade-Vorhaltepunkt) und KI: In welche Richtung muss geschossen werden,
## damit ein Geschoss ein Ziel mit Position/Geschwindigkeit/Beschleunigung trifft?
## Rechnet mit derselben Ballistik wie das ProjectileSystem.

## Ergebnis: {"valid", "dir" (Abschussrichtung Welt), "time" (Flugzeit s),
##  "intercept" (Treffpunkt Welt), "aim_point" (Punkt auf der Abschussrichtung in
##  Treffentfernung – für die HUD-Projektion)}.
static func solve(shooter_pos: Vector3, shooter_vel: Vector3, target_pos: Vector3,
		target_vel: Vector3, v0: float, k: float, target_acc := Vector3.ZERO,
		max_range := 1500.0, iterations := 5, dt := 1.0 / 60.0) -> Dictionary:
	var t := Ballistics.time_of_flight(shooter_pos.distance_to(target_pos), v0, k)
	var intercept := target_pos
	var dir := (target_pos - shooter_pos).normalized()
	var valid := true
	for i in iterations:
		intercept = target_pos + target_vel * t + target_acc * (0.5 * t * t)
		dir = Ballistics.solve_direction(shooter_pos, intercept, v0, k, shooter_vel, dt, 4)
		var c := Ballistics.cross_plane(shooter_pos, shooter_vel + dir * v0, k, dt,
				intercept, (intercept - shooter_pos).normalized(), 5.0)
		if c.is_empty():
			valid = false
			break
		var dt_err: float = absf(c.time - t)
		t = c.time
		if dt_err < 1e-4:
			break
	intercept = target_pos + target_vel * t + target_acc * (0.5 * t * t)
	var r := shooter_pos.distance_to(intercept)
	return {"valid": valid and r <= max_range, "dir": dir, "time": t,
			"intercept": intercept, "aim_point": shooter_pos + dir * r}


## Schnelle Näherung ohne Bahnsimulation (nur Tabellen), z. B. für viele Ziele im HUD.
static func quick(shooter_pos: Vector3, shooter_vel: Vector3, target_pos: Vector3,
		target_vel: Vector3, v0: float, k: float) -> Dictionary:
	var rel_v := target_vel - shooter_vel
	var t := Ballistics.time_of_flight(shooter_pos.distance_to(target_pos), v0, k)
	var p := target_pos
	for i in 3:
		p = target_pos + rel_v * t
		t = Ballistics.time_of_flight(shooter_pos.distance_to(p), v0, k)
	var aim := p + Vector3.UP * Ballistics.drop(shooter_pos.distance_to(p), v0, k)
	return {"time": t, "intercept": target_pos + target_vel * t, "aim_point": aim,
			"dir": (aim - shooter_pos).normalized()}
