extends TestSuite
## Prüfung Boden/Welt: Baumkollision ohne Physikkörper (TreeObstacles) – headless, weit weg von
## jeder Kamera. Tiefflug durch einen Wald zerschellt, knapp über den Kronen nicht; Kosten je Tick.

const SUITE := "fast"


func make_world() -> Node3D:
	return TerrainWorld.new()


## Dichter Wald fern der Plätze: Zelle mit vielen hohen Bäumen (deterministisch gesucht).
func _forest(tw: TerrainWorld) -> Dictionary:
	var to := tw.trees
	to._ensure_gen()
	var g := to.gen
	for k in 300:
		var x := -15000.0 + float((k * 7919) % 30000)
		var z := -15000.0 + float((k * 104729) % 30000)
		var m := g.mask_at(x, z)
		if m.r < 0.9 or g.near_airfield(x, z) or g.keepout(x, z) != 0:
			continue
		var key := to._key_t(x, z)
		var c := TreeObstacles.build_cell_obstacles(g, key)
		var col: PackedFloat32Array = c.col
		if col.size() < 4 * 300:
			continue
		# hoher Baum in der Zellenmitte
		for i in range(0, col.size(), 4):
			var lx: float = col[i] - float(c.x0)
			var lz: float = col[i + 2] - float(c.z0)
			if lx > 80.0 and lx < 176.0 and lz > 80.0 and lz < 176.0 and col[i + 3] - col[i + 1] >= 14.0:
				to.cells[key] = c
				return {"tree": Vector3(col[i], col[i + 1], col[i + 2]), "top": col[i + 3], "key": key}
	return {}


func _fly(tw: TerrainWorld, from: Vector3, dir: Vector3) -> Aircraft:
	var a := Aircraft.create(load(FIGHTER), false)
	world.add_child(a)
	var p := tw.to_scene(from)
	a.place(Transform3D(Basis.looking_at(dir, Vector3.UP), p), 60.0, 0.8, false)
	var c := ScriptedController.new()
	c.intent.throttle = 0.8
	c.intent.gear_down = false
	a.add_child(c)
	a.pilot_seat.possess(c)
	return a


func test_low_flight_hits_trees_far_from_camera() -> Array:
	var tw := world as TerrainWorld
	var f := _forest(tw)
	if f.is_empty():
		return [false, "kein Wald gefunden"]
	var tree: Vector3 = f.tree
	var dir := Vector3(1, 0, 0)
	var tall := float(f.top) - tree.y
	# 1) Tiefflug: Rumpf auf halber Baumhöhe, 120 m vor dem Baum
	var start := tree - dir * 120.0 + Vector3(0, tall * 0.5, 0)
	start.y = tw.height_at_terrain(start.x, start.z) + tall * 0.5
	var a := _fly(tw, start, dir)
	var t0 := Time.get_ticks_usec()
	var n := 0
	while n < 240 and a.damage.outcome == DamageModel.Outcome.FLYING:
		await get_tree().physics_frame
		n += 1
	var us := (Time.get_ticks_usec() - t0) / maxf(n, 1)
	var hit_low := a.damage.outcome != DamageModel.Outcome.FLYING
	var hits := tw.trees.hits
	var dist := a.global_position.distance_to(tw.to_scene(start))
	a.queue_free()
	await get_tree().physics_frame
	# 2) 12 m über der höchsten Krone der Strecke: kein Treffer
	var top := -INF
	for k in 30:
		var q := tw.to_scene(tree - dir * 120.0 + dir * (k * 10.0))
		top = maxf(top, tw.trees.canopy_top(q.x, q.z, 8.0))
	var high := tree - dir * 120.0
	high.y = top - tw.origin().y + 12.0
	var b := _fly(tw, high, dir)
	await _step(180)
	var safe_high := b.damage.outcome == DamageModel.Outcome.FLYING
	var ok := hit_low and hits >= 1 and safe_high and top > tree.y and us < 4000.0
	return [ok, "Wald Zelle %s, Baum %.0f m hoch: Tiefflug zerschellt %s nach %.0f m (%d Treffer, Ausgang %d), 12 m über den Kronen (%.0f m) heil %s, %.0f µs je Tick" % [
		f.key, tall, hit_low, dist, hits, a.damage.outcome if is_instance_valid(a) else -1, top, safe_high, us]]


## Einzelbaum auf der Piste (flach, sonst baumfrei), Durchflug mit 100 m/s: trifft bei 5 m
## Seitenabstand (Flügel 5,35 m + Stamm), verfehlt bei 6,5 m; kein Tunneln trotz 1,7 m je Tick.
func test_single_tree_sweep() -> Array:
	var tw := world as TerrainWorld
	var to := tw.trees
	var t0 := Time.get_ticks_usec()
	to._ensure_gen()
	var gen_ms := (Time.get_ticks_usec() - t0) / 1000.0
	var c: Vector3 = tw.airfield(0).center
	var res := []
	for lateral in [0.0, 5.0, 6.5]:
		var key := to._key_t(c.x, c.z)
		for dz in range(-2, 3):
			for dx in range(-2, 3):
				var k := key + Vector2i(dx, dz)
				var o := to.cell_origin(k)
				to.cells[k] = TreeObstacles.cell_from(PackedFloat32Array(), o.x, o.y)
		var g := tw.height_at_terrain(c.x + lateral, c.z)
		var o0 := to.cell_origin(key)
		to.cells[key] = TreeObstacles.cell_from(PackedFloat32Array([c.x + lateral, g - 0.3, c.z, g + 15.7]), o0.x, o0.y)
		var start := Vector3(c.x, tw.height_at_terrain(c.x, c.z) + 6.0, c.z + 80.0)
		var a := _fly(tw, start, Vector3(0, 0, -1))
		a.linear_velocity = Vector3(0, 0, -100.0)
		var n := 0
		while n < 90 and a.damage.outcome == DamageModel.Outcome.FLYING:
			await get_tree().physics_frame
			n += 1
		res.append(a.damage.outcome != DamageModel.Outcome.FLYING)
		a.queue_free()
		await get_tree().physics_frame
	var ok: bool = res == [true, true, false]
	return [ok, "Treffer bei 0 / 5 / 6,5 m seitlich: %s (soll true, true, false), Baumdaten anlegen %.0f ms, Abfrage im Mittel %.0f µs, max. %d µs je Tick" % [
		res, gen_ms, to.mean_usec(), to.max_usec]]


func test_segment_box() -> Array:
	var e := Vector3(5.0, 0.5, 1.0)
	var r := [
		TreeObstacles.segment_hits_box(Vector3(0, -10, 0), Vector3(0, 10, 0), e),     # mitten durch
		TreeObstacles.segment_hits_box(Vector3(4.9, -10, 0.9), Vector3(4.9, 10, 0.9), e),
		TreeObstacles.segment_hits_box(Vector3(5.2, -10, 0), Vector3(5.2, 10, 0), e),
		TreeObstacles.segment_hits_box(Vector3(0, -10, 0), Vector3(0, -0.6, 0), e),   # endet darunter
	]
	return [r == [true, true, false, false], "Strecke/Box %s (soll true, true, false, false)" % [r]]
