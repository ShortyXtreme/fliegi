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
## Test/Vorschau: -1 = Eingabe (crew_wheel), 0 = losgelassen, 1 = gehalten.
var wheel_override := -1
var pad := false
var ui_scale := 1.0

var hint: InteractionHint
var wheel: CommandWheel
var status: AircraftStatusPanel
var stock_bar: StockBar
var timer: TurnaroundDisplay
var guide: ParkingGuide
var help: GroundHelp
## M3.2: Tasten-Leiste unten Mitte (alle Kontexte, auch Flug).
var key_bar: KeyBar
## Maschine im Statuspanel (für Tests).
var status_aircraft: Node = null

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
	wheel = CommandWheel.new()
	wheel.command_chosen.connect(issue_command)
	add_child(wheel)
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
func issue_command(cmd: int, target: Node) -> int:
	command_issued.emit(cmd, target)
	if command_receiver.is_valid():
		command_receiver.call(cmd, target)
		return 1
	if dispatch == null or not is_instance_valid(dispatch):
		return 0
	if dispatch.has_method("command"):
		dispatch.call("command", cmd, target)
		return 1
	var n := 0
	for c in (dispatch.get("crews") if dispatch.get("crews") != null else []):
		var brain = c
		if c is Object and not c.has_method("command") and c.get("brain") != null:
			brain = c.get("brain")
		if brain is Object and brain.has_method("command"):
			brain.call("command", cmd, target)
			n += 1
	return n


# --- Eingabe ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	KeyGlyphs.note_input(event)
	pad = KeyGlyphs.pad
	if wheel == null or not wheel.is_open:
		return
	if event is InputEventMouseMotion:
		wheel.feed_mouse(event.relative / maxf(ui_scale, 0.1))
		get_viewport().set_input_as_handled()     # Blick friert ein, solange das Rad offen ist
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			wheel.cycle_target(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			wheel.cycle_target(1)
	elif event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_DPAD_LEFT:
			wheel.cycle_target(-1)
		elif event.button_index == JOY_BUTTON_DPAD_RIGHT:
			wheel.cycle_target(1)


func _unhandled_input(event: InputEvent) -> void:
	if on_ground_context() and InputMap.has_action(&"help_toggle") and event.is_action_pressed(&"help_toggle"):
		toggle_help()


func toggle_help() -> void:
	help.visible = not help.visible


func _wheel_held() -> bool:
	if wheel_override >= 0:
		return wheel_override == 1
	return InputMap.has_action(&"crew_wheel") and Input.is_action_pressed(&"crew_wheel")


func _update_wheel() -> void:
	var held := on_ground_context() and _wheel_held()
	if held and not wheel.is_open:
		var list := known_aircraft()
		var pos := viewer_position()
		list.sort_custom(func(a, b): return a.global_position.distance_to(pos) < b.global_position.distance_to(pos))
		wheel.open_wheel(list, list[0] if not list.is_empty() else null)
	elif not held and wheel.is_open:
		wheel.close_wheel(on_ground_context())
	if wheel.is_open:
		wheel.pad = pad
		var v := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
		wheel.feed_stick(v)


# --- Bild -------------------------------------------------------------------------------

func _process(dt: float) -> void:
	_connect_bus()
	var ground := on_ground_context()
	var b := board if board != null else JobBoard.current
	if b != null and not is_instance_valid(b):
		b = null
	if manage_flight_hud:
		_apply_flight_hud(not ground)
	_layout()
	# Interaktion (nur zu Fuß)
	var crew := current_context() == InputBindings.Context.CREW
	_update_wheel()
	hint.set_data(GroundHudData.interaction(character, b, pad) if crew and not wheel.is_open else {"visible": false})
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
	if status.visible:
		status.set_data(GroundHudData.aircraft_status(status_aircraft, b, character), dt)
	# Lager: nur nahe Lager oder Maschine (M3.2)
	stock_bar.visible = ground and (depot != null or bunker != null) and _near_stock_or_aircraft()
	if stock_bar.visible:
		stock_bar.set_data(GroundHudData.stock(depot, bunker))
	# Abfertigung + Alarm
	_update_turnaround(dt)
	timer.visible = timer.timer_visible() and ground
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
	key_bar.set_entries(KeyBar.entries_for(key_state()), pad)
	_layout()


## Lage für die Tasten-Leiste (KeyBar.entries_for).
func key_state() -> Dictionary:
	var ctx := current_context()
	var st := {"ctx": ctx, "wheel_open": wheel != null and wheel.is_open, "pad": pad,
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
			if c is CanvasItem and (c as CanvasItem).visible:
				(c as CanvasItem).visible = false
				if n == "combat":
					(c as Node).process_mode = Node.PROCESS_MODE_DISABLED
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
	for c in [hint, wheel, status, stock_bar, timer, timer.alarm_banner, key_bar]:
		(c as Control).scale = sv
	# Zonen (M3.2): Mitte frei (Hinweis, Rad) · unten Mitte Tasten-Leiste · links unten Zustand
	# Flugzeug/Figur · rechts unten Waffen/Schaden · oben Mitte Meldungen/Alarm · oben links Lager
	# · oben rechts Abfertigungszeit.
	hint.position = Vector2(vs.x * 0.5, vs.y * 0.5 + 70.0 * s)
	wheel.position = vs * 0.5
	key_bar.position = Vector2(vs.x * 0.5, vs.y - (MARGIN + KeyBar.H * 0.5) * s)
	var sy := vs.y - (MARGIN + status.panel_height()) * s
	status.position = Vector2(MARGIN * s, sy)
	if not on_ground_context():
		# Im Cockpit (Stand): rechts unten an Stelle des Waffen-Panels (keine doppelte Skizze)
		status.position = Vector2(vs.x - (MARGIN + AircraftStatusPanel.W) * s, sy)
	stock_bar.position = Vector2(MARGIN * s, MARGIN * s)
	timer.position = Vector2(vs.x - (MARGIN + TurnaroundDisplay.W) * s, MARGIN * s)
	timer.alarm_banner.position = Vector2(vs.x * 0.5, (74.0 if on_ground_context() else 104.0) * s)
