class_name MatchRules
extends RefCounted
## Lobby-/Partie-Einstellungen, die mehrere Systeme lesen. Nur der Server ändert sie
## (ab M3 repliziert). Vertrag aus Paket 0: Felder nur in Paket 14 ergänzen.

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
