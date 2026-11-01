class_name CombatHud
extends Control
## Kampf-HUD und neues Gesamt-Layout (Agent D, Paket 9).
## Hud fügt ihn genau einmal hinzu: add_child(CombatHud.create(self)).
## Liest hud.aircraft / hud.player / hud.camera_rig jeden Frame (Referenzen können
## beim Neustart wechseln), dazu aircraft.weapons, aircraft.damage, CombatEvents, Spotting.
##
## Layout (1080p-Einheiten, skaliert mit HudStyle.ui_scale):
##   oben Mitte: Kompassband · oben links: Radar-Light (Arcade) · oben rechts: Kill-Feed
##   links unten: FlightPanel (Fluganzeigen + Warnungen) · rechts unten: Waffen/Schaden
##   Mitte: Feindmarker, Randpfeile, Vorhaltepunkt, Trefferanzeige, Notausstieg-Hinweis

const MARGIN := 24.0

## true: blendet das alte Text-HUD aus hud.gd aus (_info, _warn, _warn2). Standard aus,
## bis Paket 14 umstellt (Hook, siehe docs/m2_hooks_DE.md).
static var replace_legacy_text := false

var hud: Hud
var flight_panel: FlightPanel
var ui_scale := 1.0


static func create(h: Hud) -> CombatHud:
	var c := CombatHud.new()
	c.name = "CombatHud"
	c.hud = h
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	flight_panel = FlightPanel.new()
	add_child(flight_panel)


func aircraft() -> Aircraft:
	if hud == null or hud.aircraft == null or not is_instance_valid(hud.aircraft):
		return null
	return hud.aircraft


func _process(_dt: float) -> void:
	var a := aircraft()
	visible = a != null
	if a == null:
		return
	_layout()
	if replace_legacy_text:
		_hide_legacy()
	flight_panel.set_data(FlightPanel.gather(a, hud.player, hud.camera_rig, hud.debug_visible))


func _layout() -> void:
	var vs := get_viewport_rect().size
	ui_scale = HudStyle.ui_scale(vs)
	var s := ui_scale
	flight_panel.scale = Vector2(s, s)
	flight_panel.position = Vector2(MARGIN * s, vs.y - (MARGIN + flight_panel.panel_height()) * s)


func _hide_legacy() -> void:
	for n in ["_info", "_warn", "_warn2"]:
		var l = hud.get(n)
		if l is CanvasItem:
			(l as CanvasItem).visible = false
