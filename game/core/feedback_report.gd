class_name FeedbackReport
extends RefCounted
## Feedback-Taste: Inhalt von bericht.md (lesbar, Deutsch). collect() läuft im Moment des
## Tastendrucks (Zustand vor dem Eingabefeld), markdown() setzt danach den Text des Testers ein.
## Alles defensiv (get()/has_method), damit ein fehlendes Teil nie den Bericht verhindert.

const NEAR_AIR_M := 40000.0
const NEAR_GROUND_M := 1500.0
const MAX_NEAR := 14


## Abschnitte: [[Titel, PackedStringArray Zeilen], …]
static func collect(fb: Feedback) -> Array:
	var g: Node = fb.game if fb.game != null and is_instance_valid(fb.game) else null
	var out: Array = []
	out.append(["Kontext", _context_lines(fb, g)])
	out.append(["Einstellungen", _settings_lines()])
	out.append(["Bildrate", _fps_lines(fb)])
	out.append(["Hardware", _hardware_lines(fb)])
	var a: Node3D = g.get("player_aircraft") if g != null else null
	if a != null and is_instance_valid(a):
		out.append(["Spielerflugzeug", aircraft_lines(a, g)])
	var ground := _ground_lines(g)
	if not ground.is_empty():
		out.append([ground[0], ground[1]])
	if g != null:
		out.append(["In der Nähe", _nearby_lines(g)])
	return out


static func markdown(sections: Array, text: String, meta: Dictionary) -> String:
	var L := PackedStringArray()
	L.append("# Feedback Flugkern %s" % Hud.VERSION)
	L.append("")
	L.append("- **Datum:** %s" % meta.get("datum", ""))
	L.append("- **Version:** %s" % Hud.VERSION)
	L.append("- **Ordner:** %s" % meta.get("ordner", ""))
	L.append("- **Screenshot:** %s" % meta.get("screenshot", ""))
	L.append("- **Spiel pausiert:** %s" % meta.get("pause", ""))
	L.append("")
	L.append("## Text des Testers")
	L.append("")
	L.append("> " + (text.strip_edges() if text.strip_edges() != "" else "(ohne Text)").replace("\n", "\n> "))
	L.append("")
	for s in sections:
		L.append("## " + String(s[0]))
		L.append("")
		for line in s[1]:
			L.append(line if String(line).begins_with("|") or String(line).begins_with("  ") else "- " + String(line))
		L.append("")
	return "\n".join(L)


# --- Kontext ------------------------------------------------------------------------------------

## Kontextname (Flug, Zu Fuß, Fahren, Funk …, Hauptmenü, Pausenmenü).
static func context_name(fb: Feedback, g: Node) -> String:
	var tree := fb.get_tree()
	var scene := tree.current_scene if tree != null else null
	if g == null:
		if scene is MainMenu:
			return "Hauptmenü"
		return "ohne Partie (%s)" % (scene.name if scene != null else "–")
	var s = g.get("session")
	var ctx := int(s.context) if s != null else InputBindings.Context.FLIGHT
	var name_s := String(InputBindings.CONTEXT_NAMES.get(ctx, str(ctx)))
	var hud = g.get("hud")
	var gh = hud.get("ground_hud") if hud != null else null
	var radio = gh.get("radio") if gh != null else null
	if radio != null and bool(radio.get("is_open")):
		name_s += " · Funkgerät offen"
	var pm = g.get("pause_menu")
	if pm != null and is_instance_valid(pm):
		name_s += " · Pausenmenü offen"
	return name_s


static func _context_lines(fb: Feedback, g: Node) -> PackedStringArray:
	var L := PackedStringArray()
	var tree := fb.get_tree()
	var scene := tree.current_scene if tree != null else null
	L.append("**Kontext:** %s" % context_name(fb, g))
	var scene_s := "–"
	if g != null:
		scene_s = "%s (%s)" % [g.name, g.scene_file_path if g.scene_file_path != "" else "ohne Datei"]
	elif scene != null:
		scene_s = "%s (%s)" % [scene.name, scene.scene_file_path]
	L.append("**Szene:** " + scene_s)
	if g != null:
		var w = g.get("world")
		L.append("**Welt:** %s" % ("Gelände (TerrainWorld)" if w is TerrainWorld else "Testwelt"))
		var tut = g.get("tutorial")
		if g.has_method("is_tutorial") and g.is_tutorial():
			var step := "–"
			if tut != null and is_instance_valid(tut):
				step = "Schritt %d / %d%s" % [int(tut.index) + 1, Tutorial.STEP_COUNT, "" if tut.active else " (beendet)"]
			L.append("**Tutorial:** an, %s" % step)
		var sc = g.get("scenario")
		if sc != null and is_instance_valid(sc):
			L.append("**Szenario:** Luftkampf 1 gegen %d, KI-Stufe %s" % [int(sc.enemy_count), sc.difficulty_name()])
	var pl = g.get("player") if g != null else null
	if pl != null:
		L.append("**Steuerungsmodus:** %s, Maus-Zielsteuerung %s" % [
			"Realistisch" if int(pl.assist_mode) == FlightAssist.Mode.REALISTIC else "Arcade",
			"an" if bool(pl.mouse_aim_enabled) else "aus"])
	else:
		L.append("**Steuerungsmodus:** %s (Einstellung)" % GameSettings.label_of("flug"))
	L.append("**Realismusstufe:** Flug %s, Bodenbetrieb %s" % [GameSettings.label_of("flug"),
		["Einfach", "Standard", "Authentisch"][clampi(MatchRules.ground_realism, 0, 2)]])
	L.append("**Eingabegerät zuletzt:** %s" % ("Controller" if KeyGlyphs.pad else "Tastatur/Maus"))
	L.append("**Spielzeit seit Partiestart:** %s (ohne Pausen %s)" % [_clock(fb.match_real_s()), _clock(fb.game_time)])
	if Weather.enabled() or g != null:
		L.append("**" + Weather.describe().replace("Wetter: ", "Wetter:** "))
	return L


static func _settings_lines() -> PackedStringArray:
	var L := PackedStringArray()
	for o in GameSettings.OPTIONS:
		L.append("%s: %s" % [o[2], GameSettings.label_of(o[0])])
	var changed := []
	var c := ConfigFile.new()
	if c.load(GameSettings.PATH) == OK and c.has_section(KeyRebind.SECTION):
		for k in c.get_section_keys(KeyRebind.SECTION):
			changed.append("%s = %s" % [KeyRebind.label(StringName(k)), KeyRebind.display(StringName(k))])
	L.append("Tastenbelegung geändert: %s" % (", ".join(changed) if not changed.is_empty() else "nein (Standard)"))
	return L


static func _fps_lines(fb: Feedback) -> PackedStringArray:
	var st: Vector2 = fb.frozen.fps_stats() if fb.frozen != null else fb.recorder.fps_stats()
	return PackedStringArray([
		"Aktuell: %.0f fps" % Engine.get_frames_per_second(),
		"Mittel der letzten 60 s: %.1f fps" % st.x,
		"Minimum der letzten 60 s: %.1f fps (kürzester Einzelframe-Wert je Sekunde)" % st.y,
		"Physik: %d Hz, Zeitfaktor %.2f" % [Engine.physics_ticks_per_second, Engine.time_scale]])


static func _hardware_lines(fb: Feedback) -> PackedStringArray:
	var L := PackedStringArray()
	L.append("Betriebssystem: %s %s (%s)" % [OS.get_name(), OS.get_version(), Engine.get_architecture_name()])
	L.append("Grafikkarte: %s (%s)" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_vendor()])
	var drv := OS.get_video_adapter_driver_info()
	L.append("Treiber: %s, API %s, Renderer %s" % [" ".join(drv) if not drv.is_empty() else "–",
		RenderingServer.get_video_adapter_api_version(), str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))])
	L.append("Anzeige-Server: %s, Grafik-Treiber %s" % [DisplayServer.get_name(), RenderingServer.get_current_rendering_driver_name()])
	L.append("CPU: %s, %d Kerne" % [OS.get_processor_name(), OS.get_processor_count()])
	var mem := OS.get_memory_info()
	L.append("Arbeitsspeicher: %.1f GB (frei %.1f GB), Spiel belegt %.0f MB" % [float(mem.get("physical", 0)) / 1e9,
		float(mem.get("available", 0)) / 1e9, OS.get_static_memory_usage() / 1e6])
	var vs := fb.get_viewport().get_visible_rect().size if fb.is_inside_tree() else Vector2.ZERO
	var scr := DisplayServer.screen_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	var win := DisplayServer.window_get_size() if DisplayServer.get_name() != "headless" else Vector2i.ZERO
	L.append("Auflösung: Bildschirm %dx%d, Fenster %dx%d, Bild %dx%d" % [scr.x, scr.y, win.x, win.y, vs.x, vs.y])
	L.append("Godot: %s" % Engine.get_version_info().get("string", ""))
	return L


# --- Spielerflugzeug ---------------------------------------------------------------------------

static func aircraft_lines(a: Node3D, g: Node) -> PackedStringArray:
	var L := PackedStringArray()
	if not a.has_method("telemetry"):
		return L
	var t: FlightTelemetry = a.telemetry()
	var xf := a.global_transform
	var fwd := -xf.basis.z
	var d = a.get("data")
	L.append("Typ: %s" % (d.display_name if d != null else a.name))
	L.append("Position: x %.1f, y %.1f, z %.1f m" % [xf.origin.x, xf.origin.y, xf.origin.z])
	L.append("Höhe: %.0f m über NN, %.1f m über Grund%s" % [t.altitude, t.height_agl, ", am Boden" if t.on_ground else ""])
	L.append("Geschwindigkeit: IAS %.0f km/h, TAS %.0f km/h, über Grund %.0f km/h, Steigen %+.1f m/s, Mach %.2f" % [
		t.ias * 3.6, t.airspeed * 3.6, t.ground_speed * 3.6, t.climb_rate, t.mach])
	L.append("Lage: Nick %+.1f°, Roll %+.1f°, Kurs %03.0f°, Anstellwinkel %+.1f°, Schiebewinkel %+.1f°" % [
		rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0))), FeedbackRecorder.roll_deg(xf.basis),
		fposmod(rad_to_deg(atan2(fwd.x, -fwd.z)), 360.0), rad_to_deg(t.aoa), rad_to_deg(t.sideslip)])
	var pg = a.get("pilot_g")
	L.append("g-Last: %.2f g%s; Abriss %.0f %%, Schütteln %.0f %%" % [t.g_load,
		(", Pilot: Grau %.0f %%, Blackout %.0f %%, Redout %.0f %%" % [pg.grey * 100.0, pg.black * 100.0, pg.red * 100.0]) if pg != null else "",
		t.stall_amount * 100.0, t.buffet * 100.0])
	var ec := EngineControl.find(a)
	var es := ec.state() if ec != null else {}
	var dm = a.get("damage")
	var eng_hp := "%.0f %%" % (dm.hp_fraction(DamageModel.Zone.ENGINE) * 100.0) if dm != null else "–"
	L.append("Motor: Gas %.0f %%, Drehzahl ≈ %.0f U/min, Leistung %.0f %%, Kühlmittel %.1f °C, Kühlerklappe %.0f %%, Zustand %s, Motor-Trefferpunkte %s%s" % [
		t.throttle_actual * 100.0, FeedbackRecorder.engine_rpm(a), t.engine_power_fraction * 100.0, t.coolant_temp,
		t.radiator * 100.0, es.get("phase_name", "–"), eng_hp,
		", Motor tot" if dm != null and bool(dm.engine_dead) else ""])
	if not es.is_empty():
		L.append("Schalter: Hauptschalter %s, Pumpe %s, Zündung %s, Gemisch %s" % [_an(es.master), _an(es.fuel_pump),
			_an(es.magnetos), "reich" if es.mixture else "abgestellt"])
	if dm != null:
		var f: FuelSystem = dm.fuel
		L.append("Treibstoff: %.0f von %.0f l (%.0f %%), links %.0f l, rechts %.0f l%s" % [f.total(),
			f.capacity[0] + f.capacity[1], f.fraction() * 100.0, f.liters[0], f.liters[1],
			", LECK %.2f l/s" % (f.leak_lps[0] + f.leak_lps[1]) if f.is_leaking() else ""])
	var w = a.get("weapons")
	if w != null:
		L.append("Munition: MG %d / %d%s%s" % [w.ammo(WeaponSystem.Group.PRIMARY), w.ammo_max(WeaponSystem.Group.PRIMARY),
			(", Sekundär %d / %d" % [w.ammo(WeaponSystem.Group.SECONDARY), w.ammo_max(WeaponSystem.Group.SECONDARY)])
				if w.has_weapons(WeaponSystem.Group.SECONDARY) else "",
			", Hemmung" if w.is_jammed() else ""])
	if dm != null:
		var zs := PackedStringArray()
		for z in DamageModel.Zone.COUNT:
			zs.append("%s %.0f %%%s" % [DamageModel.ZONE_NAMES[z], dm.hp_fraction(z) * 100.0, " (brennt)" if dm.is_burning(z) else ""])
		L.append("Schadenszonen: " + ", ".join(zs))
		L.append("Pilot: %s, Zustand %s%s" % [["unverletzt", "verwundet", "tot", "ausgestiegen"][clampi(dm.pilot_state, 0, 3)],
			["fliegt", "bauchgelandet", "abgestürzt"][clampi(dm.outcome, 0, 2)], ", ZERSTÖRT" if dm.is_destroyed else ""])
	var pl = g.get("player") if g != null else null
	L.append("Fahrwerk %s (%.0f %%), Klappenstufe %s, Parkbremse %s, Räder am Boden %d" % [
		"ausgefahren" if t.gear_down_cmd else "eingefahren", t.gear_extension * 100.0,
		str(pl.flap_index) if pl != null else "–", _an(bool(pl.parking_brake)) if pl != null else "–", t.wheels_in_contact])
	L.append("Wind am Ort: %s" % wind_text(t.wind))
	return L


static func wind_text(v: Vector3) -> String:
	var h := Vector2(v.x, v.z)
	if h.length() < 0.05 and absf(v.y) < 0.05:
		return "still"
	# Herkunftsrichtung (aus Kompassgrad), Weltachse -Z = Nord
	var from_deg := fposmod(rad_to_deg(atan2(-v.x, v.z)), 360.0)
	return "aus %03.0f°, %.1f m/s waagerecht, %+.1f m/s senkrecht" % [from_deg, h.length(), v.y]


# --- Boden ---------------------------------------------------------------------------------------

static func _ground_lines(g: Node) -> Array:
	if g == null:
		return []
	var s = g.get("session")
	if s == null:
		return []
	var ctx := int(s.context)
	var veh = s.seat.vehicle if s.seat != null else null
	if ctx == InputBindings.Context.CREW or veh is CrewCharacter:
		var c: Node3D = veh if veh is CrewCharacter else g.get("crew")
		return ["Zu Fuß", crew_lines(c)] if c != null and is_instance_valid(c) else []
	if ctx == InputBindings.Context.DRIVE and veh is GroundVehicle:
		return ["Im Fahrzeug", vehicle_lines(veh)]
	return []


static func crew_lines(c: Node3D) -> PackedStringArray:
	var L := PackedStringArray()
	var p := c.global_position
	var gh := WorldGround.height_at(p.x, p.z)
	L.append("Position: x %.1f, y %.1f, z %.1f m (%.1f m über Grund)" % [p.x, p.y, p.z, p.y - gh])
	var v: Vector3 = c.get("velocity") if c.get("velocity") != null else Vector3.ZERO
	L.append("Geschwindigkeit: %.1f km/h, Blickrichtung %03.0f°" % [v.length() * 3.6,
		fposmod(rad_to_deg(float(c.get("heading"))), 360.0) if c.get("heading") != null else 0.0])
	var st := int(c.get("anim_state")) if c.get("anim_state") != null else 0
	L.append("Zustand: %s%s%s" % [String(CrewCharacter.ANIM_NAMES[clampi(st, 0, CrewCharacter.ANIM_NAMES.size() - 1)]),
		", arbeitet" if bool(c.get("working")) else "", ", schwimmt" if c.has_method("is_swimming") and c.is_swimming() else ""])
	var carried = c.get("carried")
	L.append("Trägt: %s" % (_node_name(carried) if carried != null else "nichts"))
	var f = c.get("focus")
	if f != null and is_instance_valid(f):
		L.append("Blickziel: %s an %s" % [String(f.marker), _node_name(f.target)])
	if c.has_method("current_action"):
		var act: Dictionary = c.current_action()
		if not act.is_empty():
			L.append("Aktion: %s" % str(act.get("label", act)))
	L.append("Wind am Ort: %s" % wind_text(Weather.surface_wind(p) if Weather.enabled() else Vector3.ZERO))
	return L


static func vehicle_lines(v: Node3D) -> PackedStringArray:
	var L := PackedStringArray()
	var p := v.global_position
	L.append("Fahrzeug: %s" % _node_name(v))
	L.append("Position: x %.1f, y %.1f, z %.1f m" % [p.x, p.y, p.z])
	L.append("Geschwindigkeit: %.1f km/h, Kurs %03.0f°, Lenkung %+.2f" % [float(v.get("speed")) * 3.6,
		HudContacts.heading_of(v.forward()) if v.has_method("forward") else 0.0, float(v.get("steer"))])
	if v.has_method("water_depth") and v.water_depth() > 0.0:
		L.append("Wassertiefe: %.2f m" % v.water_depth())
	var tank = v.get("tank")
	if tank != null and tank.has_method("total"):
		L.append("Tank: %.0f l von %.0f l" % [tank.total(), float(tank.total_capacity)])
	var crates = v.get("crates")
	if crates != null:
		L.append("Kisten: %d" % int(crates))
	L.append("Wind am Ort: %s" % wind_text(Weather.surface_wind(p) if Weather.enabled() else Vector3.ZERO))
	return L


# --- Umgebung ------------------------------------------------------------------------------------

static func focus_position(g: Node) -> Vector3:
	var s = g.get("session")
	if s != null and s.seat != null and s.seat.vehicle is Node3D and is_instance_valid(s.seat.vehicle):
		return (s.seat.vehicle as Node3D).global_position
	var a = g.get("player_aircraft")
	return (a as Node3D).global_position if a != null and is_instance_valid(a) else Vector3.ZERO


static func _nearby_lines(g: Node) -> PackedStringArray:
	var L := PackedStringArray()
	var me := focus_position(g)
	var air: Array = []
	for a in g.get("ai_aircrafts") if g.get("ai_aircrafts") != null else []:
		if a != null and is_instance_valid(a) and a.is_inside_tree():
			var dist: float = (a as Node3D).global_position.distance_to(me)
			if dist <= NEAR_AIR_M:
				air.append([dist, a])
	air.sort_custom(func(x, y): return x[0] < y[0])
	L.append("**KI-Flugzeuge (bis %.0f km, ganze Karte):** %d" % [NEAR_AIR_M / 1000.0, air.size()])
	for e in air.slice(0, MAX_NEAR):
		L.append("  - " + _ai_aircraft_text(e[1], e[0]))
	var ground: Array = []
	var ops_list: Array = (g.get("airfields") as Dictionary).values() if g.get("airfields") is Dictionary else []
	for ops in ops_list:
		for k in ops.crews.size():
			var c: Node3D = ops.crews[k]
			if c == null or not is_instance_valid(c):
				continue
			var br = ops.brains[k] if k < ops.brains.size() else null
			var st := "–"
			if br != null:
				st = ["bereit", "unterwegs", "arbeitet", "räumt auf"][clampi(int(br.state), 0, 3)]
				if int(br.job_id) != 0:
					st += ", Auftrag %d" % int(br.job_id)
			ground.append([c.global_position.distance_to(me), "%s: %s" % [c.name, st]])
		for v in [ops.truck, ops.cart]:
			if v != null and is_instance_valid(v):
				var drv = v.driver_seat.controller if v.get("driver_seat") != null and v.driver_seat != null else null
				ground.append([v.global_position.distance_to(me), "%s: %.0f km/h, Fahrer %s" % [_node_name(v),
					absf(float(v.speed)) * 3.6, "KI" if drv != null and drv.is_ai() else ("Spieler" if drv != null else "keiner")]])
	ground = ground.filter(func(e): return e[0] <= NEAR_GROUND_M)
	ground.sort_custom(func(x, y): return x[0] < y[0])
	L.append("**Bodenpersonal und Fahrzeuge (bis %.1f km):** %d" % [NEAR_GROUND_M / 1000.0, ground.size()])
	for e in ground.slice(0, MAX_NEAR):
		L.append("  - %s, %.0f m" % [e[1], e[0]])
	return L


static func _ai_aircraft_text(a: Node, dist: float) -> String:
	var d = a.get("data")
	var t: FlightTelemetry = a.telemetry() if a.has_method("telemetry") else null
	var phase := "–"
	var seat = a.get("pilot_seat")
	var br = seat.controller if seat != null else null
	if br is AIPilotBrain:
		var ap = br.airfield
		phase = br.state_name()
		if ap != null and int(ap.phase) != AirfieldPhases.Phase.COMBAT:
			phase = String(AirfieldPhases.PHASE_NAMES[int(ap.phase)])
		elif ap != null:
			phase = "Kampf · " + phase
	elif br != null:
		phase = br.get_class() if br.get_script() == null else String(br.get_script().get_global_name())
	var dm = a.get("damage")
	var hp := " , Zelle %.0f %%" % (dm.health_fraction() * 100.0) if dm != null else ""
	if dm != null and dm.is_destroyed:
		hp = ", ZERSTÖRT"
	return "%s (%s): %.0f m, Höhe %.0f m, %.0f km/h, Phase %s%s" % [HudContacts.display_name(a),
		d.display_name if d != null else "Flugzeug", dist, t.altitude if t != null else 0.0,
		t.ias * 3.6 if t != null else 0.0, phase, hp.replace(" ,", ",")]


# --- Helfer --------------------------------------------------------------------------------------

static func _ja(b: bool) -> String:
	return "ja" if b else "nein"


static func _an(b) -> String:
	return "an" if bool(b) else "aus"


static func _clock(s: float) -> String:
	var t := int(s)
	return "%d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60]


static func _node_name(n) -> String:
	if n == null or not (n is Object) or not is_instance_valid(n):
		return "–"
	if n is Node:
		if (n as Node).has_meta("display_name"):
			return str((n as Node).get_meta("display_name"))
		var scr = (n as Node).get_script()
		var cls: String = String(scr.get_global_name()) if scr != null else (n as Node).get_class()
		return "%s (%s)" % [(n as Node).name, cls]
	return str(n)
