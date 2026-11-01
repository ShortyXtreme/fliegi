class_name ServiceState
extends RefCounted
## M3 (Paket 0b): Versorgungszustand, mit dem eine Maschine am Abstellplatz erscheint
## (Aircraft.place(..., refill, service), SpawnManager Paket 10).
##   fuel_fraction / ammo_fraction: 0..1, < 0 = Restzustand behalten
##   grade_mix: Anteil Ersatzbenzin (nur wenn fuel_fraction ≥ 0)
##   fresh_airframe: true = neue Maschine (DamageModel.reset), false = Schäden bleiben

var fuel_fraction := -1.0
var ammo_fraction := -1.0
var grade_mix := 0.0
var fresh_airframe := false


static func make(fuel: float, ammo: float, fresh: bool = true, mix: float = 0.0) -> ServiceState:
	var s := ServiceState.new()
	s.fuel_fraction = fuel
	s.ammo_fraction = ammo
	s.fresh_airframe = fresh
	s.grade_mix = mix
	return s


## Volle Maschine (M2-Verhalten).
static func full() -> ServiceState:
	return make(1.0, 1.0, true)


## Restzustand (nach Landung): nichts ändern.
static func keep() -> ServiceState:
	return make(-1.0, -1.0, false)


## Startzustand nach MatchRules (FIRST 50 %/voll, AFTER_LOSS 15 %/0, AFTER_LANDING Rest).
static func for_start(kind: int) -> ServiceState:
	return make(MatchRules.start_fuel(kind), MatchRules.start_ammo(kind),
		kind != MatchRules.StartKind.AFTER_LANDING)


## Auf ein Flugzeug anwenden (Server). Aircraft.place() ruft das auf.
func apply(a: Node) -> void:
	var d: DamageModel = a.get("damage")
	var w: WeaponSystem = a.get("weapons")
	if fresh_airframe and d != null:
		d.reset()
	if fuel_fraction >= 0.0 and d != null:
		d.fuel.set_fraction(fuel_fraction, grade_mix)
	if ammo_fraction >= 0.0 and w != null:
		w.set_ammo_fraction(ammo_fraction)
