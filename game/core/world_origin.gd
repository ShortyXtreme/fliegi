class_name WorldOrigin
extends RefCounted
## Floating Origin (Paket 13, Agent F). Gameplay/Netz rechnen absolut; nur die
## Client-Darstellung kann verschoben sein. `offset` = absolute Lage des Szenen-Ursprungs,
## gesetzt ausschließlich von OriginShifter (world/origin_shifter.gd); ohne Shifter ZERO.

static var offset := Vector3.ZERO


static func to_abs(local_pos: Vector3) -> Vector3:
	return local_pos + offset


static func to_local(abs_pos: Vector3) -> Vector3:
	return abs_pos - offset
