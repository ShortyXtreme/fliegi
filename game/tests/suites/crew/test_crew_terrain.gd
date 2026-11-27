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
	# Prüfung Boden: bergauf langsamer (Tobler), vorher volle 45 m auf jeder Steigung
	var tob := exp(-3.5 * (dh / 45.0 + 0.05 - 0.05))
	var ok: bool = max_err < 0.01 and flat > 45.0 * tob * 0.85 and flat < 45.0 * tob * 1.15 + 1.0 and d.y > 1.5
	return [ok, "Hang %.1f m auf 45 m: Weg %.1f m (Tobler-Faktor %.2f → Soll ≈ %.1f m), gestiegen %.1f m, max. Abweichung height_at %.4f m" % [
		dh, flat, tob, 45.0 * tob, d.y, max_err]]


class Cliff extends RefCounted:
	func height_at(x: float, _z: float) -> float:
		return maxf(x, 0.0) * 2.0       # ab x = 0: 63° steil


class River extends RefCounted:
	func height_at(x: float, _z: float) -> float:
		return -2.8 if x > 10.0 else 0.0
	func water_level_at(x: float, _z: float) -> float:
		return -0.1 if x > 10.0 else NAN


## Prüfung Boden: keine Wand hinauf; im tiefen Fluss schwimmen (Kopf über Wasser, ≤ 0,9 m/s).
func test_cliff_and_swim() -> Array:
	WorldGround.set_provider(Cliff.new())
	var ch := CrewTestUtil.make_crew(world, Vector3(-3, 0, 0))
	var ctl := CrewTestUtil.ctl(ch)
	ctl.ci.look_yaw = -PI / 2          # Blick nach +X
	ctl.ci.move = Vector2(0, 1)
	for i in 180:
		ch.step(ctl.compute_crew_intent(1.0 / 60.0), 1.0 / 60.0)
	var cliff_x := ch.global_position.x
	WorldGround.set_provider(River.new())
	ch.global_position = Vector3(12, 0, 0)
	ch._snap_to_ground()
	var y_swim := ch.global_position.y
	var x0 := ch.global_position.x
	ctl.ci.sprint = true
	for i in 120:
		ch.step(ctl.compute_crew_intent(1.0 / 60.0), 1.0 / 60.0)
	var v_swim := (ch.global_position.x - x0) / 2.0
	var ok := cliff_x < 0.6 and absf(y_swim - (-0.1 - CrewCharacter.SWIM_DEPTH)) < 0.01 and v_swim <= CrewCharacter.SWIM_SPEED + 0.01 and v_swim > 0.5
	return [ok, "Wand: bleibt bei x %.2f m; Fluss 2,8 m tief: Körper auf %.2f m (Spiegel -0,10), schwimmt %.2f m/s (Sprint gedrückt)" % [
		cliff_x, y_swim, v_swim]]
