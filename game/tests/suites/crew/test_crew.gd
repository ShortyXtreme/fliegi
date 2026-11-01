extends TestSuite
## Strang H, Paket 4: Figur laufen, Punktwahl im Blickkegel, Kamera Third/Ego.

const SUITE := "fast"


func _walk(yaw: float, sprint: bool, seconds: float) -> Array:
	var ch := CrewTestUtil.make_crew(world, Vector3(200, 0, 200))
	var c := CrewTestUtil.ctl(ch)
	c.ci.look_yaw = yaw
	c.ci.move = Vector2(0, 1)
	c.ci.sprint = sprint
	var p0 := ch.global_position
	await _step(int(seconds * 60))
	var d := ch.global_position - p0
	ch.queue_free()
	return [d, ch.anim_state]


func test_walk_and_sprint_speed() -> Array:
	var w = await _walk(0.0, false, 3.0)
	var s = await _walk(PI / 2, true, 3.0)
	var dw: Vector3 = w[0]
	var ds: Vector3 = s[0]
	# Gehen nach -Z; Sprint mit Blick nach links (-X). Anlauf ~0,1–0,4 s abziehen
	var ok: bool = absf(dw.length() - 1.6 * 3.0) < 0.25 and dw.z < -4.5 and absf(dw.x) < 0.01 \
		and absf(ds.length() - 4.5 * 3.0) < 1.0 and ds.x < -12.0 \
		and w[1] == CrewCharacter.AnimState.WALK and s[1] == CrewCharacter.AnimState.RUN
	return [ok, "Gehen 3 s: %.2f m %s, Sprint 3 s: %.2f m %s, Anim %d/%d" % [
		dw.length(), dw.snapped(Vector3.ONE * 0.01), ds.length(), ds.snapped(Vector3.ONE * 0.01), w[1], s[1]]]


func _point(pos: Vector3, label: String) -> Interactable:
	var it := Interactable.new()
	it.marker = label
	it.add_action(StringName(label), label, 0.5)
	world.add_child(it)
	it.global_position = pos
	return it


func test_interaction_pick() -> Array:
	var from := Vector3(0, 1.1, 100)
	var fwd := Vector3(0, 0, -1)
	var behind := _point(from + Vector3(0, 0, 1.0), "hinten")
	var front := _point(from + Vector3(0, 0.6, -2.0), "vorn")
	var far := _point(from + Vector3(0, 0, -3.0), "weit")
	var side := _point(from + Vector3(-1.0, 0, -1.6), "seitlich")      # 32°, 1,89 m
	var out := _point(from + Vector3(-1.6, 0, -0.6), "aussen")        # 69°, außerhalb
	var cands := [behind, front, far, side, out]
	var p1 := InteractionQuery.pick(from, fwd, cands)
	side.global_position = from + Vector3(-0.4, 0, -1.3)              # 17°, 1,36 m
	var p2 := InteractionQuery.pick(from, fwd, cands)
	var p3 := InteractionQuery.pick(from, Vector3(0, 0, 1), cands)    # umdrehen
	front.enabled = false
	side.enabled = false
	behind.enabled = false
	var p4 := InteractionQuery.pick(from, fwd, cands)
	var names := [p1, p2, p3, p4].map(func(p): return p.marker if p != null else "-")
	return [names == ["vorn", "seitlich", "hinten", "-"], "Wahl %s (soll vorn, seitlich, hinten, -)" % [names]]


func test_character_hold_action() -> Array:
	var ch := CrewTestUtil.make_crew(world, Vector3(0, 0, 50))
	var it := Interactable.new()
	it.add_action(&"gurt", "Gurt einlegen", 0.5, &"crate")
	it.add_action(&"klappe", "Klappe öffnen", 0.5)
	world.add_child(it)
	it.global_position = Vector3(0, 1.0, 48.5)
	var done := []
	var held := [0.0]
	it.performed.connect(func(id, _c): done.append(id))
	it.holding.connect(func(_id, _c, dt, _p): held[0] += dt)
	await _step(2)
	var hint := it.hint_for(ch)
	var c := CrewTestUtil.ctl(ch)
	c.ci.interact = true
	c.ci.move = Vector2(0, 1)       # Arbeiten hält die Figur fest
	var p0 := ch.global_position
	await _step(25)
	var moved := ch.global_position.distance_to(p0)
	var state := ch.anim_state
	await _step(20)
	c.ci.interact = false
	await _step(2)
	var ok: bool = ch.focus == it and hint.id == &"gurt" and hint.missing == &"crate" \
		and done == [&"klappe"] and absf(held[0] - 0.5) < 0.03 and moved < 0.01 \
		and state == CrewCharacter.AnimState.WORK
	return [ok, "Fokus %s, Hinweis %s (fehlt %s), ausgelöst %s nach %.2f s gehalten, bewegt %.3f m" % [
		ch.focus == it, hint.get("label"), hint.get("missing"), done, held[0], moved]]


func test_camera_third_and_ego() -> Array:
	var ch := CrewTestUtil.make_crew(world, Vector3(10, 0, 10))
	var cam := CrewCamera.new()
	world.add_child(cam)
	CrewTestUtil.ctl(ch).ci.look_yaw = 0.0
	await _step(2)
	cam.follow(ch)
	var t := cam.camera.global_position
	CrewTestUtil.ctl(ch).ci.view_toggle = true
	await _step(2)
	cam.update_now()
	var e := cam.camera.global_position
	var ok: bool = cam.mode == CrewCamera.Mode.EGO and t.z > 12.0 and t.x > 10.2 and t.y > 1.5 \
		and absf(e.y - CrewCharacter.EYE_HEIGHT) < 0.01 and e.distance_to(Vector3(10, 1.62, 10)) < 0.2 \
		and not ch.visual.visible and ch.face_look
	return [ok, "Third %s (hinter rechter Schulter), Ego %s, Körper verborgen %s" % [
		t.snapped(Vector3.ONE * 0.01), e.snapped(Vector3.ONE * 0.01), not ch.visual.visible]]
