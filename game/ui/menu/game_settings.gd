class_name GameSettings
extends RefCounted
## Einstellungen (M3.2, Haupt-/Pausenmenü) in user://flugkern.cfg – dieselbe Datei, die
## CombatScenario ([m2] ki_stufe) und MatchRules ([m3] bodenbetrieb) beim Spielstart lesen.
## Neu: [m3_2] flug = "arcade" | "realistisch", radar = "immer" | "kampf", maus = 0,5 … 2,0.
## M3.3: [audio] vol_master/vol_motor/vol_waffen/vol_umgebung/vol_ui = 0,0 … 1,0, alarmton = "sirene" | "glocke".
## apply_runtime() setzt die sofort wirksamen Werte (Flugmodus, Radar, Maus) im laufenden Spiel.

const PATH := "user://flugkern.cfg"

## [Schlüssel, Abschnitt, Beschriftung, Werte, Anzeigenamen, Standard]
const OPTIONS := [
	# M3.4: Anzeige (beim Start und sofort angewendet)
	["fenster", "anzeige", "Anzeigemodus", ["vollbild", "rahmenlos", "fenster"],
		["Vollbild", "Rahmenloses Fenster", "Fenster"], "fenster"],
	["aufloesung", "anzeige", "Fenstergröße", RES, RES, "1600x900"],
	["vsync", "anzeige", "V-Sync", ["an", "aus"], ["An", "Aus"], "an"],
	["flug", "m3_2", "Realismus Flug", ["arcade", "realistisch"], ["Arcade", "Realistisch"], "arcade"],
	["bodenbetrieb", "m3", "Realismus Bodenbetrieb", ["einfach", "standard", "authentisch"],
		["Einfach", "Standard", "Authentisch"], "standard"],
	["ki_stufe", "m2", "KI-Stufe", ["rekrut", "erfahren", "veteran"], ["Rekrut", "Erfahren", "Veteran"], "erfahren"],
	["radar", "m3_2", "Radar (Kreiskarte)", ["immer", "kampf"], ["Immer", "Nur im Kampf"], "immer"],
	["maus", "m3_2", "Maus-Empfindlichkeit", [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
		["50 %", "75 %", "100 %", "125 %", "150 %", "200 %"], 1.0],
	# M3.3: Lautstärken je Audio-Bus (0 … 100 %, Regler ohne Umlauf)
	["vol_master", "audio", "Lautstärke Gesamt", VOL, VOL_LABELS, 0.8],
	["vol_motor", "audio", "Lautstärke Motor", VOL, VOL_LABELS, 0.8],
	["vol_waffen", "audio", "Lautstärke Waffen", VOL, VOL_LABELS, 0.8],
	["vol_umgebung", "audio", "Lautstärke Umgebung", VOL, VOL_LABELS, 0.7],
	["vol_ui", "audio", "Lautstärke Menü/UI", VOL, VOL_LABELS, 0.7],
	# M3.4: Strömungsabriss – Kamera-Rütteln (Standard aus), Controller-Vibration (Standard leicht)
	["kamera_ruetteln", "m3_4", "Kamera-Rütteln", ["aus", "leicht"], ["Aus", "Leicht"], "aus"],
	["vibration", "m3_4", "Controller-Vibration", ["aus", "leicht", "stark"], ["Aus", "Leicht", "Stark"], "leicht"],
	# M3.5: 3D-Markierungen an Tankstutzen, MG-Klappen, Schlauch und Kisten (Standard an)
	["hilfen", "m3_5", "Interaktionshilfen", ["an", "aus"], ["An", "Aus"], "an"],
	["funk_piep", "m3_5", "Funk-Klang", ["an", "aus"], ["An", "Aus"], "an"],
	["alarmton", "audio", "Alarmton", ["sirene", "glocke"], ["Sirene", "Glocke"], "sirene"],
	# M3.7: Bäume, Büsche, Gras (Dichte und Sichtweite), Standard Mittel
	["vegetation", "m3_7", "Vegetation", Vegetation.LEVELS, Vegetation.LABELS, "mittel"],
]
const VOL := [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
const VOL_LABELS := ["0 %", "10 %", "20 %", "30 %", "40 %", "50 %", "60 %", "70 %", "80 %", "90 %", "100 %"]
const RES := ["1280x720", "1600x900", "1920x1080", "2560x1440", "2560x1080", "3440x1440"]

## Faktor auf PlayerController.MOUSE_SENS.
static var mouse_mul := 1.0


static func _cfg() -> ConfigFile:
	var c := ConfigFile.new()
	c.load(PATH)
	return c


static func option(key: String) -> Array:
	for o in OPTIONS:
		if o[0] == key:
			return o
	return []


static func get_value(key: String):
	var o := option(key)
	var v = _cfg().get_value(o[1], o[0], o[5])
	return v if (o[3] as Array).has(v) else o[5]


static func set_value(key: String, v) -> void:
	var o := option(key)
	var c := _cfg()
	c.set_value(o[1], o[0], v)
	c.save(PATH)


## Index des aktuellen Werts (für Menü-Optionen).
static func index_of(key: String) -> int:
	return maxi((option(key)[3] as Array).find(get_value(key)), 0)


static func label_of(key: String) -> String:
	return String(option(key)[4][index_of(key)])


## Wert um d Schritte weiterschalten (zyklisch) und speichern.
static func cycle(key: String, d: int) -> void:
	var vals: Array = option(key)[3]
	if is_slider(key) or key == "aufloesung":   # Regler: am Rand stehen bleiben
		set_value(key, vals[clampi(index_of(key) + d, 0, vals.size() - 1)])
		return
	set_value(key, vals[posmod(index_of(key) + d, vals.size())])


## Regler (Balken mit Prozentwert) statt Auswahl.
static func is_slider(key: String) -> bool:
	return key.begins_with("vol_")


## Reglerstellung 0..1.
static func slider_frac(key: String) -> float:
	return float(index_of(key)) / float(maxi((option(key)[3] as Array).size() - 1, 1))


## M3.4: Anzeigemodus, Fenstergröße und V-Sync anwenden (headless: nichts).
static func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if get_value("vsync") == "an"
		else DisplayServer.VSYNC_DISABLED)
	var scr := DisplayServer.window_get_current_screen()
	match String(get_value("fenster")):
		"vollbild":
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		"rahmenlos":
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
			DisplayServer.window_set_size(DisplayServer.screen_get_size(scr))
			DisplayServer.window_set_position(DisplayServer.screen_get_position(scr))
		_:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var p := String(get_value("aufloesung")).split("x")
			var sz := Vector2i(int(p[0]), int(p[1]))
			var ss := DisplayServer.screen_get_size(scr)
			sz = Vector2i(mini(sz.x, ss.x), mini(sz.y, ss.y))
			DisplayServer.window_set_size(sz)
			DisplayServer.window_set_position(DisplayServer.screen_get_position(scr) + (ss - sz) / 2)


## Sofort wirksame Werte ins laufende Spiel (Game) übernehmen; null = nur statische Werte.
static func apply_runtime(game: Node = null) -> void:
	mouse_mul = float(get_value("maus"))
	CameraRig.shake_mul = 0.2 if get_value("kamera_ruetteln") == "leicht" else 0.0
	Hud.rumble_mul = {"aus": 0.0, "leicht": 0.35, "stark": 0.8}.get(String(get_value("vibration")), 0.35)
	GameAudio.apply_volumes()
	InteractionGuide.enabled = get_value("hilfen") != "aus"
	InteractionHint.arcade = get_value("flug") != "realistisch"
	RadioPanel.beep_on = get_value("funk_piep") != "aus"
	Vegetation.set_level(maxi(Vegetation.LEVELS.find(String(get_value("vegetation"))), 0))
	CombatHud.radar_mode = CombatHud.RadarMode.ALWAYS if get_value("radar") == "immer" \
		else CombatHud.RadarMode.COMBAT_ONLY
	if game != null:
		var pl = game.get("player")
		if pl != null:
			pl.assist_mode = FlightAssist.Mode.REALISTIC if get_value("flug") == "realistisch" \
				else FlightAssist.Mode.ARCADE
