extends TestSuite
## Paket 15: Hitzekurve, Ladehemmung, Abkühlen; Standard-MG ohne Hitze unverändert.


func test_heat_curve() -> Array:
	var a := _spawn(false, 1500.0, 0.0, 0.0)
	a.freeze = true
	var w: WeaponDef = (load("res://weapons/data/mg_t1.tres") as WeaponDef).duplicate()
	w.heat_per_shot = 0.05
	w.cool_rate = 0.1           # netto +0,4/s beim Feuern, 10 s von heiß auf kalt
	w.jam_chance_hot = 1.0
	var lo: WeaponLoadout = (load("res://weapons/data/loadout_fighter_t1.tres") as WeaponLoadout).duplicate(true)
	for m in lo.mounts:
		m.weapon = w
	a.weapons.set_loadout(lo)
	var fire := [true]
	_seat(a, func(_a, i: PilotIntent, _dt): i.fire_primary = fire[0])
	var curve := []
	for s in 4:
		await _step(45)
		curve.append(snappedf(a.weapons.heat_level(), 0.01))
	var jammed := a.weapons.is_jammed()
	var fired := a.weapons.ammo_max() - a.weapons.ammo()
	await _step(30)
	var fired_after := a.weapons.ammo_max() - a.weapons.ammo()
	fire[0] = false
	await _step(420)
	var cooled := a.weapons.heat_level()
	var cleared := not a.weapons.is_jammed()
	var rising: bool = curve[1] > curve[0] and curve[0] > 0.0
	# klemmt bei Hitze ≥ 1 → höchstens ≈ 26 Schuss je Waffe, danach keine weiteren
	var ok := rising and jammed and fired <= 56 and fired_after == fired and cleared and cooled < 0.5
	return [ok, "Hitze %s, gehemmt %s nach %d Schuss, nach 7 s Pause %.2f (frei: %s)" % [
			curve, jammed, fired, cooled, cleared]]


func test_default_no_heat() -> Array:
	var a := _spawn(false, 1500.0, 0.0, 0.0)
	a.freeze = true
	_seat(a, func(_a, i: PilotIntent, _dt): i.fire_primary = true)
	await _step(240)
	return [a.weapons.heat_level() == 0.0 and not a.weapons.is_jammed() and
			a.weapons.ammo() < a.weapons.ammo_max() - 70, "Standard-MG: keine Hitze"]
