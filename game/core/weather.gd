class_name Weather
extends RefCounted
## Wetter/Wind der Partie (zentral, statisch wie MatchRules/WorldGround). Der Wind ist die
## Bewegung der Luftmasse (m/s, Weltkoordinaten); Flugzeuge fliegen relativ zu ihr (FlightModel),
## Fallschirme, Rauch, Trümmer, Windsäcke, Gras, Bäume und Wasser richten sich danach.
## Grundlagen und Quellen: docs/recherche_windphysik.md.
##
## M3.9 – Modell:
## - Grundwind je Partie aus dem Seed: Richtung „woher“ im Nordsektor (die Pisten liegen in der
##   Hauptwindrichtung), Stärke nach Stufe, bezogen auf 10 m über kurzem Gras (Flugplatz).
## - Wetterentwicklung: langsames Drehen (Großwetterlage, Stunden) und Schwanken (Minuten),
##   Auffrischen/Abflauen über die Partie, in manchen Partien eine Kaltfront (Rechtsdrehung
##   25–55° in ~15 min, frischt auf, eine Zeit lang böiger). Richtung bleibt im Pistensektor.
## - Höhenprofil: logarithmisch mit örtlicher Rauigkeit z0 (Wald, Felder, Wiese, Wasser, Fels)
##   unterhalb der Mischungshöhe (60 m), darüber Log-Profil bis zur Grenzschicht (1.100 m), dann
##   Gradientwind (MAX_FACTOR × Bodenwind). Rechtsdrehung mit der Höhe (Ekman) bis VEER_LAND.
## - Turbulenz: eingefrorenes Feld (Taylor), das mit dem Wind treibt – drei Größenbänder aus
##   FastNoiseLite (nativ, deterministisch per Seed), Gewichte je Höhe nach den Dryden-
##   Längenskalen (MIL-F-8785C: Lw = h, Lu = h/(0,177+0,000823h)^1,2, ab 600 m 533 m),
##   Stärke aus der Schubspannungsgeschwindigkeit u* (σu = 2,4 u*, σv = 1,9 u*, σw = 1,25 u*),
##   dazu Konvektion (Nachmittag) und Böen in Schüben. Rollböe aus der Vertikalwind-Differenz
##   an den Flügelspitzen (sample()). Zwei Flugzeuge nah beieinander und der Windsack spüren
##   dieselben Böen.
## - Gelände (WindTerrain, wenn ein TerrainWorld da ist): Hangauf-/abwind, Lee hinter Kämmen
##   (schwächerer, aber turbulenter Wind), Kanalisierung im Tal, Rauigkeitsübergang (Waldrand im
##   Luv macht böig), Thermik über Feldern/Fels (Zellen, treiben mit dem Wind), Absinken über Wasser.
##
## Alles hängt nur von Seed, Ort (absolut, WorldOrigin) und Weather.time ab – Server und Clients
## rechnen dasselbe. Aus = exakt kein Wind (altes Verhalten). Tests und Selbsttest: aus (reset()).
## set_steady(): fester Wind nur mit Höhenprofil (ohne Drehen, Böen, Gelände) für Tests.

enum Level { AUS, SCHWACH, NORMAL, STARK }
const LEVELS := ["aus", "schwach", "normal", "stark"]
const LABELS := ["Aus", "Schwach", "Normal", "Stark"]
## Grundwind (10 m über Gras, Mittel) je Stufe: [min, max] m/s. Böen kommen aus dem Modell
## (Böenfaktor ≈ 1,3–1,6 je nach Untergrund).
const SPEED_RANGE := [Vector2(0.0, 0.0), Vector2(1.0, 3.0), Vector2(3.0, 6.0), Vector2(6.0, 9.0)]
## Richtung „woher“ (Grad, 0 = Nord = −Z, 90 = Ost): Sektor um Nord
const DIR_SECTOR := 80.0
## Normierung der Böe für die Shader (relative Längsböe ±GUST ↔ 0..1)
const GUST := 0.5
const REF_H := 10.0
## Gradientwind / Bodenwind (10 m, Gras) oberhalb der Grenzschicht
const MAX_FACTOR := 1.7
const KAPPA := 0.4
const Z0_REF := 0.03
const BLEND_H := 60.0
const BL_TOP := 1100.0
## Rechtsdrehung von 10 m bis zur Grenzschicht-Oberkante (Grad)
const VEER_LAND := 25.0
## Turbulenz-Bänder: integrale Längenskala (m; das kleinste nicht für die Rollböe, < Spannweite); FastNoiseLite Simplex, 2 Oktaven:
## L_int ≈ NOISE_L / Frequenz, Standardabweichung NOISE_STD (gemessen, test_wind_model)
const BANDS := [420.0, 105.0, 26.0, 6.5]
const NOISE_L := 0.247
const NOISE_STD := 0.332
## Spielbarkeit: Anteil der bodennahen Vertikal- und Rollböen (unter ~40 m), 1 = voll
const NEAR_GROUND_W := 0.75
## Konvektion am Nachmittag (0 = stabile Nacht … 1 = kräftig); feste Sonne, siehe Recherche
const DAY_CONVECTION := 0.8
## Konvektive Geschwindigkeitsskala w* (m/s) bei voller Konvektion, je Stufe (starker Wind zerreißt Thermik)
const W_STAR := 1.6
const THERMAL_LEVEL := [0.0, 1.0, 0.9, 0.75]
const THERMAL_CELL := 1700.0
const THERMAL_LIFE := 1100.0

static var level: int = Level.AUS
static var seed_value := 0
## Grundwind: Richtung „woher“ (Grad) und Stärke (m/s, 10 m über Gras) zu Beginn
static var base_from_deg := 0.0
static var base_speed := 0.0
## Spielzeit (s), weitergezählt von WeatherDriver
static var time := 0.0
## Fester Wind ohne Böen/Drehen/Gelände (Tests, set_steady)
static var steady := false
## Entwicklung über die Partie: Trend (relativ, über TREND_T), Front (Zeit, Drehung, Auffrischen)
static var trend := 0.0
static var front_time := INF
static var front_veer := 0.0
static var front_fresh := 1.0
const TREND_T := 5400.0
const FRONT_DUR := 900.0
## Gelände-Windgitter (TerrainWorld setzt es) und dessen Knoten (für den Ursprung)
static var terrain: WindTerrain = null
static var terrain_node: Node3D = null

static var _ph := PackedFloat32Array([0, 0, 0, 0, 0, 0, 0, 0])
static var _bands: Array[FastNoiseLite] = []
static var _env := FastNoiseLite.new()
static var _tmp := WindSample.new()
## Bandgewichte je 2 m Höhe (0 … 640 m, darüber konstant)
const _LUT_N := 320
static var _lut_u: Array[Vector4] = []
static var _lut_w: Array[Vector4] = []


static func _build_lut() -> void:
	_lut_u.clear()
	_lut_w.clear()
	for k in _LUT_N:
		var h := k * 2.0 + 1.0
		_lut_u.append(band_weights(_len_u(h)))
		_lut_w.append(band_weights(_len_w(h)))


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
	# Entwicklung: Trend ±30 % über 1,5 h; Front in ~35 % der Partien (Schwach seltener)
	trend = rng.randf_range(-0.3, 0.3)
	front_time = INF
	front_veer = 0.0
	front_fresh = 1.0
	var p_front := 0.15 if level == Level.SCHWACH else 0.35
	if level != Level.AUS and rng.randf() < p_front:
		front_time = rng.randf_range(1800.0, 6000.0)
		front_veer = rng.randf_range(25.0, 55.0)
		front_fresh = rng.randf_range(1.2, 1.45)
		# nach der Front noch im Pistensektor (Front dreht rechts herum)
		base_from_deg = minf(base_from_deg, DIR_SECTOR - front_veer - 15.0)
	_setup_noise(s)


static func _setup_noise(s: int) -> void:
	if _bands.is_empty():
		for i in BANDS.size():
			var n := FastNoiseLite.new()
			n.noise_type = FastNoiseLite.TYPE_SIMPLEX
			n.fractal_type = FastNoiseLite.FRACTAL_FBM
			n.fractal_octaves = 2
			n.fractal_gain = 0.5
			n.frequency = NOISE_L / BANDS[i]
			_bands.append(n)
	for i in _bands.size():
		_bands[i].seed = s * 7 + i * 101
	_env.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_env.fractal_type = FastNoiseLite.FRACTAL_NONE
	_env.frequency = 1.0 / 1400.0
	_env.seed = s * 7 + 977


## Fester Wind (Tests): Richtung „woher“ in Grad, Stärke m/s; Böen, Drehen, Gelände aus.
static func set_steady(from_deg: float, speed: float) -> void:
	level = Level.NORMAL if speed > 0.0 else Level.AUS
	base_from_deg = from_deg
	base_speed = speed
	steady = true
	front_time = INF


static func enabled() -> bool:
	return level != Level.AUS and base_speed > 0.0


static func parse_level(s: String) -> int:
	return LEVELS.find(s.strip_edges().to_lower())


## Gelände-Windgitter anmelden/abmelden (TerrainWorld).
static func set_terrain(wt: WindTerrain, node: Node3D) -> void:
	terrain = wt
	terrain_node = node


static func clear_terrain(node: Node3D = null) -> void:
	if node == null or terrain_node == node:
		terrain = null
		terrain_node = null


# --- Großwetter ---------------------------------------------------------------------------

## Fortschritt der Front 0..1 zur Zeit t.
static func front_progress(t: float) -> float:
	if front_time == INF:
		return 0.0
	return smoothstep(front_time - FRONT_DUR * 0.5, front_time + FRONT_DUR * 0.5, t)


## Böigkeits-Zuschlag um den Frontdurchgang (0 … ~0,6).
static func front_gustiness(t: float) -> float:
	if front_time == INF:
		return 0.0
	var x := (t - front_time) / (FRONT_DUR * 1.2)
	return 0.6 * exp(-x * x)


## M3.13: Bedeckung 0..1 (Himmel, Licht, Nebel): vor einer Kaltfront zieht es zu, beim Durchgang
## bedeckt, dahinter klart es auf (Rückseitenwetter). Ohne Front/ohne Wind 0 (klarer Nachmittag).
static func overcast_at(t: float) -> float:
	if front_time == INF or not enabled() or steady:
		return 0.0
	var x := (t - front_time + FRONT_DUR * 0.4) / (FRONT_DUR * 1.6)
	return clampf(1.5 * exp(-x * x), 0.0, 1.0)


## Richtung „woher“ (Grad, 10 m) zur Zeit t: Großwetter dreht langsam, schwankt über Minuten.
static func from_deg_at(t: float) -> float:
	if steady:
		return base_from_deg
	var d := base_from_deg + 10.0 * (sin(t / 2300.0 + _ph[0]) - sin(_ph[0])) + 6.0 * sin(t / 420.0 + _ph[1]) \
		+ 3.0 * sin(t / 137.0 + _ph[2])
	d += front_veer * front_progress(t)
	# Pistensektor: weich auf ±(DIR_SECTOR + 15°) begrenzen (die Pisten liegen in der Hauptwindrichtung)
	var lim := DIR_SECTOR + 5.0
	if absf(d) > lim:
		d = signf(d) * (lim + 10.0 * tanh((absf(d) - lim) / 10.0))
	return d


## Grundstärke (10 m über Gras, ohne Böen) zur Zeit t.
static func mean_speed_at(t: float) -> float:
	if steady:
		return base_speed
	var s := base_speed * (1.0 + trend * clampf(t / TREND_T, 0.0, 1.0)) * (1.0 + 0.08 * sin(t / 610.0 + _ph[3]))
	s *= lerpf(1.0, front_fresh, front_progress(t))
	return minf(s, SPEED_RANGE[level].y * 1.15)


## Höhenfaktor über Gras (1 bei 10 m, MAX_FACTOR ab der Grenzschicht).
static func height_factor(agl: float) -> float:
	return _profile(agl, Z0_REF, 0.0)


## Profilfaktor (Wind in agl / Bodenwind 10 m über Gras) bei örtlicher Rauigkeit z0, Verdrängung d.
static func _profile(agl: float, z0: float, d: float) -> float:
	var lr := log(BLEND_H / Z0_REF)
	var fb := lr / log(REF_H / Z0_REF)           # Faktor in Mischungshöhe (≈ 1,31)
	if agl >= BLEND_H:
		var g := clampf(log(agl / BLEND_H) / log(BL_TOP / BLEND_H), 0.0, 1.0)
		return fb + (MAX_FACTOR - fb) * pow(g, 0.85)
	var zz := maxf(agl - d, z0 * 3.0 + 0.2)
	var top := maxf(BLEND_H - d, zz + 0.1)
	return fb * maxf(log(zz / z0), 0.0) / log(top / z0)


## Einheitsvektor „wohin“ der Wind weht (waagerecht).
static func dir_to(from_deg: float) -> Vector3:
	var r := deg_to_rad(from_deg)
	return -Vector3(sin(r), 0.0, -cos(r))


# --- Abfragen ----------------------------------------------------------------------------

## Wind (Luftbewegung, m/s) an Szenen-Position p. Höhe über Grund aus WorldGround.
static func wind_at(p: Vector3) -> Vector3:
	if not enabled():
		return Vector3.ZERO
	var agl := p.y - WorldGround.height_at(p.x, p.z)
	return wind_at_agl(p, agl)


static func wind_at_agl(p: Vector3, agl: float) -> Vector3:
	if not enabled():
		return Vector3.ZERO
	sample(_tmp, p, agl)
	return _tmp.total


## Wind am Boden für Windsäcke/Gras (Windsack-Höhe 7 m), mit Böen.
static func surface_wind(p: Vector3, h := 7.0) -> Vector3:
	return wind_at_agl(p, h)


## Relative Längsböe (u'/U, etwa ±0,5) an Szenen-Position p in 10 m über Grund – für die Shader.
static func gust_at(_t: float, p: Vector3) -> float:
	if not enabled() or steady:
		return 0.0
	sample(_tmp, p, REF_H)
	var m := _tmp.mean
	var ml := m.length()
	return _tmp.turb.dot(m / ml) / ml if ml > 0.1 else 0.0


## Vollständige Abfrage mit Anteilen. agl = Höhe über Grund (NAN: aus WorldGround).
## right/span: Querachse und Spannweite des Flugzeugs für die Rollböe (span = 0: keine).
static func sample(out: WindSample, p: Vector3, agl := NAN, right := Vector3.ZERO, span := 0.0) -> void:
	out.clear()
	if not enabled():
		return
	if is_nan(agl):
		agl = p.y - WorldGround.height_at(p.x, p.z)
	agl = maxf(agl, 0.0)
	out.agl = agl
	var t := time
	var deg := from_deg_at(t)
	var u10 := mean_speed_at(t)
	if steady:
		out.mean = dir_to(deg) * u10 * height_factor(agl)
		out.total = out.mean
		return
	# --- Gelände ---
	var z0 := Z0_REF
	var d := 0.0
	var z0_up := Z0_REF
	var src := 0.55
	var oro := 0.0
	var lee := 0.0
	var chan := 0.0
	var dir := dir_to(deg)
	var wt := terrain
	var lx := 0.0
	var lz := 0.0
	if wt != null and is_instance_valid(terrain_node) and terrain_node.is_inside_tree():
		var o: Vector3 = terrain_node.origin()
		lx = p.x - o.x
		lz = p.z - o.z
		z0 = exp(wt.at(wt.ln_z0, lx, lz))
		d = minf(wt.at(wt.disp, lx, lz), agl * 0.7)
		z0_up = exp(wt.at(wt.ln_z0, lx - dir.x * 250.0, lz - dir.z * 250.0))
		src = wt.at(wt.src, lx, lz)
		var hh := wt.at(wt.h1, lx, lz)
		var y := p.y - o.y
		# Lee: Kamm im Luv höher als hier, Flugzeug unterhalb der Kammhöhe
		var hu1 := wt.at(wt.h1, lx - dir.x * 500.0, lz - dir.z * 500.0)
		var hu2 := wt.at(wt.h1, lx - dir.x * 1100.0, lz - dir.z * 1100.0)
		var hup := maxf(hu1, hu2)
		var shelter := hup - hh
		if shelter > 20.0:
			var u_ridge := u10 * _profile(maxf(hup - hh, 10.0), Z0_REF, 0.0)
			lee = smoothstep(20.0, 140.0, shelter) * (1.0 - smoothstep(hup - 0.3 * shelter, hup + 0.8 * shelter, y)) \
				* smoothstep(3.0, 8.0, u_ridge)
		# Kanalisierung im Tal (unterhalb der Talränder)
		var ac := wt.at(wt.ax_c, lx, lz)
		var as_ := wt.at(wt.ax_s, lx, lz)
		var cs := sqrt(ac * ac + as_ * as_)
		if cs > 0.02:
			var dpt := maxf(wt.at(wt.depth, lx, lz), 1.0)
			chan = cs * (1.0 - smoothstep(0.5 * dpt, 1.3 * dpt, agl))
			if chan > 0.0:
				var th := 0.5 * atan2(as_, ac)
				var ax := Vector3(cos(th), 0.0, sin(th))
				var al := signf(ax.dot(dir)) if absf(ax.dot(dir)) > 1e-3 else 1.0
				dir = dir.lerp(ax * al, 0.6 * chan).normalized()
		# Hangwind: Strömung folgt dem Gelände (U · ∇H), klingt mit der Höhe ab
		var g := Vector3(wt.at(wt.gx, lx, lz), 0.0, wt.at(wt.gz, lx, lz))
		oro = dir.dot(g)
	out.z0 = z0
	out.lee = lee
	out.channel = chan
	# --- mittlerer Wind ---
	var prof := _profile(agl, z0, d)
	var spd := u10 * prof * (1.0 - 0.35 * lee)
	var veer := VEER_LAND * clampf(log(maxf(agl, REF_H) / REF_H) / log(BL_TOP / REF_H), 0.0, 1.0)
	var mdir := dir.rotated(Vector3.UP, -deg_to_rad(veer))   # „woher“ wächst im Uhrzeigersinn
	out.mean = mdir * spd
	var w_oro := clampf(oro * spd, -0.35 * spd, 0.35 * spd) * exp(-agl / 350.0) * (1.0 - 0.5 * lee)
	out.orographic = w_oro
	# --- Turbulenz ---
	var ub := u10 * _profile(BLEND_H, Z0_REF, 0.0)
	var z0t := maxf(z0, 0.5 * z0_up)
	var ustar := KAPPA * ub / log(maxf(BLEND_H - d, 1.0) / z0t)
	var dec := 1.0 - smoothstep(0.55 * BL_TOP, 1.2 * BL_TOP, agl)
	var hu := 0.45 + 0.55 * exp(-agl / 120.0)
	var su := 2.4 * ustar * hu * dec
	var sv := 1.9 * ustar * hu * dec
	var sw := 1.25 * ustar * dec
	# Konvektion (Nachmittag): σw ~ w* (z/zi)^⅓ (1 − 0,8 z/zi), σu,v ~ 0,5 w*
	var conv := _convection(u10)
	var zr := clampf(agl / BL_TOP, 0.0, 1.0)
	var swc := 1.0 * W_STAR * conv * pow(maxf(zr, 1e-4), 1.0 / 3.0) * (1.0 - 0.8 * zr) * dec
	var suc := 0.5 * W_STAR * conv * dec
	# freie Atmosphäre: schwache Restturbulenz
	var sfree := (0.12 + 0.02 * u10 * MAX_FACTOR) * (1.0 - dec)
	su = sqrt(su * su + suc * suc) + sfree
	sv = sqrt(sv * sv + suc * suc) + sfree
	sw = sqrt(sw * sw + swc * swc) + sfree
	var amp := (1.0 + 1.5 * lee) * (1.0 + front_gustiness(t))
	var near := lerpf(NEAR_GROUND_W, 1.0, smoothstep(10.0, 40.0, agl))
	out.sigma = Vector3(su, sv, sw * near) * amp
	# eingefrorenes Feld, treibt mit dem Wind (Bezug: Grundwind in ~100 m); Wirbel steigen langsam
	var pa := WorldOrigin.to_abs(p)
	var adv := dir_to(base_from_deg) * maxf(base_speed, 1.0) * 1.35
	var qx := pa.x - adv.x * t
	var qz := pa.z - adv.z * t
	var qy := pa.y - 0.4 * t
	var env := clampf(1.0 + 1.1 * _env.get_noise_3d(qx, qy * 0.3, qz), 0.35, 1.9) / 1.08
	var li := clampi(int(agl * 0.5), 0, _LUT_N - 1)
	if _lut_u.is_empty():
		_build_lut()
	var bu: Vector4 = _lut_u[li]
	var bw: Vector4 = _lut_w[li]
	var tu := 0.0
	var tv := 0.0
	var tw := 0.0
	for i in 4:
		var n := _bands[i]
		var wuv: float = bu[i]
		var ww: float = bw[i]
		tu += wuv * n.get_noise_3d(qx, qy, qz)
		tv += wuv * n.get_noise_3d(qx + 7919.3, qy + 311.7, qz - 5113.1)
		tw += ww * n.get_noise_3d(qx - 3301.7, qy - 911.3, qz + 2207.9)
	var k := env / NOISE_STD
	var side := Vector3(-mdir.z, 0.0, mdir.x)
	out.turb = mdir * (tu * k * out.sigma.x) + side * (tv * k * out.sigma.y) + Vector3.UP * (tw * k * out.sigma.z)
	# Rollböe: Vertikalwind der kleinen Bänder an den Flügelspitzen
	if span > 0.0 and right != Vector3.ZERO:
		var h := right * (span * 0.5)
		var dw := 0.0
		for i in range(1, 3):
			var n := _bands[i]
			var ww: float = bw[i]
			dw += ww * (n.get_noise_3d(qx + h.x - 3301.7, qy + h.y - 911.3, qz + h.z + 2207.9)
				- n.get_noise_3d(qx - h.x - 3301.7, qy - h.y - 911.3, qz - h.z + 2207.9))
		out.roll_grad = dw * k * out.sigma.z / span
	# --- Thermik, Absinken über Wasser ---
	if conv > 0.0 and agl < BL_TOP:
		out.thermal = _thermals(Vector2(qx, qz), p, agl, conv, t, src)
	out.total = out.mean + out.turb + Vector3.UP * (out.orographic + out.thermal)


## Konvektionsstärke 0..1 (Tageszeit, Stufe; starker Wind zerreißt die Thermik).
static func _convection(u10: float) -> float:
	return DAY_CONVECTION * THERMAL_LEVEL[level] * clampf(1.25 - u10 / 9.0, 0.35, 1.0)


## Dryden-Längenskalen (m) über Grund (MIL-F-8785C, Formeln in ft).
static func _len_u(agl: float) -> float:
	var hf := clampf(agl, 1.0, 1000.0 / 3.28084 * 1.0) * 3.28084
	var lo := hf / pow(0.177 + 0.000823 * hf, 1.2) / 3.28084
	return lerpf(lo, 533.0, smoothstep(300.0, 600.0, agl))


static func _len_w(agl: float) -> float:
	return lerpf(clampf(agl, 1.0, 305.0), 533.0, smoothstep(300.0, 600.0, agl))


## Anteile (Amplituden) der Bänder bei Ziel-Längenskala L: Bänder bis L mit Kolmogorov-Abfall
## zu kleinen Skalen (σ² ∝ L^⅔), größere Bänder stark gedämpft; Σ w² = 1.
static func band_weights(l: float) -> Vector4:
	var e := Vector4.ZERO
	for j in 4:
		var r: float = BANDS[j] / l
		e[j] = pow(r, 2.0 / 3.0) if r <= 1.0 else 1.0 / (r * r * r)
	return Vector4(sqrt(e.x), sqrt(e.y), sqrt(e.z), sqrt(e.w)) / sqrt(e.x + e.y + e.z + e.w)


## Thermikzellen (Hash-Gitter, treiben mit dem Wind, leben ~18 min) und Absinken über Wasser.
static func _thermals(q: Vector2, p: Vector3, agl: float, conv: float, t: float, src_here: float) -> float:
	var zr := agl / BL_TOP
	var prof := pow(maxf(zr, 1e-4), 1.0 / 3.0) * maxf(1.0 - 1.1 * zr * zr, 0.0) * smoothstep(5.0, 80.0, agl)
	if prof <= 0.0:
		return 0.0
	var wmax := 2.6 * W_STAR * conv
	var radius := 70.0 + 0.12 * agl
	var fx := q.x / THERMAL_CELL
	var fz := q.y / THERMAL_CELL
	var cx := floori(fx)
	var cz := floori(fz)
	var ox := -1 if fx - cx < 0.5 else 1
	var oz := -1 if fz - cz < 0.5 else 1
	var w := 0.0
	for c in 4:
		var ix := cx + (ox if c & 1 else 0)
		var iz := cz + (oz if c & 2 else 0)
		var hx := _h01(ix, iz, 1)
		var hz := _h01(ix, iz, 2)
		var ctr := Vector2((ix + 0.15 + 0.7 * hx) * THERMAL_CELL, (iz + 0.15 + 0.7 * hz) * THERMAL_CELL)
		var r2 := (q - ctr).length_squared() / (radius * radius)
		if r2 > 9.0:
			continue
		var life := fposmod(t / THERMAL_LIFE + _h01(ix, iz, 3), 1.0)
		var env := sin(PI * life)
		var strength := 0.6 + 0.8 * _h01(ix, iz, 4)
		# Auslöser am Boden unter der Thermik (Felder/Fels gut, Wald schwach, Wasser keine)
		var s := src_here
		var wt := terrain
		if wt != null and is_instance_valid(terrain_node):
			var o: Vector3 = terrain_node.origin()
			s = wt.at(wt.src, p.x + ctr.x - q.x - o.x, p.z + ctr.y - q.y - o.z)
		w += wmax * maxf(s, 0.0) * strength * env * exp(-r2)
	# Ausgleich: leichtes Absinken zwischen den Thermiken, stärker über Wasser
	w -= 0.12 * W_STAR * conv + 0.5 * W_STAR * conv * maxf(-src_here, 0.0)
	return w * prof


static func _h01(ix: int, iz: int, k: int) -> float:
	var h := (ix * 73856093) ^ (iz * 19349663) ^ (seed_value * 83492791) ^ (k * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFFFF) / 16777216.0


# --- Meldungen ---------------------------------------------------------------------------

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


static func strength_class(speed: float) -> int:
	return ["still", "schwach", "mäßig", "frisch", "stark"].find(strength_name(speed))


## Böig? (Böenfaktor über Gras > ~1,4 oder Front)
static func gusty_at(t: float) -> bool:
	return not steady and mean_speed_at(t) > 4.0 or front_gustiness(t) > 0.2


## Funkmeldung, z. B. „Wind aus Südwest, mäßig, böig“ (am Boden, 10 m).
static func report() -> String:
	if not enabled() or base_speed < 1.0:
		return "Windstill"
	var s := mean_speed_at(time)
	var txt := "Wind aus %s, %s" % [compass_name(from_deg_at(time)), strength_name(s)]
	if not steady and gusty_at(time):
		txt += ", böig"
	return txt


## Zustand für Änderungsmeldungen: [Richtung 0..7, Stärkeklasse, Front 0/1]
static func report_state(t: float) -> Array:
	var sec := posmod(int(round(fposmod(from_deg_at(t), 360.0) / 45.0)), 8)
	return [sec, strength_class(mean_speed_at(t)), 1 if front_gustiness(t) > 0.3 else 0]


## Meldung bei Änderung (leer = nichts zu melden), z. B. „Wind dreht auf West, frischt auf“.
static func change_report(prev: Array, now: Array) -> String:
	if not enabled() or prev.is_empty():
		return ""
	var parts: Array[String] = []
	if now[2] == 1 and prev[2] == 0:
		parts.append("Front zieht durch")
	if now[0] != prev[0]:
		parts.append("Wind dreht auf %s" % compass_name(now[0] * 45.0))
	if now[1] > prev[1]:
		parts.append("frischt auf" if not parts.is_empty() else "Wind frischt auf")
	elif now[1] < prev[1]:
		parts.append("flaut ab" if not parts.is_empty() else "Wind flaut ab")
	if parts.is_empty():
		return ""
	var txt := ", ".join(parts)
	if now[2] == 1:
		txt += ", böig"
	return txt


## Debug-Text mit Werten.
static func describe() -> String:
	if not enabled():
		return "Wetter: kein Wind (Stufe %s)" % LABELS[level]
	var fr := ""
	if front_time != INF:
		fr = ", Front bei %.0f min (+%.0f°, ×%.2f)" % [front_time / 60.0, front_veer, front_fresh]
	return "Wetter: %s (aus %03.0f°, %.1f m/s in 10 m, Stufe %s, Seed %d, Trend %+.0f %%%s)" % [report(),
		fposmod(from_deg_at(time), 360.0), mean_speed_at(time), LABELS[level], seed_value, trend * 100.0, fr]
