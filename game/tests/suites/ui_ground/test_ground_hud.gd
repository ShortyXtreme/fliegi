extends TestSuite
## Boden-HUD (Paket 13): Smoke-Tests und Datenanbindung mit Fake-Daten (Figur, JobBoard, Lager).

var _g: GroundHud
var _board: JobBoard


class FakeCrew extends Node3D:
	var focus: Interactable = null
	var hold_progress := 0.0
	var carried = null
	var action := {}
	func current_action() -> Dictionary:
		return action


class FakeHud extends Node:
	var aircraft: Aircraft = null


func after_each() -> void:
	for n in [_g, _board]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	_g = null
	_board = null


func _make(a: Aircraft = null) -> GroundHud:
	var h := FakeHud.new()
	h.aircraft = a
	world.add_child(h)
	_g = GroundHud.create(h)
	h.add_child(_g)
	return _g


func _make_board() -> JobBoard:
	_board = JobBoard.new()
	world.add_child(_board)
	return _board


func test_smoke_all_contexts() -> Array:
	var a := _spawn(true)
	var g := _make(a)
	var ch := FakeCrew.new()
	world.add_child(ch)
	ch.global_position = a.global_position + Vector3(4, 0, 0)
	g.character = ch
	g.depot = FuelDepot.new()
	g.bunker = AmmoBunker.new()
	var seen := []
	for ctx in [InputBindings.Context.CREW, InputBindings.Context.DRIVE, InputBindings.Context.FLIGHT]:
		g.set_context(ctx)
		g.help.visible = true
		await _step(3)
		seen.append([ctx, g.status.visible, g.stock_bar.visible])
	ch.queue_free()
	# Zu Fuß 4 m neben der Maschine: Statuspanel + Lager; im Flug (Stand am Boden): Statuspanel, kein Lager
	var ok: bool = seen[0][1] and seen[0][2] and seen[2][1] and not seen[2][2] and not g.help.visible
	return [ok, "Kontexte [ctx, status, lager]: %s" % str(seen)]


func test_status_data() -> Array:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(0.5, 0.25)
	a.weapons.set_ammo_fraction(0.5)
	var b := _make_board()
	var j := RefuelJob.new()
	j.target = a
	b.add_job(j)
	var me := Node.new()
	me.name = "Ich"
	var r := RearmJob.new()
	r.target = a
	r.gun_index = 1
	b.add_job(r)
	b.claim(1, r.id, me)
	var d := GroundHudData.aircraft_status(a, b, me)
	me.free()
	var guns: Array = d.guns
	var ok: bool = absf(d.fuel_frac - 0.5) < 0.02 and d.grade.begins_with("Gemisch") and guns.size() == 2 \
		and guns[0].label == "L" and guns[1].label == "R" and guns[0].ammo > 0 and d.jobs.size() == 2 \
		and d.zones.size() == DamageModel.Zone.COUNT
	var workers := []
	for e in d.jobs:
		workers.append("%s/%s/%s" % [e.text, e.step, e.worker])
	ok = ok and workers.has("Munition R/Kiste holen/Du")
	return [ok, "Treibstoff %.0f l (%s), MG %s, Jobs %s" % [d.fuel_l, d.grade, str(guns), str(workers)]]


func test_stock_data() -> Array:
	var dep := FuelDepot.new()
	var bun := AmmoBunker.new()
	dep.draw(FuelSystem.GRADE_AVIATION, 500.0)
	bun.request(AmmoBunker.AMMO_792, 1000)
	var d := GroundHudData.stock(dep, bun)
	var ok: bool = absf(d.aviation - 7500.0) < 1.0 and absf(d.ersatz - 3000.0) < 1.0 and d.ammo == 19000
	return [ok, "Lager %s" % str(d)]


func test_interaction_hint() -> Array:
	var a := _spawn(true)
	var ch := FakeCrew.new()
	world.add_child(ch)
	var it := Interactable.new()
	it.marker = "svc_gun_hatch_L"
	it.target = a
	it.add_action(&"belt", "Gurt einlegen", 2.0, CarryItem.CRATE)
	world.add_child(it)
	ch.focus = it
	# Kiste fehlt: current_action leer, hint_for liefert den Hinweis
	var d1 := GroundHudData.interaction(ch, null, false)
	# mit Aktion, halb gehalten, Pad
	ch.action = it.actions[0]
	ch.hold_progress = 0.5
	var d2 := GroundHudData.interaction(ch, null, true)
	it.queue_free()
	ch.queue_free()
	var ok: bool = d1.visible and d1.missing == "Kiste fehlt" and d1.key == "E" and d2.key == "A" \
		and d2.hold and absf(d2.progress - 0.5) < 1e-3 and d2.missing == "" and d2.label == "Gurt einlegen"
	return [ok, "ohne Kiste: %s / mit: %s" % [d1.missing, str([d2.key, d2.label, d2.progress])]]


func test_blocked_and_pump() -> Array:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(0.3)
	var b := _make_board()
	b.rules = GroundRules.for_realism(MatchRules.GroundRealism.STANDARD)
	var j := RefuelJob.new()
	j.target = a
	b.add_job(j)
	var ch := FakeCrew.new()
	world.add_child(ch)
	var it := Interactable.new()
	it.marker = ServiceMarkers.SVC_FUEL_CAP
	it.target = a
	world.add_child(it)
	ch.focus = it
	# Pumpen läuft: Literanzeige
	j.step_index = j.steps.find(&"pump")
	j.pumped = 120.0
	var dp := GroundHudData.interaction(ch, b, false)
	# Ankoppeln blockiert: Lager leer
	j.step_index = j.steps.find(&"attach")
	j.blocked_reason = &"depot_empty"
	var db := GroundHudData.interaction(ch, b, false)
	it.queue_free()
	ch.queue_free()
	var ok: bool = dp.pump and absf(dp.liters - 120.0) < 0.1 and dp.liters_target > 120.0 and db.blocked == "Lager leer"
	return [ok, "Pumpen %.0f/%.0f l, blockiert „%s“ (Punkt %s)" % [dp.liters, dp.liters_target, db.blocked,
		j.point(&"attach", b.rules)]]


func test_wheel_segments() -> Array:
	var segs := [CommandWheel.segment_for(Vector2(0, -1)), CommandWheel.segment_for(Vector2(1, 0)),
		CommandWheel.segment_for(Vector2(0, 1)), CommandWheel.segment_for(Vector2(-1, 0)),
		CommandWheel.segment_for(Vector2(0.7, -0.7))]
	var ok: bool = segs == [0, 2, 4, 6, 1] and CommandWheel.count() == 8
	return [ok, "Segmente %s, Befehle %s" % [str(segs), str(CommandWheel.labels())]]


func test_wheel_issues_command() -> Array:
	var a := _spawn(true)
	var g := _make(a)
	g.set_context(InputBindings.Context.CREW)
	var got := []
	g.command_receiver = func(cmd: int, t: Node): got.append([cmd, t])
	g.wheel_override = 1
	await _step(2)
	var opened := g.wheel.is_open and g.wheel.target() == a
	g.wheel.feed_mouse(Vector2(0, 80))          # nach unten = Segment 4
	g.wheel_override = 0
	await _step(2)
	var ok: bool = opened and got.size() == 1 and got[0][0] == GroundCrewBrain.Command.TRUCK_TO_ME and got[0][1] == a \
		and not g.wheel.is_open
	return [ok, "Rad offen %s, Befehle %s" % [opened, str(got)]]


func test_wheel_to_dispatch_crews() -> Array:
	# Ohne command_receiver: Aufruf an dispatch.crews[i].command(cmd, target)
	var g := _make(null)
	var calls := []
	var brain := FakeBrain.new()
	brain.log = calls
	var disp := FakeDispatch.new()
	disp.crews = [brain]
	world.add_child(disp)
	g.dispatch = disp
	var n := g.issue_command(GroundCrewBrain.Command.FUEL_ONLY, null)
	return [n == 1 and calls == [[GroundCrewBrain.Command.FUEL_ONLY, null]], "Empfänger %d, Aufrufe %s" % [n, str(calls)]]


class FakeBrain extends RefCounted:
	var log: Array
	func command(cmd: int, t: Node) -> bool:
		log.append([cmd, t])
		return true


class FakeDispatch extends Node:
	var crews: Array = []
	var aircraft: Array = []


func test_alarm_and_turnaround() -> Array:
	var g := _make(null)
	g.set_context(InputBindings.Context.CREW)
	var ta := Turnaround.new()
	ta.best_path = "user://test_hud_bestzeit.cfg"
	g.turnaround = ta
	GroundEvents.bus().alarm_started.emit(167.0)
	ta.running = true
	ta.elapsed = 83.0
	await _step(2)
	var banner := g.timer.alarm_banner.visible and absf(g.timer.alarm_left - 167.0) < 1.0
	var shown := g.timer.visible
	ta.running = false
	ta.last_stars = 2
	await _step(2)
	var result := g.timer.visible and int(g.timer.timer.stars) == 2
	GroundEvents.bus().alarm_ended.emit(true)
	await _step(2)
	var ok: bool = banner and shown and result and not g.timer.alarm_banner.visible \
		and GroundHudData.clock(167.0) == "2:47"
	return [ok, "Banner %s, Uhr %s, Ergebnis %s, danach Banner %s" % [banner, shown, result, g.timer.alarm_banner.visible]]


func test_flight_hud_hidden_on_ground() -> Array:
	var a := _spawn(true)
	var h := Hud.new()
	h.aircraft = a
	world.add_child(h)
	_g = GroundHud.create(h)
	h.add_child(_g)
	await _step(3)
	var before := h.combat.visible
	_g.set_context(InputBindings.Context.CREW)
	await _step(3)
	var hidden := not h.combat.visible
	_g.set_context(InputBindings.Context.FLIGHT)
	await _step(3)
	var back := h.combat.visible
	h.queue_free()
	return [before and hidden and back, "Kampf-HUD: Flug %s, zu Fuß aus %s, zurück %s" % [before, hidden, back]]


func test_parking_bearing() -> Array:
	var cam := Transform3D(Basis.IDENTITY, Vector3.ZERO)     # Blick nach -Z
	var right := ParkingGuide.relative_bearing(cam, Vector3.ZERO, Vector3(10, 0, 0))
	var ahead := ParkingGuide.relative_bearing(cam, Vector3.ZERO, Vector3(0, 0, -10))
	var ok := absf(right - PI * 0.5) < 0.01 and absf(ahead) < 0.01
	return [ok, "rechts %.2f, voraus %.2f rad" % [right, ahead]]


func test_help_rows() -> Array:
	var crew := GroundHelp.help_rows(InputBindings.Context.CREW)
	var drive := GroundHelp.help_rows(InputBindings.Context.DRIVE)
	var flight := GroundHelp.help_rows(InputBindings.Context.FLIGHT)
	var has := func(rows: Array, act: String, kb: String) -> bool:
		return rows.any(func(r): return String(r[0]).begins_with(act) and r[1] == kb)
	var ok: bool = has.call(crew, "Befehlsrad", "Tab") and has.call(crew, "Einsteigen", "F") \
		and has.call(drive, "Handbremse", "Leertaste") and has.call(flight, "Aussteigen", "J")
	return [ok, "Zeilen zu Fuß %d, Fahren %d, Flug %d" % [crew.size(), drive.size(), flight.size()]]
