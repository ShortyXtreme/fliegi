class_name ScriptedController
extends Controller
## Test-Controller: liefert einen festen bzw. per Callable berechneten Intent.
## Beweist nebenbei, dass Tests nur über den Intent-Weg steuern.

var intent := PilotIntent.new()
## Optional: func(aircraft: Aircraft, intent: PilotIntent, dt: float) -> void
var logic: Callable


func compute_intent(dt: float) -> PilotIntent:
	if logic.is_valid():
		logic.call(get_vehicle(), intent, dt)
	return intent
