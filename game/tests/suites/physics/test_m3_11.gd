extends TestSuite
## M3.11 Feinschliff (Punkte 2–6): Massen- und Trägheitskopplung, Motor (Drehmoment,
## P-Faktor, Drall, Kühlung, Verbrauch), IAS-Anzeige, Rollreibung, g-Toleranz des Piloten.
## Suite "fast".


## Punkt 2: Munitionsmasse. Verschossene Munition macht das Flugzeug leichter
## (40 g je Schuss inkl. Gurtglied), Nachladen (place/refill) stellt die Masse wieder her.
func test_ammo_mass_coupling() -> Array:
	var a := _spawn(false, 1500.0, 120.0, 0.8)
	await _step(3)
	var m_full := a.mass
	var full_kg := a.weapons.ammo_mass_full_kg()
	var taken := 0
	for mg in a.weapons.magazines:
		taken += mg.take(300)
	await _step(3)
	var drop := m_full - a.mass
	var want := taken * 0.040
	a.place(a.global_transform, 120.0, 0.8, false)
	await _step(3)
	var back := a.mass
	var ok := full_kg > 30.0 and absf(drop - want) < 0.6 and absf(back - m_full) < 0.6
	return [ok, "Munition voll %.1f kg, %d Schuss verschossen: −%.2f kg (Soll %.2f), nach Nachladen %.1f kg (vorher %.1f)" % [
		full_kg, taken, drop, want, back, m_full]]


## Punkt 3: Trägheitsmomente. Voll 8.000/9.000/4.400 kg m² (Roskam), mit leeren Tanks und
## leerer Munition sinken Gieren und Rollen um Δm·r² (Tanks ±1,0 m, Waffen ±2,35 m),
## Nicken kaum.
func test_inertia_loading() -> Array:
	var a := _spawn(false, 1500.0, 120.0, 0.8)
	await _step(3)
	var i_full := a.inertia
	a.damage.fuel.liters = PackedFloat32Array([0.0, 0.0])
	for mg in a.weapons.magazines:
		mg.take(mg.count)
	await _step(3)
	var i_empty := a.inertia
	var d := i_full - i_empty
	var ok := i_full.is_equal_approx(Vector3(8000, 9000, 4400)) and d.z > 350.0 and d.z < 700.0 \
		and d.y > 350.0 and d.y < 700.0 and d.x < 120.0 and a.mass < 2500.0 - 290.0
	return [ok, "Trägheit voll %s, leer %s (Δ %s), Masse leer %.0f kg" % [i_full, i_empty, d, a.mass]]
