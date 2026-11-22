extends TestSuite
## M3.5: Befehlsrad überarbeitet – Fahrzeuge rufen / zurückschicken, einzelne Mechaniker beauftragen
## (Tanken, Aufmunitionieren, Reparieren, Voll abfertigen), danach Aufräumen (Schlauch ein, Klappen
## zu, Wagen zum Stellplatz, Figur zum Crew-Platz), Selbstbedienung (Automatik aus) und Meldungen.

const StubCrew := preload("res://tests/suites/ai_ground/stub_crew.gd")
const C := GroundCrewBrain.Command


func _setup() -> Dictionary:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(0.2)
	a.weapons.set_ammo_fraction(0.0)
	var tz := DamageModel.Zone.TAIL
	a.damage.hp[tz] = a.damage.hp_max[tz] * 0.7
	var board := JobBoard.new()
	board.rules = GroundRules.for_realism(MatchRules.GroundRealism.STANDARD)
	world.add_child(board)
	var disp := GroundCrewDispatch.new()
	disp.board = board
	disp.depot = FuelDepot.new()
	disp.store = AmmoBunker.new()
	disp.aircraft = [a]
	disp.nation_id = a.nation_id
	var side := Vector3(a.global_transform.basis.x.x, 0.0, a.global_transform.basis.x.z).normalized()
	disp.depot_pos = a.global_position + side * -60.0
	disp.depot.position = disp.depot_pos
	disp.truck_pos = disp.depot_pos + Vector3(0, 0, 8)
	disp.crew_spawn = a.global_position + side * -20.0
	world.add_child(disp)
	var svc := SeatService.new()
	world.add_child(svc)
	var said := []
	disp.crew_report.connect(func(t, _b): said.append(t))
	return {a = a, board = board, disp = disp, side = side, said = said}


func _crew(s: Dictionary, mode: int, start: Vector3, nm := "Mechaniker A") -> GroundCrewBrain:
	var br := GroundCrewBrain.new()
	br.dispatch = s.disp
	br.board = s.board
	br.force_mode = mode
	br.sim_pos = start
	var c := StubCrew.new()
	c.name = nm
	world.add_child(c)
	c.global_position = start
	c.add_child(br)
	c.crew_seat.possess(br)
	s.disp.crews.append(br)
	return br


func _vehicles(s: Dictionary) -> Array:
	var t := FuelTruck.create(2000.0)
	world.add_child(t)
	t.place(s.disp.truck_pos, 0.0)
	t.depot = s.disp.depot
	s.disp.fuel_truck = t
	var cart := AmmoCart.new()
	world.add_child(cart)
	cart.place(s.disp.truck_pos + Vector3(0, 0, -12), 0.0)
	s.disp.ammo_cart = cart
	s.disp.set_home(t, t.global_position)
	s.disp.set_home(cart, cart.global_position)
	return [t, cart]


func _run(max_t: float, until: Callable) -> float:
	var t := 0.0
	while t < max_t:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if until.call():
			break
	return t


func _home_d(s: Dictionary, v: Node3D) -> float:
	var h: Vector3 = s.disp.home_of(v)
	return Vector2(v.global_position.x - h.x, v.global_position.z - h.z).length()


func _spawn_d(br: GroundCrewBrain, s: Dictionary) -> float:
	var p := br.position_now()
	var q: Vector3 = s.disp.crew_spawn
	return Vector2(p.x - q.x, p.z - q.z).length()


## „Tankwagen kommen“: ein freier Mechaniker fährt den Wagen neben die Maschine (Schlauch reicht),
## steigt aus; die Maschine ist danach in Selbstbedienung (KI nimmt ihre Jobs nicht).
func test_call_truck() -> Array:
	var s := _setup()
	var vs := _vehicles(s)
	var t: FuelTruck = vs[0]
	var br := _crew(s, 0, s.disp.truck_pos + Vector3(4, 0, 0))
	var n: int = s.disp.command(C.CALL_TRUCK, s.a)
	var tt := await _run(60.0, func(): return br._leg_for == "" and br.in_vehicle() == null and _home_d(s, t) > 8.0)
	await _step(30)
	var cap: Vector3 = s.a.service_point(ServiceMarkers.SVC_FUEL_CAP)
	var d := t.global_position.distance_to(cap)
	var reserved: Array = s.board.open_jobs(s.a).filter(func(j): return j.reserved)
	var ai_took: bool = s.board.open_jobs(s.a).any(func(j): return j.worker != null)
	var ready: bool = s.said.any(func(x): return String(x).contains("steht bereit"))
	var ok: bool = n == 1 and d < FuelTruck.HOSE_LENGTH and br.in_vehicle() == null and s.disp.is_self_service(s.a) \
		and not reserved.is_empty() and not ai_took and ready
	return [ok, "%.1f s, Wagen %.1f m vom Deckel, reserviert %d, KI arbeitet %s, Meldungen %s" % [tt, d,
		reserved.size(), ai_took, str(s.said)]]


## „Tankwagen zurück“: Schlauch liegt am Boden -> einrollen, zum Stellplatz fahren, zu Fuß zurück.
## Mit angekoppeltem Schlauch wird der Befehl abgelehnt.
func test_send_truck_home() -> Array:
	var s := _setup()
	var vs := _vehicles(s)
	var t: FuelTruck = vs[0]
	t.place(s.a.global_position + s.side * 8.0, 0.0)
	var br := _crew(s, 1, s.disp.crew_spawn)
	s.disp.set_self_service(s.a, true)          # Spieler hat selbst getankt (Automatik aus)
	t.hose.couple(s.a, ServiceMarkers.aircraft_point(s.a, ServiceMarkers.SVC_FUEL_CAP))
	var refused: bool = s.disp.command(C.TRUCK_HOME, null) == 0
	t.hose.uncouple()
	var lying := not t.hose.stowed
	var n: int = s.disp.command(C.TRUCK_HOME, null)
	var tt := await _run(240.0, func(): return br._leg_for == "")
	var ok: bool = refused and lying and n == 1 and t.hose.stowed and _home_d(s, t) < GroundCrewBrain.HOME_R \
		and _spawn_d(br, s) < 2.0 and br.in_vehicle() == null
	return [ok, "abgelehnt %s, %.0f s, Schlauch ein %s, Wagen %.1f m vom Stellplatz, Figur %.1f m, %s" % [refused, tt,
		t.hose.stowed, _home_d(s, t), _spawn_d(br, s), str(s.said)]]


## „Munitionswagen kommen“ und „Munitionswagen zurück“.
func test_call_and_send_cart() -> Array:
	var s := _setup()
	var vs := _vehicles(s)
	var cart: AmmoCart = vs[1]
	var br := _crew(s, 1, s.disp.crew_spawn)
	var n1: int = s.disp.command(C.CALL_CART, s.a)
	await _run(120.0, func(): return br._leg_for == "")
	var hatch: Vector3 = s.a.service_point(ServiceMarkers.SVC_GUN_HATCH_L)
	var d := Vector2(cart.global_position.x - hatch.x, cart.global_position.z - hatch.z).length()
	var n2: int = s.disp.command(C.CART_HOME, null)
	await _run(120.0, func(): return br._leg_for == "")
	var ok: bool = n1 == 1 and n2 == 1 and d < GroundCrewBrain.CART_MAX and _home_d(s, cart) < GroundCrewBrain.HOME_R
	return [ok, "Wagen an der Klappe %.1f m, danach %.1f m vom Stellplatz" % [d, _home_d(s, cart)]]


## Einzelauftrag: Mechaniker A tankt (B arbeitet nicht mit), danach Schlauch ein, Wagen zurück.
func _order(cmd: int) -> Dictionary:
	var s := _setup()
	var vs := _vehicles(s)
	var a_br := _crew(s, 1, s.disp.crew_spawn, "Mechaniker A")
	var b_br := _crew(s, 1, s.disp.crew_spawn + Vector3(0, 0, 2.5), "Mechaniker B")
	var b_worked := [false]
	await _step(30)
	var n: int = s.disp.command(cmd, s.a, a_br)
	var tt := await _run(400.0, func():
		for j in s.board.open_jobs(s.a):
			if j.worker == b_br.body():
				b_worked[0] = true
		return not a_br.ordered and a_br._leg_for == "")
	return {s = s, t = vs[0], cart = vs[1], a = a_br, b = b_br, n = n, tt = tt, b_worked = b_worked[0]}


func test_order_fuel_and_tidy() -> Array:
	var r := await _order(C.FUEL_ONLY)
	var s: Dictionary = r.s
	var t: FuelTruck = r.t
	var ok: bool = r.n == 1 and s.a.damage.fuel.fraction() > 0.99 and s.a.weapons.ammo() == 0 and not r.b_worked \
		and t.hose.stowed and not t.hose.is_coupled() and _home_d(s, t) < GroundCrewBrain.HOME_R \
		and _spawn_d(r.a, s) < 2.0 and s.said.any(func(x): return String(x).contains("Tanken erledigt"))
	return [ok, "%.0f s, Tank %.2f, B half %s, Schlauch ein %s, Wagen %.1f m, %s" % [r.tt, s.a.damage.fuel.fraction(),
		r.b_worked, t.hose.stowed, _home_d(s, t), str(s.said)]]


func test_order_ammo_and_tidy() -> Array:
	var r := await _order(C.AMMO_ONLY)
	var s: Dictionary = r.s
	var a: Aircraft = s.a
	var hatches_closed: bool = s.board.jobs_for(a).filter(func(j): return j is RearmJob).all(func(j): return j.is_done())
	var ok: bool = r.n == 1 and a.weapons.ammo() == a.weapons.ammo_max() and a.damage.fuel.fraction() < 0.21 \
		and not r.b_worked and hatches_closed and _home_d(s, r.cart) < GroundCrewBrain.HOME_R and _spawn_d(r.a, s) < 2.0
	return [ok, "%.0f s, Munition %d, Klappen zu %s, B half %s, Wagen %.1f m" % [r.tt, a.weapons.ammo(),
		hatches_closed, r.b_worked, _home_d(s, r.cart)]]


func test_order_repair_and_tidy() -> Array:
	var r := await _order(C.REPAIR)
	var s: Dictionary = r.s
	var a: Aircraft = s.a
	var tz := DamageModel.Zone.TAIL
	var ok: bool = r.n == 1 and is_equal_approx(a.damage.hp[tz], a.damage.hp_max[tz]) and a.weapons.ammo() == 0 \
		and not r.b_worked and _spawn_d(r.a, s) < 2.0
	return [ok, "%.0f s, Leitwerk %.0f/%.0f, B half %s" % [r.tt, a.damage.hp[tz], a.damage.hp_max[tz], r.b_worked]]


func test_order_full_and_tidy() -> Array:
	var r := await _order(C.FULL_SERVICE)
	var s: Dictionary = r.s
	var a: Aircraft = s.a
	var ok: bool = r.n == 1 and a.damage.fuel.fraction() > 0.99 and a.weapons.ammo() == a.weapons.ammo_max() \
		and not r.b_worked and r.t.hose.stowed and _home_d(s, r.t) < GroundCrewBrain.HOME_R \
		and _home_d(s, r.cart) < GroundCrewBrain.HOME_R and _spawn_d(r.a, s) < 2.0
	return [ok, "%.0f s, Tank %.2f, Munition %d, Wagen %.1f/%.1f m, %s" % [r.tt, a.damage.fuel.fraction(),
		a.weapons.ammo(), _home_d(s, r.t), _home_d(s, r.cart), str(s.said)]]


## Statuszeile „Mechaniker A: tankt – 60 %“ während der Arbeit; „Automatik“ hebt Selbstbedienung auf.
func test_status_and_auto() -> Array:
	var s := _setup()
	_vehicles(s)
	var br := _crew(s, 1, s.disp.crew_spawn)
	await _step(30)
	s.disp.command(C.FUEL_ONLY, s.a, br)
	var seen := [""]
	await _run(200.0, func():
		var st := br.status()
		if st.text == "tankt" and st.progress > 0.3:
			seen[0] = CrewPanel.row_text({name = br.crew_name(), text = st.text, progress = st.progress})
		return seen[0] != "")
	var self_on: bool = s.disp.is_self_service(s.a)
	s.disp.command(C.AUTO, s.a, br)
	await _run(400.0, func(): return s.board.is_serviced(s.a) and s.a.weapons.ammo() == s.a.weapons.ammo_max())
	var ok: bool = seen[0].begins_with("Mechaniker A: tankt – ") and self_on and not s.disp.is_self_service(s.a) \
		and s.a.weapons.ammo() == s.a.weapons.ammo_max()
	return [ok, "Zeile „%s“, Handbetrieb %s, danach Automatik versorgt %s" % [seen[0], self_on, s.board.is_serviced(s.a)]]


## Befehlsrad-Ebenen: Fahrzeuge, je Mechaniker, alle; Auswahl gibt den Mechaniker der Ebene mit.
func test_wheel_pages_route_crew() -> Array:
	var s := _setup()
	var a_br := _crew(s, 1, s.disp.crew_spawn, "Mechaniker A")
	var b_br := _crew(s, 1, s.disp.crew_spawn + Vector3(0, 0, 3), "Mechaniker B")
	var w := CommandWheel.new()
	world.add_child(w)
	var got := []
	w.command_chosen.connect(func(c, t, cr): got.append([c, t, cr]))
	w.open_wheel([s.a], s.a, CommandWheel.default_pages([a_br, b_br]))
	var titles: Array = w.pages.map(func(p): return p.title)
	w.cycle_page(2)                        # Mechaniker B
	w.feed_mouse(Vector2(0, -80))          # oben = Tanken
	var c1 := w.close_wheel()
	w.open_wheel([s.a], s.a, CommandWheel.default_pages([a_br, b_br]))
	var kept := w.page == 2                # Ebene bleibt beim nächsten Öffnen
	w.cycle_page(-2)                       # Fahrzeuge
	w.feed_mouse(Vector2(0, -80))
	var c2 := w.close_wheel()
	w.queue_free()
	var ok: bool = titles == ["Fahrzeuge", "Mechaniker A", "Mechaniker B", "Alle Mechaniker"] \
		and c1 == C.FUEL_ONLY and got[0][2] == b_br and kept and c2 == C.CALL_TRUCK and got[1][2] == null
	return [ok, "Ebenen %s, Befehle %s" % [str(titles), str(got)]]
