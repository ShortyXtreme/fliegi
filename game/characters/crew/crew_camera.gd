class_name CrewCamera
extends Node3D
## M3 Stub (Paket 0b, gehört Strang H / Paket 4): Kamera der Figur bzw. des Fahrzeugs.
## Third-Person über die Schulter (Standard, PO-Entscheidung 1), Ego auf C (crew_view_toggle).
## PlayerSession ruft follow(target) und schaltet über process_mode/current um.

enum Mode { THIRD, EGO }

var mode: Mode = Mode.THIRD
var target: Node3D = null
var camera: Camera3D


func _init() -> void:
	camera = Camera3D.new()
	camera.name = "Camera3D"
	add_child(camera)


func follow(t: Node3D) -> void:
	target = t


func toggle_view() -> void:
	mode = Mode.EGO if mode == Mode.THIRD else Mode.THIRD
