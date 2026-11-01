class_name MatchRules
extends RefCounted
## Lobby-/Partie-Einstellungen, die mehrere Systeme lesen. Nur der Server ändert sie
## (ab M3 repliziert). Vertrag aus Paket 0: Felder nur in Paket 14 ergänzen.
## M3 (Paket 0a): Realismus-Stufe Bodenbetrieb und Startzustände der Maschinen
## (Konfig user://flugkern.cfg [m3] bodenbetrieb = "einfach" | "standard" | "authentisch",
## Startoption `-- --boden=einfach`).

enum SpotMode { ARCADE, REALISTIC }
## M2.1: Zoom im Realistisch-Modus – nach Flugzeug (Visier-Upgrade), immer, nie.
enum RealisticZoom { AIRCRAFT, ALWAYS, NEVER }

## Eigenbeschuss: Treffer werden immer erkannt, Schaden nur wenn true (Entscheidung 4).
static var friendly_fire_damage := false
## Ausfallzeit nach Verlust/Ausstieg bis zum Neustart (s, Entscheidung 3).
static var respawn_delay := 15.0
## Wracks verschwinden nach (s).
static var wreck_lifetime := 30.0
## Abschuss-Kredit: letzter Schütze innerhalb dieses Fensters (s).
static var kill_credit_window := 30.0
## Erkennungs-/Marker-Modus (Entscheidung 2): Arcade = Vorhalt, Radar-Light, frühe Marker.
static var spot_mode: int = SpotMode.ARCADE
## Vorhaltepunkt und Radar-Light im HUD (nur Arcade, Lobby-Option).
static var lead_indicator := true
static var radar_light := true
## M2.1 Lobby-Option (Konfig [m2] zoom_realistisch = "flugzeug" | "immer" | "nie").
static var realistic_zoom: int = RealisticZoom.AIRCRAFT
## Zoom-Faktor im Arcade-Modus (70° → 30°).
static var arcade_zoom_factor := 2.33


## --- M3: Bodenbetrieb ---
enum GroundRealism { EINFACH, STANDARD, AUTHENTISCH }
## Wie eine Maschine am Abstellplatz erscheint (SpawnManager, Paket 10).
enum StartKind { FIRST, AFTER_LOSS, AFTER_LANDING }
const GROUND_REALISM_NAMES := ["einfach", "standard", "authentisch"]
const CONFIG_PATH := "user://flugkern.cfg"
static var ground_realism: int = GroundRealism.STANDARD
## Erste Maschine einer Partie (PO-Entscheidung 6): 50 % Treibstoff, volle Munition.
static var first_fuel := 0.5
static var first_ammo := 1.0
## Nach Abschuss/Verlust: neue Maschine mit 15 % Treibstoff, ohne Munition.
static var loss_fuel := 0.15
static var loss_ammo := 0.0


## Anteil Treibstoff/Munition (0..1) für einen Start; -1 = Restzustand behalten.
static func start_fuel(kind: int) -> float:
	match kind:
		StartKind.FIRST: return first_fuel
		StartKind.AFTER_LOSS: return loss_fuel
	return -1.0


static func start_ammo(kind: int) -> float:
	match kind:
		StartKind.FIRST: return first_ammo
		StartKind.AFTER_LOSS: return loss_ammo
	return -1.0


## "einfach" | "standard" | "authentisch" (auch "vereinfacht") -> GroundRealism, sonst -1.
static func parse_ground_realism(s: String) -> int:
	s = s.strip_edges().to_lower()
	if s == "vereinfacht":
		return GroundRealism.EINFACH
	return GROUND_REALISM_NAMES.find(s)


static func ground_realism_name(r: int = -1) -> String:
	if r < 0:
		r = ground_realism
	return GROUND_REALISM_NAMES[clampi(r, 0, 2)]


## Stufe aus Konfig ([m3] bodenbetrieb=) und Kommandozeile (--boden=). Kommandozeile gewinnt.
static func load_ground_config(path: String = CONFIG_PATH,
		args: PackedStringArray = OS.get_cmdline_user_args()) -> void:
	var cf := ConfigFile.new()
	if cf.load(path) == OK:
		var r := parse_ground_realism(str(cf.get_value("m3", "bodenbetrieb", "standard")))
		if r >= 0:
			ground_realism = r
		else:
			push_warning("Unbekannte Stufe [m3] bodenbetrieb, nehme 'standard'")
	for a in args:
		if a.begins_with("--boden="):
			var r2 := parse_ground_realism(a.substr(8))
			if r2 >= 0:
				ground_realism = r2
			else:
				push_warning("Unbekannte Stufe '%s', nehme 'standard'" % a)


static func reset() -> void:
	friendly_fire_damage = false
	respawn_delay = 15.0
	wreck_lifetime = 30.0
	kill_credit_window = 30.0
	spot_mode = SpotMode.ARCADE
	lead_indicator = true
	radar_light = true
	realistic_zoom = RealisticZoom.AIRCRAFT
	arcade_zoom_factor = 2.33
	ground_realism = GroundRealism.STANDARD
	first_fuel = 0.5
	first_ammo = 1.0
	loss_fuel = 0.15
	loss_ammo = 0.0
