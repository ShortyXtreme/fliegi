extends TestSuite
## M3 Paket 1 (Strang G): Tanklager, Munitionsbunker, Sorten, Ersatzbenzin.


## Mengen-Erhalt Lager -> Tankwagen -> Flugzeug, Summe ±0,1 %.
func test_fuel_conservation_chain() -> Array:
	var a := _spawn(true)
	var f := a.damage.fuel
	f.set_fraction(0.05)
	var depot := FuelDepot.new()
	var truck := FuelSource.new({}, {FuelSystem.GRADE_AVIATION: 2000.0, FuelSystem.GRADE_ERSATZ: 2000.0})
	var sum0 := depot.total() + truck.total() + f.total()
	var t1 := depot.transfer_to_source(truck, FuelSystem.GRADE_AVIATION, 2500.0)   # Wagen läuft voll
	var moved := 0.0
	for k in 100:                                       # 100 × 6 l, Flugzeugtank läuft über
		moved += truck.transfer_to_tank(f, FuelSystem.GRADE_AVIATION, 6.0)
	var back := truck.transfer_to_source(depot, FuelSystem.GRADE_AVIATION, 5000.0)
	var sum1 := depot.total() + truck.total() + f.total()
	var ok: bool = absf(sum1 - sum0) <= sum0 * 0.001 and is_equal_approx(t1, 2000.0) \
		and is_equal_approx(f.fraction(), 1.0) and truck.is_empty() and back > 0.0
	return [ok, "Summe %.2f -> %.2f l, Wagen %.0f l, ins Flugzeug %.1f l, zurück %.1f l" % [
		sum0, sum1, t1, moved, back]]


## Leeres Lager liefert nichts; Sortenwahl fällt auf Ersatz zurück, ganz leer = &"".
func test_empty_depot_blocks() -> Array:
	var a := _spawn(true)
	a.damage.fuel.set_fraction(0.2)
	var before := a.damage.fuel.total()
	var depot := FuelDepot.new({FuelSystem.GRADE_AVIATION: 0.0, FuelSystem.GRADE_ERSATZ: 50.0},
		{FuelSystem.GRADE_AVIATION: 8000.0, FuelSystem.GRADE_ERSATZ: 3000.0})
	var g1 := depot.pick_grade()
	var got0 := depot.transfer_to_tank(a.damage.fuel, FuelSystem.GRADE_AVIATION, 100.0)
	var got1 := depot.transfer_to_tank(a.damage.fuel, FuelSystem.GRADE_ERSATZ, 100.0)
	var g2 := depot.pick_grade()
	var g3 := depot.pick_grade(FuelSystem.GRADE_AVIATION, false)
	var bunker := AmmoBunker.new({AmmoBunker.AMMO_792: 0})
	a.weapons.set_ammo_fraction(0.0)
	var loaded := a.weapons.load_gun(0, bunker, 500)
	var ok: bool = g1 == FuelSystem.GRADE_ERSATZ and got0 == 0.0 and is_equal_approx(got1, 50.0) \
		and g2 == &"" and g3 == &"" and loaded == 0 and bunker.is_empty() \
		and is_equal_approx(a.damage.fuel.total(), before + 50.0)
	return [ok, "Sorte %s, leer %s/%s, Ersatz %.0f l, Munition aus leerem Bunker %d" % [
		g1, g2, g3, got1, loaded]]


## Ersatzbenzin: Leistung ×0,88 bei reinem Ersatz, anteilig gemischt.
func test_ersatz_power() -> Array:
	var a := _spawn(true)
	var f := a.damage.fuel
	f.set_fraction(0.0)
	var depot := FuelDepot.new()
	depot.transfer_to_tank(f, FuelSystem.GRADE_ERSATZ, 200.0)
	await _step(2)
	var p1 := a.damage.modifiers.engine_power_mul
	depot.transfer_to_tank(f, FuelSystem.GRADE_AVIATION, 200.0)
	await _step(2)
	var p2 := a.damage.modifiers.engine_power_mul
	var ok: bool = is_equal_approx(p1, 0.88) and absf(p2 - (1.0 - 0.12 * f.grade_mix)) < 0.001 and f.grade_mix > 0.5 and f.grade_mix < 0.6 \
		and is_equal_approx(depot.available(FuelSystem.GRADE_ERSATZ), FuelDepot.START_ERSATZ - 200.0)
	return [ok, "Ersatz %.3f, 50/50 %.3f, Mix %.2f" % [p1, p2, f.grade_mix]]


## Munition: Bunker -> Waffe, Summe bleibt; Typ passt zum MG.
func test_ammo_conservation() -> Array:
	var a := _spawn(true)
	var w := a.weapons
	w.set_ammo_fraction(0.0)
	var bunker := AmmoBunker.new()
	var t: StringName = w.magazines[0].ammo_type
	var sum0 := bunker.available(t)
	var n := 0
	for i in w.gun_count():
		n += w.load_gun(i, bunker, 100000)
	var sum1 := bunker.available(t)
	for i in w.gun_count():
		sum1 += w.gun_ammo(i)
	var ok: bool = t == AmmoBunker.AMMO_792 and n > 0 and sum1 == sum0 and w.ammo() == w.ammo_max()
	return [ok, "Typ %s, geladen %d, Summe %d -> %d" % [t, n, sum0, sum1]]


## Client darf nichts ändern; Netz-Arrays laufen hin und zurück; Treffer-Haken.
func test_client_and_state() -> Array:
	var depot := FuelDepot.new()
	var bunker := AmmoBunker.new()
	var events := []
	GroundEvents.bus().depot_changed.connect(func(d): events.append(d))
	Authority.simulate_client = true
	var c := depot.draw(FuelSystem.GRADE_AVIATION, 10.0) + depot.deposit(FuelSystem.GRADE_ERSATZ, 1.0) \
		+ bunker.request(AmmoBunker.AMMO_792, 10) + bunker.give_back(AmmoBunker.AMMO_792, 10)
	Authority.simulate_client = false
	depot.draw(FuelSystem.GRADE_AVIATION, 1000.0)
	bunker.request(AmmoBunker.AMMO_792, 500)
	var d2 := FuelDepot.new()
	d2.from_array(depot.to_array())
	var b2 := AmmoBunker.new()
	b2.from_array(bunker.to_array())
	var dead := [false]
	depot.destroyed.connect(func(): dead[0] = true)
	depot.take_damage(1000.0)
	var ok: bool = c == 0.0 and is_equal_approx(d2.available(FuelSystem.GRADE_AVIATION), 7000.0) \
		and b2.available(AmmoBunker.AMMO_792) == 19500 and dead[0] and events.size() >= 3 \
		and is_equal_approx(depot.available(FuelSystem.GRADE_AVIATION), 7000.0)
	return [ok, "Client %.0f, Lager %s, Bunker %s, zerstört %s, Ereignisse %d" % [
		c, d2.to_array(), b2.to_array(), dead[0], events.size()]]
