class_name VegetationGen
extends RefCounted
## M3.7: Baum-/Buschplätze je Zelle (256 m) – reine Rechnung auf Kopien der Daten, läuft im
## WorkerThreadPool. Rechnet die Felder des Gelände-Shaders nach (gleicher Hash, gleiche
## Verzerrungs-Texturen), damit Baumreihen und Hecken auf den Schlaggrenzen stehen.
## Koordinaten: Gelände (Kartenmitte 0); Instanzen lokal zur Zellecke.
##
## Freihalten (je Platz, lokal zur Pistenmitte, Piste entlang z):
##   Platzfläche |x| < 215, |z| < 830: keine Bäume; Büsche nur außerhalb der Hecke/des Zauns.
##   An-/Abflugschneisen bis 5 km: |x| < 130 + 0.12 · (|z| − 770): gar nichts.

enum { LAUB_A, LAUB_B, NADEL_A, NADEL_B, BUSCH }
const SPECIES := ["laub_a", "laub_b", "nadel_a", "nadel_b", "busch"]
## Modellhöhe (m) je Art – für Kollisionszylinder
const HEIGHT := [13.4, 19.0, 16.5, 16.0, 2.3]
const CELL := 256.0
const FLOATS := 12   # Transform 3×4 (Farbton und Wind-Phase rechnet der Shader aus der Lage)

var half := 20000.0
var size := 40000.0
var heights := PackedFloat32Array()
var n := 2049
var inv_sp := 1.0
var mask := PackedByteArray()
var mask_res := 1024
var noise := PackedByteArray()
var warp_lo := PackedByteArray()
var warp_mid := PackedByteArray()
var wl_res := 24
var wm_res := 64
var airfields: Array = []   # Vector3 Mitte (Gelände)


static func create(tw: TerrainWorld) -> VegetationGen:
	var g := VegetationGen.new()
	g.size = tw.data.size_m
	g.half = g.size * 0.5
	g.heights = tw.heights
	g.n = tw.data.samples
	g.inv_sp = 1.0 / tw.data.spacing()
	var m := tw.data.decode_mask()
	m.convert(Image.FORMAT_RGBA8)
	g.mask_res = m.get_width()
	g.mask = m.get_data()
	var imgs := tw.field_images()
	g.noise = (imgs[0] as Image).get_data()
	g.wl_res = (imgs[1] as Image).get_width()
	g.warp_lo = (imgs[1] as Image).get_data()
	g.wm_res = (imgs[2] as Image).get_width()
	g.warp_mid = (imgs[2] as Image).get_data()
	for i in tw.airfield_count():
		g.airfields.append(tw.airfield(i).center)
	return g


# --- Nachgerechnete Shader-Funktionen ----------------------------------------------------------

func height(x: float, z: float) -> float:
	var fx := clampf((x + half) * inv_sp, 0.0, n - 1.0)
	var fz := clampf((z + half) * inv_sp, 0.0, n - 1.0)
	var i := mini(int(fx), n - 2)
	var j := mini(int(fz), n - 2)
	var u := fx - i
	var v := fz - j
	var k := j * n + i
	var a := lerpf(heights[k], heights[k + 1], u)
	var b := lerpf(heights[k + n], heights[k + n + 1], u)
	return lerpf(a, b, v)


## L8-Bild mit Wiederholung, bilinear (wie texture() mit repeat_enable)
static func _tex(d: PackedByteArray, res: int, u: float, v: float) -> float:
	var x := u * res - 0.5
	var y := v * res - 0.5
	var x0 := floori(x)
	var y0 := floori(y)
	var fx := x - x0
	var fy := y - y0
	x0 = posmod(x0, res)
	y0 = posmod(y0, res)
	var x1 := (x0 + 1) % res
	var y1 := (y0 + 1) % res
	var a := lerpf(d[y0 * res + x0], d[y0 * res + x1], fx)
	var b := lerpf(d[y1 * res + x0], d[y1 * res + x1], fx)
	return lerpf(a, b, fy) / 255.0


func nz(u: float, v: float) -> float:
	return _tex(noise, 512, u, v)


func wlo(u: float, v: float) -> float:
	return (_tex(warp_lo, wl_res, u, v) - 0.5) * 1.6 + 0.5


func wmid(u: float, v: float) -> float:
	return (_tex(warp_mid, wm_res, u, v) - 0.5) * 1.6 + 0.5


## Bodenmaske RGBA (R Wald, G Platz, B Wasser, A Felder), bilinear, Rand geklemmt
func mask_at(x: float, z: float) -> Color:
	var fx := (x + half) / size * mask_res - 0.5
	var fz := (z + half) / size * mask_res - 0.5
	var x0 := clampi(floori(fx), 0, mask_res - 1)
	var z0 := clampi(floori(fz), 0, mask_res - 1)
	var x1 := mini(x0 + 1, mask_res - 1)
	var z1 := mini(z0 + 1, mask_res - 1)
	var u := clampf(fx - floorf(fx), 0.0, 1.0)
	var v := clampf(fz - floorf(fz), 0.0, 1.0)
	var c := [0.0, 0.0, 0.0, 0.0]
	for ch in 4:
		var a := lerpf(mask[(z0 * mask_res + x0) * 4 + ch], mask[(z0 * mask_res + x1) * 4 + ch], u)
		var b := lerpf(mask[(z1 * mask_res + x0) * 4 + ch], mask[(z1 * mask_res + x1) * 4 + ch], u)
		c[ch] = lerpf(a, b, v) / 255.0
	return Color(c[0], c[1], c[2], c[3])


static func _perm(x: float) -> float:
	return fposmod((34.0 * x + 1.0) * x, 289.0)


static func _hash(px: float, py: float) -> Vector2:
	px = fposmod(px, 289.0)
	py = fposmod(py, 289.0)
	return Vector2(_perm(_perm(px) + py), _perm(_perm(py + 51.0) + px)) / 289.0


## Wie voronoi() im Shader: [F1, F2 − F1, Hash x, Hash y]
static func voronoi(px: float, py: float) -> Array:
	var ipx := floorf(px)
	var ipy := floorf(py)
	var fx := px - ipx
	var fy := py - ipy
	var f1 := 8.0
	var f2 := 8.0
	var idx := 0.0
	var idy := 0.0
	for j in [-1.0, 0.0, 1.0]:
		for i in [-1.0, 0.0, 1.0]:
			var o := _hash(ipx + i, ipy + j)
			var rx: float = i + 0.15 + 0.7 * o.x - fx
			var ry: float = j + 0.15 + 0.7 * o.y - fy
			var d := rx * rx + ry * ry
			if d < f1:
				f2 = f1
				f1 = d
				idx = ipx + i
				idy = ipy + j
			elif d < f2:
				f2 = d
	var h := _hash(idx + 101.0, idy + 37.0)
	return [sqrt(f1), sqrt(f2) - sqrt(f1), h.x, h.y]


## Schlag-Info an (x, z): [Schlaggrenze (vc.y), Flurgrenze (reg.y), Felder 0..1, Schlag-Hash]
func field_info(x: float, z: float, m: Color) -> Array:
	var wx := wlo(x / 1700.0 + 0.11, z / 1700.0 + 0.11) - 0.5
	var wz := wlo(x / 1700.0 + 0.53, z / 1700.0 + 0.53) - 0.5
	var fpx := x + wx * 220.0
	var fpz := z + wz * 220.0
	var reg := voronoi(fpx / 1900.0, fpz / 1900.0)
	var ang: float = reg[2] * PI
	var c := cos(ang)
	var s := sin(ang)
	var w2x := wmid(x / 420.0 + 0.27, z / 420.0 + 0.27) - 0.5
	var w2z := wmid(x / 420.0 + 0.81, z / 420.0 + 0.81) - 0.5
	var qx := fpx + w2x * 14.0
	var qz := fpz + w2z * 14.0
	# GLSL mat2(vec2(c, s), vec2(-s, c)) * q
	var fqx: float = c * qx - s * qz + reg[2] * 977.0
	var fqz: float = s * qx + c * qz + reg[3] * 977.0
	var sc := Vector2(310.0, 105.0).lerp(Vector2(230.0, 150.0), reg[3])
	var vc := voronoi(fqx / sc.x, fqz / sc.y)
	var n2 := nz(x / 610.0 + 0.37, z / 610.0 + 0.37)
	var fv: float = m.a * 0.9 + (vc[3] - 0.5) * 0.5 + (n2 - 0.5) * 0.15
	var fields := smoothstep(0.5, 0.56, fv)
	return [vc[1], reg[1], fields, vc[2]]


## Waldanteil wie fedge im Shader (ausgefranster Rand)
func forest_at(x: float, z: float, m: Color) -> float:
	return m.r + (nz(x / 140.0 + 0.4, z / 140.0 + 0.4) - 0.5) * 0.4


## 0 = frei, 1 = nur Büsche erlaubt, 2 = gar nichts (Platz, Schneisen)
func keepout(x: float, z: float) -> int:
	var res := 0
	for c: Vector3 in airfields:
		var lx := absf(x - c.x)
		var lz := absf(z - c.z)
		if lz > 5200.0 or lx > 900.0:
			continue
		if lz > 770.0 and lx < 130.0 + 0.12 * (lz - 770.0):
			return 2
		if lx < 215.0 and lz < 830.0:
			var inside := x - c.x > -172.0 and x - c.x < 157.0 and lz < 778.0
			if inside:
				return 2
			res = 1
	return res


func near_airfield(x: float, z: float) -> bool:
	for c: Vector3 in airfields:
		if absf(x - c.x) < 700.0 and absf(z - c.z) < 1300.0:
			return true
	return false


# --- Zelle -------------------------------------------------------------------------------------

## Ergebnis: {bufs: [PackedFloat32Array × 5], counts: [int × 5], col: PackedFloat32Array (x, y, z, h)}
func build_cell(cx: int, cz: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(cx, cz)) + 7
	var x0 := cx * CELL - half
	var z0 := cz * CELL - half
	var bufs := []
	var counts := []
	for s in SPECIES.size():
		bufs.append([])
		counts.append(0)
	var col := []   # Arrays (Referenz) beim Sammeln, am Ende gepackt
	# Zelle grob prüfen (Ecken + Mitte): Wald, Felder, Platz
	var any_forest := false
	var any_fields := false
	for p in [Vector2(0, 0), Vector2(CELL, 0), Vector2(0, CELL), Vector2(CELL, CELL), Vector2(CELL * 0.5, CELL * 0.5)]:
		var m := mask_at(x0 + p.x, z0 + p.y)
		any_forest = any_forest or m.r > 0.15
		any_fields = any_fields or m.a > 0.25
	var af := near_airfield(x0 + CELL * 0.5, z0 + CELL * 0.5) or near_airfield(x0, z0) or near_airfield(x0 + CELL, z0 + CELL)
	# 1) Wald: verwackeltes Raster 7 m
	if any_forest:
		var st := 7.0
		var k := int(CELL / st)
		for j in k:
			for i in k:
				var x := x0 + (i + rng.randf()) * st
				var z := z0 + (j + rng.randf()) * st
				var m := mask_at(x, z)
				if m.b > 0.7:
					continue
				var f := forest_at(x, z, m)
				if f < 0.42:
					continue
				var ko := keepout(x, z)
				if ko == 2:
					continue
				var y := height(x, z)
				if _slope(x, z) > 0.42:
					continue
				var edge := f < 0.5
				var sp: int
				if ko == 1 or (edge and rng.randf() < 0.45):
					sp = BUSCH
				else:
					# Nadelanteil mit Höhe und großflächigem Rauschen (Fichtenforste, Kiefernheide)
					var conif := nz(x / 3100.0 + 0.7, z / 3100.0 + 0.7) + smoothstep(300.0, 650.0, y) * 0.5
					if rng.randf() < smoothstep(0.42, 0.62, conif):
						sp = NADEL_A if nz(x / 900.0 + 0.2, z / 900.0 + 0.2) > 0.45 else NADEL_B
					else:
						sp = LAUB_A if rng.randf() < 0.85 else LAUB_B
				_add(bufs, counts, col, sp, x - x0, y, z - z0, rng, ko == 0 and sp != BUSCH)
				# Waldmantel: zusätzliche Büsche am Rand
				if f < 0.58 and sp != BUSCH and rng.randf() < 0.6:
					var bx := x + rng.randf_range(-3.5, 3.5)
					var bz := z + rng.randf_range(-3.5, 3.5)
					if keepout(bx, bz) != 2:
						_add(bufs, counts, col, BUSCH, bx - x0, height(bx, bz), bz - z0, rng, false)
	# 2) Hecken und Baumreihen auf den Schlag-/Flurgrenzen (nur wo der Shader Hecken zeichnet)
	if any_fields:
		var st := 6.0
		var k := int(CELL / st)
		for j in k:
			for i in k:
				var x := x0 + (i + rng.randf()) * st
				var z := z0 + (j + rng.randf()) * st
				var m := mask_at(x, z)
				if m.a < 0.2 or m.r > 0.45 or m.b > 0.7 or m.g > 0.3:
					continue
				var fi := field_info(x, z, m)
				if fi[2] < 0.5:
					continue
				var on_edge: bool = fi[0] < 0.035 and nz(x / 160.0, z / 160.0) >= 0.4
				var on_reg: bool = fi[1] < 0.007
				if not (on_edge or on_reg):
					continue
				var ko := keepout(x, z)
				if ko == 2 or rng.randf() > 0.5:
					continue
				var y := height(x, z)
				var r := rng.randf()
				var sp := BUSCH
				if ko == 0 and r < (0.45 if on_reg else 0.3):
					# Pappelreihen an Flurgrenzen (Wege), sonst Eichen/Linden
					sp = LAUB_B if on_reg and fi[3] < 0.5 else LAUB_A
				_add(bufs, counts, col, sp, x - x0, y, z - z0, rng, sp != BUSCH)
	# 3) Einzelbäume und Büsche auf Wiesen, dichter rund um den Flugplatz
	var tries := 40 if af else 10
	for t in tries:
		var x := x0 + rng.randf() * CELL
		var z := z0 + rng.randf() * CELL
		var m := mask_at(x, z)
		if m.r > 0.35 or m.b > 0.6 or m.a > 0.5:
			continue
		var ko := keepout(x, z)
		if ko == 2:
			continue
		if m.g > 0.3 and ko == 0 and not af:
			continue
		var y := height(x, z)
		if _slope(x, z) > 0.35:
			continue
		var p := rng.randf()
		if ko == 1 or p < 0.55:
			# Buschgruppe
			for b in rng.randi_range(1, 4):
				var bx := x + rng.randf_range(-5.0, 5.0)
				var bz := z + rng.randf_range(-5.0, 5.0)
				if keepout(bx, bz) == 2:
					continue
				_add(bufs, counts, col, BUSCH, bx - x0, height(bx, bz), bz - z0, rng, false)
		elif p < 0.85 or not af:
			_add(bufs, counts, col, LAUB_A, x - x0, y, z - z0, rng, true)
		else:
			_add(bufs, counts, col, LAUB_B if rng.randf() < 0.5 else NADEL_B, x - x0, y, z - z0, rng, true)
	for s in bufs.size():
		bufs[s] = PackedFloat32Array(bufs[s])
	return {"bufs": bufs, "counts": counts, "col": PackedFloat32Array(col)}


func _slope(x: float, z: float) -> float:
	var d := 10.0
	var gx := (height(x + d, z) - height(x - d, z)) / (2.0 * d)
	var gz := (height(x, z + d) - height(x, z - d)) / (2.0 * d)
	return 1.0 - 1.0 / sqrt(1.0 + gx * gx + gz * gz)


func _add(bufs: Array, counts: Array, col: Array, sp: int, lx: float, y: float, lz: float,
		rng: RandomNumberGenerator, collide: bool) -> void:
	var s := rng.randf_range(0.72, 1.18)
	if sp == BUSCH:
		s = rng.randf_range(0.6, 1.4)
	var sy := s * rng.randf_range(0.9, 1.12)
	var a := rng.randf() * TAU
	var c := cos(a)
	var sn := sin(a)
	var b: Array = bufs[sp]
	# Zeilen der 3×4-Matrix (Basis = Drehung um Y · Skalierung)
	b.append_array([c * s, 0.0, sn * s, lx, 0.0, sy, 0.0, y, -sn * s, 0.0, c * s, lz])
	counts[sp] += 1
	if collide:
		col.append_array([lx, y, lz, HEIGHT[sp] * sy])
