class_name GroundHud
extends Control
## Boden-HUD (Paket 13): Interaktionshinweis + Fortschrittsring, Befehlsrad, Statuspanel Flugzeug,
## Lagerleiste, Abfertigungszeit/Alarm, Bodenmarke zum Abstellplatz, F1-Hilfe je Kontext.
## create(hud) wie CombatHud. Datenquellen setzt Paket 14 (siehe docs/m3_hooks_HUD.md); fehlt eine,
## bleibt das zugehörige Element einfach aus.
##
## Wichtig: Das Boden-HUD verwaltet seine Sichtbarkeit selbst je Kontext (auch im Flug: Bodenmarke,
## Statuspanel nach der Landung, Alarm). PlayerSession.ground_hud darum NICHT setzen, sondern
## ground_hud.session = session (oder set_context()).

## Befehl aus dem Befehlsrad (immer gesendet, auch ohne Empfänger).
signal command_issued(cmd: int, target: Node)

const MARGIN := 24.0
const STATUS_FLIGHT_MAX_SPEED := 3.0   # m/s: Statuspanel im Cockpit nur fast im Stand
const BEST_REFRESH := 1.0
## M3.2: Lagerleiste nur nahe Lager (m) oder nahe einer Maschine (m).
const STOCK_NEAR_STORE := 60.0
const STOCK_NEAR_AIRCRAFT := 15.0
## Einsteigen-Hinweis in der Tasten-Leiste bis zu diesem Abstand (m).
const ENTER_NEAR := 8.0

var hud: Node = null
## PlayerSession (optional): liefert context und seat.
var session: Node = null
var context: int = InputBindings.Context.FLIGHT
## Spielerfigur (CrewCharacter).
var character: Node3D = null
var board: JobBoard = null
var depot: FuelSource = null
var bunker: AmmoStore = null
var turnaround: Turnaround = null
## GroundCrewDispatch des eigenen Platzes (Befehlsempfänger, Maschinenliste).
var dispatch: Node = null
## Eigene Maschinen für Statuspanel/Befehlsrad (sonst dispatch.aircraft + hud.aircraft).
var aircraft_list: Array = []
## Zugewiesener Abstellplatz nach der Landung.
var parking_target := Vector3.ZERO
var has_parking_target := false
## Optionaler Empfänger func(cmd: int, target: Node) – sonst dispatch.command bzw. crews[i].command.
var command_receiver := Callable()
## Kampf-HUD/Alt-Text im Boden-Kontext ausblenden (Ersatz, bis Paket 14 das in hud.gd regelt).
var manage_flight_hud := true
var pad := false
var ui_scale := 1.0

var hint: InteractionHint
## M3.5: Funkgerät (ersetzt das Befehlsrad), Kanal Bodenpersonal.
var radio: RadioPanel
var channels: Array = []
var status: AircraftStatusPanel
var stock_bar: StockBar
var timer: TurnaroundDisplay
var guide: ParkingGuide
var help: GroundHelp
## M3.2: Tasten-Leiste unten Mitte (alle Kontexte, auch Flug).
var key_bar: KeyBar
## M3.2: Tutorial setzt hier die Tasten des Schritts (leer = automatisch je Lage).
var key_override: Array = []
## Maschine im Statuspanel (für Tests).
var status_aircraft: Node = null
## M3.5: Empfänger des letzten Befehls (null = alle) und Mannschafts-Panel.
var last_crew: Node = null
var crew_panel: CrewPanel
## M3.5: Rolle des Spielers (Pilot; später &"supply"/&"workshop" sehen Lagerbestände).
var player_role: StringName = &"pilot"

var _bus: GroundEvents
var _alarm_fallback := -1.0
var _ta_running := false
var _result_t := 0.0
var _best := -1.0
var _best_t := 0.0
var _hidden_flight: Array = []


static func create(h: Node) -> GroundHud:
	var g := GroundHud.new()
	g.name = "GroundHud"
	g.hud = h
	g.set_anchors_preset(Control.PRESET_FULL_RECT)
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.visible = false
	return g


func _ready() -> void:
	guide = ParkingGuide.new()
	add_child(guide)
	status = AircraftStatusPanel.new()
	add_child(status)
	stock_bar = StockBar.new()
	add_child(stock_bar)
	timer = TurnaroundDisplay.new()
	add_child(timer)
	add_child(timer.alarm_banner)
	hint = InteractionHint.new()
	add_child(hint)
	crew_panel = CrewPanel.new()
	add_child(crew_panel)
	channels = RadioChannel.default_channels()
	for ch in channels:
		ch.receiver = func(cmd: int, t: Node, cid: StringName) -> int:
			if cmd == GroundCrewBrain.Command.STATUS:
				return radio_status(cid, t)
			return issue_command(cmd, t)
	radio = RadioPanel.new()
	radio.channels = channels
	for ch in channels:
		ch.answered.connect(func(_t): radio.beep())
	radio.command_chosen.connect(func(ch: RadioChannel, c: RadioCommand): ch.send(c, radio_target()))
	add_child(radio)
	help = GroundHelp.new()
	add_child(help)
	key_bar = KeyBar.new()
	add_child(key_bar)
	theme = HudStyle.theme()
	visible = true
	_connect_bus()


func set_context(ctx: int) -> void:
	context = ctx


func current_context() -> int:
	if session != null and is_instance_valid(session) and session.get("context") != null:
		return int(session.get("context"))
	return context


func on_ground_context() -> bool:
	return current_context() != InputBindings.Context.FLIGHT


func own_aircraft() -> Node3D:
	if hud != null and is_instance_valid(hud):
		var a = hud.get("aircraft")
		if a != null and is_instance_valid(a):
			return a
	return null


## Maschinen für Statuspanel und Befehlsrad.
func known_aircraft() -> Array:
	var out: Array = []
	for a in aircraft_list:
		if a != null and is_instance_valid(a) and not out.has(a):
			out.append(a)
	if dispatch != null and is_instance_valid(dispatch):
		for a in (dispatch.get("aircraft") if dispatch.get("aircraft") != null else []):
			if a != null and is_instance_valid(a) and not out.has(a):
				out.append(a)
	var own := own_aircraft()
	if own != null and not out.has(own):
		out.append(own)
	return out


## Position, von der aus Abstand und Richtung gemessen werden (Figur bzw. gefahrenes Fahrzeug).
func viewer_position() -> Vector3:
	if current_context() == InputBindings.Context.DRIVE and session != null and is_instance_valid(session):
		var st = session.get("seat")
		if st != null and st.vehicle is Node3D:
			return (st.vehicle as Node3D).global_position
	if character != null and is_instance_valid(character):
		return character.global_position
	var own := own_aircraft()
	return own.global_position if own != null else Vector3.ZERO


# --- Befehle ---------------------------------------------------------------------------

## Gibt den Befehl weiter: Signal command_issued, dann command_receiver, sonst dispatch.command(cmd, target),
## sonst jedes crews[i].command(cmd, target) (GroundCrewBrain). Rückgabe: Anzahl Empfänger.
## M3.5: crew = einzelner Mechaniker oder null = Zuteilung durch die Dispatch (freier Mechaniker).
func issue_command(cmd: int, target: Node, crew: Node = null) -> int:
	last_crew = crew
	command_issued.emit(cmd, target)
	if command_receiver.is_valid():
		command_receiver.call(cmd, target)
		return 1
	if dispatch == null or not is_instance_valid(dispatch):
		return 0
	if dispatch.has_method("command"):
		return int(dispatch.call("command", cmd, target, crew))
	var n := 0
	for c in (dispatch.get("crews") if dispatch.get("crews") != null else []):
		var brain = c
		if c is Object and not c.has_method("command") and c.get("brain") != null:
			brain = c.get("brain")
		if brain is Object and brain.has_method("command"):
			brain.call("command", cmd, target)
			n += 1
	return n


## M3.5: KI-Mechaniker des eigenen Platzes (dispatch.crews).
func crew_list() -> Array:
	if dispatch == null or not is_instance_valid(dispatch):
		return []
	var c = dispatch.get("crews")
	return (c as Array).filter(func(b): return b is GroundCrewBrain and is_instance_valid(b)) if c is Array else []


# --- Eingabe ---------------------------------------------------------------------------

## Funkmeldung der Mannschaft als Antwortzeile im passenden Kanal („Tankwart: …“).
func _on_crew_report(text: String, _brain: Node, ch_id: StringName = &"crew") -> void:
	var ch := channel_by_id(ch_id)
	if ch == null:
		ch = channel_by_id(&"crew")
	if ch != null:
		ch.answer("%s: %s" % [ch.speaker, text])


func channel_by_id(id: StringName) -> RadioChannel:
	for c in channels:
		if c.id == id:
			return c
	return null


## Zielmaschine des Funkspruchs: die nächste eigene Maschine (sonst die eigene).
func radio_target() -> Node:
	var na := GroundHudData.nearest_aircraft(viewer_position(), known_aircraft(), 200.0)
	if na == null:
		na = own_aircraft()
	if na == null and not known_aircraft().is_empty():
		na = known_aircraft()[0]
	return na


func toggle_radio() -> void:
	if on_ground_context():
		radio.toggle()


## Eingabe-Kontext des offenen Funkgeräts (-1 = zu).
func radio_context() -> int:
	if radio == null or not radio.is_open:
		return -1
	return InputBindings.Context.RADIO if radio.stage == RadioPanel.Stage.CHANNELS else InputBindings.Context.RADIO_CMD


## Funkgerät bedienen (Belegung aus InputMap, frei einstellbar). Rückgabe: Ereignis verbraucht.
func radio_input(event: InputEvent) -> bool:
	if not on_ground_context() or event.is_echo() or not event.is_pressed():
		return false
	var rc := radio_context()
	if rc < 0:
		if event.is_action_pressed(&"crew_wheel"):
			toggle_radio()
			return true
		return false
	if event.is_action_pressed(&"release_mouse"):
		radio.close()
		return true
	if rc == InputBindings.Context.RADIO:
		for k in InputBindings.RADIO_CHANNEL_ACTIONS.size():
			if event.is_action_pressed(InputBindings.RADIO_CHANNEL_ACTIONS[k]):
				radio.choose(k + 1)
				return true
	else:
		for k in InputBindings.RADIO_CMD_ACTIONS.size():
			if event.is_action_pressed(InputBindings.RADIO_CMD_ACTIONS[k]):
				radio.choose(k + 1)
				return true
	var acts := {&"radio_back": radio.back, &"radio_prev": radio.cycle_channel.bind(-1),
		&"radio_next": radio.cycle_channel.bind(1), &"radio_up": radio.move.bind(-1),
		&"radio_down": radio.move.bind(1), &"radio_select": radio.confirm}
	for a in acts:
		if InputMap.has_action(a) and event.is_action_pressed(a):
			acts[a].call()
			return true
	if event.is_action_pressed(&"crew_wheel"):
		radio.close()
		return true
	return false


func _input(event: InputEvent) -> void:
	KeyGlyphs.note_input(event)
	pad = KeyGlyphs.pad
	if radio_input(event):
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if on_ground_context() and InputMap.has_action(&"help_toggle") and event.is_action_pressed(&"help_toggle"):
		toggle_help()


func toggle_help() -> void:
	help.visible = not help.visible


## „Status?“: grobe Antwort der KI im Kanal (keine Prozente, M3.5 Realismus).
func radio_status(cid: StringName, t: Node) -> int:
	var ch := channel_by_id(cid)
	if ch == null:
		return 0
	var txt := "Keine Verbindung."
	if dispatch != null and is_instance_valid(dispatch) and dispatch.has_method("status_text"):
		txt = dispatch.status_text(cid, t)
	ch.answer("%s: %s" % [ch.speaker, txt])
	return 1


## Aktivität je Kanal: Statuszeile des Personals, das dort arbeitet („Tankwart: tankt – 73 %“).
func radio_activity() -> Dictionary:
	var out := {}
	for b in crew_list():
		var cid: StringName = b.active_channel()
		if cid == &"" or out.has(cid):
			continue
		var ch := channel_by_id(cid)
		var st: Dictionary = b.status()
		out[cid] = "%s: %s" % [ch.speaker if ch != null else b.crew_name(), st.text]
		if not out.has(&"crew"):
			out[&"crew"] = "%s: %s" % [b.crew_name(), st.text]
	return out


## Pad-Tasten A/B gehören bei offenem Funkgerät dem Funk (CrewPlayerController fragt das ab).
func radio_captures_pad() -> bool:
	return radio != null and radio.is_open and on_ground_context()


# --- Bild -------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_connect_bus()
	# M3.5: Funkmeldungen der Mannschaft als Antwortzeilen im Funkgerät
	if dispatch != null and is_instance_valid(dispatch) and dispatch.has_signal("crew_report") \
			and not dispatch.is_connected("crew_report", _on_crew_report):
		dispatch.connect("crew_report", _on_crew_report)
	var ground := on_ground_context()
	var b := board if board != null else JobBoard.current
	if b != null and not is_instance_valid(b):
		b = null
	if manage_flight_hud:
		_apply_flight_hud(not ground)
	_layout()
	# Interaktion (nur zu Fuß)
	var crew := current_context() == InputBindings.Context.CREW
	if radio.is_open and not ground:
		radio.close()
	radio.pad = pad
	RadioPanel.pad_capture = radio_captures_pad()
	var rt := radio_target() if radio.is_open else null
	radio.target_name = GroundHudData.aircraft_name(rt) if rt != null else ""
	radio.activity = radio_activity()
	hint.set_data(GroundHudData.interaction(character, b, pad) if crew else {"visible": false})
	# Statuspanel
	status_aircraft = null
	if ground:
		status_aircraft = GroundHudData.nearest_aircraft(viewer_position(), known_aircraft())
	else:
		var own := own_aircraft()
		if own != null and _on_ground(own) and _speed(own) < STATUS_FLIGHT_MAX_SPEED:
			status_aircraft = own
	status.visible = status_aircraft != null
	var ch = hud.get("combat") if hud != null and is_instance_valid(hud) else null
	if ch is CombatHud:
		(ch as CombatHud).suppress_weapon_panel = status.visible and not ground
		if ground and (ch as CombatHud).kill_feed != null:
			(ch as CombatHud).kill_feed.tick(dt)   # Meldungen laufen auch am Boden ab (M3.2)
	status.instruments = not ground
	if status.visible:
		status.set_data(GroundHudData.aircraft_status(status_aircraft, b, character), dt)
	# Lager: nur nahe Lager oder Maschine (M3.2)
	# M3.5: Lagerbestände nicht im normalen HUD – nur für die zuständige Rolle (StockView) oder im
	# Debug-Overlay (F3).
	var dbg: bool = hud != null and is_instance_valid(hud) and hud.get("hit_debug_visible") == true
	stock_bar.visible = (depot != null or bunker != null) and (dbg or StockView.visible_for(player_role))
	if stock_bar.visible:
		stock_bar.set_data(GroundHudData.stock(depot, bunker))
	# Abfertigung + Alarm
	_update_turnaround(dt)
	timer.visible = timer.timer_visible() and ground
	# M3.5: Mannschaft (Mechaniker A: tankt – 60 %) und letzte Funkmeldung
	var cl := crew_list()
	crew_panel.visible = ground and not cl.is_empty()
	if crew_panel.visible:
		crew_panel.set_data(CrewPanel.gather(cl, dispatch), dt)
	# Bodenmarke nach der Landung (im Cockpit)
	var own := own_aircraft()
	guide.active = has_parking_target and not ground and own != null and _on_ground(own)
	if guide.active:
		guide.cam = get_viewport().get_camera_3d()
		guide.from = own.global_position
		guide.target = parking_target
		guide.s = ui_scale
	guide.queue_redraw()
	help.context = current_context()
	if not ground:
		help.visible = false
	help.queue_redraw()
	var ks := key_state()
	var entries := KeyBar.entries_for(ks)
	if not key_override.is_empty() and not ks.radio_open:
		# M3.5: nur Tasten des aktuellen Kontexts (nach Ein-/Aussteigen keine Flugtasten zu Fuß
		# bzw. Bodentasten im Cockpit); passt keine, gilt die automatische Leiste.
		var ctx := current_context()
		var fit := key_override.filter(func(e): return not (e[0] is StringName) \
			or InputBindings.in_context(e[0], ctx))
		if not fit.is_empty():
			entries = fit
			entries.append([&"help_toggle", "Hilfe"])
	key_bar.set_entries(entries, pad)
	_layout()


## Lage für die Tasten-Leiste (KeyBar.entries_for).
func key_state() -> Dictionary:
	var ctx := current_context()
	var st := {"ctx": ctx, "radio_open": radio != null and radio.is_open, "pad": pad,
		"mouse_free": Input.mouse_mode != Input.MOUSE_MODE_CAPTURED}
	var pos := viewer_position()
	if ctx == InputBindings.Context.CREW:
		st.carrying = character != null and is_instance_valid(character) and character.get("carried") != null
		var na := GroundHudData.nearest_aircraft(pos, known_aircraft())
		st.near_aircraft = na != null and (na as Node3D).global_position.distance_to(pos) < ENTER_NEAR
	var a := own_aircraft()
	if ctx == InputBindings.Context.FLIGHT and a is Aircraft:
		var t := (a as Aircraft).telemetry()
		var pl = hud.get("player") if hud != null else null
		st.on_ground = t.on_ground
		var ec := EngineControl.find(a)
		st.engine_off = ec != null and not ec.is_running()
		st.next_switch = ec.next_switch_label() if ec != null else ""
		st.realistic = pl != null and pl.assist_mode == FlightAssist.Mode.REALISTIC
		st.speed_kmh = t.airspeed * 3.6
		st.parking_brake = FlightPanel.show_parking_brake(pl, t)
		st.gear_down = t.gear_down_cmd
		st.agl = t.height_agl
		var dm = a.get("damage")
		st.eject_possible = not t.on_ground and dm != null and dm.can_eject()
		var ch = hud.get("combat") if hud != null else null
		st.combat = ch != null and ch.get("in_combat") == true
	return st


func _near_stock_or_aircraft() -> bool:
	var pos := viewer_position()
	for s in [depot, bunker]:
		if s is Node3D and (s as Node3D).is_inside_tree() \
				and (s as Node3D).global_position.distance_to(pos) < STOCK_NEAR_STORE:
			return true
	var na := GroundHudData.nearest_aircraft(pos, known_aircraft())
	return na != null and (na as Node3D).global_position.distance_to(pos) < STOCK_NEAR_AIRCRAFT


func _update_turnaround(dt: float) -> void:
	var ta := turnaround
	var t := {}
	if ta != null:
		if ta.running and not _ta_running:
			_best_t = 0.0
		if not ta.running and _ta_running:
			_result_t = TurnaroundDisplay.RESULT_SHOW
		_ta_running = ta.running
		_best_t -= dt
		if _best_t <= 0.0:
			_best_t = BEST_REFRESH
			_best = ta.best_time(ta.helpers, ta.realism)
		_result_t = maxf(_result_t - dt, 0.0)
		t = {"running": ta.running, "elapsed": ta.elapsed, "best": _best, "stars": ta.last_stars,
			"new_best": ta.last_best, "result_t": _result_t}
		timer.alarm_left = ta.alarm_left if ta.alarm_active() else -1.0
	else:
		timer.alarm_left = -1.0
	if timer.alarm_left < 0.0 and _alarm_fallback >= 0.0:
		_alarm_fallback = maxf(_alarm_fallback - dt, 0.0)
		timer.alarm_left = _alarm_fallback
	timer.timer = t
	timer.tick(dt)


func _connect_bus() -> void:
	var bus := GroundEvents.bus()
	if bus == _bus:
		return
	_bus = bus
	bus.alarm_started.connect(func(sec: float): _alarm_fallback = sec)
	bus.alarm_ended.connect(func(_ok: bool): _alarm_fallback = -1.0)


static func _on_ground(a: Node) -> bool:
	var f = a.get("flight")
	if f != null and f.get("gear") != null and f.gear.has_method("has_weight_on_wheels"):
		return f.gear.has_weight_on_wheels()
	return false


static func _speed(a: Node) -> float:
	var v = a.get("linear_velocity")
	return (v as Vector3).length() if v is Vector3 else 0.0


## Kampf-HUD und altes Text-HUD im Boden-Kontext aus-, im Flug wieder einblenden.
func _apply_flight_hud(flight: bool) -> void:
	if hud == null or not is_instance_valid(hud):
		return
	if not flight:
		for n in ["combat", "_info", "_warn", "_warn2", "_aim_marker", "_nose_marker", "_help"]:
			var c = hud.get(n)
			if not (c is CanvasItem):
				continue
			# M3.5: auch unsichtbare Teile sperren (sonst blendet sich das Kampf-HUD im nächsten Frame
			# selbst wieder ein); im Flug kommen nur die zurück, die vorher sichtbar waren.
			if n == "combat" and (c as Node).process_mode != Node.PROCESS_MODE_DISABLED:
				(c as Node).process_mode = Node.PROCESS_MODE_DISABLED
				if not _hidden_flight.has(c):
					_hidden_flight.append(c)
			if (c as CanvasItem).visible:
				(c as CanvasItem).visible = false
				if not _hidden_flight.has(c) and n != "_help":
					_hidden_flight.append(c)
	elif not _hidden_flight.is_empty():
		for c in _hidden_flight:
			if is_instance_valid(c):
				(c as CanvasItem).visible = true
				(c as Node).process_mode = Node.PROCESS_MODE_INHERIT
		_hidden_flight.clear()


func _layout() -> void:
	var vs := get_viewport_rect().size
	ui_scale = HudStyle.ui_scale(vs)
	var s := ui_scale
	var sv := Vector2(s, s)
	for c in [hint, radio, status, stock_bar, timer, timer.alarm_banner, key_bar, crew_panel]:
		(c as Control).scale = sv
	# Zonen (M3.2): Mitte frei (Hinweis, Rad) · unten Mitte Tasten-Leiste · links unten Zustand
	# Flugzeug/Figur · rechts unten Waffen/Schaden · oben Mitte Meldungen/Alarm · oben links Lager
	# · oben rechts Abfertigungszeit.
	hint.position = Vector2(vs.x * 0.5, vs.y * 0.5 + 70.0 * s)
	# Funkgerät unten rechts (über der Tasten-Leisten-Höhe)
	radio.position = Vector2(vs.x - (MARGIN + RadioPanel.W) * s, vs.y - (MARGIN + radio.panel_height()) * s)
	key_bar.position = Vector2(vs.x * 0.5, vs.y - (MARGIN + KeyBar.H * 0.5) * s)
	var sy := vs.y - (MARGIN + status.panel_height()) * s
	status.position = Vector2(MARGIN * s, sy)
	if not on_ground_context():
		# Im Cockpit (Stand): rechts unten an Stelle des Waffen-Panels (keine doppelte Skizze)
		status.position = Vector2(vs.x - (MARGIN + AircraftStatusPanel.W) * s, sy)
	stock_bar.position = Vector2(MARGIN * s, MARGIN * s)
	# Mannschaft links über dem Statuspanel (Zone Zustand)
	var cy := (sy if status.visible else vs.y - MARGIN * s) - (crew_panel.panel_height() + 10.0) * s
	crew_panel.position = Vector2(MARGIN * s, cy)
	timer.position = Vector2(vs.x - (MARGIN + TurnaroundDisplay.W) * s, MARGIN * s)
	timer.alarm_banner.position = Vector2(vs.x * 0.5, (74.0 if on_ground_context() else 104.0) * s)
