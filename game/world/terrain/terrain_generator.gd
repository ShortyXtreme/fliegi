class_name TerrainGenerator
extends RefCounted
## Erzeugt die Prototyp-Karte (40 × 40 km) deterministisch aus einem festen Seed.
## Hügelland, zwei Bergzüge (je Seite einer, mit Erzmine), ein Talzug von Nordwest nach
## Südost für den späteren Fluss, zwei geglättete Flugplätze ~25 km auseinander und
## geglättete Flächen für die späteren Ziele. Aufruf über tools/build_terrain.gd.

const SIZE_M := 40000.0
const SAMPLES := 2049
const TILES := 16
const MASK_RES := 1024
const QUANT := 64.0   # Höhen auf 1/64 m runden (exakt als float32 darstellbar)

const RUNWAY_HALF_W := 170.0     # geglättete Platzfläche (halbe Breite, x)
const RUNWAY_HALF_L := 780.0     # geglättete Platzfläche (halbe Länge, z)
const PAD_BLEND := 650.0
const RIVER_FLOOR_HALF := 260.0
const RIVER_VALLEY := 2300.0

var seed: int
var _n_base := FastNoiseLite.new()
var _n_mask := FastNoiseLite.new()
var _n_ridge := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()
var _n_forest := FastNoiseLite.new()
var _n_meadow := FastNoiseLite.new()
var _mountains: Array = []   # [Vector2 Mitte, sigma]
var pads: Array[Dictionary] = []   # {pos: Vector2, rect: Vector2 (halbe Maße) oder radius, h}


func _init(p_seed: int = 1916) -> void:
	seed = p_seed
	_setup(_n_base, 0, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0 / 9000.0, 5)
	_setup(_n_mask, 1, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0 / 7000.0, 2)
	_setup(_n_ridge, 2, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0 / 3800.0, 4)
	_setup(_n_detail, 3, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0 / 450.0, 3)
	_setup(_n_forest, 4, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0 / 2400.0, 4)
	_setup(_n_meadow, 5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 1.0 / 5000.0, 2)
	# Bergzüge: West (Seite Blau) und Ost (Seite Rot), je ~6 km Ausdehnung
	_mountains = [[Vector2(-15500, -3500), 5200.0], [Vector2(15800, 3200), 5200.0],
		[Vector2(-3000, -16500), 3800.0], [Vector2(3500, 16800), 3800.0]]


func _setup(n: FastNoiseLite, off: int, t: int, f: float, oct: int) -> void:
	n.seed = seed + off * 7919
	n.noise_type = t
	n.frequency = f
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = oct


# --- Talzug -----------------------------------------------------------------------

## Achsen: u entlang der Diagonale NW→SO, v quer dazu (v < 0 Seite Blau / Südwest).
static func to_uv(x: float, z: float) -> Vector2:
	return Vector2((x + z), (x - z)) * 0.70710678


static func from_uv(u: float, v: float) -> Vector2:
	return Vector2(u + v, u - v) * 0.70710678


static func river_v(u: float) -> float:
	return 1800.0 * sin(u / 4300.0 + 0.4) + 650.0 * sin(u / 1500.0 + 1.3)


static func river_floor(u: float) -> float:
	return 55.0 - u / 28284.0 * 20.0


## Abstand zur Fluss-Mittellinie (genähert, quer zur Diagonale, mit Neigungskorrektur).
static func river_dist(x: float, z: float) -> float:
	var uv := to_uv(x, z)
	var dv := uv.y - river_v(uv.x)
	var slope := (river_v(uv.x + 5.0) - river_v(uv.x - 5.0)) / 10.0
	return absf(dv) / sqrt(1.0 + slope * slope)


static func river_point(u: float) -> Vector2:
	return from_uv(u, river_v(u))


# --- Höhe -------------------------------------------------------------------------

func mountain_weight(x: float, z: float) -> float:
	var w := 0.0
	for m in _mountains:
		var d: float = (Vector2(x, z) - m[0]).length() / m[1]
		w = maxf(w, exp(-d * d))
	return clampf(w * (0.75 + 0.45 * _n_mask.get_noise_2d(x, z)), 0.0, 1.0)


## Höhe ohne Platz-Glättung.
func raw_height(x: float, z: float) -> float:
	var h := 130.0 + 95.0 * _n_base.get_noise_2d(x, z)
	var r := 1.0 - absf(_n_ridge.get_noise_2d(x, z))
	h += mountain_weight(x, z) * (180.0 + 560.0 * r * r)
	h += 7.0 * _n_detail.get_noise_2d(x, z)
	# Talzug
	var uv := to_uv(x, z)
	var d := river_dist(x, z)
	var w := 1.0 - smoothstep(RIVER_FLOOR_HALF, RIVER_VALLEY, d)
	var floor_h := river_floor(uv.x) + 2.0 * _n_detail.get_noise_2d(x * 0.5, z * 0.5)
	h = lerpf(h, floor_h, w * w * (3.0 - 2.0 * w))
	if d < 45.0:
		var k := d / 45.0
		h -= 3.5 * (1.0 - k * k)
	# Kartenrand: sanft nach außen ansteigen (natürliche Grenze)
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(17500.0, 20000.0, edge) * 140.0
	return h


func _add_rect_pad(name: String, c: Vector2, half: Vector2, nation: int) -> Dictionary:
	var p := {"name": name, "pos": c, "half": half, "radius": 0.0, "h": raw_height(c.x, c.y), "nation": nation}
	pads.append(p)
	return p


func _add_round_pad(name: String, c: Vector2, radius: float, nation: int) -> Dictionary:
	# Mittlere Höhe über die Fläche, damit nicht auf einer Kuppe/Mulde geglättet wird
	var s := 0.0
	for i in 9:
		var a := i * TAU / 8.0
		var rr := 0.0 if i == 8 else radius
		s += raw_height(c.x + cos(a) * rr, c.y + sin(a) * rr)
	var p := {"name": name, "pos": c, "half": Vector2.ZERO, "radius": radius, "h": s / 9.0, "nation": nation}
	pads.append(p)
	return p


## Abstand außerhalb einer Platzfläche (0 innen).
static func pad_dist(p: Dictionary, x: float, z: float) -> float:
	var c: Vector2 = p.pos
	if p.radius > 0.0:
		return maxf(0.0, Vector2(x, z).distance_to(c) - p.radius)
	var q := Vector2(absf(x - c.x), absf(z - c.y)) - (p.half as Vector2)
	return Vector2(maxf(q.x, 0.0), maxf(q.y, 0.0)).length()


func height(x: float, z: float) -> float:
	var h := raw_height(x, z)
	for p in pads:
		var d := pad_dist(p, x, z)
		if d < PAD_BLEND:
			var w := 1.0 - smoothstep(0.0, PAD_BLEND, d)
			h = lerpf(h, p.h, w)
	return h


# --- Aufbau -----------------------------------------------------------------------

func build() -> TerrainData:
	var td := TerrainData.new()
	td.seed = seed
	td.size_m = SIZE_M
	td.samples = SAMPLES
	td.tiles = TILES
	pads.clear()
	# Flugplätze (Pisten entlang -Z), Diagonale ~24,8 km
	var af := [["Platz Blau", Vector2(-9000, 8500), Nations.BLUE], ["Platz Rot", Vector2(9000, -8500), Nations.RED]]
	for a in af:
		var p := _add_rect_pad(a[0], a[1], Vector2(RUNWAY_HALF_W, RUNWAY_HALF_L), a[2])
		td.airfields.append({"name": a[0], "center": Vector3(a[1].x, p.h, a[1].y),
			"length": 900.0, "width": 40.0, "nation": a[2]})
	# Ziele (je Seite Erzmine, Raffinerie/Tanklager, Fabrik; zwei Brücken über den Talzug)
	var tg := [
		["erzmine", "Erzmine West", Vector2(-12600, -1800), 180.0, Nations.BLUE],
		["erzmine", "Erzmine Ost", Vector2(12800, 1500), 180.0, Nations.RED],
		["raffinerie", "Raffinerie/Tanklager West", Vector2(-5200, 2600), 260.0, Nations.BLUE],
		["raffinerie", "Raffinerie/Tanklager Ost", Vector2(5400, -2900), 260.0, Nations.RED],
		["fabrik", "Fabrik West", Vector2(-14500, 13500), 240.0, Nations.BLUE],
		["fabrik", "Fabrik Ost", Vector2(14200, -13800), 240.0, Nations.RED],
	]
	for t in tg:
		var p := _add_round_pad(t[1], t[2], t[3], t[4])
		td.targets.append({"type": t[0], "name": t[1], "pos": Vector3(t[2].x, p.h, t[2].y), "radius": t[3], "nation": t[4]})
	for bu in [-7000.0, 6500.0]:
		var bp := river_point(bu)
		td.targets.append({"type": "bruecke", "name": "Brücke %s" % ("Nord" if bu < 0 else "Süd"),
			"pos": Vector3(bp.x, river_floor(bu), bp.y), "radius": 60.0, "nation": Nations.NONE})
	for i in 141:
		var u := -28000.0 + i * 400.0
		var rp := river_point(u)
		if absf(rp.x) <= SIZE_M * 0.5 and absf(rp.y) <= SIZE_M * 0.5:
			td.river.append(rp)

	# Höhen
	var n := SAMPLES
	var sp := SIZE_M / float(n - 1)
	var half := SIZE_M * 0.5
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for j in n:
		var z := -half + j * sp
		for i in n:
			var x := -half + i * sp
			hs[j * n + i] = roundf(height(x, z) * QUANT) / QUANT
	var raw := hs.to_byte_array()
	td.heights_raw_size = raw.size()
	td.heights_zstd = raw.compress(FileAccess.COMPRESSION_ZSTD)
	# Min/Max je Kachel
	var cells := (n - 1) / TILES
	td.tile_minmax.resize(TILES * TILES * 2)
	for tz in TILES:
		for tx in TILES:
			var mn := INF
			var mx := -INF
			for j in cells + 1:
				var row := (tz * cells + j) * n + tx * cells
				for i in cells + 1:
					var v := hs[row + i]
					mn = minf(mn, v)
					mx = maxf(mx, v)
			td.tile_minmax[(tz * TILES + tx) * 2] = mn
			td.tile_minmax[(tz * TILES + tx) * 2 + 1] = mx
	td.mask_png = _build_mask(hs, sp).save_png_to_buffer()
	return td


func _build_mask(hs: PackedFloat32Array, sp: float) -> Image:
	var img := Image.create(MASK_RES, MASK_RES, false, Image.FORMAT_RGBA8)
	var n := SAMPLES
	var half := SIZE_M * 0.5
	var px := SIZE_M / MASK_RES
	for j in MASK_RES:
		var z := -half + (j + 0.5) * px
		for i in MASK_RES:
			var x := -half + (i + 0.5) * px
			var gi := clampi(int(round((x + half) / sp)), 1, n - 2)
			var gj := clampi(int(round((z + half) / sp)), 1, n - 2)
			var h := hs[gj * n + gi]
			var dx := (hs[gj * n + gi + 1] - hs[gj * n + gi - 1]) / (2.0 * sp)
			var dz := (hs[(gj + 1) * n + gi] - hs[(gj - 1) * n + gi]) / (2.0 * sp)
			var slope := sqrt(dx * dx + dz * dz)
			# Plätze/Ziele: gemähte bzw. offene Fläche
			var cleared := 0.0
			var near_pad := 0.0
			for p in pads:
				var d := pad_dist(p, x, z)
				cleared = maxf(cleared, 1.0 - smoothstep(0.0, 60.0, d))
				near_pad = maxf(near_pad, 1.0 - smoothstep(0.0, 350.0, d))
			# Wasser/Aue
			var rd := river_dist(x, z)
			var water := 1.0 - smoothstep(18.0, 34.0, rd)
			var wet := (1.0 - smoothstep(60.0, 700.0, rd)) * 0.6
			# Wald: Flecken, eher an Hängen und in Hügellagen, nicht im Fels
			var f := _n_forest.get_noise_2d(x, z)
			f += clampf(slope * 1.6, 0.0, 0.35) - 0.12
			f -= smoothstep(650.0, 900.0, h) * 0.6
			f -= smoothstep(0.55, 0.9, slope) * 0.8
			var forest := smoothstep(0.16, 0.3, f) * (1.0 - near_pad) * smoothstep(40.0, 90.0, rd)
			# Felder: flach, tiefer gelegen, kein Wald; großflächige Wiesen-Inseln dazwischen
			var m := _n_meadow.get_noise_2d(x, z)
			var fields := (1.0 - smoothstep(0.08, 0.2, slope)) * (1.0 - smoothstep(380.0, 520.0, h))
			fields *= (1.0 - forest) * (1.0 - near_pad) * smoothstep(-0.35, -0.1, m)
			fields *= 1.0 - water
			img.set_pixel(i, j, Color(forest, cleared, maxf(water, wet * (1.0 - forest)), fields))
	return img
