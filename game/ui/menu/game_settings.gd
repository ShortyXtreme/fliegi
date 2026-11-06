class_name GameSettings
extends RefCounted
## Einstellungen (M3.2, Haupt-/Pausenmenü) in user://flugkern.cfg – dieselbe Datei, die
## CombatScenario ([m2] ki_stufe) und MatchRules ([m3] bodenbetrieb) beim Spielstart lesen.
## Neu: [m3_2] flug = "arcade" | "realistisch", radar = "immer" | "kampf", maus = 0,5 … 2,0.
## apply_runtime() setzt die sofort wirksamen Werte (Flugmodus, Radar, Maus) im laufenden Spiel.

const PATH := "user://flugkern.cfg"

## [Schlüssel, Abschnitt, Beschriftung, Werte, Anzeigenamen, Standard]
const OPTIONS := [
	["flug", "m3_2", "Realismus Flug", ["arcade", "realistisch"], ["Arcade", "Realistisch"], "arcade"],
	["bodenbetrieb", "m3", "Realismus Bodenbetrieb", ["einfach", "standard", "authentisch"],
		["Einfach", "Standard", "Authentisch"], "standard"],
	["ki_stufe", "m2", "KI-Stufe", ["rekrut", "erfahren", "veteran"], ["Rekrut", "Erfahren", "Veteran"], "erfahren"],
	["radar", "m3_2", "Radar (Kreiskarte)", ["immer", "kampf"], ["Immer", "Nur im Kampf"], "immer"],
	["maus", "m3_2", "Maus-Empfindlichkeit", [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
		["50 %", "75 %", "100 %", "125 %", "150 %", "200 %"], 1.0],
]

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
	set_value(key, vals[posmod(index_of(key) + d, vals.size())])


## Sofort wirksame Werte ins laufende Spiel (Game) übernehmen; null = nur statische Werte.
static func apply_runtime(game: Node = null) -> void:
	mouse_mul = float(get_value("maus"))
	CombatHud.radar_mode = CombatHud.RadarMode.ALWAYS if get_value("radar") == "immer" \
		else CombatHud.RadarMode.COMBAT_ONLY
	if game != null:
		var pl = game.get("player")
		if pl != null:
			pl.assist_mode = FlightAssist.Mode.REALISTIC if get_value("flug") == "realistisch" \
				else FlightAssist.Mode.ARCADE
