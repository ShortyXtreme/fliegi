class_name AirfieldPhases
extends RefCounted
## M3 Stub (Paket 0b, gehört Strang C / Pakete 9a–9b): Flugplatz-Phasen der KI, aufgerufen
## von AIPilotBrain. Feste Signaturen: phase, tick(aircraft, intent, dt) -> bool
## (true = Phase hat den Intent gesetzt, false = Kampf-Logik wie M2), set_phase(p).
## Stub: immer COMBAT -> M2-Verhalten.

enum Phase { PARKED, TAXI_OUT, HOLD, TAKEOFF, COMBAT, RTB, PATTERN, LANDING, TAXI_IN }
const MIN_FUEL := 0.6
const MIN_AMMO := 0.8
const TAXI_SPEED := 20.0 / 3.6
const ROTATE_SPEED := 135.0 / 3.6
const APPROACH_SPEED := 160.0 / 3.6

var phase: Phase = Phase.COMBAT
var layout: AirfieldLayout = null
var runway: RunwayControl = null


func set_phase(p: Phase) -> void:
	phase = p


func tick(_aircraft: Node, _intent: PilotIntent, _dt: float) -> bool:
	return false
