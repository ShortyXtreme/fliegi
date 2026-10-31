class_name ProjectileSystem
extends Node
## Alle Geschosse der Welt als Struct-of-Arrays (Stub aus Paket 0, Inhalt: Agent A, Paket 2).
## Genau eine Instanz pro Welt; sie meldet sich als ProjectileSystem.current an.
## In der Hauptszene legt game.gd sie an; Tests legen sie selbst an.

static var current: ProjectileSystem = null


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	if current == self:
		current = null


## Geschoss erzeugen (nur Server). Rückgabe: Slot-Index oder -1.
func spawn(_shooter: Node3D, _gun_index: int, _shot_id: int, _pos: Vector3,
		_vel: Vector3, _weapon: Resource) -> int:
	return -1


func active_count() -> int:
	return 0


func clear() -> void:
	pass
