class_name WeaponFx
extends Node3D
## Wurzel aller Waffen-Effekte (Stub aus Paket 0, Inhalt: Agent E, Paket 10):
## Leuchtspuren (MultiMesh), Mündungsfeuer-Pool, Einschläge. Hört nur auf
## CombatEvents und liest ProjectileSystem.current; ändert nie Spielzustand.
## Headless (Server/Tests) bleibt alles aus.

var enabled := true


func _ready() -> void:
	enabled = DisplayServer.get_name() != "headless"
	set_process(enabled)
