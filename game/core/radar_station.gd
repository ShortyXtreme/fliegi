class_name RadarStation
extends RefCounted
## M2-Stub eines Bodenradars (Entscheidung 2): Position, Reichweite, Nation, Zustand.
## Echte Gebäude folgen später; sie melden sich über Spotting.register_radar() an.

var position := Vector3.ZERO
var radius := 8000.0
var nation_id := Nations.BLUE
var operational := true


func _init(pos := Vector3.ZERO, r := 8000.0, nation := Nations.BLUE) -> void:
	position = pos
	radius = r
	nation_id = nation


func covers(p: Vector3) -> bool:
	return operational and position.distance_to(p) <= radius
