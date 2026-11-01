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
var weapon_panel: WeaponPanel
var overlay: TargetOverlay
var compass: CompassBand
var radar: RadarLight
var kill_feed: KillFeed
var ui_scale := 1.0
## Letzte Kontaktliste (für Tests/Sichtprüfung).
var contacts: Array = []

var _bus: CombatEvents
var _own: Aircraft


static func create(h: Hud) -> CombatHud:
	var c := CombatHud.new()
	c.name = "CombatHud"
	c.hud = h
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


func _ready() -> void:
	overlay = TargetOverlay.new()
	add_child(overlay)
	flight_panel = FlightPanel.new()
	add_child(flight_panel)
	weapon_panel = WeaponPanel.new()
	add_child(weapon_panel)
	compass = CompassBand.new()
	add_child(compass)
	radar = RadarLight.new()
	add_child(radar)
	kill_feed = KillFeed.new()
	add_child(kill_feed)


func aircraft() -> Aircraft:
	if hud == null or hud.aircraft == null or not is_instance_valid(hud.aircraft):
		return null
	return hud.aircraft


func _process(dt: float) -> void:
	_connect_signals()
	var a := aircraft()
	visible = a != null
	if a == null:
		return
	_layout()
	if replace_legacy_text:
		_hide_legacy()
	flight_panel.set_data(FlightPanel.gather(a, hud.player, hud.camera_rig, hud.debug_visible))
	weapon_panel.set_data(WeaponPanel.gather(a), dt)
	contacts = HudContacts.collect(a)
	var xf := a.get_global_transform_interpolated()
	# Kompass + Peilungen erkannter Feinde
	compass.heading = HudContacts.heading_of(-xf.basis.z)
	var bearings := PackedFloat32Array()
	for c in contacts:
		if c.hostile and c.spotted:
			bearings.append(HudContacts.heading_of((c.pos as Vector3) - xf.origin))
	compass.enemy_bearings = bearings
	compass.queue_redraw()
	# Radar-Light (Arcade)
	radar.visible = HudContacts.radar_allowed(a)
	if radar.visible:
		radar.blips = RadarLight.project(xf, contacts, HudContacts.RADAR_RANGE)
		radar.queue_redraw()
	# Mitte: Marker, Vorhalt, Treffer, Notausstieg
	overlay.s = ui_scale
	overlay.cam = get_viewport().get_camera_3d()
	overlay.own = a
	overlay.contacts = contacts
	overlay.lead_target = HudContacts.lead_target(a, contacts) if HudContacts.lead_allowed(a) else {}
	overlay.lead = HudContacts.lead_point(a, overlay.lead_target) if not overlay.lead_target.is_empty() else {}
	overlay.eject_progress = hud.player.eject_hold_progress if hud.player else 0.0
	overlay.eject_possible = a.damage != null and a.damage.can_eject()
	# Taste gedrückt, Ausstieg aber gesperrt: Hinweis kurz (2 s) statt Fortschrittsbalken
	if overlay.eject_progress > 0.0 and not overlay.eject_possible:
		overlay.on_eject_denied()
	overlay.tick(dt)
	kill_feed.tick(dt)


## Verbindet Bus- und Flugzeug-Signale neu, wenn sich Bus (reset) oder Flugzeug (Neustart) ändern.
func _connect_signals() -> void:
	var b := CombatEvents.bus()
	if b != _bus:
		_bus = b
		b.hit_confirmed.connect(_on_hit_confirmed)
		b.aircraft_destroyed.connect(_on_destroyed)
		b.pilot_ejected.connect(_on_ejected)
	var a := aircraft()
	if a != _own:
		if _own != null and is_instance_valid(_own) and _own.eject_requested.is_connected(_on_eject_requested):
			_own.eject_requested.disconnect(_on_eject_requested)
		_own = a
		if a != null:
			a.eject_requested.connect(_on_eject_requested)


func _on_hit_confirmed(shooter: Node, _target: Node, _zone: int, _damage: float) -> void:
	if shooter != null and shooter == aircraft():
		overlay.on_hit()


func _on_destroyed(victim: Node, killer: Node, cause: int) -> void:
	var a := aircraft()
	if killer != null and killer == a and victim != a:
		overlay.on_kill()
	kill_feed.add_kill(victim, killer, cause, a)


func _on_ejected(ac: Node, _pilot: RefCounted) -> void:
	kill_feed.add_text(ac, "ausgestiegen", aircraft())


func _on_eject_requested(_a: Aircraft, allowed: bool) -> void:
	if not allowed:
		overlay.on_eject_denied()


func _layout() -> void:
	var vs := get_viewport_rect().size
	ui_scale = HudStyle.ui_scale(vs)
	var s := ui_scale
	flight_panel.scale = Vector2(s, s)
	flight_panel.position = Vector2(MARGIN * s, vs.y - (MARGIN + flight_panel.panel_height()) * s)
	weapon_panel.scale = Vector2(s, s)
	weapon_panel.position = Vector2(vs.x - (MARGIN + WeaponPanel.W) * s, vs.y - (MARGIN + WeaponPanel.H) * s)
	compass.scale = Vector2(s, s)
	compass.position = Vector2(vs.x * 0.5 - CompassBand.W * 0.5 * s, 14.0 * s)
	radar.scale = Vector2(s, s)
	radar.position = Vector2(MARGIN * s, MARGIN * s)
	kill_feed.scale = Vector2(s, s)
	kill_feed.position = Vector2(vs.x - (MARGIN + KillFeed.W) * s, MARGIN * s)


func _hide_legacy() -> void:
	for n in ["_info", "_warn", "_warn2"]:
		var l = hud.get(n)
		if l is CanvasItem:
			(l as CanvasItem).visible = false
