class_name WeaponSystem
extends RefCounted
## Bordwaffen eines Flugzeugs (Stub aus Paket 0, Inhalt: Agent A, Paket 2).
## Aufrufstellen in aircraft.gd (fest, nicht mehr ändern):
##   _init(aircraft)          beim Bau, nach FlightModel
##   tick(intent, dt)         jeden Physik-Tick (nach DamageModel.filter_intent), nur Server feuert
##   reset()                  in Aircraft.place() (Neustart: Magazine voll)
## Lädt die Bewaffnung aus AircraftData.loadout_path (falls vorhanden); die Datenklassen
## (WeaponDef, GunMountDef) und das Format der Datei legt Agent A fest.
## Geschosse gehen an ProjectileSystem.current (weapons/projectile_system.gd).

enum Group { PRIMARY, SECONDARY }

signal fired(gun_index: int, shot_id: int)
signal trigger_changed(group: int, pressed: bool)

var aircraft: Node3D
## Geladene Bewaffnung (Ressource aus loadout_path) oder null.
var loadout: Resource = null
## Konvergenzentfernung der Flügelwaffen (m), Plan §2.
var convergence := 250.0
var trigger := [false, false]
## Fortlaufende Schussnummer (Seed für Streuung: hash(shooter, gun, shot)).
var shot_counter := 0


func _init(a: Node3D) -> void:
	aircraft = a
	var d = a.get("data")
	if d != null and d.loadout_path != "" and ResourceLoader.exists(d.loadout_path):
		loadout = load(d.loadout_path)


func reset() -> void:
	trigger = [false, false]


func tick(intent: PilotIntent, _dt: float) -> void:
	_set_trigger(Group.PRIMARY, intent.fire_primary)
	_set_trigger(Group.SECONDARY, intent.fire_secondary)


func _set_trigger(g: int, pressed: bool) -> void:
	if trigger[g] != pressed:
		trigger[g] = pressed
		trigger_changed.emit(g, pressed)


func has_weapons(_group: int = Group.PRIMARY) -> bool:
	return false


func gun_count() -> int:
	return 0


func ammo(_group: int = Group.PRIMARY) -> int:
	return 0


func ammo_max(_group: int = Group.PRIMARY) -> int:
	return 0


## Mündungsgeschwindigkeit der Gruppe (m/s), für Vorhalt (HUD/KI).
func muzzle_velocity(_group: int = Group.PRIMARY) -> float:
	return 800.0


## Nachladen am Platz (M2: InfiniteAmmoStore). store: request(type, n) -> int.
func rearm(_store: Object) -> void:
	pass
