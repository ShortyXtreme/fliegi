class_name GroundTextures
extends RefCounted
## M3.13: echte Boden-, Rinden- und Holztexturen (Poly Haven, CC0) je Qualitätsstufe.
## Aufbereitet von tools/prep_polyhaven.py nach assets/textures/polyhaven/ (Paket „texturen“,
## Hoch-Farben im Paket „karte“). Kanal-Packung je Material: *_col (RGB Farbe, BC1) und *_nrm
## (RG Normale OpenGL, B Rauheit, A Höhe bzw. AO, BC7). Gelände: Texture2DArray mit 7 Ebenen.
##
## Stufen (Einstellung „Texturqualität“, Standard Mittel):
##   Niedrig – keine Bilddateien, die prozeduralen Detail-Kacheln aus M3.7 (wenig Speicher)
##   Mittel  – 1K (Gelände-Farbe und -Normalen, Rinde, Bretter, Farbe)
##   Hoch    – zusätzlich Gelände-Farbe 2K für die Nah-Ebenen (Wiese, Waldboden, Laub, Schlamm, Erde);
##             Fels/Sand, Normalen/Rauheit und Rinde/Holz bleiben 1K (Paketgrenze 30 MB)
## Headless (Tests, Server) immer Niedrig – nichts wird geladen. Fehlt das Paket, ebenfalls
## Niedrig (Rückfall auf die prozeduralen Kacheln, kein Fehler).
##
## Materialien melden sich mit bind(mat, art) an; set_level() setzt dann alle neu.
##   "terrain" (terrain.gdshader), "decal" (ground_decal.gdshader), "bark" (tree.gdshader),
##   "bretter"/"farbe" (wood.gdshader). Uniforms: tex_on, *_col, *_nrm, Mittelfarben.

enum Level { NIEDRIG, MITTEL, HOCH }
const LEVELS := ["niedrig", "mittel", "hoch"]
const LABELS := ["Niedrig", "Mittel", "Hoch"]
const DIR := "res://assets/textures/polyhaven/"
const META := preload("res://assets/textures/polyhaven/polyhaven_meta.gd")
## Ebenen im Gelände-Array (wie tools/prep_polyhaven.py, terrain.gdshader L_*)
const L_GRASS := 0
const L_FOREST := 1
const L_LEAVES := 2
const L_MUD := 3
const L_ROCK := 4
const L_SAND := 5
const L_DIRT := 6

static var level := Level.MITTEL
## Tests: auch headless laden
static var force := false
static var _tex := {}
static var _bound: Array = []   # [WeakRef(ShaderMaterial), art]


## Wirksame Stufe (headless/ohne Dateien: Niedrig).
static func effective_level() -> int:
	if level == Level.NIEDRIG:
		return Level.NIEDRIG
	if DisplayServer.get_name() == "headless" and not force:
		return Level.NIEDRIG
	if not ResourceLoader.exists(DIR + "gelaende_col_1k.webp"):
		return Level.NIEDRIG
	return level


static func set_level(l: int) -> void:
	level = clampi(l, 0, LEVELS.size() - 1) as Level
	var keep: Array = []
	for b in _bound:
		var m = (b[0] as WeakRef).get_ref()
		if m != null:
			keep.append(b)
			apply(m, b[1])
	_bound = keep
	# nicht mehr gebrauchte Stufe freigeben
	if effective_level() != Level.HOCH:
		_tex.erase("gelaende_col_2k")
	if effective_level() == Level.NIEDRIG:
		_tex.clear()


static func set_level_name(s: String) -> void:
	set_level(maxi(LEVELS.find(s), 0))


## Textur (gecacht) oder null.
static func tex(key: String) -> Texture:
	if not _tex.has(key):
		var ext := ".webp"
		var p := DIR + key + ext
		_tex[key] = load(p) if ResourceLoader.exists(p) else null
	return _tex[key]


## Material anmelden und gleich passend setzen.
static func bind(mat: ShaderMaterial, art: String) -> ShaderMaterial:
	_bound.append([weakref(mat), art])
	apply(mat, art)
	return mat


static func apply(mat: ShaderMaterial, art: String) -> void:
	var lv := effective_level()
	var on := lv != Level.NIEDRIG
	match art:
		"terrain", "decal":
			var col := tex("gelaende_col_1k") if on else null
			var nrm := tex("gelaende_nrm_1k") if on else null
			on = on and col != null and nrm != null
			var hi := tex("gelaende_col_2k") if on and lv == Level.HOCH else null
			mat.set_shader_parameter("ter_col", col if on else null)
			mat.set_shader_parameter("ter_nrm", nrm if on else null)
			mat.set_shader_parameter("ter_col_hi", hi)
			mat.set_shader_parameter("tex_hi", 1.0 if hi != null else 0.0)
			var means := PackedVector3Array()
			for c: Color in META.MEAN:
				means.append(Vector3(c.r, c.g, c.b))
			mat.set_shader_parameter("ter_mean", means)
		"bark", "bretter", "farbe":
			var key := "rinde" if art == "bark" else art
			var col := tex(key + "_col_1k") if on else null
			var nrm := tex(key + "_nrm_1k") if on else null
			on = on and col != null and nrm != null
			var pre := "bark" if art == "bark" else "wood"
			mat.set_shader_parameter(pre + "_col", col if on else null)
			mat.set_shader_parameter(pre + "_nrm", nrm if on else null)
			var mc: Color = META.OBJ_MEAN[key]
			mat.set_shader_parameter(pre + "_mean", Vector3(mc.r, mc.g, mc.b))
	mat.set_shader_parameter("tex_on", 1.0 if on else 0.0)


## Alle Dateien der Stufen Mittel/Hoch und die Himmel (Pakete texturen + karte).
const FILES := ["gelaende_col_1k.webp", "gelaende_nrm_1k.webp", "gelaende_col_2k.webp", "rinde_col_1k.webp",
	"rinde_nrm_1k.webp", "bretter_col_1k.webp", "bretter_nrm_1k.webp", "farbe_col_1k.webp", "farbe_nrm_1k.webp",
	"himmel_klar_2k.hdr", "himmel_bedeckt_2k.hdr"]


static func missing_files() -> Array[String]:
	var out: Array[String] = []
	for f in FILES:
		if not ResourceLoader.exists(DIR + f):
			out.append(f)
	return out


## Diagnose: Stufe, Dateien, geladene Texturen.
static func diagnostics() -> String:
	var loaded := []
	for k in _tex:
		if _tex[k] != null:
			loaded.append(k)
	var miss := missing_files()
	return "Texturen %s (wirksam %s), %s, geladen: %s" % [LABELS[level], LABELS[effective_level()],
		"Texturdateien vollständig (%d)" % FILES.size() if miss.is_empty() else "fehlen: " + ", ".join(miss),
		", ".join(loaded) if not loaded.is_empty() else "keine (prozedural)"]
