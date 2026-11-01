class_name Seat
extends Node
## Ein Platz in einem Fahrzeug. Der Sitz kennt nur seinen Controller (Mensch, KI,
## Test) und fragt ihn einmal pro Physik-Tick nach einem Intent.
## Belegen/Freigeben ist eine Zustandsänderung und nur auf dem Server erlaubt.
## M3 (Paket 0a): Rollen CREW (Figur zu Fuß, liefert CrewIntent über poll_crew),
## DRIVER und PASSENGER (Bodenfahrzeuge, PilotIntent: throttle, yaw = Lenkung, brakes).
## Ein- und Aussteigen läuft nur über SeatService (Prüfungen Abstand, Fahrt, Boden).

signal occupant_changed(seat: Seat, controller: Controller)

enum Role { PILOT, GUNNER, BOMBARDIER, CREW, DRIVER, PASSENGER }

## Höchstabstand der Figur zum Einstiegspunkt (m) und Höchstfahrt beim Wechsel (m/s).
const ENTRY_RANGE := 3.0
const MAX_SWITCH_SPEED := 1.0

@export var role: Role = Role.PILOT
var vehicle: Node3D = null
var controller: Controller = null
## Einstiegspunkt im Fahrzeug-Koordinatensystem (Marker svc_entry/seat_driver oder
## Ersatzposition aus AircraftData). Aussteigen setzt die Figur hierhin.
var entry_offset: Vector3 = Vector3.ZERO
## Letzter gültiger Intent. Ohne Controller bleibt ein neutraler Intent (Gas weg, Bremse an).
var intent: PilotIntent = PilotIntent.new()
## M3: Letzter Intent einer Figur (nur Role.CREW).
var crew_intent: CrewIntent = CrewIntent.new()


func _ready() -> void:
	if vehicle == null:
		vehicle = get_parent() as Node3D
	_set_empty_intent()


## Nur Server: Controller in den Sitz setzen. Ein vorheriger wird freigegeben.
func possess(c: Controller) -> bool:
	if not Authority.is_server():
		push_warning("Seat.possess ist nur auf dem Server erlaubt")
		return false
	if controller == c:
		return true
	if controller != null:
		controller.on_release()
	controller = c
	if c != null:
		c.on_possess(self)
	else:
		_set_empty_intent()
	occupant_changed.emit(self, c)
	return true


func release() -> void:
	possess(null)


func is_occupied() -> bool:
	return controller != null


## Besetzt von einem Menschen (nicht KI)?
func is_human_occupied() -> bool:
	return controller != null and not controller.is_ai()


## Einstiegspunkt in Weltkoordinaten.
func entry_position() -> Vector3:
	var v := vehicle if vehicle != null else get_parent() as Node3D
	return v.global_transform * entry_offset if v != null else Vector3.ZERO


## Vom Fahrzeug pro Physik-Tick aufgerufen.
func poll(dt: float) -> PilotIntent:
	if controller != null:
		var i := controller.compute_intent(dt)
		if i != null:
			intent.copy_from(i)
			intent.clamp_values()
	return intent


## M3: von der Figur (CrewCharacter) pro Physik-Tick aufgerufen.
func poll_crew(dt: float) -> CrewIntent:
	if controller != null:
		var i := controller.compute_crew_intent(dt)
		if i != null:
			crew_intent.copy_from(i)
			crew_intent.clamp_values()
	return crew_intent


func _set_empty_intent() -> void:
	intent = PilotIntent.new()
	intent.brakes = 1.0
	crew_intent = CrewIntent.new()
