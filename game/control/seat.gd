class_name Seat
extends Node
## Ein Platz in einem Fahrzeug. Der Sitz kennt nur seinen Controller (Mensch, KI,
## Test) und fragt ihn einmal pro Physik-Tick nach einem PilotIntent.
## Belegen/Freigeben ist eine Zustandsänderung und nur auf dem Server erlaubt.

signal occupant_changed(seat: Seat, controller: Controller)

enum Role { PILOT, GUNNER, BOMBARDIER }

@export var role: Role = Role.PILOT
var vehicle: Node3D = null
var controller: Controller = null
## Letzter gültiger Intent. Ohne Controller bleibt ein neutraler Intent (Gas weg, Bremse an).
var intent: PilotIntent = PilotIntent.new()


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


## Vom Fahrzeug pro Physik-Tick aufgerufen.
func poll(dt: float) -> PilotIntent:
	if controller != null:
		var i := controller.compute_intent(dt)
		if i != null:
			intent.copy_from(i)
			intent.clamp_values()
	return intent


func _set_empty_intent() -> void:
	intent = PilotIntent.new()
	intent.brakes = 1.0
