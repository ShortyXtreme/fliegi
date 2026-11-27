class_name TerrainGenerator
extends RefCounted
## Erzeugt die Prototyp-Karte (40 × 40 km) deterministisch aus einem festen Seed.
## Hügelland, zwei Bergzüge (je Seite einer, mit Erzmine), ein Talzug von Nordwest nach
## Südost mit dem Hauptfluss, zwei geglättete Flugplätze ~25 km auseinander und
## geglättete Flächen für die späteren Ziele. Aufruf über tools/build_terrain.gd.
## M3.8: Hauptfluss im Talzug (eingeschnittenes Bett, Wasserspiegel fällt nach Südost) und
## drei Bäche, die von den Bergen bergab in ihn münden (Lauf per Gefälle gesucht, Wasserspiegel
## stromabwärts monoton, Bett und Ufer ins Gelände geschnitten). Gewässernetz in
## TerrainData.waters (RiverNet), Uferabstand/Wasserspiegel als Textur TerrainData.shore_png.

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
## M3.8: Hauptfluss – halbe Wasserbreite, Wasserspiegel unter der Talsohle, Tiefe unter dem Spiegel
const RIVER_HW := 36.0
const RIVER_BANK := 34.0
const RIVER_LEVEL_DROP := 1.2
const RIVER_DEPTH := 2.8
## Bäche: halbe Wasserbreite Quelle → Mündung, Tiefe, Ufer-Neigung
const STREAM_HW := Vector2(11.0, 15.0)
const STREAM_DEPTH := 1.6
const STREAM_BANK_SLOPE := 0.28
const STREAM_STEP := 20.0
## Quellen der Bäche (Gelände-Koordinaten), je an einem Bergzug: Nord, West, Süd.
const STREAM_SOURCES := [["Nordbach", Vector2(-3600.0, -13800.0)], ["Westbach", Vector2(-14200.0, -6800.0)],
	["Südbach", Vector2(4600.0, 14000.0)]]
## Freihaltung der Bäche um Flugplätze (Platz, Rollwege, An-/Abflugschneisen; halbe Maße x, z)
const STREAM_AF_KEEP := Vector2(1400.0, 6200.0)
const SHORE_ENC := 2.0       # Uferabstand in der Textur: 0,5 m je Stufe
const SHORE_OFF := 64.0      # Stufe 64 = Wasserkante

var seed: int
var _n_base := FastNoiseLite.new()
var _n_mask := FastNoiseLite.new()
var _n_ridge := FastNoiseLite.new()
var _n_detail := FastNoiseLite.new()
var _n_forest := FastNoiseLite.new()
var _n_meadow := FastNoiseLite.new()
var _mountains: Array = []   # [Vector2 Mitte, sigma]
var pads: Array[Dictionary] = []   # {pos: Vector2, rect: Vector2 (halbe Maße) oder radius, h}
## M3.8: Gewässer (Hauptfluss + Bäche) und nur die Bäche (für das Einschneiden)
var waters: Array[Dictionary] = []
var net: RiverNet
var _stream_net: RiverNet


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
	# M3.8: zwei kleinere Mäanderwellen dazu (der Fluss pendelt in der Talsohle)
	return 1800.0 * sin(u / 4300.0 + 0.4) + 650.0 * sin(u / 1500.0 + 1.3) \
		+ 170.0 * sin(u / 520.0 + 2.1) + 95.0 * sin(u / 310.0 + 0.2) + 40.0 * sin(u / 190.0 + 0.7)


## M3.8: halbe Wasserbreite des Hauptflusses an Talachse u (wechselt zwischen ~28 und ~46 m).
static func river_hw(u: float) -> float:
	return RIVER_HW + 6.0 * sin(u / 950.0 + 0.3) + 4.0 * sin(u / 410.0 + 1.9)


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
	var h := base_height(x, z)
	if _stream_net != null:
		h = _carve_streams(h, x, z)
	return h


## Höhe ohne Bäche (Talzug und Hauptfluss eingerechnet) – Grundlage für die Bachsuche.
func base_height(x: float, z: float) -> float:
	var h := 130.0 + 95.0 * _n_base.get_noise_2d(x, z)
	var r := 1.0 - absf(_n_ridge.get_noise_2d(x, z))
	h += mountain_weight(x, z) * (180.0 + 560.0 * r * r)
	h += 7.0 * _n_detail.get_noise_2d(x, z)
	# Talzug
	var uv := to_uv(x, z)
	var d := river_dist(x, z)
	var w := 1.0 - smoothstep(RIVER_FLOOR_HALF, RIVER_VALLEY, d)
	var fl := river_floor(uv.x)
	# M3.8: Talsohle am Fluss ohne Rauschen (Wasserspiegel eben quer zum Fluss)
	var floor_h := fl + 2.0 * _n_detail.get_noise_2d(x * 0.5, z * 0.5) * smoothstep(90.0, 420.0, d)
	h = lerpf(h, floor_h, w * w * (3.0 - 2.0 * w))
	# M3.8: Flussbett (Mulde unter dem Wasserspiegel, Ufer steigt auf die Talsohle)
	var rhw := river_hw(uv.x)
	if d < rhw + RIVER_BANK + 45.0:
		var lv := fl - RIVER_LEVEL_DROP
		var p: float
		if d < rhw:
			var k := d / rhw
			p = lv - RIVER_DEPTH * (1.0 - k * k)
		else:
			p = lerpf(lv, fl, smoothstep(rhw, rhw + RIVER_BANK, d))
		h = lerpf(h, p, 1.0 - smoothstep(rhw + RIVER_BANK, rhw + RIVER_BANK + 45.0, d))
	# Kartenrand: sanft nach außen ansteigen (natürliche Grenze); der Fluss bricht durch
	var edge := maxf(absf(x), absf(z))
	h += smoothstep(17500.0, 20000.0, edge) * 140.0 * smoothstep(250.0, 1400.0, d)
	return h


## Wasserspiegel des Hauptflusses an Talachse u.
static func river_level(u: float) -> float:
	return river_floor(u) - RIVER_LEVEL_DROP


func _carve_streams(h: float, x: float, z: float) -> float:
	var q := _stream_net.query(x, z)
	if q.is_empty():
		return h
	var d: float = q.dist
	var lv: float = q.level
	var hc: float = q.hw
	var p: float
	if d < hc:
		var k := d / hc
		p = lv - STREAM_DEPTH * (1.0 - k * k)
	else:
		p = lv + (d - hc) * STREAM_BANK_SLOPE
	# tiefer Einschnitt (Sattel): Hänge breiter auslaufen lassen
	var w := 1.0 - smoothstep(hc + 18.0, minf(hc + 60.0 + maxf(h - lv, 0.0) * 3.0, RiverNet.REACH - 5.0), d)
	# an der Quelle weich beginnen
	w *= smoothstep(0.0, 160.0, float(q.s))
	var hs := lerpf(h, p, w)
	# an der Mündung nur vertiefen (kein Damm im Hauptfluss)
	var k2 := smoothstep(RIVER_HW + 20.0, RIVER_HW + 110.0, river_dist(x, z))
	return lerpf(minf(h, hs), hs, k2)


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
	# M3.8: Gewässernetz (vor den Höhen: die Bäche werden eingeschnitten)
	_build_waters()
	td.waters = waters.duplicate(true)

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
	td.shore_png = _build_shore().save_png_to_buffer()
	return td


# --- M3.8: Gewässer --------------------------------------------------------------------

func _build_waters() -> void:
	waters.clear()
	# Hauptfluss: Mittellinie in ~20-m-Schritten über die ganze Karte (NW → SO = flussabwärts)
	var pts := PackedVector2Array()
	var lv := PackedFloat32Array()
	var hw := PackedFloat32Array()
	var lim := SIZE_M * 0.5 - 5.0
	var u := -30000.0
	while u < 30000.0:
		var rp := river_point(u)
		if absf(rp.x) <= lim and absf(rp.y) <= lim:
			pts.append(rp)
			lv.append(roundf(river_level(u) * 64.0) / 64.0)
			hw.append(river_hw(u))
		var sl := (river_v(u + 2.0) - river_v(u - 2.0)) / 4.0
		u += STREAM_STEP / sqrt(1.0 + sl * sl)
	waters.append({"name": "Fluss", "kind": RiverNet.KIND_RIVER, "pts": pts, "level": lv, "hw": hw,
		"flow": 1.1, "into": -1})
	# Bäche: bergab bis zum Fluss, an Plätzen/Zielen vorbei
	var streams: Array[Dictionary] = []
	for src in STREAM_SOURCES:
		var c := _trace_stream(src[0], src[1])
		if not c.is_empty():
			streams.append(c)
	_stream_net = RiverNet.from_data(streams, SIZE_M)
	waters.append_array(streams)
	net = RiverNet.from_data(waters, SIZE_M)


## Keine Bäche über Flugplätze samt Schneisen und über geglättete Ziel-Flächen.
func _stream_blocked(p: Vector2) -> bool:
	for pd in pads:
		if pd.radius > 0.0:
			if p.distance_to(pd.pos) < pd.radius + PAD_BLEND + 150.0:
				return true
		elif absf(p.x - pd.pos.x) < STREAM_AF_KEEP.x and absf(p.y - pd.pos.y) < STREAM_AF_KEEP.y:
			return true
	return absf(p.x) > SIZE_M * 0.5 - 600.0 or absf(p.y) > SIZE_M * 0.5 - 600.0


## Abflussrichtungen auf einem groben Gitter (FLOW_CELL) per Priority-Flood vom Hauptfluss aus:
## jede Zelle kennt ihren Abfluss-Nachbarn so, dass der Weg zum Fluss möglichst niedrige Sättel
## nimmt (Mulden werden an der tiefsten Stelle durchbrochen). Gesperrte Zellen (Plätze, Ziele)
## werden nicht durchflossen.
const FLOW_CELL := 100.0
var _flow_parent := PackedInt32Array()
var _flow_n := 0


func _build_flow() -> void:
	var n := int(SIZE_M / FLOW_CELL)
	_flow_n = n
	var half := SIZE_M * 0.5
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	var blocked := PackedByteArray()
	blocked.resize(n * n)
	_flow_parent.resize(n * n)
	_flow_parent.fill(-2)
	var heap := PackedFloat32Array()   # Priorität
	var heap_i := PackedInt32Array()   # Zelle
	for j in n:
		for i in n:
			var p := Vector2(-half + (i + 0.5) * FLOW_CELL, -half + (j + 0.5) * FLOW_CELL)
			var k := j * n + i
			hs[k] = base_height(p.x, p.y)
			blocked[k] = 1 if _stream_blocked(p) else 0
			if river_dist(p.x, p.y) < RIVER_HW:
				_flow_parent[k] = -1
				_heap_push(heap, heap_i, hs[k], k)
	var nb := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	while heap.size() > 0:
		var pr := heap[0]
		var k := heap_i[0]
		_heap_pop(heap, heap_i)
		var ci := k % n
		var cj := k / n
		for o: Vector2i in nb:
			var ni := ci + o.x
			var nj := cj + o.y
			if ni < 0 or nj < 0 or ni >= n or nj >= n:
				continue
			var nk := nj * n + ni
			if _flow_parent[nk] != -2 or blocked[nk] == 1:
				continue
			_flow_parent[nk] = k
			# leicht steigende Priorität auf Flächen: gerichteter Abfluss statt Zufall
			_heap_push(heap, heap_i, maxf(hs[nk], pr + 0.001), nk)


static func _heap_push(h: PackedFloat32Array, hi: PackedInt32Array, pr: float, k: int) -> void:
	h.append(pr)
	hi.append(k)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if h[p] <= h[i]:
			break
		var t := h[p]
		h[p] = h[i]
		h[i] = t
		var ti := hi[p]
		hi[p] = hi[i]
		hi[i] = ti
		i = p


static func _heap_pop(h: PackedFloat32Array, hi: PackedInt32Array) -> void:
	var last := h.size() - 1
	h[0] = h[last]
	hi[0] = hi[last]
	h.resize(last)
	hi.resize(last)
	var i := 0
	var n := last
	while true:
		var l := i * 2 + 1
		var r := l + 1
		var m := i
		if l < n and h[l] < h[m]:
			m = l
		if r < n and h[r] < h[m]:
			m = r
		if m == i:
			break
		var t := h[m]
		h[m] = h[i]
		h[i] = t
		var ti := hi[m]
		hi[m] = hi[i]
		hi[i] = ti
		i = m


## Bachlauf ab src: dem Abfluss-Gitter folgen bis zum Fluss, glätten, auf 20 m neu teilen und
## quer zum Lauf in die tiefste Stelle rücken. Wasserspiegel danach stromabwärts monoton.
func _trace_stream(name: String, src: Vector2) -> Dictionary:
	if _flow_parent.is_empty():
		_build_flow()
	var n := _flow_n
	var half := SIZE_M * 0.5
	var k := clampi(int((src.y + half) / FLOW_CELL), 0, n - 1) * n + clampi(int((src.x + half) / FLOW_CELL), 0, n - 1)
	if _flow_parent[k] == -2:
		return {}
	var coarse := PackedVector2Array([src])
	while k >= 0 and coarse.size() < 2000:
		k = _flow_parent[k]
		if k < 0:
			break
		coarse.append(Vector2(-half + (k % n + 0.5) * FLOW_CELL, -half + (k / n + 0.5) * FLOW_CELL))
	# Mündung: bis an die Flussmitte verlängern
	var last := coarse[coarse.size() - 1]
	coarse.append(river_point(to_uv(last.x, last.y).x).lerp(last, 0.3))
	var pts := _resample(_chaikin(coarse, 3), STREAM_STEP)
	# quer zum Lauf in die Talsohle rücken (±45 m), danach erneut glätten
	for it in 2:
		for i in range(1, pts.size() - 1):
			var t := (pts[i + 1] - pts[i - 1]).normalized()
			var nrm := Vector2(-t.y, t.x)
			var best := pts[i]
			var bh := base_height(best.x, best.y)
			for o in [-45.0, -30.0, -15.0, 15.0, 30.0, 45.0]:
				var c: Vector2 = pts[i] + nrm * o
				var hc := base_height(c.x, c.y) + absf(o) * 0.04
				if hc < bh and not _stream_blocked(c):
					bh = hc
					best = c
			pts[i] = best
		pts = _resample(_chaikin(pts, 2), STREAM_STEP)
	# Wasserspiegel: 0,8 m unter Gelände, stromabwärts nie steigend, an der Mündung = Fluss
	var np := pts.size()
	var lv := PackedFloat32Array()
	lv.resize(np)
	var hw := PackedFloat32Array()
	hw.resize(np)
	var cur := INF
	for i in np:
		var h := base_height(pts[i].x, pts[i].y)
		cur = minf(cur - 0.01, h - 0.8)
		lv[i] = cur
		hw[i] = lerpf(STREAM_HW.x, STREAM_HW.y, float(i) / (np - 1))
	var mouth := river_level(to_uv(pts[np - 1].x, pts[np - 1].y).x)
	var floor_lv := mouth + 0.02
	for i in range(np - 1, -1, -1):
		lv[i] = maxf(lv[i], floor_lv)
		floor_lv = lv[i] + 0.004
	# letzte 200 m sanft auf den Flussspiegel
	var tail := mini(10, np - 1)
	for kk in tail + 1:
		var i := np - 1 - kk
		lv[i] = lerpf(mouth, lv[i], float(kk) / tail)
	for i in np:
		lv[i] = roundf(lv[i] * 64.0) / 64.0
	return {"name": name, "kind": RiverNet.KIND_STREAM, "pts": pts, "level": lv, "hw": hw,
		"flow": 1.6, "into": 0}


static func _chaikin(p: PackedVector2Array, passes: int) -> PackedVector2Array:
	for it in passes:
		var q := PackedVector2Array([p[0]])
		for i in p.size() - 1:
			q.append(p[i].lerp(p[i + 1], 0.25))
			q.append(p[i].lerp(p[i + 1], 0.75))
		q.append(p[p.size() - 1])
		p = q
	return p


static func _resample(p: PackedVector2Array, step: float) -> PackedVector2Array:
	var out := PackedVector2Array([p[0]])
	var carry := 0.0
	for i in p.size() - 1:
		var a := p[i]
		var b := p[i + 1]
		var l := a.distance_to(b)
		var d := step - carry
		while d <= l:
			out.append(a.lerp(b, d / l))
			d += step
		carry = l - (d - step)
	if out[out.size() - 1].distance_to(p[p.size() - 1]) > step * 0.3:
		out.append(p[p.size() - 1])
	return out


## Uferabstand und Wasserspiegel je Höhenpunkt (samples²): R = Abstand zur Wasserkante
## (SHORE_OFF + SHORE_ENC · m, 0 … 255, < 64 im Wasser, 255 = kein Gewässer), G/B = Wasserspiegel
## · 64 (16 bit, G hoch), A = 255 im Wasserlauf eines Bachs, sonst 0.
func _build_shore() -> Image:
	var n := SAMPLES
	var sp := SIZE_M / float(n - 1)
	var half := SIZE_M * 0.5
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color8(255, 0, 0, 0))
	for j in n:
		var z := -half + j * sp
		for i in n:
			var x := -half + i * sp
			var q := net.query(x, z)
			if q.is_empty():
				continue
			var r := clampi(int(roundf(SHORE_OFF + SHORE_ENC * float(q.edge))), 0, 254)
			var l16 := clampi(int(roundf(float(q.level) * 64.0)), 0, 65535)
			img.set_pixel(i, j, Color8(r, l16 >> 8, l16 & 255, 255 if int(waters[q.course].kind) == RiverNet.KIND_STREAM else 0))
	return img


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
			# Wasser/Aue (M3.8: aus dem Gewässernetz, Aue am Fluss breit, am Bach schmal)
			var rd := river_dist(x, z)
			var q := net.query(x, z)
			var ed: float = q.edge if not q.is_empty() else INF
			var water := 1.0 - smoothstep(-6.0, 4.0, ed)
			var wet := (1.0 - smoothstep(60.0, 700.0, rd)) * 0.6
			if not q.is_empty() and int(waters[q.course].kind) == RiverNet.KIND_STREAM:
				wet = maxf(wet, (1.0 - smoothstep(10.0, 140.0, ed)) * 0.5)
			rd = minf(rd, ed + RIVER_HW)
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
			fields *= smoothstep(12.0, 45.0, ed)   # M3.8: Uferstreifen (Wiese) statt Acker bis ans Wasser
			img.set_pixel(i, j, Color(forest, cleared, maxf(water, wet * (1.0 - forest)), fields))
	return img
