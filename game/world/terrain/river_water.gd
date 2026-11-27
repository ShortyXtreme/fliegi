class_name RiverWater
extends Node3D
## M3.8: Wasserflächen der Fließgewässer (nur Optik). Je Lauf ein Band entlang der Mittellinie,
## in Abschnitte von ~1,2 km geteilt (Sichtbarkeit/Culling), Shader world/terrain/water.gdshader.
## Vertex: (x, Wasserspiegel, z) in Gelände-Koordinaten (Knoten liegt im Gelände-Bezug
## "Terrain"), UV2 = Fließrichtung · Strömung (m/s), COLOR.r = Deckkraft (Quelle weich,
## Bach endet im Hauptfluss), COLOR.g = Art (0 Fluss, 1 Bach).

const CHUNK_PTS := 60
## Querschnitt als Vielfaches der halben Wasserbreite (über die Kante hinaus; die echte
## Uferlinie schneidet der Shader per Höhenkarte).
const ACROSS_RIVER := [-1.4, -1.15, -0.9, -0.55, 0.0, 0.55, 0.9, 1.15, 1.4]
const ACROSS_STREAM := [-1.7, -1.0, -0.4, 0.4, 1.0, 1.7]

var material: ShaderMaterial
var chunk_count := 0

static var _wave_tex: ImageTexture


static func create(tw: TerrainWorld) -> RiverWater:
	var rw := RiverWater.new()
	rw.name = "Water"
	rw._build(tw)
	return rw


func _build(tw: TerrainWorld) -> void:
	var net := tw.water_net
	if net == null:
		return
	var tex: Array = tw.terrain_textures()
	material = ShaderMaterial.new()
	material.shader = load("res://world/terrain/water.gdshader")
	material.set_shader_parameter("heightmap", tex[0])
	material.set_shader_parameter("foam_tex", tex[2])
	material.set_shader_parameter("wave_nrm", wave_texture())
	material.set_shader_parameter("spacing", tw.data.spacing())
	material.set_shader_parameter("half_size", tw.data.size_m * 0.5)
	material.set_shader_parameter("samples", tw.data.samples)
	material.render_priority = 1
	for ci in net.courses.size():
		var c: Dictionary = net.courses[ci]
		var pts: PackedVector2Array = c.pts
		var start := 0
		while start < pts.size() - 1:
			var end := mini(start + CHUNK_PTS, pts.size() - 1)
			var mi := MeshInstance3D.new()
			mi.name = "%s_%d" % [String(c.name).validate_node_name(), start / CHUNK_PTS]
			mi.mesh = _chunk_mesh(net, ci, start, end)
			mi.material_override = material
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visibility_range_end = TerrainWorld.VIEW_DISTANCE
			add_child(mi)
			chunk_count += 1
			start = end


func _chunk_mesh(net: RiverNet, ci: int, i0: int, i1: int) -> ArrayMesh:
	var c: Dictionary = net.courses[ci]
	var pts: PackedVector2Array = c.pts
	var lv: PackedFloat32Array = c.level
	var hw: PackedFloat32Array = c.hw
	var cum: PackedFloat32Array = c.cum
	var stream := int(c.kind) == RiverNet.KIND_STREAM
	var across: Array = ACROSS_STREAM if stream else ACROSS_RIVER
	var w := across.size()
	var speed: float = c.flow
	var verts := PackedVector3Array()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()
	var total := cum[cum.size() - 1]
	for i in range(i0, i1 + 1):
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, pts.size() - 1)]
		var t := (b - a).normalized()
		var nrm := Vector2(-t.y, t.x)
		for k in w:
			var o: float = across[k] * hw[i]
			var p := pts[i] + nrm * o
			verts.append(Vector3(p.x, lv[i], p.y))
			uv.append(Vector2(across[k], cum[i]))
			# Strömung zur Mitte stärker, am Rand schwächer
			uv2.append(t * speed * (1.0 - 0.45 * absf(across[k]) / 1.4))
			var fade := 1.0
			if stream:
				fade = smoothstep(20.0, 160.0, cum[i]) * smoothstep(0.0, 60.0, total - cum[i] + 10.0)
				var mq := net.query(p.x, p.y, 0)
				if not mq.is_empty():
					fade *= smoothstep(-8.0, 4.0, float(mq.edge))
			col.append(Color(fade, 1.0 if stream else 0.0, 0.0, 1.0))
	for r in i1 - i0:
		for k in w - 1:
			var a0 := r * w + k
			var b0 := a0 + 1
			var c0 := a0 + w
			var d0 := c0 + 1
			idx.append_array([a0, c0, b0, b0, c0, d0])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_TEX_UV] = uv
	arr[Mesh.ARRAY_TEX_UV2] = uv2
	arr[Mesh.ARRAY_COLOR] = col
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# Platz für das Anheben in der Ferne (Shader)
	var bb := m.get_aabb()
	m.custom_aabb = AABB(bb.position - Vector3(0, 1, 0), bb.size + Vector3(0, 14, 0))
	return m


## Kachelbare Wellen-Normalen (256², zur Laufzeit aus Rauschen, keine Bilddatei).
static func wave_texture() -> ImageTexture:
	if _wave_tex == null:
		var fn := FastNoiseLite.new()
		fn.seed = 4711
		fn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		fn.frequency = 6.0 / 256.0
		fn.fractal_octaves = 3
		fn.fractal_gain = 0.45
		var img := fn.get_seamless_image(256, 256)
		img.convert(Image.FORMAT_RGBA8)
		img.bump_map_to_normal_map(6.0)
		img.generate_mipmaps()
		_wave_tex = ImageTexture.create_from_image(img)
	return _wave_tex
