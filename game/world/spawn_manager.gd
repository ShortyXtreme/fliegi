class_name SpawnManager
extends Node
## Neustart nach Verlust/Ausstieg (Stub aus Paket 0, Inhalt: Agent B, Paket 6). Nur Server.
## game.gd registriert jedes Flugzeug einmal mit einer Respawn-Funktion:
##   spawn_manager.register(aircraft, controller, respawn_callable)
## Paket 6 hört auf CombatEvents.aircraft_destroyed / pilot_ejected, wartet
## MatchRules.respawn_delay und ruft dann respawn_callable.call() auf.

signal respawned(aircraft: Node3D)

## aircraft -> {"controller": Controller, "respawn": Callable}
var entries := {}


func register(aircraft: Node3D, controller: Controller, respawn: Callable) -> void:
	entries[aircraft] = {"controller": controller, "respawn": respawn}


func unregister(aircraft: Node3D) -> void:
	entries.erase(aircraft)


## Sofortiger Neustart (Debugtasten R/T gehen weiter direkt über game.gd).
func respawn_now(aircraft: Node3D) -> void:
	if not Authority.is_server() or not entries.has(aircraft):
		return
	var cb: Callable = entries[aircraft]["respawn"]
	if cb.is_valid():
		cb.call()
	respawned.emit(aircraft)
