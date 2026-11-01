class_name GroundHud
extends Control
## M3 Stub (Paket 0b, gehört HUD / Paket 13): Boden-HUD (Interaktionshinweis, Fortschrittsring,
## Befehlsrad, Statuspanel, Lagerleiste, Abfertigungszeit, Bodenmarken). create(hud) wie
## CombatHud; PlayerSession blendet es je Kontext ein (ground_hud).

var hud: Node = null


static func create(h: Node) -> GroundHud:
	var g := GroundHud.new()
	g.name = "GroundHud"
	g.hud = h
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.visible = false
	return g
