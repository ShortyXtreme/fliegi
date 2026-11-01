extends TestSuite
## Strang H, Paket 4: Figur läuft auf dem echten Gelände (height_at) einen Hang hinauf.

const SUITE := "fast"


func make_world() -> Node3D:
	return TerrainWorld.new()


func test_walk_on_terrain() -> Array:
	var tw := world as TerrainWorld
	var c: Vector3 = tw.to_scene(tw.airfield(0).center)
	# Hang suchen: 45 m Weg mit 3–15 m Höhenunterschied (deterministisch)
	var start := Vector3.ZERO
	var yaw := 0.0
	var dh := 0.0
	for k in 400:
		var r := 600.0 + 37.0 * k
		var a := k * 0.7
		var p := c + Vector3(cos(a) * r, 0, sin(a) * r)
		for j in 8:
			var y := j * PI / 4
			var q := p + CrewCharacter.yaw_forward(y) * 45.0
			var h := tw.height_at(q.x, q.z) - tw.height_at(p.x, p.z)
			if h > 3.0 and h < 15.0:
				start = p
				yaw = y
				dh = h
				break
		if dh > 0.0:
			break
	if dh == 0.0:
		return [false, "kein Hang gefunden"]
	var ch := CrewTestUtil.make_crew(world, start)
	var ctl := CrewTestUtil.ctl(ch)
	ctl.ci.look_yaw = yaw
	ctl.ci.move = Vector2(0, 1)
	ctl.ci.sprint = true
	var p0 := ch.global_position
	var max_err := 0.0
	for i in 600:
		await get_tree().physics_frame
		var p := ch.global_position
		max_err = maxf(max_err, absf(p.y - tw.height_at(p.x, p.z)))
	var d := ch.global_position - p0
	var flat := Vector2(d.x, d.z).length()
	var ok: bool = max_err < 0.01 and flat > 40.0 and flat < 46.0 and d.y > 2.0
	return [ok, "Hang %.1f m auf 45 m: Weg %.1f m, gestiegen %.1f m, max. Abweichung height_at %.4f m" % [
		dh, flat, d.y, max_err]]
