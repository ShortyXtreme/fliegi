class_name Bridges
extends RefCounted
## M3.8: Brücken über den Hauptfluss an den Ziel-Markern „bruecke“ (TerrainData.targets),
## prozedural (keine Modelldateien), zeitgemäß 1930er:
##   „Brücke Nord“: stählerne Fachwerkbrücke (zwei Felder à 52 m, Strompfeiler aus Stein),
##   „Brücke Süd“: Steinbogenbrücke mit vier Bögen.
## Beide mit gemauerten Widerlagern und Erddämmen als Auffahrt. Kollision (Layers.WORLD) aus
## einfachen Boxen (Fahrbahn, Pfeiler, Fachwerkwände bzw. Bogenwände) – tief fliegende
## Flugzeuge zerschellen daran. Knoten in Gruppe "bridge" (spätere Bodenangriffsziele) mit
## Metadaten name, type ("fachwerk" | "steinbogen"), nation, span (m), deck_height (m über Wasser).
## Lage im Gelände-Bezug (terrain_root), lokale Achse x = quer über den Fluss, z = flussabwärts.

const DECK_W := 7.0
const DECK_CLEAR := 6.5      # Fahrbahn über der Talsohle (m)
const RAMP_LEN := 70.0

static var _mats := {}


static func build_all(tw: TerrainWorld) -> Array[Node3D]:
	var out: Array[Node3D] = []
	if tw.water_net == null or tw.water_net.courses.is_empty():
		return out
	var k := 0
	for t in tw.targets("bruecke"):
		var b := build(tw, t, "fachwerk" if k == 0 else "steinbogen")
		if b != null:
			out.append(b)
		k += 1
	return out


static func build(tw: TerrainWorld, t: Dictionary, kind: String) -> Node3D:
	var p: Vector3 = t.pos
	var q := tw.water_net.query(p.x, p.z, 0)
	if q.is_empty():
		return null
	var flow: Vector2 = q.dir
	var root := StaticBody3D.new()
	root.name = String(t.name).validate_node_name()
	root.collision_layer = Layers.WORLD
	root.collision_mask = 0
	# Brückenmitte genau auf der Flussmitte, y = Talsohle
	var c: Dictionary = tw.water_net.courses[0]
	var cp: PackedVector2Array = c.pts
	var mid := cp[q.seg].lerp(cp[q.seg + 1], q.t)
	var floor_y := float(q.level) + TerrainGenerator.RIVER_LEVEL_DROP
	# lokale Achsen: x quer (über den Fluss), z = Strömung
	var bz := Vector3(flow.x, 0, flow.y)
	var bx := Vector3(-flow.y, 0, flow.x)
	root.transform = Transform3D(Basis(bx, Vector3.UP, bz), Vector3(mid.x, floor_y, mid.y))
	var hw := float(q.hw)
	var half_span := hw + 16.0                    # Widerlager hinter der Wasserkante
	var deck_y := DECK_CLEAR
	root.set_meta("name", t.name)
	root.set_meta("type", kind)
	root.set_meta("nation", t.get("nation", Nations.NONE))
	root.set_meta("span", half_span * 2.0)
	root.set_meta("deck_height", deck_y + TerrainGenerator.RIVER_LEVEL_DROP)
	root.add_to_group("bridge")
	var parts := {}   # Material-Name -> SurfaceTool
	var shapes: Array = []   # [Transform3D, Vector3 Größe]
	# Fahrbahn (durchgehend) und Brüstung/Geländer
	_box(parts, "deck", Vector3(0, deck_y - 0.35, 0), Vector3(half_span * 2.0 + 2.0, 0.7, DECK_W), shapes)
	_box(parts, "road", Vector3(0, deck_y + 0.02, 0), Vector3(half_span * 2.0 + 2.0, 0.04, DECK_W - 1.2), null)
	# Widerlager (Stein) an beiden Ufern
	for sx in [-1.0, 1.0]:
		var ax: float = sx * (half_span + 3.0)
		var gy := _ground_local(tw, root, Vector3(ax, 0, 0))
		_box(parts, "stone", Vector3(ax, (gy + deck_y) * 0.5 - 0.5, 0), Vector3(6.0, deck_y - gy + 1.0, DECK_W + 1.6), shapes)
		_ramp(parts, tw, root, sx, half_span + 6.0, deck_y)
	if kind == "fachwerk":
		_truss_bridge(parts, half_span, deck_y, shapes)
	else:
		_arch_bridge(parts, half_span, deck_y, shapes)
	for s in shapes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s[1]
		cs.shape = bs
		cs.transform = s[0]
		root.add_child(cs)
	if tw.build_visuals:
		for m in parts:
			var mi := MeshInstance3D.new()
			mi.name = "Mesh_" + m
			var stl: SurfaceTool = parts[m]
			stl.generate_normals()
			mi.mesh = stl.commit()
			mi.material_override = _mat(m)
			mi.visibility_range_end = 9000.0
			root.add_child(mi)
	tw.terrain_root.add_child(root)
	return root


static func _ground_local(tw: TerrainWorld, root: Node3D, local: Vector3) -> float:
	var w := root.transform * local
	return tw.height_at_terrain(w.x, w.z) - root.transform.origin.y


# --- Bauarten --------------------------------------------------------------------------

## Parallelgurt-Fachwerk (Warren mit Pfosten), zwei Felder, Strompfeiler in der Mitte.
static func _truss_bridge(parts: Dictionary, half_span: float, deck_y: float, shapes: Array) -> void:
	var h := 7.0
	var panels := 8
	for side in [-1.0, 1.0]:
		var z: float = side * (DECK_W * 0.5 + 0.3)
		for span in 2:
			var x0 := -half_span if span == 0 else 0.0
			var x1 := 0.0 if span == 0 else half_span
			var pl := (x1 - x0) / panels
			for i in panels:
				var xa := x0 + i * pl
				var xb := xa + pl
				_beam(parts, "steel", Vector3(xa, deck_y, z), Vector3(xb, deck_y, z), 0.5)          # Untergurt
				_beam(parts, "steel", Vector3(xa, deck_y + h, z), Vector3(xb, deck_y + h, z), 0.55)  # Obergurt
				if i % 2 == 0:
					_beam(parts, "steel", Vector3(xa, deck_y, z), Vector3(xb, deck_y + h, z), 0.35)
				else:
					_beam(parts, "steel", Vector3(xa, deck_y + h, z), Vector3(xb, deck_y, z), 0.35)
				_beam(parts, "steel", Vector3(xa, deck_y, z), Vector3(xa, deck_y + h, z), 0.3)
			_beam(parts, "steel", Vector3(x1, deck_y, z), Vector3(x1, deck_y + h, z), 0.4)
			# Wand als Kollisionsbox
			shapes.append([Transform3D(Basis.IDENTITY, Vector3((x0 + x1) * 0.5, deck_y + h * 0.5, z)), Vector3(x1 - x0, h, 0.6)])
	# Querverbände oben (je zweites Feld) und Endrahmen
	var n := 16
	for i in n + 1:
		var x := -half_span + i * half_span * 2.0 / n
		if i % 2 == 0:
			_beam(parts, "steel", Vector3(x, deck_y + h, -DECK_W * 0.5 - 0.3), Vector3(x, deck_y + h, DECK_W * 0.5 + 0.3), 0.3)
	# Strompfeiler (Stein, mit Eisbrecher-Spitze flussaufwärts) und Lager
	var py := -TerrainGenerator.RIVER_LEVEL_DROP - TerrainGenerator.RIVER_DEPTH - 0.5
	_box(parts, "stone", Vector3(0, (py + deck_y) * 0.5, 0), Vector3(3.2, deck_y - py, DECK_W + 2.0), shapes)
	_wedge(parts, "stone", Vector3(0, py, -(DECK_W * 0.5 + 1.0)), 3.2, deck_y - 1.2 - py, 2.4)


## Steinbogenbrücke: vier gleich weite Bögen (Halbkreis-Segmente), Pfeiler mit Vorköpfen.
static func _arch_bridge(parts: Dictionary, half_span: float, deck_y: float, shapes: Array) -> void:
	var arches := 4
	var pier_w := 3.0
	var span := (half_span * 2.0 - (arches - 1) * pier_w) / arches
	var rise := minf(span * 0.42, deck_y - 1.2)
	var base := -TerrainGenerator.RIVER_LEVEL_DROP - TerrainGenerator.RIVER_DEPTH - 0.5
	var spring := deck_y - 1.0 - rise      # Kämpferhöhe
	# Umriss der Stirnwand (x, y) als ein Polygon: oben die Fahrbahn, unten Bögen und Pfeiler
	var poly := PackedVector2Array()
	poly.append(Vector2(-half_span, deck_y))
	poly.append(Vector2(half_span, deck_y))
	poly.append(Vector2(half_span, base))
	var x := half_span
	for a in arches:
		var xr := x
		var xl := x - span
		var xc := (xl + xr) * 0.5
		poly.append(Vector2(xr, spring))
		var seg := 14
		for k in range(1, seg):
			var ang := PI * k / seg
			poly.append(Vector2(xc + cos(ang) * span * 0.5, spring + sin(ang) * rise))
		poly.append(Vector2(xl, spring))
		if a < arches - 1:
			poly.append(Vector2(xl, base))
			poly.append(Vector2(xl - pier_w, base))
			x = xl - pier_w
		else:
			x = xl
	poly.append(Vector2(-half_span, base))
	var tri := Geometry2D.triangulate_polygon(poly)
	for side in [-1.0, 1.0]:
		var z: float = side * DECK_W * 0.5
		var stl := _st(parts, "stone")
		for i in range(0, tri.size(), 3):
			var ids := [tri[i], tri[i + 1], tri[i + 2]]
			if side > 0.0:
				ids.reverse()
			for id in ids:
				var p2: Vector2 = poly[id]
				stl.set_uv(Vector2(p2.x, p2.y) * 0.25)
				stl.add_vertex(Vector3(p2.x, p2.y, z))
	# Bogenleibung (Unterseite der Bögen) als Tonnengewölbe
	x = half_span
	for a in arches:
		var xr := x
		var xl := x - span
		var xc := (xl + xr) * 0.5
		var seg := 14
		for k in seg:
			var a0 := PI * k / seg
			var a1 := PI * (k + 1) / seg
			var p0 := Vector3(xc + cos(a0) * span * 0.5, spring + sin(a0) * rise, 0)
			var p1 := Vector3(xc + cos(a1) * span * 0.5, spring + sin(a1) * rise, 0)
			_quad(parts, "stone", p0 + Vector3(0, 0, -DECK_W * 0.5), p1 + Vector3(0, 0, -DECK_W * 0.5),
				p1 + Vector3(0, 0, DECK_W * 0.5), p0 + Vector3(0, 0, DECK_W * 0.5))
		# Pfeiler-Innenseiten unter dem Kämpfer
		for xs in [xl, xr]:
			var f := 1.0 if xs == xl else -1.0
			_quad(parts, "stone", Vector3(xs, base, -DECK_W * 0.5), Vector3(xs, spring, -DECK_W * 0.5),
				Vector3(xs, spring, DECK_W * 0.5), Vector3(xs, base, DECK_W * 0.5), f < 0.0)
		if a < arches - 1:
			var pc := xl - pier_w * 0.5
			# Vorkopf (Eisbrecher) flussaufwärts, Kollision je Pfeiler
			_wedge(parts, "stone", Vector3(pc, base, -DECK_W * 0.5), pier_w, spring + rise * 0.4 - base, 2.2)
			shapes.append([Transform3D(Basis.IDENTITY, Vector3(pc, (base + deck_y) * 0.5, 0)), Vector3(pier_w, deck_y - base, DECK_W)])
			x = xl - pier_w
		# Bogen-Scheitel als Kollision (flache Box über dem Bogen)
		shapes.append([Transform3D(Basis.IDENTITY, Vector3(xc, deck_y - 0.6, 0)), Vector3(span, 1.4, DECK_W)])
	# Brüstung aus Stein
	for side in [-1.0, 1.0]:
		_box(parts, "stone_light", Vector3(0, deck_y + 0.5, side * (DECK_W * 0.5 - 0.25)), Vector3(half_span * 2.0, 1.0, 0.5), null)


## Erddamm als Auffahrt: Krone DECK_W, Böschung 1:1,5, vom Widerlager bis auf das Gelände.
static func _ramp(parts: Dictionary, tw: TerrainWorld, root: Node3D, sx: float, x_start: float, deck_y: float) -> void:
	var n := 8
	var prev := []
	for i in n + 1:
		var f := float(i) / n
		var x := sx * (x_start + f * RAMP_LEN)
		var gy := _ground_local(tw, root, Vector3(x, 0, 0))
		var top := lerpf(deck_y, gy + 0.15, f * f * (3.0 - 2.0 * f))
		var hgt := maxf(top - gy, 0.0)
		var wb := DECK_W * 0.5 + hgt * 1.5 + 0.5
		var gl := _ground_local(tw, root, Vector3(x, 0, -wb)) - 0.5
		var gr := _ground_local(tw, root, Vector3(x, 0, wb)) - 0.5
		var cur := [Vector3(x, gl, -wb), Vector3(x, top, -DECK_W * 0.5), Vector3(x, top, DECK_W * 0.5), Vector3(x, gr, wb)]
		if not prev.is_empty():
			var flip := sx < 0.0
			_quad(parts, "earth", prev[0], cur[0], cur[1], prev[1], flip)
			_quad(parts, "road", prev[1], cur[1], cur[2], prev[2], flip)
			_quad(parts, "earth", prev[2], cur[2], cur[3], prev[3], flip)
		prev = cur


# --- Mesh-Helfer -----------------------------------------------------------------------

static func _st(parts: Dictionary, m: String) -> SurfaceTool:
	if not parts.has(m):
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		parts[m] = s
	return parts[m]


static func _quad(parts: Dictionary, m: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, flip := false) -> void:
	var s := _st(parts, m)
	var v := [a, b, c, a, c, d]
	if flip:
		v = [a, c, b, a, d, c]
	for p: Vector3 in v:
		s.set_uv(Vector2(p.x + p.z, p.y) * 0.25)
		s.add_vertex(p)


## Quader (Mitte, Größe), optional als Kollisionsbox.
static func _box(parts: Dictionary, m: String, c: Vector3, size: Vector3, shapes) -> void:
	var h := size * 0.5
	var p := []
	for i in 8:
		p.append(c + Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	_quad(parts, m, p[0], p[2], p[3], p[1])   # -z
	_quad(parts, m, p[4], p[5], p[7], p[6])   # +z
	_quad(parts, m, p[0], p[4], p[6], p[2])   # -x
	_quad(parts, m, p[1], p[3], p[7], p[5])   # +x
	_quad(parts, m, p[2], p[6], p[7], p[3])   # +y
	_quad(parts, m, p[0], p[1], p[5], p[4])   # -y
	if shapes != null:
		(shapes as Array).append([Transform3D(Basis.IDENTITY, c), size])


## Träger (quadratischer Querschnitt t) von a nach b.
static func _beam(parts: Dictionary, m: String, a: Vector3, b: Vector3, t: float) -> void:
	var d := b - a
	var l := d.length()
	if l < 0.01:
		return
	var f := d / l
	var up := Vector3.UP if absf(f.y) < 0.95 else Vector3.RIGHT
	var r := f.cross(up).normalized() * t * 0.5
	var u := r.cross(f).normalized() * t * 0.5
	var c := [a - r - u, a + r - u, a + r + u, a - r + u]
	var e := [b - r - u, b + r - u, b + r + u, b - r + u]
	for i in 4:
		var j := (i + 1) % 4
		_quad(parts, m, c[i], c[j], e[j], e[i], true)


## Keilförmiger Pfeilervorkopf flussaufwärts (−z) vor der Pfeilerfront.
static func _wedge(parts: Dictionary, m: String, front_base: Vector3, w: float, h: float, depth: float) -> void:
	var l := front_base + Vector3(-w * 0.5, 0, 0)
	var r := front_base + Vector3(w * 0.5, 0, 0)
	var tip := front_base + Vector3(0, 0, -depth)
	var up := Vector3(0, h, 0)
	_quad(parts, m, l, tip, tip + up, l + up)
	_quad(parts, m, tip, r, r + up, tip + up)
	var s := _st(parts, m)
	for p: Vector3 in [l + up, tip + up, r + up]:
		s.set_uv(Vector2(p.x, p.z) * 0.25)
		s.add_vertex(p)


static func _mat(m: String) -> StandardMaterial3D:
	if _mats.has(m):
		return _mats[m]
	var col: Color = {"stone": Color(0.42, 0.39, 0.34), "stone_light": Color(0.5, 0.47, 0.41),
		"steel": Color(0.17, 0.2, 0.19), "deck": Color(0.3, 0.28, 0.25), "road": Color(0.22, 0.2, 0.17),
		"earth": Color(0.26, 0.33, 0.13)}.get(m, Color.GRAY)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.55 if m == "steel" else 0.92
	mat.metallic = 0.35 if m == "steel" else 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mats[m] = mat
	return mat
