class_name CombatHud
extends Control
## Container für das Kampf-HUD (Stub aus Paket 0, Inhalt: Agent D, Paket 9).
## Hud fügt ihn genau einmal hinzu: add_child(CombatHud.create(self)).
## Liest hud.aircraft / hud.player / hud.camera_rig jeden Frame (Referenzen können
## beim Neustart wechseln), dazu aircraft.weapons, aircraft.damage, CombatEvents, Spotting.
## Unterelemente (Vorhalt, Kill-Feed, Radar …) legt Agent D als eigene Dateien in ui/combat/ an.

var hud: Hud


static func create(h: Hud) -> CombatHud:
	var c := CombatHud.new()
	c.name = "CombatHud"
	c.hud = h
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c
