class_name Controller
extends Node
## Basisklasse für alles, was einen Sitz steuern kann (Spieler, KI, Test-Skript).
## Der Sitz ruft compute_intent() einmal pro Physik-Tick auf.

var seat: Seat = null


## Wird vom Sitz aufgerufen, wenn dieser Controller ihn übernimmt.
func on_possess(new_seat: Seat) -> void:
	seat = new_seat


func on_release() -> void:
	seat = null


## Muss überschrieben werden. dt = Physik-Schrittweite.
func compute_intent(_dt: float) -> PilotIntent:
	return PilotIntent.new()


## Bequemer Zugriff auf das Fahrzeug, in dem der Sitz steckt.
func get_vehicle() -> Node3D:
	return seat.vehicle if seat else null
