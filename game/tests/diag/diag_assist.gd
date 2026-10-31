class_name DiagAssist
extends FlightAssist
## Nur Diagnose: wie FlightAssist, merkt sich zusätzlich das Höhenruder-Kommando
## OHNE Stall-Schutz (raw_elevator), um den Eingriff des Schutzes sichtbar zu machen.
## (M1.1: der stetige Begrenzer ist jetzt im Produktionscode; alt_limiter bleibt als
## Schalter erhalten, hat aber keine eigene Logik mehr.)

var raw_elevator := 0.0
var limiter_active := false
var alt_limiter := false


func apply(intent: PilotIntent, t: FlightTelemetry, dt: float) -> ControlCommands:
	var keep := stall_protection
	var pi0 := _pitch_i
	stall_protection = false
	raw_elevator = super.apply(intent, t, dt).elevator
	_pitch_i = pi0
	stall_protection = keep
	var c := super.apply(intent, t, dt)
	limiter_active = intent.assist_mode == Mode.ARCADE and absf(c.elevator - raw_elevator) > 0.01
	return c
