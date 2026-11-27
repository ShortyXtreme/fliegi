class_name Weather
extends RefCounted
## M3.8: Wetter/Wind der Partie (zentral, statisch wie MatchRules/WorldGround). Der Wind ist die
## Bewegung der Luftmasse (m/s, Weltkoordinaten); Flugzeuge fliegen relativ zu ihr (FlightModel),
## Fallschirme, Rauch, Trümmer, Windsäcke, Gras, Bäume und Wasser richten sich danach.
##
## Grundwind je Partie aus einem Seed: Richtung „woher“ im Nordsektor (die Pisten liegen in der
## Hauptwindrichtung, Start nach Norden = gegen den Wind; bis ±80° → kräftiger Seitenwind
## möglich), Stärke nach Stufe (Aus / Schwach / Normal / Stark). Dreht langsam (±15° über
## Minuten), Böen (zeitlich und räumlich, ±25 %), mit der Höhe stärker (Potenzgesetz, Bezug 10 m
## über Grund, ab ~1.000 m konstant 1,6-fach), in Bodennähe schwächer (1 m: ~0,7-fach).
## Leichte senkrechte Böen erst ab 60 m über Grund (Landeanflug ruhig).
##
## Zeit: Weather.time läuft mit dem Spiel (WeatherDriver im Spiel, sonst steht sie). Aus =
## exakt kein Wind (altes Verhalten). Tests und Selbsttest: aus (reset()).

enum Level { AUS, SCHWACH, NORMAL, STARK }
const LEVELS := ["aus", "schwach", "normal", "stark"]
const LABELS := ["Aus", "Schwach", "Normal", "Stark"]
## Grundwind (10 m über Grund) je Stufe: [min, max] m/s
const SPEED_RANGE := [Vector2(0.0, 0.0), Vector2(1.0, 3.0), Vector2(3.0, 6.0), Vector2(6.0, 8.5)]
## Richtung „woher“ (Grad, 0 = Nord = −Z, 90 = Ost): Sektor um Nord
const DIR_SECTOR := 80.0
const GUST := 0.25
const REF_H := 10.0
const MAX_FACTOR := 1.6

static var level: int = Level.AUS
static var seed_value := 0
## Grundwind: Richtung „woher“ (Grad) und Stärke (m/s, 10 m über Grund)
static var base_from_deg := 0.0
static var base_speed := 0.0
## Spielzeit (s), weitergezählt von WeatherDriver
static var time := 0.0
## Fester Wind ohne Böen/Drehen (Tests, set_steady)
static var steady := false
static var _ph := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])


## Kein Wind (Tests, Selbsttest, Start).
static func reset() -> void:
	setup(Level.AUS, 0)
	time = 0.0


## Wind für eine Partie: Stufe und Seed (gleicher Seed = gleicher Wind).
static func setup(lvl: int, s: int) -> void:
	level = clampi(lvl, 0, LEVELS.size() - 1)
	seed_value = s
	steady = false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(s) ^ 0x5eed
	base_from_deg = rng.randf_range(-DIR_SECTOR, DIR_SECTOR)
	var r: Vector2 = SPEED_RANGE[level]
	base_speed = rng.randf_range(r.x, r.y)
	_ph.resize(8)
	for i in 8:
		_ph[i] = rng.randf() * TAU


## Fester Wind (Tests): Richtung „woher“ in Grad, Stärke m/s; Böen und Drehen aus.
static func set_steady(from_deg: float, speed: float) -> void:
	level = Level.NORMAL if speed > 0.0 else Level.AUS
	base_from_deg = from_deg
	base_speed = speed
	steady = true


static func enabled() -> bool:
	return level != Level.AUS and base_speed > 0.0


static func parse_level(s: String) -> int:
	return LEVELS.find(s.strip_edges().to_lower())


## Richtung „woher“ (Grad) zur Zeit t (dreht langsam).
static func from_deg_at(t: float) -> float:
	if steady:
		return base_from_deg
	return base_from_deg + 11.0 * sin(t / 173.0 + _ph[0]) + 5.0 * sin(t / 61.0 + _ph[1])


## Grundstärke (10 m über Grund, ohne Böen) zur Zeit t.
static func mean_speed_at(t: float) -> float:
	if steady:
		return base_speed
	return base_speed * (1.0 + 0.12 * sin(t / 97.0 + _ph[2]))


## Böenfaktor (−GUST … +GUST) an einem Ort.
static func gust_at(t: float, p: Vector3) -> float:
	if steady:
		return 0.0
	var a := sin(t * 0.61 + p.x * 0.0031 + p.z * 0.0023 + _ph[3])
	var b := sin(t * 1.73 + p.x * 0.011 - p.z * 0.007 + _ph[4])
	var c := sin(t * 0.23 + _ph[5])
	# Böen kommen in Schüben (c), dazwischen ruhiger
	return GUST * (0.55 * a + 0.3 * b) * (0.6 + 0.4 * c)


## Höhenfaktor über Grund (1 bei 10 m).
static func height_factor(agl: float) -> float:
	return minf(pow(maxf(agl, 0.5) / REF_H, 0.15), MAX_FACTOR)


## Einheitsvektor „wohin“ der Wind weht (waagerecht).
static func dir_to(from_deg: float) -> Vector3:
	var r := deg_to_rad(from_deg)
	return -Vector3(sin(r), 0.0, -cos(r))


## Wind (Luftbewegung, m/s) an Szenen-Position p. Höhe über Grund aus WorldGround.
static func wind_at(p: Vector3) -> Vector3:
	if not enabled():
		return Vector3.ZERO
	var agl := p.y - WorldGround.height_at(p.x, p.z)
	return wind_at_agl(p, agl)


static func wind_at_agl(p: Vector3, agl: float) -> Vector3:
	if not enabled():
		return Vector3.ZERO
	var t := time
	var pa := WorldOrigin.to_abs(p)
	var g := gust_at(t, pa)
	var deg := from_deg_at(t) + (0.0 if steady else 8.0 * sin(t * 0.37 + pa.x * 0.002 + _ph[6]))
	var spd := mean_speed_at(t) * (1.0 + g) * height_factor(agl)
	var w := dir_to(deg) * spd
	if not steady and agl > 60.0:
		var k := smoothstep(60.0, 200.0, agl)
		w.y = base_speed * 0.07 * k * sin(t * 0.9 + pa.x * 0.006 + pa.z * 0.005 + _ph[7])
	return w


## Wind am Boden für Windsäcke/Gras (Windsack-Höhe 7 m), mit Böen.
static func surface_wind(p: Vector3, h := 7.0) -> Vector3:
	return wind_at_agl(p, h)


## Kompassrichtung „woher“ als Text (8 Richtungen).
static func compass_name(from_deg: float) -> String:
	var names := ["Nord", "Nordost", "Ost", "Südost", "Süd", "Südwest", "West", "Nordwest"]
	return names[posmod(int(round(fposmod(from_deg, 360.0) / 45.0)), 8)]


## Stärke grob (Beaufort-nah): still, schwach, mäßig, frisch, stark.
static func strength_name(speed: float) -> String:
	if speed < 1.0:
		return "still"
	if speed < 3.5:
		return "schwach"
	if speed < 6.0:
		return "mäßig"
	if speed < 8.0:
		return "frisch"
	return "stark"


## Funkmeldung, z. B. „Wind aus Südwest, mäßig, böig“ (am Boden, 10 m).
static func report() -> String:
	if not enabled() or base_speed < 1.0:
		return "Windstill"
	var s := mean_speed_at(time)
	var txt := "Wind aus %s, %s" % [compass_name(from_deg_at(time)), strength_name(s)]
	if not steady and s > 4.0:
		txt += ", böig"
	return txt


## Debug-Text mit Werten.
static func describe() -> String:
	if not enabled():
		return "Wetter: kein Wind (Stufe %s)" % LABELS[level]
	return "Wetter: %s (aus %03.0f°, %.1f m/s in 10 m, Stufe %s, Seed %d)" % [report(), fposmod(from_deg_at(time), 360.0),
		mean_speed_at(time), LABELS[level], seed_value]
