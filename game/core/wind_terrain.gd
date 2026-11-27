class_name WindTerrain
extends RefCounted
## M3.9: grobes Gelände-Windgitter (312,5 m) aus Höhenkarte und Bodenmaske eines TerrainWorld –
## einmal je Gelände gebaut (statischer Cache, < 0,2 s, fast alles nativ über Image-Verkleinerung).
## Je Zelle: Rauigkeit ln z0 und Verdrängungshöhe d (Wald), Thermik-Eignung (Felder/Fels gut,
## Wald schwach, Wasser Absinken), geglättete Höhe mit Gradient (Hangwind, Lee) sowie
## Taltiefe und Talachse (Kanalisierung). Koordinaten: Gelände-lokal (x, z), Kartenmitte = 0.

const RES := 128
const Z0_GRASS := 0.03
const Z0_FIELD := 0.10
const Z0_FOREST := 1.0
const Z0_CLEARED := 0.02
const Z0_WATER := 0.001
const Z0_ROCK := 0.01
const FOREST_D := 10.0      # Verdrängungshöhe Wald (≈ 0,7 × Baumhöhe)
const ROCK_H := Vector2(650.0, 900.0)

var size := 40000.0
var half := 20000.0
var cell := 312.5
var inv_cell := 1.0 / 312.5
var ln_z0 := PackedFloat32Array()
var disp := PackedFloat32Array()
var src := PackedFloat32Array()
var h1 := PackedFloat32Array()
var gx := PackedFloat32Array()
var gz := PackedFloat32Array()
var depth := PackedFloat32Array()
var ax_c := PackedFloat32Array()   # cos 2θ der Talachse (θ: Winkel in x/z), gewichtet mit Kanalstärke
var ax_s := PackedFloat32Array()

static var _cache := {}


## Gitter zu einem TerrainWorld (gecacht je Datenpfad).
static func for_terrain(tw: Node) -> WindTerrain:
	var key: String = tw.data_path
	if _cache.has(key):
		return _cache[key]
	var wt := WindTerrain.new()
	wt._build(tw.data, tw.heights)
	_cache[key] = wt
	return wt


func _build(td: TerrainData, heights: PackedFloat32Array) -> void:
	size = td.size_m
	half = size * 0.5
	cell = size / RES
	inv_cell = 1.0 / cell
	var n := td.samples
	# Höhen: 2049² → 1024² (bilinear) → halbieren bis 128² (je 2×2 gemittelt), dazu 16² für die Taltiefe
	var him := Image.create_from_data(n, n, false, Image.FORMAT_RF, heights.to_byte_array())
	him.resize(1024, 1024, Image.INTERPOLATE_BILINEAR)
	var hs := []
	var s := 1024
	while s > 16:
		s /= 2
		him.resize(s, s, Image.INTERPOLATE_BILINEAR)
		hs.append(him.duplicate())
	var h128: Image = hs[2]
	var h16: Image = hs[5]
	h1 = h128.get_data().to_float32_array()
	var big := h16.get_data().to_float32_array()
	# Bodenmaske 1024² → 128²
	var mim := td.decode_mask()
	mim.convert(Image.FORMAT_RGBA8)
	var ms := mim.get_width()
	while ms > RES:
		ms /= 2
		mim.resize(ms, ms, Image.INTERPOLATE_BILINEAR)
	var md := mim.get_data()
	var cnt := RES * RES
	ln_z0.resize(cnt)
	disp.resize(cnt)
	src.resize(cnt)
	gx.resize(cnt)
	gz.resize(cnt)
	depth.resize(cnt)
	ax_c.resize(cnt)
	ax_s.resize(cnt)
	var lg := log(Z0_GRASS)
	for j in RES:
		for i in RES:
			var k := j * RES + i
			var forest := md[k * 4] / 255.0
			var cleared := md[k * 4 + 1] / 255.0
			var wet := md[k * 4 + 2] / 255.0
			var fields := md[k * 4 + 3] / 255.0
			var h := h1[k]
			var rock := smoothstep(ROCK_H.x, ROCK_H.y, h) * (1.0 - forest)
			# Rauigkeit: im Log-Raum gemischt (Flächenmittel nach Mason/Wieringa)
			var water := clampf(wet - 0.25, 0.0, 1.0)
			var rest := maxf(1.0 - forest - fields - cleared - water - rock, 0.0)
			var tot := maxf(rest + forest + fields + cleared + water + rock, 1e-3)
			ln_z0[k] = (rest * lg + forest * log(Z0_FOREST) + fields * log(Z0_FIELD) + cleared * log(Z0_CLEARED)
				+ water * log(Z0_WATER) + rock * log(Z0_ROCK)) / tot
			disp[k] = FOREST_D * forest
			src[k] = clampf(0.55 + 0.45 * fields + 0.25 * cleared + 0.5 * rock - 0.35 * forest - 1.4 * water, -0.6, 1.2)
			var il := maxi(i - 1, 0)
			var ir := mini(i + 1, RES - 1)
			var jd := maxi(j - 1, 0)
			var ju := mini(j + 1, RES - 1)
			gx[k] = (h1[j * RES + ir] - h1[j * RES + il]) / ((ir - il) * cell)
			gz[k] = (h1[ju * RES + i] - h1[jd * RES + i]) / ((ju - jd) * cell)
	# Taltiefe und -achse (Krümmung der großräumigen Höhe, 2,5 km)
	var bc := size / 16.0
	for j in RES:
		for i in RES:
			var k := j * RES + i
			var x := -half + (i + 0.5) * cell
			var z := -half + (j + 0.5) * cell
			var hb := _bil(big, 16, bc, x, z)
			var dpt := hb - h1[k]
			depth[k] = dpt
			var d := 1500.0
			var hxx := (_bil(big, 16, bc, x + d, z) + _bil(big, 16, bc, x - d, z) - 2.0 * hb) / (d * d)
			var hzz := (_bil(big, 16, bc, x, z + d) + _bil(big, 16, bc, x, z - d) - 2.0 * hb) / (d * d)
			var hxz := (_bil(big, 16, bc, x + d, z + d) - _bil(big, 16, bc, x + d, z - d)
				- _bil(big, 16, bc, x - d, z + d) + _bil(big, 16, bc, x - d, z - d)) / (4.0 * d * d)
			# Eigenwerte der Krümmung; Achse = Richtung der kleineren Krümmung, nur in Mulden (größere > 0)
			var tr := 0.5 * (hxx + hzz)
			var df := sqrt(0.25 * (hxx - hzz) * (hxx - hzz) + hxz * hxz)
			var lmax := tr + df
			var ang := 0.5 * atan2(2.0 * hxz, hxx - hzz)   # Richtung der größten Krümmung (quer zum Tal)
			var strength := smoothstep(30.0, 140.0, dpt) * smoothstep(0.0, 2e-5, lmax)
			var axis := ang + PI * 0.5
			ax_c[k] = cos(2.0 * axis) * strength
			ax_s[k] = sin(2.0 * axis) * strength


static func _bil(a: PackedFloat32Array, res: int, cs: float, x: float, z: float) -> float:
	var hf := res * cs * 0.5
	var fx := clampf((x + hf) / cs - 0.5, 0.0, res - 1.001)
	var fz := clampf((z + hf) / cs - 0.5, 0.0, res - 1.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var k := j * res + i
	return lerpf(lerpf(a[k], a[k + 1], u), lerpf(a[k + res], a[k + res + 1], u), v)


## Bilinear in einem der Gitter (Gelände-lokale x, z).
func at(a: PackedFloat32Array, x: float, z: float) -> float:
	var fx := clampf((x + half) * inv_cell - 0.5, 0.0, RES - 1.001)
	var fz := clampf((z + half) * inv_cell - 0.5, 0.0, RES - 1.001)
	var i := int(fx)
	var j := int(fz)
	var u := fx - i
	var v := fz - j
	var k := j * RES + i
	return lerpf(lerpf(a[k], a[k + 1], u), lerpf(a[k + RES], a[k + RES + 1], u), v)


func z0_at(x: float, z: float) -> float:
	return exp(at(ln_z0, x, z))
