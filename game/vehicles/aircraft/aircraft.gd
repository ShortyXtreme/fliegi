class_name Aircraft
extends RigidBody3D
## Flugzeug: RigidBody mit FlightModel. Wird komplett im Code aufgebaut:
##   var a := Aircraft.create(load("res://vehicles/aircraft/data/fighter_t1.tres"))
## Eingaben kommen ausschließlich über den Pilotensitz (Seat -> PilotIntent).
##
## M2-Vertrag (Paket 0): feste Aufrufstellen für Kampfsysteme, die Inhalte liegen in
## eigenen Dateien (weapons/, vehicles/aircraft/damage/). Reihenfolge pro Physik-Tick:
##   Seat.poll -> damage.filter_intent -> eject-Flanke -> weapons.tick -> damage.tick
## In _integrate_forces liest FlightModel die FlightModifiers (damage.modifiers).

signal crashed(aircraft: Aircraft)
## Pilot hat Notausstieg verlangt (steigende Flanke von intent.eject).
## allowed = damage.can_eject(); bei false zeigt das HUD „gesperrt“.
signal eject_requested(aircraft: Aircraft, allowed: bool)

static var _next_entity_id := 1

var data: AircraftData
var flight: FlightModel
var assist: FlightAssist
var pilot_seat: Seat
var visual: AircraftVisual
## Nation (core/nations.gd). Freund/Feind nur über Nations.is_hostile().
var nation_id: int = Nations.BLUE
## Eindeutige Kennung je Instanz (Ereignis-Log, Netz, Seeds).
var entity_id: int = 0
## Besatzungslevel für Spotting (PilotRecord.level; bis Paket 6 fest 1).
var crew_level: int = 1
## Aktueller Pilot (characters/pilot_record.gd) oder null. Setzt SpawnManager (Paket 6).
var pilot: PilotRecord = null
## Kampfsysteme (Stubs aus Paket 0).
var weapons: WeaponSystem
var damage: DamageModel
## Vom Server erlaubte Hilfen-Modi (Lobby-Einstellung).
var allowed_assist_modes: Array[int] = [FlightAssist.Mode.ARCADE, FlightAssist.Mode.REALISTIC]
var assist_mode: int = FlightAssist.Mode.ARCADE

## Treibstoffdichte (kg/l) für die Massenkopplung. data.mass gilt mit vollen Tanks.
const FUEL_DENSITY := 0.72

var _intent := PilotIntent.new()
var _fuel_mass_applied := 0.0
## Physik-Tick der letzten Platzierung: Kontakte aus der Erzeugungs-/Vorposition in den
## ersten Ticks danach ignorieren (Jolt meldet sie sonst als Aufprall).
var _placed_frame := -100
var _exclude: Array[RID] = []
var _eject_prev := false


static func create(d: AircraftData, with_visual: bool = true) -> Aircraft:
	var a := Aircraft.new()
	a.data = d
	a.entity_id = _next_entity_id
	_next_entity_id += 1
	a._build(with_visual)
	return a


func _build(with_visual: bool) -> void:
	name = "Aircraft"
	mass = data.mass
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO
	inertia = data.inertia
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp = 0.0
	can_sleep = false
	continuous_cd = true
	var pm := PhysicsMaterial.new()
	pm.friction = 0.6
	pm.bounce = 0.05
	physics_material_override = pm
	contact_monitor = true
	max_contacts_reported = 4
	collision_layer = Layers.AIRCRAFT
	collision_mask = Layers.MASK_AIRCRAFT

	_add_box(data.fuselage_box_center, data.fuselage_box_size)
	_add_box(data.wing_box_center, data.wing_box_size)

	flight = FlightModel.new(data)
	assist = FlightAssist.new(data)
	damage = DamageModel.new(self, flight.modifiers)
	weapons = WeaponSystem.new(self)
	damage.grounded.connect(_on_grounded)

	pilot_seat = Seat.new()
	pilot_seat.name = "PilotSeat"
	pilot_seat.vehicle = self
	add_child(pilot_seat)

	if with_visual:
		visual = AircraftVisual.new()
		visual.name = "Visual"
		add_child(visual)
		visual.build(data)


func _add_box(center: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = center
	add_child(cs)


func _ready() -> void:
	_exclude = [get_rid()]
	body_entered.connect(_on_body_entered)


func _physics_process(dt: float) -> void:
	var i := pilot_seat.poll(dt)
	_intent.copy_from(i)
	damage.filter_intent(_intent, dt)
	if _intent.eject and not _eject_prev:
		eject_requested.emit(self, damage.can_eject())
	_eject_prev = _intent.eject
	weapons.tick(_intent, dt)
	damage.tick(dt)
	_update_fuel(dt)
	# Server entscheidet, ob der gewünschte Modus erlaubt ist.
	if Authority.is_server() and _intent.assist_mode in allowed_assist_modes:
		assist_mode = _intent.assist_mode
	_intent.assist_mode = assist_mode
	if visual:
		visual.update_controls(flight.telemetry, dt)


## Treibstoffmasse koppeln (verbrauchter/ausgelaufener Treibstoff macht leichter) und
## Füllstand für HUD/KI in der Telemetrie melden.
func _update_fuel(_dt: float) -> void:
	var f := damage.fuel
	var cap := 0.0
	for c in f.capacity:
		cap += c
	var missing := maxf(cap - f.total(), 0.0) * FUEL_DENSITY
	flight.telemetry.fuel_fraction = f.total() / maxf(cap, 1e-3)
	if absf(missing - _fuel_mass_applied) > 1.0:
		_fuel_mass_applied = missing
		mass = maxf(data.mass - missing, data.mass * 0.5)


## Wrack nach Absturz einfrieren (rutscht/rollt nicht weiter); place() hebt das auf.
func _on_grounded(outcome: int) -> void:
	if outcome == DamageModel.Outcome.CRASHED:
		set_deferred("freeze", true)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	var cmd := assist.apply(_intent, flight.telemetry, state.step)
	flight.telemetry.assist_mode = assist_mode
	flight.integrate(state, cmd, _exclude)


## Telemetrie für HUD/KI/Tests.
func telemetry() -> FlightTelemetry:
	return flight.telemetry


## Setzt das Flugzeug an eine Position (Server). speed in m/s entlang der Nase.
func place(xf: Transform3D, speed: float = 0.0, throttle: float = 0.0,
		gear_down: bool = true) -> void:
	freeze = false
	_placed_frame = Engine.get_physics_frames()
	_fuel_mass_applied = 0.0
	mass = data.mass
	global_transform = xf
	linear_velocity = -xf.basis.z * speed
	angular_velocity = Vector3.ZERO
	flight.reset(gear_down)
	damage.reset()
	weapons.reset()
	_eject_prev = false
	if visual:
		visual.snap_gear(flight.gear.extension)
	flight.engine.throttle_actual = throttle
	reset_physics_interpolation()


## Startposition auf der Piste: Heck unten, Fahrwerk auf dem Boden.
func place_on_ground(pos: Vector3, heading_dir: Vector3) -> void:
	var fwd := heading_dir.normalized()
	var b := Basis.looking_at(fwd, Vector3.UP)
	b = b * Basis(Vector3.RIGHT, deg_to_rad(data.ground_pitch_deg))
	place(Transform3D(b, pos + Vector3.UP * data.ground_height), 0.0, 0.0)


func is_hostile_to(other: Node) -> bool:
	var n = other.get("nation_id") if other != null else null
	return n is int and Nations.is_hostile(nation_id, n)


func _on_body_entered(body: Node) -> void:
	if Engine.get_physics_frames() - _placed_frame < 3:
		return
	damage.on_impact(body, linear_velocity)
	var t := flight.telemetry
	if linear_velocity.length() > 25.0 or t.wheels_in_contact == 0 and absf(t.climb_rate) > 6.0:
		crashed.emit(self)
