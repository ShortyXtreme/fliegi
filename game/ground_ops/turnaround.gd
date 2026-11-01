class_name Turnaround
extends RefCounted
## M3 Stub (Paket 0b, gehört Strang G / Paket 3): Abfertigungszeit einer Maschine,
## Alarmstart-Countdown und Bestzeit (user://). Meldet GroundEvents.turnaround.

const BEST_PATH := "user://abfertigung_bestzeit.cfg"

var aircraft: Node = null
var elapsed := 0.0
var running := false
var helpers := 0
## Alarm: Restzeit (s), < 0 = kein Alarm.
var alarm_left := -1.0


func start(a: Node) -> void:
	aircraft = a
	elapsed = 0.0
	running = true


func tick(dt: float) -> void:
	if running:
		elapsed += dt
	if alarm_left > 0.0:
		alarm_left = maxf(alarm_left - dt, 0.0)


func finish() -> float:
	running = false
	GroundEvents.bus().turnaround.emit(aircraft, elapsed, helpers)
	return elapsed
