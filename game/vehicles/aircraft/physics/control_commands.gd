class_name ControlCommands
extends RefCounted
## Ausgang der Steuerhilfen-Schicht, Eingang des Flugmodells: Ruderstellungen.
## elevator +1 = Nase hoch, aileron +1 = rechts rollen, rudder +1 = Nase rechts.

var elevator: float = 0.0
var aileron: float = 0.0
var rudder: float = 0.0
var flaps: float = 0.0
var throttle: float = 0.0
var brakes: float = 0.0
## Fahrwerk ausgefahren gewünscht.
var gear_down: bool = true
## Arcade-Hilfe: Bremsen automatisch lösen, wenn das Heck abhebt (Überschlagschutz).
var anti_nose_over: bool = false


func axis_value(axis: int) -> float:
	match axis:
		AeroSurfaceDef.ControlAxis.PITCH: return elevator
		AeroSurfaceDef.ControlAxis.ROLL: return aileron
		AeroSurfaceDef.ControlAxis.YAW: return rudder
		AeroSurfaceDef.ControlAxis.FLAPS: return flaps
	return 0.0
