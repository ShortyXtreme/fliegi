class_name WorldOrigin
extends RefCounted
## Floating Origin (Paket 13, gehört danach Agent F). Gameplay/Netz rechnen absolut;
## nur die Client-Darstellung kann verschoben sein. Stub: keine Verschiebung.

static var offset := Vector3.ZERO


static func to_abs(local_pos: Vector3) -> Vector3:
	return local_pos + offset


static func to_local(abs_pos: Vector3) -> Vector3:
	return abs_pos - offset
