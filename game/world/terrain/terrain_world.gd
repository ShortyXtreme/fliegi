class_name TerrainWorld
extends Node3D
## Höhenkarten-Gelände 40 × 40 km (Stub aus Paket 0, Inhalt: Agent F, Paket 12).
## Schnittstelle wie TestWorld: runway_spawn(index), RUNWAY_DIR, dazu height_at(x, z).
## Meldet sich bei WorldGround als Höhen-Provider an (Geschosse, KI-Bodenschutz).
## Physik-Kacheln auf Layers.WORLD.

const RUNWAY_DIR := Vector3(0, 0, -1)


func _enter_tree() -> void:
	WorldGround.set_provider(self)


func _exit_tree() -> void:
	WorldGround.clear_provider(self)


func height_at(_x: float, _z: float) -> float:
	return 0.0


func runway_spawn(index: int = 0) -> Vector3:
	return Vector3(index * 12.0, 0, -10.0 - index * 40.0)
