class_name GroundNav
extends RefCounted
## M3.1: Wegsuche am Boden für KI-Personal und Wagen. Deterministisches A* auf einem Raster
## um Start und Ziel (ohne Physik, auch für das Sim-LOD: path_length). Hindernisse sind
## waagerechte Rechtecke: Gebäude (register_model/register_static), Flugzeuge am Boden
## (Rumpf-, Flügel- und Leitwerkbox aus AircraftData), Wagen (GroundVehicle) und – für Personal –
## die Zone drehender Propeller (Kreis). Zellen im Saum (Abstand < clearance) sind teuer, Zellen
## im Hindernis sehr teuer statt verboten: Start und Ziel im Saum (Servicepunkt am Rumpf,
## Fahrertür) bleiben erreichbar; liegt das Ziel im Saum, endet der Weg an der letzten freien
## Zelle davor. Hindernis: PackedFloat32Array [cx, cz, ux, uz, hx, hz, r] (r > 0: Kreis um c).

const CREW_CLEAR := 0.7         # Figur: Kapsel 0,3 m + Sicherheitsabstand
const MAX_CELLS := 150
const MIN_CELL := 0.8
const MARGIN := 12.0
const COST_SOFT := 8.0
const COST_HARD := 60.0
## Flugzeuge darüber (m über Grund) zählen nicht (fliegen).
const AIR_ALT := 6.0
const GOAL_SEARCH := 4.0
const PROP_R := 1.5
## Freizuhaltender Fahrweg vor gefahrenen Wagen (m).
const DRIVE_AHEAD := 6.0

## Flugzeuge, Wagen (bewegliche Hindernisse) und Figuren (nur für Wagen: Bremsen).
static var movers: Array = []
static var walkers: Array = []
static var _statics: Array = []        # [{node: Node3D, xf: Transform3D (lokal), h: Vector2}]


static func add_mover(n: Node) -> void:
	if not movers.has(n):
		movers.append(n)


static func remove_mover(n: Node) -> void:
	movers.erase(n)


static func add_walker(n: Node) -> void:
	if not walkers.has(n):
		walkers.append(n)


static func remove_walker(n: Node) -> void:
	walkers.erase(n)


## Gebäude-Box (lokal zu owner: Mitte und halbe Größe x/z). Verschwindet mit owner.
static func register_static(owner: Node3D, center: Vector3, half: Vector2) -> void:
	_statics.append({node = owner, xf = Transform3D(Basis(), center), h = half})


## Gebäude aus dem Modell: Box um alle Meshes (lokal zum Modell), optional verkleinert.
static func register_model(model: Node3D, shrink := 0.0) -> void:
	var bb := model_aabb(model)
	if bb.size.length_squared() < 0.01:
		return
	register_static(model, bb.get_center(), Vector2(bb.size.x, bb.size.z) * 0.5 - Vector2(shrink, shrink))


static func model_aabb(model: Node3D) -> AABB:
	var bb := AABB()
	var first := true
	for mi: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D()
		var n: Node = mi
		while n != model and n is Node3D:
			t = (n as Node3D).transform * t
			n = n.get_parent()
		var a: AABB = t * mi.get_aabb()
		bb = a if first else bb.merge(a)
		first = false
	return bb


static func _box(xf: Transform3D, c: Vector3, h: Vector2) -> PackedFloat32Array:
	var p := xf * c
	var u := xf.basis.x
	u.y = 0.0
	u = u.normalized() if u.length_squared() > 1e-6 else Vector3.RIGHT
	var sx := Vector3(xf.basis.x.x, 0.0, xf.basis.x.z).length()
	var sz := Vector3(xf.basis.z.x, 0.0, xf.basis.z.z).length()
	return PackedFloat32Array([p.x, p.z, u.x, u.z, h.x * sx, h.y * sz, 0.0])


static func _circle(p: Vector3, r: float) -> PackedFloat32Array:
	return PackedFloat32Array([p.x, p.z, 1.0, 0.0, 0.0, 0.0, r])


## Hindernisse in der Nähe von (lo, hi) (Szene, waagerecht). exclude: Knoten ohne Hindernis.
## props: Propellerzonen dazunehmen (Personal), walkers: Figuren als Kreise (Wagen).
static func obstacles(exclude: Array = [], props := false, with_walkers := false) -> Array:
	var out := []
	var keep := []
	for s in _statics:
		if not is_instance_valid(s.node):
			continue
		var o: Node3D = s.node
		if not o.is_inside_tree():
			continue
		keep.append(s)
		if exclude.has(o):
			continue
		out.append(_box(o.global_transform * s.xf, Vector3.ZERO, s.h))
	_statics = keep
	for m in movers:
		if not is_instance_valid(m) or exclude.has(m) or not m.is_inside_tree() or not m.visible:
			continue
		if m is Aircraft:
			var a := m as Aircraft
			if a.damage.is_destroyed:
				continue
			var g := a.global_position
			if g.y - WorldGround.height_at(g.x, g.z) > AIR_ALT:
				continue
			out.append_array(aircraft_boxes(a))
			if props and GroundCrewBrain.prop_danger(a):
				out.append(_circle(a.service_point(ServiceMarkers.SVC_ENGINE), GroundCrewBrain.PROP_ZONE))
		elif m is GroundVehicle:
			var v := m as GroundVehicle
			var hw := maxf(v.body_radius, 1.12)
			if v.driver_seat.controller != null:
				# gefahrener Wagen: Fahrweg davor freihalten (Wagen bremsen sonst vor der Figur)
				out.append(_box(v.global_transform, Vector3(0, 0, -DRIVE_AHEAD * 0.5), Vector2(hw + 0.3, v.body_length * 0.5 + DRIVE_AHEAD * 0.5)))
			else:
				out.append(_box(v.global_transform, Vector3.ZERO, Vector2(hw, v.body_length * 0.5)))
	if with_walkers:
		for w in walkers:
			if is_instance_valid(w) and not exclude.has(w) and w.is_inside_tree() and w.visible:
				out.append(_circle((w as Node3D).global_position, 0.3))
	return out


## Rumpf-, Propeller-, Flügel- und Leitwerkbox (Leitwerk geschätzt: Spannweite 1/3, am
## Rumpfende; Propellerkreis PROP_R vor der Rumpfnase).
static func aircraft_boxes(a: Aircraft) -> Array:
	var d := a.data
	var xf := a.global_transform
	var fs := d.fuselage_box_size
	var ws := d.wing_box_size
	var tail_z := d.fuselage_box_center.z + fs.z * 0.5 - 0.8
	var nose_z := d.fuselage_box_center.z - fs.z * 0.5
	return [
		_box(xf, d.fuselage_box_center, Vector2(fs.x, fs.z) * 0.5),
		_box(xf, Vector3(0, d.fuselage_box_center.y, nose_z - 0.25), Vector2(PROP_R, 0.35)),     # Propellerkreis
		_box(xf, d.wing_box_center, Vector2(ws.x, ws.z) * 0.5),
		_box(xf, Vector3(0, d.fuselage_box_center.y, tail_z), Vector2(ws.x / 6.0, 0.7)),
	]


## Abstand (waagerecht) von (x, z) zum Hindernis o; negativ = innen.
static func dist_to(o: PackedFloat32Array, x: float, z: float) -> float:
	var dx := x - o[0]
	var dz := z - o[1]
	if o[6] > 0.0:
		return sqrt(dx * dx + dz * dz) - o[6]
	var lx := absf(dx * o[2] + dz * o[3]) - o[4]
	var lz := absf(-dx * o[3] + dz * o[2]) - o[5]
	if lx < 0.0 and lz < 0.0:
		return maxf(lx, lz)
	return Vector2(maxf(lx, 0.0), maxf(lz, 0.0)).length()


static func min_dist(obs: Array, x: float, z: float) -> float:
	var best := INF
	for o in obs:
		best = minf(best, dist_to(o, x, z))
	return best


## Ist die Strecke a -> b frei (Abstand ≥ clear)? Die letzten skip_end Meter zählen nicht.
static func segment_free(obs: Array, a: Vector3, b: Vector3, clear: float, skip_end := 0.0) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z)
	var l := d.length() - skip_end
	if l <= 0.0:
		return true
	var n := int(ceil(l / 0.4))
	for i in n + 1:
		var t := (l * i / maxf(n, 1)) / maxf(d.length(), 1e-6)
		if min_dist(obs, a.x + d.x * t, a.z + d.y * t) < clear:
			return false
	return true


## Weg from -> to (Szene) als Wegpunkte ohne Start; letzter Punkt = Ziel oder letzte freie
## Stelle davor. obs = obstacles(...). Deterministisch.
static func find_path(obs: Array, from: Vector3, to: Vector3, clear: float) -> PackedVector3Array:
	if segment_free(obs, from, to, clear):
		return PackedVector3Array([to])
	var lo := Vector2(minf(from.x, to.x), minf(from.z, to.z)) - Vector2(MARGIN, MARGIN)
	var hi := Vector2(maxf(from.x, to.x), maxf(from.z, to.z)) + Vector2(MARGIN, MARGIN)
	var cell := maxf(MIN_CELL, maxf(hi.x - lo.x, hi.y - lo.y) / MAX_CELLS)
	var nx := int(ceil((hi.x - lo.x) / cell)) + 1
	var nz := int(ceil((hi.y - lo.y) / cell)) + 1
	var cls := PackedByteArray()
	cls.resize(nx * nz)
	cls.fill(0)
	for o: PackedFloat32Array in obs:
		var ext: float = (o[6] if o[6] > 0.0 else absf(o[2]) * o[4] + absf(o[3]) * o[5] + absf(o[3]) * o[4] + absf(o[2]) * o[5]) + clear
		var x0 := maxi(0, int(floor((o[0] - ext - lo.x) / cell)))
		var x1 := mini(nx - 1, int(ceil((o[0] + ext - lo.x) / cell)))
		var z0 := maxi(0, int(floor((o[1] - ext - lo.y) / cell)))
		var z1 := mini(nz - 1, int(ceil((o[1] + ext - lo.y) / cell)))
		for iz in range(z0, z1 + 1):
			for ix in range(x0, x1 + 1):
				var k := iz * nx + ix
				if cls[k] == 2:
					continue
				var dd := dist_to(o, lo.x + ix * cell, lo.y + iz * cell)
				if dd < 0.0:
					cls[k] = 2
				elif dd < clear:
					cls[k] = 1
	var s := _cell_of(from, lo, cell, nx, nz)
	var g := _cell_of(to, lo, cell, nx, nz)
	# Ziel im Saum: nächstgelegene freie Stelle (≤ GOAL_SEARCH m) als Ziel
	var goal_free := cls[g] == 0 and min_dist(obs, to.x, to.z) >= clear * 0.5
	var end_p = null
	if not goal_free:
		end_p = free_near(obs, to, clear, from)
		if end_p != null:
			g = _cell_of(end_p, lo, cell, nx, nz)
	var cells := _astar(cls, nx, nz, s, g)
	if cells.is_empty():
		return PackedVector3Array([to])
	if not goal_free and end_p == null:
		var last := -1
		for i in range(cells.size() - 1, -1, -1):
			if cls[cells[i]] == 0:
				last = i
				break
		if last < 0:
			return PackedVector3Array([to])
		cells = cells.slice(0, last + 1)
	# Glätten: von jedem Anker so weit wie möglich geradeaus (nicht schlechter als der Rasterweg)
	var pts := PackedVector3Array()
	var anchor := Vector2(from.x, from.z)
	var i := 0
	var n := cells.size()
	while i < n - 1:
		var best := i + 1
		var worst := cls[cells[i]]
		for j in range(i + 1, n):
			worst = maxi(worst, cls[cells[j]])
			var cj := _center(cells[j], lo, cell, nx)
			if _los(cls, nx, nz, lo, cell, anchor, cj, worst):
				best = j
		var c := _center(cells[best], lo, cell, nx)
		if best == n - 1:
			break
		pts.append(_ground(c))
		anchor = c
		i = best
	if goal_free:
		pts.append(to)
	elif end_p != null:
		pts.append(end_p)
	else:
		pts.append(_ground(_center(cells[n - 1], lo, cell, nx)))
	return pts


## Nächste Stelle um p mit Abstand ≥ clear zu allen Hindernissen (Ringe zu 0,1 m, 32 Richtungen;
## auf dem ersten Ring mit freien Stellen die zu near nächste), null = keine innerhalb GOAL_SEARCH.
static func free_near(obs: Array, p: Vector3, clear: float, near: Vector3):
	var r := 0.1
	while r <= GOAL_SEARCH:
		var best = null
		var bd := INF
		for k in 32:
			var ang := TAU * k / 32.0
			var x := p.x + cos(ang) * r
			var z := p.z + sin(ang) * r
			if min_dist(obs, x, z) >= clear:
				var dd := Vector2(x - near.x, z - near.z).length_squared()
				if dd < bd - 1e-6:
					bd = dd
					best = Vector3(x, WorldGround.height_at(x, z), z)
		if best != null:
			return best
		r += 0.1
	return null


## Weglänge from -> to (Sim-LOD-Gehzeiten).
static func path_length(obs: Array, from: Vector3, to: Vector3, clear: float) -> float:
	var l := 0.0
	var p := from
	for q in find_path(obs, from, to, clear):
		l += Vector2(q.x - p.x, q.z - p.z).length()
		p = q
	return l + Vector2(to.x - p.x, to.z - p.z).length()


static func _ground(c: Vector2) -> Vector3:
	return Vector3(c.x, WorldGround.height_at(c.x, c.y), c.y)


static func _cell_of(p: Vector3, lo: Vector2, cell: float, nx: int, nz: int) -> int:
	var ix := clampi(int(round((p.x - lo.x) / cell)), 0, nx - 1)
	var iz := clampi(int(round((p.z - lo.y) / cell)), 0, nz - 1)
	return iz * nx + ix


static func _center(k: int, lo: Vector2, cell: float, nx: int) -> Vector2:
	return Vector2(lo.x + (k % nx) * cell, lo.y + (k / nx) * cell)


static func _los(cls: PackedByteArray, nx: int, nz: int, lo: Vector2, cell: float, a: Vector2, b: Vector2, worst: int) -> bool:
	var l := a.distance_to(b)
	var n := int(ceil(l / (cell * 0.5)))
	for k in n + 1:
		var p := a.lerp(b, float(k) / maxf(n, 1))
		var ix := clampi(int(round((p.x - lo.x) / cell)), 0, nx - 1)
		var iz := clampi(int(round((p.y - lo.y) / cell)), 0, nz - 1)
		if cls[iz * nx + ix] > worst:
			return false
	return true


static func _astar(cls: PackedByteArray, nx: int, nz: int, s: int, g: int) -> PackedInt32Array:
	var n := nx * nz
	var gs := PackedFloat32Array()
	gs.resize(n)
	gs.fill(INF)
	var par := PackedInt32Array()
	par.resize(n)
	par.fill(-1)
	var done := PackedByteArray()
	done.resize(n)
	done.fill(0)
	var hf := PackedFloat32Array()     # Heap: f-Werte
	var hk := PackedInt32Array()       # Heap: Zellen
	var gx := g % nx
	var gz := g / nx
	gs[s] = 0.0
	_push(hf, hk, _h(s % nx, s / nx, gx, gz), s)
	var cost := [1.0, COST_SOFT, COST_HARD]
	while hk.size() > 0:
		var u := _pop(hf, hk)
		if done[u] == 1:
			continue
		done[u] = 1
		if u == g:
			break
		var ux := u % nx
		var uz := u / nx
		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dz == 0:
					continue
				var vx: int = ux + dx
				var vz: int = uz + dz
				if vx < 0 or vz < 0 or vx >= nx or vz >= nz:
					continue
				var v := vz * nx + vx
				if done[v] == 1:
					continue
				var step := 1.41421 if dx != 0 and dz != 0 else 1.0
				var ng: float = gs[u] + step * float(cost[cls[v]])
				if ng < gs[v] - 1e-5:
					gs[v] = ng
					par[v] = u
					_push(hf, hk, ng + _h(vx, vz, gx, gz), v)
	if par[g] < 0 and g != s:
		return PackedInt32Array()
	var out := PackedInt32Array()
	var c := g
	while c >= 0:
		out.append(c)
		if c == s:
			break
		c = par[c]
	out.reverse()
	return out


static func _h(x: int, z: int, gx: int, gz: int) -> float:
	var dx := absi(x - gx)
	var dz := absi(z - gz)
	return maxi(dx, dz) + 0.41421 * mini(dx, dz)


static func _push(hf: PackedFloat32Array, hk: PackedInt32Array, f: float, k: int) -> void:
	hf.append(f)
	hk.append(k)
	var i := hf.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if hf[p] <= f:
			break
		hf[i] = hf[p]
		hk[i] = hk[p]
		i = p
	hf[i] = f
	hk[i] = k


static func _pop(hf: PackedFloat32Array, hk: PackedInt32Array) -> int:
	var top := hk[0]
	var lf := hf[hf.size() - 1]
	var lk := hk[hk.size() - 1]
	hf.resize(hf.size() - 1)
	hk.resize(hk.size() - 1)
	var n := hf.size()
	if n == 0:
		return top
	var i := 0
	while true:
		var c := 2 * i + 1
		if c >= n:
			break
		if c + 1 < n and hf[c + 1] < hf[c]:
			c += 1
		if hf[c] >= lf:
			break
		hf[i] = hf[c]
		hk[i] = hk[c]
		i = c
	hf[i] = lf
	hk[i] = lk
	return top
