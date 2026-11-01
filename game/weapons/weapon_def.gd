class_name WeaponDef
extends Resource
## Daten einer Waffe (Plan M2 §2). Alle Werte in SI-Einheiten.

@export var display_name := "MG"
@export var caliber_mm := 7.92
## Kadenz (Schuss/min) je Waffe.
@export var rpm := 600.0
## Mündungsgeschwindigkeit (m/s) relativ zum Schützen.
@export var muzzle_velocity := 800.0
## Geschossmasse (kg).
@export var projectile_mass := 0.0128
## Luftwiderstands-Faktor k = ½·ρ·Cd·A/m (1/m); a = g − k·|v|·v.
@export var ballistic_k := 7.0e-4
## Streuung (Standardabweichung je Achse, mrad).
@export var dispersion_mrad := 1.5
## Schaden je Treffer (Zonen-HP, DamageModel).
@export var damage := 10.0
## Leuchtspur jeder n-te Schuss (0 = keine).
@export var tracer_every := 5
## Maximale Reichweite (m); danach verschwindet das Geschoss.
@export var max_range := 1500.0
## Munitionsart für AmmoStore.request().
@export var ammo_type: StringName = &"7.92mm"
## Optional (Paket 15): Hitze je Schuss, Abkühlung je s, Ladehemmung bei Hitze.
@export var heat_per_shot := 0.0
@export var cool_rate := 0.0
@export var jam_chance_hot := 0.0


## Abstand zweier Schüsse derselben Waffe (s).
func shot_interval() -> float:
	return 60.0 / maxf(rpm, 1.0)


## Lebensdauer eines Geschosses (s), konservativ über die abgebremste Flugzeit.
func lifetime() -> float:
	return Ballistics.time_of_flight(max_range, muzzle_velocity, ballistic_k) + 0.25
