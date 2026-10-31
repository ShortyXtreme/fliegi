class_name Spotting
extends RefCounted
## Erkennungsweite (Entscheidung 2), gemeinsam für Spieler-HUD und KI:
##   spot_range = base(Modus) × aircraft_visibility × crew_level_mul + radar_bonus
## Werte sind Startwerte (Stub, Paket 0); Feinabstimmung durch Agent C (KI/Wahrnehmung).
## Der vergrößerte Frontkegel der KI und Reaktionsverzögerung liegen in ai/perception.gd.

## Basisweite je MatchRules.SpotMode (m): Arcade, Realistisch.
const BASE_RANGE := [5000.0, 3000.0]
## Jeder zusätzliche Besatzer/Beobachter verbessert die Sicht um diesen Anteil.
const OBSERVER_BONUS := 0.1
## Ab Pilotenlevel 3: Sichtweite +15 % (GDD §6.1).
const LEVEL_SPOT_MUL := 1.15
const LEVEL_SPOT_FROM := 3
## Zusatzweite, wenn das Ziel im Bereich eines intakten eigenen Bodenradars liegt (m).
const RADAR_BONUS := 3000.0

static var radars: Array[RadarStation] = []


static func base(mode: int) -> float:
	return BASE_RANGE[clampi(mode, 0, BASE_RANGE.size() - 1)]


## Sicht aus dem Cockpit × Beobachter (AircraftData.cockpit_visibility, crew_count).
static func aircraft_visibility(viewer: Node) -> float:
	var d: AircraftData = viewer.get("data") if viewer != null else null
	if d == null:
		return 1.0
	return d.cockpit_visibility * (1.0 + OBSERVER_BONUS * maxi(d.crew_count - 1, 0))


static func crew_level_mul(level: int) -> float:
	return LEVEL_SPOT_MUL if level >= LEVEL_SPOT_FROM else 1.0


static func radar_bonus(viewer: Node, target: Node3D) -> float:
	if viewer == null or target == null:
		return 0.0
	var nation: int = viewer.get("nation_id") if viewer.get("nation_id") != null else Nations.NONE
	for r in radars:
		if r.nation_id == nation and r.covers(target.global_position):
			return RADAR_BONUS
	return 0.0


## mode < 0: MatchRules.spot_mode.
static func spot_range(viewer: Node3D, target: Node3D, mode: int = -1) -> float:
	if mode < 0:
		mode = MatchRules.spot_mode
	var lvl = viewer.get("crew_level") if viewer != null else null
	var level: int = lvl if lvl is int else 1
	return base(mode) * aircraft_visibility(viewer) * crew_level_mul(level) \
		+ radar_bonus(viewer, target)


static func can_spot(viewer: Node3D, target: Node3D, mode: int = -1) -> bool:
	return viewer.global_position.distance_to(target.global_position) \
		<= spot_range(viewer, target, mode)


static func register_radar(r: RadarStation) -> void:
	if not radars.has(r):
		radars.append(r)


static func unregister_radar(r: RadarStation) -> void:
	radars.erase(r)


static func reset() -> void:
	radars.clear()
