extends TestSuite
## Paket 4: DamageModel – ein Test je Zone, Brand, Leck, FuelSystem, Neutralität (Agent B).

const SUITE := "fast"
const Z := DamageModel.Zone


## Flugzeug am Boden, ohne eigenen Physik-Tick (Logik wird direkt getickt).
func _ac(nation := Nations.BLUE) -> Aircraft:
	var a := _spawn(true)
	a.nation_id = nation
	a.set_physics_process(false)
	return a


func _tick(a: Aircraft, seconds: float, dt := 1.0 / 60.0) -> void:
	for i in int(round(seconds / dt)):
		a.damage.tick(dt)


func _destroyed_log() -> Array:
	var log := []
	CombatEvents.bus().aircraft_destroyed.connect(func(v, k, c): log.append([v, k, c]))
	return log


func test_profile_loaded() -> Array:
	var a := _ac()
	var d := a.damage
	var ok := d.profile.resource_path.ends_with("damage_profile_t1.tres") and d.hp_max == PackedFloat32Array([120, 80, 80, 200, 200, 120, 100])
	_tick(a, 1.0)
	ok = ok and d.modifiers.is_neutral() and not d.is_destroyed
	return [ok, "Profil %s, intakt nach 1 s neutral=%s" % [d.profile.resource_path.get_file(), d.modifiers.is_neutral()]]


func test_zone_engine() -> Array:
	var a := _ac()
	var e := _ac(Nations.RED)
	var d := a.damage
	d.apply_hit(Z.ENGINE, 40.0, e)          # 67 %
	var p1 := d.modifiers.engine_power_mul
	var oil := d.oil_leaking()
	var seize := d.seize_timer
	d.apply_hit(Z.ENGINE, 50.0, e)          # 25 %
	var p2 := d.modifiers.engine_power_mul
	var eject_ok := d.can_eject()
	d.apply_hit(Z.ENGINE, 40.0, e)          # 0
	var ok := is_equal_approx(p1, 0.85) and oil and is_equal_approx(seize, 90.0) \
		and is_equal_approx(p2, 0.5) and eject_ok and d.modifiers.engine_failed and not d.is_destroyed
	# Festfress-Timer allein
	var b := _ac()
	b.damage.apply_hit(Z.ENGINE, 40.0, e)
	_tick(b, 91.0, 0.5)
	ok = ok and b.damage.engine_dead and b.damage.modifiers.engine_failed
	return [ok, "Leistung 67 %%: ×%.2f (Öl %s, Timer %.0f s), 25 %%: ×%.2f, 0: Stillstand; Festfressen nach 90 s: %s" % [p1, oil, seize, p2, b.damage.engine_dead]]


func test_zone_fuel_tank_leak() -> Array:
	var a := _ac()
	var d := a.damage
	d.apply_hit(Z.FUEL_L, 40.0, null)       # 50 % -> Leck 0,75 l/s
	d.extinguish()
	var l0 := d.fuel.liters[0]
	var r0 := d.fuel.liters[1]
	_tick(a, 10.0)
	var lost_l := l0 - d.fuel.liters[0]
	var lost_r := r0 - d.fuel.liters[1]
	var ok := absf(lost_l - lost_r - 7.5) < 0.2 and d.fuel.is_leaking()
	# Leerlaufen -> Motor steht
	d.fuel.liters[1] = 0.0
	d.fuel.liters[0] = 0.5
	_tick(a, 2.0)
	ok = ok and d.fuel.is_empty() and d.modifiers.engine_failed
	return [ok, "Leck links %.2f l in 10 s (rechts %.2f l Verbrauch), leer -> Motor aus: %s" % [lost_l, lost_r, d.modifiers.engine_failed]]


func test_zone_fuel_tank_fire_chance() -> Array:
	# 8 % je Treffer: über viele Flugzeuge/Treffer statistisch
	var fires := 0
	var n := 0
	for k in 25:
		var a := _ac()
		for h in 4:
			a.damage.apply_hit(Z.FUEL_R, 2.0, null)
			n += 1
			if a.damage.is_burning(Z.FUEL_R):
				fires += 1
				break
		a.free()
	var ok := fires >= 1 and fires <= 25
	return [ok, "Tankbrand bei %d von 25 Flugzeugen (≤ 4 Treffer, %d Treffer gesamt)" % [fires, n]]


func test_fire_burn_spread_extinguish() -> Array:
	var a := _ac()
	var d := a.damage
	d.start_fire(Z.FUEL_L)
	_tick(a, 5.0)
	var hp5 := d.hp[Z.FUEL_L]
	var wing_before := d.is_burning(Z.WING_L)
	_tick(a, 6.0)
	var ok := absf(hp5 - 60.0) < 0.5 and not wing_before and d.is_burning(Z.WING_L) and d.can_eject()
	# Sturzflug > 450 km/h löscht (15 %/s)
	var b := _ac()
	b.damage.start_fire(Z.ENGINE)
	b.flight.telemetry.airspeed = 140.0
	var t := 0.0
	while b.damage.is_burning() and t < 60.0:
		b.damage.tick(0.1)
		b.flight.telemetry.airspeed = 140.0
		t += 0.1
	ok = ok and not b.damage.is_burning() and t > 0.0
	return [ok, "Brand 4 HP/s (Tank %.1f nach 5 s), Übergriff Flügel nach 10 s: %s, gelöscht im Sturzflug nach %.1f s" % [hp5, d.is_burning(Z.WING_L), t]]


func test_zone_wing() -> Array:
	var a := _ac()
	var e := _ac(Nations.RED)
	var log := _destroyed_log()
	var d := a.damage
	d.apply_hit(Z.WING_L, 60.0, e)          # 70 %
	var lift70 := d.modifiers.lift[3]
	var ail70 := d.modifiers.control[5]
	d.apply_hit(Z.WING_L, 50.0, e)          # 45 %
	var ail45 := d.modifiers.control[5]
	var right_ok := d.modifiers.lift[0] == 1.0 and d.modifiers.control[2] == 1.0
	d.apply_hit(Z.WING_L, 100.0, e)
	var ok: bool = lift70 < 1.0 and lift70 > 0.8 and ail70 == 1.0 and ail45 == 0.0 and right_ok \
		and d.is_destroyed and log.size() == 1 and log[0][1] == e and log[0][2] == CombatEvents.Cause.WING_BROKEN \
		and d.modifiers.lift[5] == 0.0
	return [ok, "Auftrieb 70 %%: %.3f, Querruder 70 %%: %.0f / 45 %%: %.0f, Bruch -> Abschuss %s durch Gegner" % [lift70, ail70, ail45, log.size() == 1]]


func test_zone_tail() -> Array:
	var a := _ac()
	var d := a.damage
	d.apply_hit(Z.TAIL, 60.0, null)         # 50 %
	var c := d.modifiers.control[6]
	var ok := c < 1.0 and c > 0.3 and is_equal_approx(d.modifiers.control[8], c)
	# klemmendes Ruder: bei vielen Treffern irgendwann
	var stuck := 0
	for k in 20:
		var b := _ac()
		for h in 5:
			b.damage.apply_hit(Z.TAIL, 15.0, null)
		for s in b.damage.modifiers.stuck:
			stuck += s
		if b.damage.modifiers.stuck.count(1) > 0 and not b.damage.can_eject():
			ok = false
		b.free()
	ok = ok and stuck > 0
	return [ok, "Ruderwirkung 50 %% HP: %.2f, klemmende Ruder in 20 Versuchen: %d" % [c, stuck]]


func test_zone_cockpit() -> Array:
	var a := _ac()
	var e := _ac(Nations.RED)
	var log := _destroyed_log()
	var d := a.damage
	var locked := not d.can_eject()
	d.apply_hit(Z.COCKPIT, 45.0, e)         # 55 % -> verwundet
	var wounded := d.pilot_wounded() and d.can_eject()
	var it := PilotIntent.new()
	var sum := 0.0
	for k in 30:
		it.pitch = 1.0
		d.tick(1.0 / 60.0)
		d.filter_intent(it, 1.0 / 60.0)
		sum += it.pitch
	var avg := sum / 30.0
	d.apply_hit(Z.COCKPIT, 60.0, e)
	it.pitch = 1.0
	it.fire_primary = true
	d.filter_intent(it, 0.016)
	var ok: bool = locked and wounded and avg < 0.9 and avg > 0.4 and d.is_destroyed \
		and log.size() == 1 and log[0][2] == CombatEvents.Cause.PILOT_KILLED and it.pitch == 0.0 and not it.fire_primary
	return [ok, "intakt: Ausstieg gesperrt %s, verwundet -> Eingabe Ø %.2f, tot -> Abschuss %s, Steuer lose" % [locked, avg, log.size() == 1]]


func test_friendly_fire_and_credit() -> Array:
	var a := _ac()
	var friend := _ac()
	var e := _ac(Nations.RED)
	a.damage.apply_hit(Z.WING_R, 50.0, friend)
	var ff_blocked := a.damage.hp[Z.WING_R] == 200.0
	a.damage.apply_hit(Z.WING_R, 20.0, e)
	_tick(a, 31.0, 0.5)
	var expired := a.damage.credited_attacker() == null
	a.damage.apply_hit(Z.WING_R, 10.0, e)
	var ok := ff_blocked and expired and a.damage.credited_attacker() == e
	return [ok, "Eigenbeschuss ohne Schaden %s, Kredit nach 31 s verfallen %s" % [ff_blocked, expired]]


func test_state_array_roundtrip() -> Array:
	var a := _ac()
	a.damage.apply_hit(Z.WING_L, 120.0, null)
	a.damage.apply_hit(Z.COCKPIT, 50.0, null)
	a.damage.start_fire(Z.ENGINE)
	var arr := a.damage.to_array()
	var b := _ac()
	b.damage.from_array(arr)
	var ok := b.damage.to_array() == arr and b.damage.pilot_wounded() and b.damage.is_burning(Z.ENGINE) \
		and b.damage.modifiers.control[5] == 0.0
	return [ok, "Zustand %d Werte, Rundreise gleich" % arr.size()]


func test_damaged_flight_effect() -> Array:
	# Flug mit zerschossenem linken Flügel rollt nach links weg (echte Physik).
	var a := _spawn(false, 800.0, 90.0, 0.8)
	_seat(a, func(_a, i, _dt): i.throttle = 0.8)
	a.damage.apply_hit(Z.WING_L, 140.0, null)
	await _step(60)
	var roll_rate := a.flight.telemetry.angular_velocity_local.z
	var bank := a.global_transform.basis.x.y   # >0: rechte Fläche oben = Rollen nach links
	var ok := absf(bank) > 0.05 and not a.damage.is_destroyed
	return [ok, "1 s nach Flügeltreffer: Querlage-Komponente %.2f, Rollrate %.2f rad/s" % [bank, roll_rate]]
