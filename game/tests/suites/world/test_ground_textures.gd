extends TestSuite
## M3.13: echte Texturen (Poly Haven) – Dateien, Stufen der Texturqualität, Binden an Materialien,
## Packet-Zuordnung, Himmel/Sonne, Bedeckung aus dem Wetter. Headless: lädt nur mit force.


func after_each() -> void:
	super.after_each()
	GroundTextures.force = false
	GroundTextures.set_level(GroundTextures.Level.MITTEL)
	Weather.reset()


func test_texture_files_and_imports() -> Array:
	var miss := GroundTextures.missing_files()
	var meta := GroundTextures.META
	var ok := miss.is_empty() and meta.LAYERS.size() == 7 and meta.MEAN.size() == 7 and meta.HI_INDEX.size() == 7
	# Index-Zuordnung wie im Shader (ground_detail.gdshaderinc GD_HI) und in GroundTextures.L_*
	ok = ok and meta.LAYERS[GroundTextures.L_GRASS] == "aerial_grass_rock" and meta.LAYERS[GroundTextures.L_DIRT] == "dirt_floor" \
		and meta.LAYERS[GroundTextures.L_ROCK] == "rocks_ground_02"
	var inc := FileAccess.get_file_as_string("res://world/terrain/ground_detail.gdshaderinc")
	ok = ok and inc.contains("int[7](%s)" % ", ".join(meta.HI_INDEX.map(func(x): return str(x))))
	# VRAM-Kompression in den .import-Dateien
	for f in GroundTextures.FILES:
		var imp := FileAccess.get_file_as_string(GroundTextures.DIR + f + ".import")
		ok = ok and imp.contains("compress/mode=2")
		if f.contains("nrm"):
			ok = ok and imp.contains("compress/high_quality=true") and not imp.contains("compress/normal_map=1")
	return [ok, "fehlend %s, Ebenen %d" % [str(miss), meta.LAYERS.size()]]


func test_texture_levels_bind() -> Array:
	var m := ShaderMaterial.new()
	m.shader = load("res://world/terrain/terrain.gdshader")
	GroundTextures.force = true
	GroundTextures.set_level(GroundTextures.Level.MITTEL)
	GroundTextures.bind(m, "terrain")
	var mid_on: float = m.get_shader_parameter("tex_on")
	var mid_col: Texture = m.get_shader_parameter("ter_col")
	var mid_hi: float = m.get_shader_parameter("tex_hi")
	GroundTextures.set_level(GroundTextures.Level.HOCH)
	var hi: float = m.get_shader_parameter("tex_hi")
	var hi_tex = m.get_shader_parameter("ter_col_hi")
	GroundTextures.set_level(GroundTextures.Level.NIEDRIG)
	var low_on: float = m.get_shader_parameter("tex_on")
	var low_cached := GroundTextures._tex.size()
	GroundTextures.force = false
	GroundTextures.set_level(GroundTextures.Level.MITTEL)
	var headless_on: float = m.get_shader_parameter("tex_on")
	var arr := mid_col as Texture2DArray
	var ok := mid_on == 1.0 and arr != null and arr.get_layers() == 7 and mid_hi == 0.0 and hi == 1.0 \
		and hi_tex is Texture2DArray and (hi_tex as Texture2DArray).get_layers() == 5 and low_on == 0.0 and low_cached == 0 \
		and headless_on == 0.0
	return [ok, "Mittel %.0f (%s), Hoch %.0f, Niedrig %.0f (Cache %d), headless %.0f" % [mid_on,
		str(arr.get_layers()) if arr else "-", hi, low_on, low_cached, headless_on]]


func test_texture_setting_and_packs() -> Array:
	var o := GameSettings.option("texturen")
	var ok := not o.is_empty() and o[3] == GroundTextures.LEVELS and o[5] == "mittel"
	ok = ok and PackLoader.PACKS.any(func(p): return p[0] == "Flugkern_texturen.pck" and p[2] == false)
	# split_pck: 1K/Himmel/Holz -> texturen, 2K-Gelände-Farben -> karte
	var py := FileAccess.get_file_as_string("res://tools/split_pck.py")
	ok = ok and py.contains('"texturen": "Flugkern_texturen.pck"') and py.contains('"_2k." in src and "gelaende" in src')
	return [ok, "Option %s" % str(o)]


func test_sky_sun_and_overcast() -> Array:
	# Sonne der DirectionalLight3D zeigt zur Sonne des HDRI (Azimut ~216°, Höhe ~48°)
	var b := Basis.from_euler(TerrainWorld.sun_rotation() * (PI / 180.0))
	var to_sun := b.z
	var d: Vector3 = GroundTextures.META.HIMMEL_KLAR.sun
	var elev := rad_to_deg(asin(to_sun.y))
	var ok := to_sun.distance_to(d.normalized()) < 0.01 and absf(elev - 47.9) < 0.5
	# Bedeckung: ohne Front 0, um den Frontdurchgang bedeckt, lange danach wieder klar
	Weather.setup(Weather.Level.NORMAL, 3)
	Weather.front_time = 3000.0
	var before := Weather.overcast_at(0.0)
	var at := Weather.overcast_at(2900.0)
	var after := Weather.overcast_at(6000.0)
	Weather.reset()
	var off := Weather.overcast_at(3000.0)
	ok = ok and before < 0.05 and at > 0.9 and after < 0.05 and off == 0.0
	return [ok, "Sonne Höhe %.1f°, Abstand %.3f; Bedeckung vor %.2f, Front %.2f, danach %.2f, aus %.2f" % [
		elev, to_sun.distance_to(d.normalized()), before, at, after, off]]
