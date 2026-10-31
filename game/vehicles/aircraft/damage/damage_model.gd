class_name DamageModel
extends RefCounted
## Schadensmodell eines Flugzeugs (Stub aus Paket 0, Inhalt: Agent B, Pakete 4/6).
## Vom Flugzeug an festen Stellen aufgerufen (aircraft.gd, jeden Physik-Tick):
##   filter_intent(intent, dt)  -> verwundeter/toter Pilot, gesperrte Eingaben
##   tick(dt)                   -> Brand, Lecks, Festfress-Timer; schreibt modifiers
##   can_eject()                -> Notausstieg erlaubt? (beim Drücken von "eject")
##   on_impact(body, velocity)  -> Bodenberührung/Kollision (Bauchlandung vs. Absturz)
##   reset()                    -> Aircraft.place() (Neustart/Respawn)
## Treffer kommen über apply_hit() (ProjectileSystem/HitValidator, nur Server).
## Zustandsänderungen nur wenn Authority.is_server(); Zustand kompakt über to_array().

enum Zone { ENGINE, FUEL_L, FUEL_R, WING_L, WING_R, TAIL, COCKPIT, COUNT }
const ZONE_NAMES := ["engine", "fuel_tank_L", "fuel_tank_R", "wing_L", "wing_R", "tail", "cockpit"]

## Stub-Startwerte (Plan §3); das echte Profil kommt aus damage_profile_t1.tres.
const DEFAULT_HP := [120.0, 80.0, 80.0, 200.0, 200.0, 120.0, 100.0]

signal zone_changed(zone: int, hp_fraction: float)
signal destroyed(cause: int, killer: Node)

var aircraft: Node3D
var modifiers: FlightModifiers
var hitboxes: HitboxSet
var hp: PackedFloat32Array = []
var hp_max: PackedFloat32Array = []
var is_destroyed := false
var last_attacker: Node = null
var last_hit_time := -1.0


func _init(a: Node3D, mods: FlightModifiers) -> void:
	aircraft = a
	modifiers = mods
	hp_max = PackedFloat32Array(DEFAULT_HP)
	hitboxes = HitboxSet.from_aircraft_data(a.get("data"))
	reset()


func reset() -> void:
	hp = hp_max.duplicate()
	is_destroyed = false
	last_attacker = null
	last_hit_time = -1.0
	modifiers.reset()


## Treffer anwenden (nur Server). local_point im Flugzeug-Koordinatensystem.
func apply_hit(zone: int, damage: float, attacker: Node, _local_point := Vector3.ZERO) -> void:
	if not Authority.is_server() or zone < 0 or zone >= Zone.COUNT or is_destroyed:
		return
	hp[zone] = maxf(hp[zone] - damage, 0.0)
	last_attacker = attacker
	last_hit_time = Time.get_ticks_msec() / 1000.0
	zone_changed.emit(zone, hp_fraction(zone))
	CombatEvents.bus().aircraft_damaged.emit(aircraft, zone, damage, attacker)


func hp_fraction(zone: int) -> float:
	return hp[zone] / maxf(hp_max[zone], 1e-3)


func tick(_dt: float) -> void:
	pass


func filter_intent(_intent: PilotIntent, _dt: float) -> void:
	pass


## Notausstieg nur bei schwerem Schaden (GDD §6.3). Stub: nie.
func can_eject() -> bool:
	return false


## Pilot verwundet (Stub: nie). HUD-Vignette, Spotting.
func pilot_wounded() -> bool:
	return false


func on_impact(_body: Node, _velocity: Vector3) -> void:
	pass


func to_array() -> PackedFloat32Array:
	var a := hp.duplicate()
	a.append(1.0 if is_destroyed else 0.0)
	return a


func from_array(a: PackedFloat32Array) -> void:
	for i in mini(a.size(), Zone.COUNT):
		hp[i] = a[i]
	if a.size() > Zone.COUNT:
		is_destroyed = a[Zone.COUNT] > 0.5
