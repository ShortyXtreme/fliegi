class_name Hud
extends CanvasLayer
## Einfaches HUD: Fahrt, Höhe, Gas, Anstellwinkel, Stall-Warnung, Modus, FPS.
## F3: Treffer-Debug (M2.1, ui/debug/), Shift+F3: Kräfte-Overlay (Text + 3D-Pfeile),
## F1: Steuerungshilfe.

const VERSION := "M3.11"
## Hilfe: ui/ground/ground_help.gd (Tafel je Kontext, M3.2)

var aircraft: Aircraft
var player: PlayerController
var camera_rig: CameraRig
## Kräfte-Overlay (Shift+F3)
var debug_visible := false
## Treffer-Debug-Modus (F3 / Xbox L3)
var hit_debug_visible := false
var hit_debug: HitDebug
var hit_overlay: HitDebugOverlay
var hit_sound: HitSound
## Kampf-HUD (ui/combat/, Agent D). Einziger Registrierungspunkt, siehe _ready().
var combat: CombatHud
## M3 Boden-HUD (ui/ground/, Paket 13). Einziger Registrierungspunkt, siehe _ready().
var ground_hud: GroundHud

var _info: Label
var _warn: Label
var _debug: Label
var _help: GroundHelp
var _aim_marker: Control
var _nose_marker: Control
var _debug_mesh: ImmediateMesh
var _debug_mi: MeshInstance3D
var _warn_t := 0.0
var _gear_msg := ""
var _gear_msg_t := 0.0
var _belly_t := 0.0
var _warn2: Label
var _beep: AudioStreamPlayer
var _beep_gen: AudioStreamGeneratorPlayback
var _beep_phase := 0.0
var _buffet_phase := 0.0
var _noise_lp := 0.0
var _warn_tone := 0.0     # 0..1 Lautstärke Warnton
var _buffet_vol := 0.0    # 0..1 Lautstärke Rumpeln
## M3.4: Controller-Vibration bei Abriss-Warnung (Einstellung, Standard leicht).
static var rumble_mul := 0.35
var _rumbling := false
var _buzz_lp := 0.0


func _ready() -> void:
	var font_size := 18
	_info = _label(Vector2(20, 20), font_size)
	_warn = _label(Vector2(0, 0), 34)
	_warn.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_warn.position.y = 120
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.add_theme_color_override("font_color", Color(1, 0.25, 0.2))
	_warn2 = _label(Vector2(0, 0), 26)
	_warn2.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_warn2.position.y = 170
	_warn2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn2.add_theme_color_override("font_color", Color(1, 0.75, 0.2))
	_setup_audio()
	_debug = _label(Vector2(380, 236), 15)
	_debug.visible = false
	_debug.theme = HudStyle.theme()   # Debug unverändert, nur Epochen-Theme (Schrift/Farbe)
	_help = GroundHelp.new()       # M3.2: gemeinsame Hilfe-Tafel, hier Kontext Flug
	_help.context = InputBindings.Context.FLIGHT
	_help.visible = false   # M3.2: nicht mehr automatisch (übernimmt das Tutorial)
	add_child(_help)
	CombatHud.replace_legacy_text = true   # Paket 14: neues Flug-Panel ersetzt Text-HUD
	combat = CombatHud.create(self); add_child(combat)   # M2-Vertrag: einzige Kampf-HUD-Zeile
	ground_hud = GroundHud.create(self); add_child(ground_hud)   # M3-Vertrag: einzige Boden-HUD-Zeile
	hit_debug = HitDebug.new()
	# Log nur im echten Spiel (nicht in Tests/Diagnose mit --script, außer mit --log)
	var args := OS.get_cmdline_args()
	hit_debug.log_enabled = not "--script" in args or "--log" in OS.get_cmdline_user_args()
	add_child(hit_debug)
	hit_overlay = HitDebugOverlay.new()
	hit_overlay.hud = self
	hit_overlay.data = hit_debug
	add_child(hit_overlay)
	hit_sound = HitSound.new()
	add_child(hit_sound)
	if hit_debug.log_enabled:
		hit_debug.open_log()
		print("Treffer-Log: ", hit_debug.absolute_log_path())
	_aim_marker = _make_circle(14.0, Color(1, 1, 1, 0.9))
	_nose_marker = _make_cross(10.0, Color(0.4, 1.0, 0.4, 0.9))
	_debug_mesh = ImmediateMesh.new()
	_debug_mi = MeshInstance3D.new()
	_debug_mi.mesh = _debug_mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.no_depth_test = true
	_debug_mi.material_override = m
	_debug_mi.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func _exit_tree() -> void:
	if is_instance_valid(_debug_mi) and _debug_mi.get_parent() == null:
		_debug_mi.free()


func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 5)
	add_child(l)
	return l


func _make_circle(r: float, c: Color) -> Control:
	var ctl := Control.new()
	ctl.draw.connect(func(): ctl.draw_arc(Vector2.ZERO, r, 0, TAU, 32, c, 2.0, true))
	add_child(ctl)
	return ctl


func _make_cross(r: float, c: Color) -> Control:
	var ctl := Control.new()
	ctl.draw.connect(func():
		ctl.draw_line(Vector2(-r, 0), Vector2(r, 0), c, 2.0)
		ctl.draw_line(Vector2(0, -r), Vector2(0, r * 0.5), c, 2.0))
	add_child(ctl)
	return ctl


## F3: Treffer-Debug-Modus an/aus.
func toggle_debug() -> void:
	hit_debug_visible = not hit_debug_visible
	hit_overlay.set_active(hit_debug_visible)


## Debug-Tasten im Treffer-Debug-Modus (nur Tastatur): F4 Hitboxen, F5 Bahnen, F6 andere.
func _unhandled_input(event: InputEvent) -> void:
	if not hit_debug_visible or not event is InputEventKey or not event.pressed or event.echo:
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F4:
			hit_overlay.show_hitboxes = not hit_overlay.show_hitboxes
		KEY_F5:
			hit_overlay.show_tracers = not hit_overlay.show_tracers
		KEY_F6:
			hit_debug.show_others = not hit_debug.show_others


## Shift+F3: Kräfte-Overlay (M1-Debug) an/aus.
func toggle_forces() -> void:
	debug_visible = not debug_visible
	_debug.visible = debug_visible
	if aircraft:
		aircraft.flight.collect_debug = debug_visible
	if debug_visible and _debug_mi.get_parent() == null:
		add_child(_debug_mi)
	_debug_mi.visible = debug_visible


## Prozeduraler Ton (M3.4): elektrischer Abriss-Summer der Epoche (rauer Rechteck-Summer
## ~ 240 Hz mit Schnarr-Obertönen), pulsiert schneller und lauter, je näher der Abriss; im Abriss
## Dauerton. Dazu Zellen-Vibrationsgeräusch (Rumpeln) proportional zum Buffet. Kein Kamera-Rütteln.
func _setup_audio() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = 22050.0
	gen.buffer_length = 0.1
	_beep = AudioStreamPlayer.new()
	_beep.stream = gen
	_beep.volume_db = -3.0
	_beep.bus = &"UI"   # M3.4: Warnung über den UI-Bus (nicht mit dem Motor leiser, kein Cockpit-Filter)
	add_child(_beep)
	_beep.play()
	_beep_gen = _beep.get_stream_playback() as AudioStreamGeneratorPlayback


func _fill_audio() -> void:
	if _beep_gen == null:
		return
	var rate := 22050.0
	var n := _beep_gen.get_frames_available()
	# Pulsdauer: weit weg 0,5 s Takt, nah 0,18 s, im Abriss Dauerton
	var period := lerpf(0.5, 0.18, clampf(_warn_tone, 0.0, 1.0))
	for k in n:
		_beep_phase += 1.0 / rate
		var pulse := 1.0 if _warn_tone >= 0.99 or fmod(_beep_phase, period) < period * 0.6 else 0.0
		var buzz := buzzer_sample(_beep_phase)
		_buzz_lp = lerpf(_buzz_lp, buzz * pulse, 0.35)   # weiche Flanken, kein Klicken
		_noise_lp = lerpf(_noise_lp, randf_range(-1.0, 1.0), 0.04)
		var rumble := _noise_lp * 2.5 * (0.6 + 0.4 * sin(_beep_phase * TAU * 11.0))
		var smp := _buzz_lp * _warn_tone * 0.55 + rumble * _buffet_vol * 0.45
		_beep_gen.push_frame(Vector2(smp, smp))


## Summer: Rechteck 240 Hz (weich begrenzt) + schnarrende 50-Hz-Modulation (Anker des Summers).
static func buzzer_sample(ph: float) -> float:
	var sq := tanh(sin(ph * TAU * 240.0) * 4.0) * 0.6 + tanh(sin(ph * TAU * 480.0 + 0.7) * 3.0) * 0.25
	return sq * (0.7 + 0.3 * signf(sin(ph * TAU * 50.0)))


## Lautstärke des Abriss-Warntons 0..1 (0 = aus): ab BUFFET_ONSET vor dem Abriss 0,35, steigt
## bis zum Abriss auf 1, im Abriss 1.
static func stall_warn_level(t: FlightTelemetry) -> float:
	if t.on_ground or t.airspeed <= 10.0:
		return 0.0
	if t.stall_amount > 0.3:
		return 1.0
	var d := t.aoa - (t.stall_aoa - FlightModel.BUFFET_ONSET)
	if d <= 0.0:
		return 0.0
	return clampf(0.35 + 0.65 * d / FlightModel.BUFFET_ONSET, 0.35, 1.0)


func _update_rumble(level: float) -> void:
	var on := level > 0.0 and rumble_mul > 0.0
	if on:
		for dev in Input.get_connected_joypads():
			Input.start_joy_vibration(dev, rumble_mul * level * 0.6, rumble_mul * level * level, 0.15)
	elif _rumbling:
		for dev in Input.get_connected_joypads():
			Input.stop_joy_vibration(dev)
	_rumbling = on


func on_gear_toggled(down: bool, accepted: bool) -> void:
	if not accepted:
		_gear_msg = "Fahrwerk: Einfahren am Boden nicht möglich"
	else:
		_gear_msg = "Fahrwerk wird ausgefahren" if down else "Fahrwerk wird eingefahren"
	_gear_msg_t = 2.5


static func gear_text(t: FlightTelemetry) -> String:
	if t.gear_extension >= 0.999:
		return "AUSGEFAHREN"
	if t.gear_extension <= 0.001:
		return "eingefahren"
	return "%s %3.0f %%" % ["fährt aus" if t.gear_down_cmd else "fährt ein", t.gear_extension * 100.0]


func toggle_help() -> void:
	_help.visible = not _help.visible


func _process(dt: float) -> void:
	if aircraft == null or not is_instance_valid(aircraft):
		return
	hit_debug.own = aircraft
	hit_sound.own = aircraft
	var t := aircraft.telemetry()
	var thr := player.throttle if player else t.throttle_actual
	var flaps := int(round(aircraft.pilot_seat.intent.flaps * 100.0))
	var stall_aoa_deg := rad_to_deg(t.stall_aoa)
	_info.text = "%s  [%s]\nFahrt   %4.0f km/h IAS\nHöhe    %4.0f m  (Grund %4.0f m)\nSteigen %+5.1f m/s\nGas     %3.0f %%   Klappen %d %%\nFahrwerk %s\nAnstellw. %+5.1f°  (Abriss ~%.0f°)\nG       %4.1f\nModus   %s%s\nKamera  %s\nFPS     %d" % [
		aircraft.data.display_name, VERSION,
		t.ias * 3.6, t.altitude, t.height_agl, t.climb_rate,
		thr * 100.0, flaps, gear_text(t),
		rad_to_deg(t.aoa) if t.airspeed > 10.0 else 0.0, stall_aoa_deg, t.g_load,
		FlightAssist.MODE_NAMES[aircraft.assist_mode],
		" + Maus-Ziel" if player and player.mouse_aim_active() else "",
		CameraRig.MODE_NAMES[camera_rig.mode] if camera_rig else "-",
		Engine.get_frames_per_second()]
	if FlightPanel.show_parking_brake(player, t):
		_info.text += "\nPARKBREMSE (Gas > 10 % oder B löst)"
	elif aircraft.pilot_seat.intent.brakes > 0.1:
		_info.text += "\nBREMSE"
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_info.text += "\n(Linksklick: Maus fangen)"
	# Stall-Warnung: ab FlightModel.BUFFET_ONSET (1,5°) vor dem Abriss, Ton progressiv
	_warn_t += dt
	var near_stall := not t.on_ground and t.airspeed > 10.0 \
		and t.aoa > t.stall_aoa - FlightModel.BUFFET_ONSET
	if t.stall_amount > 0.3 and not t.on_ground:
		_warn.text = "STRÖMUNGSABRISS!" if fmod(_warn_t, 0.5) < 0.3 else ""
	elif near_stall:
		_warn.text = "STALL-WARNUNG – nachdrücken"
	else:
		_warn.text = ""
	_warn_tone = stall_warn_level(t)
	_buffet_vol = t.buffet
	_update_rumble(_warn_tone)
	_fill_audio()
	# Zweite Zeile: Fahrwerk / Bauchlandung
	_gear_msg_t -= dt
	if t.belly_contact and t.gear_extension < 0.999:
		_belly_t = 4.0
	_belly_t -= dt
	var w2 := ""
	if _belly_t > 0.0:
		w2 = "BAUCHLANDUNG"
	elif t.gear_overspeed:
		w2 = "FAHRWERK: ZU SCHNELL (max. %.0f km/h)" % (aircraft.data.gear_max_speed * 3.6) \
			if fmod(_warn_t, 0.6) < 0.4 else ""
	elif not t.on_ground and t.gear_extension < 0.5 and t.height_agl < 60.0 \
			and t.climb_rate < -1.0 and t.airspeed < 70.0:
		w2 = "FAHRWERK EINGEFAHREN!"
	elif _gear_msg_t > 0.0:
		w2 = _gear_msg
	_warn2.text = w2
	_update_markers()
	if debug_visible:
		_update_debug(t)


func _update_markers() -> void:
	var cam := get_viewport().get_camera_3d()
	_aim_marker.visible = false
	_nose_marker.visible = false
	if cam == null:
		return
	var xf := aircraft.get_global_transform_interpolated()
	var nose := xf.origin - xf.basis.z * 500.0
	if not cam.is_position_behind(nose):
		_nose_marker.visible = true
		_nose_marker.position = cam.unproject_position(nose)
		_nose_marker.queue_redraw()
	if player and player.mouse_aim_active():
		var aim := cam.global_position + player.aim_dir * 500.0
		if not cam.is_position_behind(aim):
			_aim_marker.visible = true
			_aim_marker.position = cam.unproject_position(aim)
			_aim_marker.queue_redraw()


func _update_debug(t: FlightTelemetry) -> void:
	var c := t.commands
	var g := 9.81 * aircraft.mass
	_debug.text = "KRÄFTE (Shift+F3)\nAuftrieb   %7.0f N  (%.2f × G)\nWiderstand %7.0f N\nSchub      %7.0f N\nGewicht    %7.0f N\nFahrwerk   %d Räder Kontakt\nSchiebew.  %+5.1f°\nDrehraten  N %+5.2f  G %+5.2f  R %+5.2f rad/s\nRuder: Höhe %+4.2f  Quer %+4.2f  Seite %+4.2f\nAbriss Hauptflügel %3.0f %%  Buffet %3.0f %%\nAbwind Leitwerk %4.1f°  Begrenzer %3.0f %%" % [
		t.lift, t.lift / g, t.drag, t.thrust, g, t.wheels_in_contact,
		rad_to_deg(t.sideslip),
		t.angular_velocity_local.x, t.angular_velocity_local.y, t.angular_velocity_local.z,
		c.elevator, c.aileron, c.rudder, t.stall_amount * 100.0, t.buffet * 100.0,
		rad_to_deg(t.downwash), aircraft.assist.limiter_amount * 100.0]
	# M3.8: Wind (nur Debug, im Spiel kein Windanzeiger)
	var wh := Vector2(t.wind.x, t.wind.z)
	_debug.text += "\nWind %4.1f m/s nach %03.0f° (vert. %+4.1f)  Fahrt %5.1f km/h  über Grund %5.1f km/h\n%s" % [
		wh.length(), fposmod(rad_to_deg(atan2(wh.x, -wh.y)), 360.0), t.wind.y, t.airspeed * 3.6,
		t.ground_speed * 3.6, Weather.describe()]
	# M3.9: Anteile (mittlerer Wind, Böe, Hang/Thermik, Rollböe, Turbulenzstärke)
	var wi := t.wind_info
	if wi != null and Weather.enabled():
		var mh := Vector2(wi.mean.x, wi.mean.z)
		_debug.text += "\n  mittel %4.1f m/s aus %03.0f°  Böe %+4.1f/%+4.1f/%+4.1f m/s  Hang %+4.1f  Thermik %+4.1f m/s\n  Rollböe %+5.3f 1/s  σ %.1f/%.1f/%.1f m/s  z0 %.3f m  Lee %3.0f %%  Tal %3.0f %%  %3.0f m ü. Grund" % [
			mh.length(), fposmod(rad_to_deg(atan2(-mh.x, mh.y)), 360.0), wi.turb.x, wi.turb.z, wi.turb.y,
			wi.orographic, wi.thermal, wi.roll_grad, wi.sigma.x, wi.sigma.y, wi.sigma.z, wi.z0,
			wi.lee * 100.0, wi.channel * 100.0, wi.agl]
	for s in aircraft.flight.surfaces:
		if s.def.is_main_wing and s.def.name.ends_with("root") or s.def.name.begins_with("htail_R") or s.def.name == "vtail":
			_debug.text += "\n  %-14s α %+5.1f°  Cl %+4.2f  Abriss %3.0f %%" % [s.def.name,
				rad_to_deg(s.last_alpha), s.last_lift_coef, s.last_stall_t * 100.0]
	_debug_mesh.clear_surfaces()
	var vecs: Array = aircraft.flight.debug_vectors
	if vecs.is_empty():
		return
	_debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var scale := 1.0 / 2500.0   # 2500 N = 1 m
	for v in vecs:
		_debug_mesh.surface_set_color(v[2])
		_debug_mesh.surface_add_vertex(v[0])
		_debug_mesh.surface_add_vertex(v[0] + (v[1] as Vector3) * scale)
	_debug_mesh.surface_end()
