class_name Controller
extends Node
## Basisklasse für alles, was einen Sitz steuern kann (Spieler, KI, Test-Skript).
## Der Sitz ruft compute_intent() (Flugzeug/Fahrzeug) bzw. compute_crew_intent()
## (Figur, Seat.Role.CREW) einmal pro Physik-Tick auf.
##
## M3 (Paket 0a):
##  - peer_id: Wem gehört der Controller? 0 = Server/KI, sonst Netz-Peer des Menschen
##    (offline 1). SeatService prüft damit Sitzwechsel-Rechte; die KI macht Platz.
##  - session: PlayerSession (oder anderer Besitzer mit controller_for(role)), damit
##    SeatService beim Sitzwechsel den passenden Controller des Insassen einsetzt.

var seat: Seat = null
var peer_id: int = 0
var session: Object = null


## Wird vom Sitz aufgerufen, wenn dieser Controller ihn übernimmt.
func on_possess(new_seat: Seat) -> void:
	seat = new_seat


func on_release() -> void:
	seat = null


## Muss überschrieben werden. dt = Physik-Schrittweite.
func compute_intent(_dt: float) -> PilotIntent:
	return PilotIntent.new()


## M3: Figur zu Fuß. Standard: stehen bleiben, nichts tun.
func compute_crew_intent(_dt: float) -> CrewIntent:
	return CrewIntent.new()


## Gehört der Controller der KI bzw. dem Server (macht bei Sitzwechsel Platz)?
func is_ai() -> bool:
	return peer_id == 0


## Bequemer Zugriff auf das Fahrzeug, in dem der Sitz steckt.
func get_vehicle() -> Node3D:
	return seat.vehicle if seat else null
