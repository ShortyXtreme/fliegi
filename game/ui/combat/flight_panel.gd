class_name FlightPanel
extends Control
## Kompaktes Instrument-Panel für die Fluganzeigen (links unten), ersetzt das zentrale
## Text-HUD aus hud.gd: Fahrt, Höhe, Steigen, G, Gas, Klappen, Fahrwerk, Modus, Kamera,
## dazu farbige Warnungen über dem Panel. FPS nur mit F3 (hud.debug_visible).
## Zeichnet in 1080p-Einheiten; CombatHud setzt position/scale.

const W := 340.0
const PAD := 16.0

## Zuletzt gesammelte Werte (siehe gather()).
var data := {}
var _blink := 0.0


func _init() -> void:
	name = "FlightPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Reine Datensammlung (auch headless testbar).
static func gather(aircraft: Aircraft, player: PlayerController, cam: CameraRig,
		debug := false) -> Dictionary:
	var t := aircraft.telemetry()
	var d := {}
	d.speed_kmh = t.airspeed * 3.6
	d.altitude = t.altitude
	d.agl = t.height_agl
	d.climb = t.climb_rate
	d.g = t.g_load
	d.throttle = player.throttle if player else t.throttle_actual
	d.flaps = int(round(aircraft.pilot_seat.intent.flaps * 100.0)) if aircraft.pilot_seat else 0
	d.gear = t.gear_extension
	d.gear_down_cmd = t.gear_down_cmd
	d.mode = FlightAssist.MODE_NAMES[aircraft.assist_mode]
	d.mouse_aim = player != null and player.mouse_aim_active()
	d.camera = CameraRig.MODE_NAMES[cam.mode] if cam else ""
	d.fps = Engine.get_frames_per_second() if debug else -1
	d.mouse_free = Input.mouse_mode != Input.MOUSE_MODE_CAPTURED
	var w: Array = []
	var near_stall := not t.on_ground and t.airspeed > 10.0 \
		and t.aoa > t.stall_aoa - FlightModel.BUFFET_ONSET
	if t.stall_amount > 0.3 and not t.on_ground:
		w.append(["STRÖMUNGSABRISS", 2, true])
	elif near_stall:
		w.append(["STALL-WARNUNG", 1, false])
	if t.gear_overspeed:
		w.append(["FAHRWERK ZU SCHNELL  max. %d km/h" % int(aircraft.data.gear_max_speed * 3.6), 1, true])
	elif not t.on_ground and t.gear_extension < 0.5 and t.height_agl < 60.0 \
			and t.climb_rate < -1.0 and t.airspeed < 70.0:
		w.append(["FAHRWERK EINGEFAHREN", 2, false])
	if t.belly_contact and t.gear_extension < 0.999:
		w.append(["BAUCHLANDUNG", 2, false])
	if show_parking_brake(player, t):
		w.append(["PARKBREMSE  (Gas > 10 % oder B)", 0, false])
	elif t.on_ground and aircraft.pilot_seat and aircraft.pilot_seat.intent.brakes > 0.1:
		w.append(["BREMSE", 0, false])
	d.warnings = w   # [Text, Stufe 0 Hinweis / 1 Vorsicht / 2 Warnung, blinkt]
	return d


func set_data(d: Dictionary) -> void:
	data = d
	queue_redraw()


func _process(dt: float) -> void:
	_blink += dt


static func dec(v: float, digits := 1) -> String:
	return (("%." + str(digits) + "f") % v).replace(".", ",")


func panel_height() -> float:
	return 196.0


func _draw() -> void:
	if data.is_empty():
		return
	var h := panel_height()
	HudStyle.draw_panel(self, Rect2(0, 0, W, h), 12)
	var x0 := PAD
	var x1 := 182.0
	# Kopfzeile: Beschriftungen
	HudStyle.heading(self, Vector2(x0, 26), "FAHRT", 11)
	HudStyle.heading(self, Vector2(x1, 26), "HÖHE", 11)
	# Große Werte
	var sp := HudStyle.text(self, Vector2(x0, 64), str(int(round(data.speed_kmh))), 38,
			HudStyle.VALUE, true)
	HudStyle.text(self, Vector2(x0 + sp + 5, 64), "km/h", 14, HudStyle.LABEL)
	var al := HudStyle.text(self, Vector2(x1, 64), HudStyle.thousands(data.altitude), 38,
			HudStyle.VALUE, true)
	HudStyle.text(self, Vector2(x1 + al + 5, 64), "m", 14, HudStyle.LABEL)
	# Zweite Zeile: G | Steigen, Grund
	var g: float = data.g
	var gcol := HudStyle.VALUE if g < 4.5 else (HudStyle.CAUTION if g < 6.5 else HudStyle.WARNING)
	if g < -0.5:
		gcol = HudStyle.CAUTION
	HudStyle.text(self, Vector2(x0, 88), "G", 13, HudStyle.LABEL)
	HudStyle.text(self, Vector2(x0 + 16, 88), dec(g), 16, gcol, true)
	var c: float = data.climb
	var arrow := "↑" if c > 0.3 else ("↓" if c < -0.3 else "•")
	var ccol := HudStyle.VALUE if absf(c) < 20.0 else HudStyle.CAUTION
	var cs := "%s %s%s" % [arrow, "+" if c >= 0.05 else ("−" if c <= -0.05 else ""), dec(absf(c))]
	var cw := HudStyle.text(self, Vector2(x1, 88), cs, 16, ccol, true)
	HudStyle.text(self, Vector2(x1 + cw + 4, 88), "m/s", 12, HudStyle.LABEL)
	if data.agl < 400.0:   # Grundabstand nur in Bodennähe
		HudStyle.text(self, Vector2(W - PAD, 26), "Grund %s m" % HudStyle.thousands(data.agl), 12,
				HudStyle.CAUTION if data.agl < 60.0 else HudStyle.DIM, false, 2)
	# Trennlinie
	HudStyle.rule(self, Vector2(x0, 102), Vector2(W - PAD, 102))
	# Gas-Balken
	HudStyle.heading(self, Vector2(x0, 126), "GAS", 11)
	var bar := Rect2(x0 + 40, 115, 210, 10)
	draw_rect(bar, Color(1, 1, 1, 0.08))
	var thr: float = clampf(data.throttle, 0.0, 1.0)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * thr, bar.size.y)),
			HudStyle.ACCENT if thr < 0.995 else HudStyle.CAUTION)
	for k in [0.25, 0.5, 0.75]:
		var xx: float = bar.position.x + bar.size.x * k
		draw_line(Vector2(xx, bar.position.y), Vector2(xx, bar.end.y), Color(0, 0, 0, 0.35), 1.0)
	HudStyle.text(self, Vector2(W - PAD, 126), "%d %%" % int(round(thr * 100.0)), 15,
			HudStyle.VALUE, true, 2)
	# Klappen / Fahrwerk
	HudStyle.heading(self, Vector2(x0, 152), "KLAPPEN", 11)
	var fl: int = data.flaps
	HudStyle.text(self, Vector2(x0 + 80, 152), "%d %%" % fl, 15,
			HudStyle.VALUE if fl == 0 else HudStyle.ACCENT, true)
	HudStyle.heading(self, Vector2(x1 - 30, 152), "FAHRWERK", 11)
	var ge: float = data.gear
	var gs := "ausgefahren" if ge >= 0.999 else ("eingefahren" if ge <= 0.001 else
			("%s %d %%" % ["↓" if data.gear_down_cmd else "↑", int(ge * 100.0)]))
	var gc := HudStyle.OK if ge >= 0.999 else (HudStyle.LABEL if ge <= 0.001 else HudStyle.CAUTION)
	HudStyle.text(self, Vector2(x1 + 56, 152), gs, 15, gc, true)
	# Fußzeile: Modus-Chip, Maus-Ziel, Kamera, FPS
	# Fußzeile: Modus-Schild + Stufe-0-Hinweise (Parkbremse/Bremse) als Schild;
	# Warnungen ab Stufe 1 zeigt AlertStack oben Mitte (M3.2), Kamera/Maus die Tasten-Leiste.
	var cx := x0
	cx = _chip(cx, String(data.mode), HudStyle.ACCENT)
	if data.mouse_aim:
		cx = _chip(cx, "Maus-Ziel", HudStyle.LABEL)
	for e in data.get("warnings", []):
		if int(e[1]) == 0:
			cx = _chip(cx, String(e[0]).get_slice("  ", 0), HudStyle.CAUTION)
	if data.fps >= 0:
		HudStyle.text(self, Vector2(W - PAD, 181), "%d FPS" % data.fps, 12, HudStyle.DIM, false, 2)


func _chip(x: float, t: String, col: Color) -> float:
	var s := t.to_upper()
	var mw := HudStyle.text_width(s, 11, true) + HudStyle.HEADING_SPACING * s.length()
	var chip := Rect2(x, 166, mw + 16, 20)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.14)
	sb.border_color = Color(col, 0.6)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	draw_style_box(sb, chip)
	HudStyle.heading(self, Vector2(x + 8, 180), s, 11, col)
	return chip.end.x + 6.0


static func show_parking_brake(player, t) -> bool:
	return player != null and player.parking_brake and t != null and t.on_ground \
			and t.wheels_in_contact > 0 and t.airspeed * 3.6 < 5.0
