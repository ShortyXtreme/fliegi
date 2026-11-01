class_name ZoomRules
extends RefCounted
## M2.1: Regeln für den Ziel-Zoom (Taste halten: RMT, Z, Xbox R3).
##  Arcade: immer verfügbar (MatchRules.arcade_zoom_factor, Standard 70° → 30°).
##  Realistisch: nur mit Visier-Upgrade (AircraftData.has_zoom_sight, Faktor
##  sight_zoom_factor); Lobby-Option MatchRules.realistic_zoom kann es erzwingen/verbieten.

## Weiche Überblendung (Zeitkonstante, s).
const BLEND_TIME := 0.12


static func allowed(assist_mode: int, data: Resource) -> bool:
	if assist_mode == FlightAssist.Mode.ARCADE:
		return true
	match MatchRules.realistic_zoom:
		MatchRules.RealisticZoom.ALWAYS:
			return true
		MatchRules.RealisticZoom.NEVER:
			return false
	return data != null and bool(data.get("has_zoom_sight"))


## Vergrößerung bei voll gedrückter Taste (1 = kein Zoom).
static func factor(assist_mode: int, data: Resource) -> float:
	if not allowed(assist_mode, data):
		return 1.0
	if assist_mode == FlightAssist.Mode.ARCADE:
		return MatchRules.arcade_zoom_factor
	var f = data.get("sight_zoom_factor") if data != null else null
	return maxf(float(f), 1.0) if f != null and bool(data.get("has_zoom_sight")) \
			else MatchRules.arcade_zoom_factor


## Sichtfeld (Grad) für eine Vergrößerung: tan(fov/2) skaliert mit 1/mul.
static func zoomed_fov(base_fov_deg: float, mul: float) -> float:
	if mul <= 1.0001:
		return base_fov_deg
	return rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov_deg) * 0.5) / mul))
