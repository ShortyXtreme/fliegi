class_name AIPilotBrain
extends Controller
## Kampf-KI (Stub aus Paket 0, Inhalt: Agent C, Paket 7). Liefert nur PilotIntents,
## lenkt über Autopilot.steer_to_direction, nimmt Ziele über Nations.is_hostile() und
## Spotting.spot_range() wahr. Schwierigkeit als Ressource (ai/data/*.tres).
## Bis Paket 7 fliegt sie geradeaus mit Reisegas.

var difficulty: Resource = null
var rng_seed := 0
var _intent := PilotIntent.new()


func compute_intent(_dt: float) -> PilotIntent:
	_intent.throttle = 0.8
	_intent.gear_down = false
	_intent.assist_mode = FlightAssist.Mode.ARCADE
	return _intent
