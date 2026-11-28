class_name PilotGTolerance
extends RefCounted
## M3.11: g-Toleranz des Piloten mit Zeitverlauf (Spieler und KI gleich; nur der Spieler
## sieht den Bildschirmeffekt, CombatHud -> GEffectOverlay).
##
## Modell: Die wirksame Last g_eff folgt der g-Last verzögert (Blutverlagerung und
## Sauerstoffreserve des Gehirns, ≈ 4–6 s: kurze Spitzen werden vertragen). Aufbau mit
## TAU_ONSET, Abbau mit TAU_RECOVER. Daraus:
##   grey  (Grauschleier, Tunnelblick): ab GREY_START bis GREY_FULL g_eff
##   black (Blackout):                   ab BLACK_START bis BLACK_FULL g_eff
##   red   (Redout, negative g):         ab RED_START bis RED_FULL (negativ)
## Sehen kehrt nur langsam zurück (RECOVER_RATE je s), ein voller Blackout hält zusätzlich
## HOLD_AFTER_BLACK s nach.
## Sollwerte (Stil B, ohne Anti-g-Anzug, entspannt sitzend; Literatur: Grauschleier
## ≈ 4–5 g, Blackout ≈ 5–6 g anhaltend, Redout ≈ −2,5 … −3 g):
##   5 g anhaltend -> Grauschleier ~50 %, kein Blackout
##   6,5 g anhaltend -> Blackout beginnt nach ≈ 4,5 s, voll nach ≈ 7–8 s
##   7,5 g für 2 s -> nur leichter Grauschleier
##   −2,5 g anhaltend -> Redout ~70 %, −3 g -> voll nach ≈ 3–4 s
## Arcade: Schwellen um ARCADE_SHIFT g höher (Blackout praktisch erst an der 7,5-g-Grenze
## nach langer Zeit), der Effekt wird vom Overlay zusätzlich abgeschwächt.

const TAU_ONSET := 2.5
const TAU_RECOVER := 3.0
const TAU_NEG := 1.5
const GREY_START := 4.5
const GREY_FULL := 5.5
const BLACK_START := 5.6
const BLACK_FULL := 6.2
const RED_START := -2.0
const RED_FULL := -2.7
const RECOVER_RATE := 0.2
const HOLD_AFTER_BLACK := 2.0
const ARCADE_SHIFT := 1.5

var g_eff := 1.0
var g_neg := 0.0
var grey := 0.0
var black := 0.0
var red := 0.0
var arcade := false
var _hold := 0.0


func reset() -> void:
	g_eff = 1.0
	g_neg = 0.0
	grey = 0.0
	black = 0.0
	red = 0.0
	_hold = 0.0


func tick(dt: float, g: float, is_arcade: bool) -> void:
	arcade = is_arcade
	var tau := TAU_ONSET if g > g_eff else TAU_RECOVER
	g_eff += (g - g_eff) * (1.0 - exp(-dt / tau))
	g_neg += (minf(g, 0.0) - g_neg) * (1.0 - exp(-dt / TAU_NEG))
	var sh := ARCADE_SHIFT if is_arcade else 0.0
	var grey_t := clampf((g_eff - GREY_START - sh) / (GREY_FULL - GREY_START), 0.0, 1.0)
	var black_t := clampf((g_eff - BLACK_START - sh) / (BLACK_FULL - BLACK_START), 0.0, 1.0)
	var red_t := clampf((g_neg - RED_START + sh * 0.5) / (RED_FULL - RED_START), 0.0, 1.0)
	if black >= 0.99 and black_t >= 0.99:
		_hold = HOLD_AFTER_BLACK      # läuft erst ab, wenn die Last nachlässt
	_hold = maxf(_hold - dt, 0.0)
	grey = _approach(grey, maxf(grey_t, black_t), dt, 1.0)
	black = _approach(black, black_t, dt, 1.0) if _hold <= 0.0 or black_t >= black else black
	red = _approach(red, red_t, dt, 1.5)


static func _approach(v: float, target: float, dt: float, up_rate: float) -> float:
	if target > v:
		return minf(v + up_rate * dt, target)
	return maxf(v - RECOVER_RATE * dt, target)


## Pilot sieht nichts mehr (Blackout/Redout).
func is_blind() -> bool:
	return black > 0.9 or red > 0.9
