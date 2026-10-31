class_name PilotRecord
extends RefCounted
## Pilot eines Spielers/KI innerhalb der Partie (GDD §6.1). Nur Datenstruktur
## (Stub aus Paket 0, Inhalt: Agent B, Paket 6). XP werden erst bei Landung am
## eigenen Platz gutgeschrieben (xp_pending -> xp_banked).

static var _next_id := 1

var id: int
var level := 1
var xp_banked := 0
var xp_pending: Array = []
var alive := true


func _init() -> void:
	id = _next_id
	_next_id += 1


## Level-Hooks (Stub: neutral). Spotting nutzt zusätzlich Spotting.crew_level_mul(level).
func dispersion_mul() -> float:
	return 1.0


func spot_range_mul() -> float:
	return Spotting.crew_level_mul(level)
