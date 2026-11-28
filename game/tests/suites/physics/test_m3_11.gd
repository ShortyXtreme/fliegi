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
