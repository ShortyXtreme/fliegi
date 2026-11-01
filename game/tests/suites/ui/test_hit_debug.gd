extends TestSuite
## M2.1 Treffer-Debug: Datensammlung (HitDebug) ohne Rendering, CSV-Log, Hauptszene-Schalter.


func _two_aircraft() -> Array:
	var a := _spawn(false, 1500.0, 0.0, 0.0)
	a.nation_id = Nations.BLUE
	a.freeze = true
	var b := Aircraft.create(load(FIGHTER), false)
	b.nation_id = Nations.RED
	world.add_child(b)
	b.place(Transform3D(a.global_transform.basis, a.global_transform * Vector3(0, 0.95, -200)), 0.0, 0.0)
	b.freeze = true
	return [a, b]


func test_classifies_own_received_others() -> Array:
	var d := HitDebug.new()
	d.log_enabled = false
	add_child(d)
	var me := Node3D.new()
	var foe := Node3D.new()
	var foe2 := Node3D.new()
	for n in [me, foe, foe2]:
		add_child(n)
	foe.set_meta("display_name", "Rot 1")
	d.own = me
	foe2.position = Vector3(0, 0, -300)
	d.on_hit_resolved(me, foe, DamageModel.Zone.ENGINE, 10.0, Vector3(0, 0, -150), Vector3(0, 0, -1), 0)
	d.on_hit_resolved(foe, me, DamageModel.Zone.WING_L, 10.0, Vector3.ZERO, Vector3(-3, 0, 0), 0)
	d.on_hit_resolved(foe, foe2, DamageModel.Zone.TAIL, 10.0, Vector3(0, 0, -300), Vector3.ZERO, 0)
	d.on_hit_resolved(me, foe, DamageModel.Zone.TAIL, 0.0, Vector3(0, 0, -150), Vector3.ZERO,
			HitValidator.Result.POSITION)
	var mine := d.mine()
	var rec := d.received()
	var oth := d.others()
	var rej := d.rejected_recent()
	var mk := d.markers()
	var inc := d.incoming()
	var ok: bool = mine.size() == 1 and mine[0].target_name == "Rot 1" and mine[0].zone_name == "Motor" \
		and absf(mine[0].distance - 150.0) < 0.1 and rec.size() == 1 and rec[0].zone_name == "Flügel L" \
		and rec[0].shooter_name == "Rot 1" and oth.size() == 1 and rej.size() == 1 \
		and rej[0].reason == "Position" and d.rejected_total == 1 and mk.size() == 1 \
		and inc.size() == 1
	for n in [me, foe, foe2, d]:
		n.queue_free()
	return [ok, "mine %d (%s %s, %.0f m), erhalten %d (%s), andere %d, abgelehnt %d (%s), Marker %d, Pfeile %d" % [
		mine.size(), mine[0].target_name if mine else "-", mine[0].zone_name if mine else "-",
		mine[0].distance if mine else 0.0, rec.size(), rec[0].zone_name if rec else "-", oth.size(),
		rej.size(), rej[0].reason if rej else "-", mk.size(), inc.size()]]


func test_real_hits_with_damage_and_zone_hp() -> Array:
	var ab := _two_aircraft()
	var a: Aircraft = ab[0]
	var b: Aircraft = ab[1]
	var d := HitDebug.new()
	d.log_enabled = false
	add_child(d)
	d.own = a
	var fire := [true]
	_seat(a, func(_a, i: PilotIntent, _dt): i.fire_primary = fire[0])
	await _step(20)
	fire[0] = false
	await _step(30)
	var mine := d.mine(50)
	var sum := 0.0
	for e in mine:
		sum += float(e.damage)
	var lost := 0.0
	for r in HitDebug.zone_hp(b):
		lost += float(r.max) - float(r.hp)
	var mk := d.markers()
	var txt: String = mk[0].text if not mk.is_empty() else ""
	d.queue_free()
	return [mine.size() > 3 and absf(sum - lost) < 0.5 and txt.contains("−") and mine[0].distance > 150.0,
		"%d eigene Treffer, Summe %.0f HP = Zonenverlust %.0f HP, Marker „%s“, Entfernung %.0f m" % [
		mine.size(), sum, lost, txt, mine[0].distance if mine else 0.0]]


func test_csv_log() -> Array:
	var d := HitDebug.new()
	add_child(d)
	var p := d.open_log("test")
	var me := Node3D.new()
	add_child(me)
	d.own = me
	d.on_hit_resolved(me, null, 0, 10.0, Vector3(1, 2, 3), Vector3.ZERO, 0)
	d.on_hit_resolved(null, me, 3, 10.0, Vector3(1, 2, 3), Vector3.ZERO, 13)
	d.queue_free()
	me.queue_free()
	await _step(1)
	var txt := FileAccess.get_file_as_string(p)
	var lines := txt.strip_edges().split("\n")
	DirAccess.remove_absolute(p)
	var ok: bool = p == "user://logs/kampf_test.csv" and lines.size() == 3 and lines[0].begins_with("zeit_s;") \
		and lines[1].contains(";Motor;") and lines[1].contains(";aus;") and lines[2].contains(";Position;")
	return [ok, "%s: %d Zeilen, %s" % [ProjectSettings.globalize_path(p), lines.size(),
		lines[1] if lines.size() > 1 else "-"]]


func test_main_scene_debug_toggle() -> Array:
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	get_tree().root.add_child(g)
	await _step(3)
	var h := g.hud
	var before := h.hit_overlay.visible
	h.toggle_debug()
	await _step(2)
	var on := h.hit_overlay.visible and h.hit_debug.own == g.player_aircraft
	var f4 := InputEventKey.new()
	f4.physical_keycode = KEY_F4
	f4.pressed = true
	h._unhandled_input(f4)
	var hb_off := not h.hit_overlay.show_hitboxes
	h.toggle_forces()
	var forces := h.debug_visible and h.hit_debug_visible
	var no_log := not h.hit_debug.log_enabled
	g.queue_free()
	await _step(2)
	return [not before and on and hb_off and forces and no_log and Hud.VERSION == "M2.1",
		"Start aus %s, F3 an %s, F4 Hitboxen aus %s, Shift+F3 Kräfte zusätzlich %s, kein Log in Tests %s" % [
		not before, on, hb_off, forces, no_log]]
