class_name TreeObstacles
extends Node
## Prüfung Boden/Welt: Baum-Kollision für Flugzeuge ohne Kollisionskörper – überall auf der Karte,
## auch headless (Server) und unabhängig von Kamera und Grafikstufe „Vegetation“.
## Vorher hatten nur Bäume bis Vegetation.COLLIDE_R (700 m) um die Kamera Zylinder; KI-Maschinen
## weiter weg (und alle auf dem Server ohne Optik) flogen durch Wälder.
##
## Ablauf je Physik-Tick (nur Server): Für jedes fliegende Flugzeug unter PREFETCH_AGL werden die
## Baumzellen um die aktuelle und die Lage in PREFETCH_S Sekunden im Hintergrund gerechnet
## (VegetationGen.build_cell, gleiche Plätze wie die Optik; nur die Kollisionsliste bleibt im Cache).
## Unter CHECK_AGL wird der Weg seit dem letzten Tick gegen die Bäume geprüft: Baum = senkrechter
## Zylinder wie in Vegetation._make_body (Radius TREE_RADIUS, Höhe 0,9 × Modellhöhe, 2-m-Raster),
## Flugzeug = Rumpf- und Flügelbox (AircraftData), um den Radius vergrößert, in SUBSTEP-Schritten.
## Ein Treffer meldet sich wie ein Physik-Kontakt: body_entered des Flugzeugs mit diesem Knoten
## (Aircraft._on_body_entered -> DamageModel.on_impact). Zellen, in denen die Optik gerade echte
## Kollisionskörper hat (Vegetation, nah an der Kamera), überspringt die Abfrage – dort wirkt Jolt.
## Kosten: eine Zelle (256 m) rechnet einmal im WorkerThreadPool; Abfrage über ein 16-m-Raster je
## Zelle, also nur eine Handvoll Bäume je Flugzeug und Tick.

const CHECK_AGL := 32.0
const PREFETCH_AGL := 300.0
const PREFETCH_S := 4.0
const MAX_CELLS := 160
const MAX_TASKS := 2
const BUCKET := 16.0
const SUBSTEP := 0.6
const TREE_RADIUS := Vegetation.TREE_RADIUS
const CELL := VegetationGen.CELL

static var current: TreeObstacles = null
## Stellschraube (Tests/Einstellungen): false = keine Abfrage (nur die Körper um die Kamera).
static var enabled := true

var tw: TerrainWorld
var gen: VegetationGen
## Vector2i -> {col: PackedFloat32Array (x, y0, z, y1 in Gelände-Koordinaten), grid: Array}
var cells := {}
var pending := {}          # Vector2i -> Task-ID
var _results := {}
var _mutex := Mutex.new()
var _used := {}            # Vector2i -> Physik-Tick der letzten Nutzung
var _prev := {}            # Flugzeug-Instanz-ID -> Vector3 (Szene) des letzten Ticks
## Statistik (Tests/Bericht)
var hits := 0
var checks := 0
## Rechenzeit des letzten Ticks (µs) und Höchstwert
var last_usec := 0
var max_usec := 0
var sum_usec := 0
var ticks := 0


func setup(t: TerrainWorld) -> void:
	tw = t


func _enter_tree() -> void:
	current = self


func _exit_tree() -> void:
	for k in pending:
		WorkerThreadPool.wait_for_task_completion(pending[k])
	pending.clear()
	if current == self:
		current = null


func _ensure_gen() -> bool:
	if gen == null and tw != null and tw.data != null:
		gen = VegetationGen.create(tw)
	return gen != null


func _physics_process(_dt: float) -> void:
	if not enabled or tw == null or not Authority.is_server():
		return
	var t0 := Time.get_ticks_usec()
	_tick()
	last_usec = Time.get_ticks_usec() - t0
	max_usec = maxi(max_usec, last_usec)
	sum_usec += last_usec
	ticks += 1


## Mittlere Rechenzeit je Tick (µs).
func mean_usec() -> float:
	return float(sum_usec) / maxf(ticks, 1)


func _tick() -> void:
	_collect()
	var frame := Engine.get_physics_frames()
	var o := tw.origin()
	for m in GroundNav.movers:
		if not (m is Aircraft) or not is_instance_valid(m) or not m.is_inside_tree():
			continue
		var a := m as Aircraft
		var id := a.get_instance_id()
		var p := a.global_position
		var prev: Vector3 = _prev.get(id, p)
		_prev[id] = p
		if a.damage == null or a.damage.outcome != DamageModel.Outcome.FLYING or a.freeze:
			continue
		var agl := p.y - WorldGround.height_at(p.x, p.z)
		if agl > PREFETCH_AGL:
			continue
		if not _ensure_gen():
			return
		var pt := p - o
		_want_cell(_key_t(pt.x, pt.z), frame)
		var ahead := pt + a.linear_velocity * PREFETCH_S
		_want_cell(_key_t(ahead.x, ahead.z), frame)
		_want_cell(_key_t(lerpf(pt.x, ahead.x, 0.5), lerpf(pt.z, ahead.z, 0.5)), frame)
		if agl > CHECK_AGL or (prev - p).length() > 200.0:   # Sprung (place/Teleport): kein Weg
			continue
		if sweep_hit(a, prev, p):
			hits += 1
			a.body_entered.emit(self)
	_trim()


func _key_t(x: float, z: float) -> Vector2i:
	return Vector2i(int(floor((x + gen.half) / CELL)), int(floor((z + gen.half) / CELL)))


func _want_cell(k: Vector2i, frame: int) -> void:
	var n := int(ceil(gen.size / CELL))
	if k.x < 0 or k.y < 0 or k.x >= n or k.y >= n:
		return
	_used[k] = frame
	if cells.has(k) or pending.has(k):
		return
	if pending.size() >= MAX_TASKS:
		return
	pending[k] = WorkerThreadPool.add_task(_task.bind(k), false, "Baumkollision")


func _task(k: Vector2i) -> void:
	var res := build_cell_obstacles(gen, k)
	_mutex.lock()
	_results[k] = res
	_mutex.unlock()


## Kollisionsliste einer Zelle aus VegetationGen.build_cell (gleiche Bäume wie die Optik):
## col je Baum [x, y0, z, y1] in Gelände-Koordinaten (Zylinder wie Vegetation._make_body),
## grid = Raster BUCKET × BUCKET mit Baum-Indizes.
static func build_cell_obstacles(g: VegetationGen, k: Vector2i) -> Dictionary:
	var raw: PackedFloat32Array = g.build_cell(k.x, k.y).col
	var x0 := k.x * CELL - g.half
	var z0 := k.y * CELL - g.half
	var col := PackedFloat32Array()
	col.resize(raw.size())
	for i in range(0, raw.size(), 4):
		var h := snappedf(raw[i + 3] * 0.9, 2.0)
		var y0 := raw[i + 1] - 0.3
		col[i] = raw[i] + x0
		col[i + 1] = y0
		col[i + 2] = raw[i + 2] + z0
		col[i + 3] = y0 + h
	return cell_from(col, x0, z0)


## Zelle aus fertiger Liste [x, y0, z, y1] (Gelände-Koordinaten) mit Raster; x0/z0 = Zellecke.
static func cell_from(col: PackedFloat32Array, x0: float, z0: float) -> Dictionary:
	var nb := int(CELL / BUCKET)
	var grid := []
	grid.resize(nb * nb)
	for i in range(0, col.size(), 4):
		var b := clampi(int((col[i + 2] - z0) / BUCKET), 0, nb - 1) * nb + clampi(int((col[i] - x0) / BUCKET), 0, nb - 1)
		if grid[b] == null:
			grid[b] = PackedInt32Array()
		var arr: PackedInt32Array = grid[b]
		arr.append(i)
		grid[b] = arr
	return {"col": col, "grid": grid, "x0": x0, "z0": z0}


## Zellecke (Gelände-Koordinaten) zum Schlüssel.
func cell_origin(k: Vector2i) -> Vector2:
	return Vector2(k.x * CELL - gen.half, k.y * CELL - gen.half)


func _collect() -> void:
	for k in pending.keys():
		var tid: int = pending[k]
		if WorkerThreadPool.is_task_completed(tid):
			WorkerThreadPool.wait_for_task_completion(tid)
			pending.erase(k)
			_mutex.lock()
			var res: Dictionary = _results.get(k, {})
			_results.erase(k)
			_mutex.unlock()
			if not res.is_empty():
				cells[k] = res


## Alte Zellen abbauen (LRU), damit der Cache in langen Partien begrenzt bleibt.
func _trim() -> void:
	if _prev.size() > 64:
		_prev.clear()
	if cells.size() <= MAX_CELLS:
		return
	var ks := cells.keys()
	ks.sort_custom(func(a, b): return int(_used.get(a, 0)) < int(_used.get(b, 0)))
	for i in ks.size() - MAX_CELLS:
		cells.erase(ks[i])
		_used.erase(ks[i])


## Zelle sofort rechnen (blockierend; Tests, Messungen).
func warm(scene_pos: Vector3) -> void:
	if not _ensure_gen():
		return
	var pt := scene_pos - tw.origin()
	var k := _key_t(pt.x, pt.z)
	if pending.has(k):
		WorkerThreadPool.wait_for_task_completion(pending[k])
		_collect()
	if not cells.has(k):
		cells[k] = build_cell_obstacles(gen, k)
	_used[k] = Engine.get_physics_frames()


## Hat die Optik in dieser Zelle gerade echte Kollisionskörper (dann wirkt Jolt)?
func _has_body(k: Vector2i) -> bool:
	var v: Vegetation = tw.vegetation
	if v == null or not is_instance_valid(v):
		return false
	var c = v.cells.get(k)
	return c != null and c.body != null


## Bäume (Gelände-Koordinaten) im Rechteck [lo, hi] (x/z). Rückgabe: Liste [x, y0, z, y1].
func trees_in(lo: Vector2, hi: Vector2, skip_bodies := true) -> Array:
	var out := []
	if gen == null:
		return out
	var k0 := _key_t(lo.x, lo.y)
	var k1 := _key_t(hi.x, hi.y)
	var nb := int(CELL / BUCKET)
	for kz in range(k0.y, k1.y + 1):
		for kx in range(k0.x, k1.x + 1):
			var k := Vector2i(kx, kz)
			if not cells.has(k) or (skip_bodies and _has_body(k)):
				continue
			var c: Dictionary = cells[k]
			var col: PackedFloat32Array = c.col
			var bx0 := clampi(int((lo.x - c.x0) / BUCKET), 0, nb - 1)
			var bx1 := clampi(int((hi.x - c.x0) / BUCKET), 0, nb - 1)
			var bz0 := clampi(int((lo.y - c.z0) / BUCKET), 0, nb - 1)
			var bz1 := clampi(int((hi.y - c.z0) / BUCKET), 0, nb - 1)
			for bz in range(bz0, bz1 + 1):
				for bx in range(bx0, bx1 + 1):
					var arr = c.grid[bz * nb + bx]
					if arr == null:
						continue
					for i: int in arr:
						var x := col[i]
						var z := col[i + 2]
						if x >= lo.x and x <= hi.x and z >= lo.y and z <= hi.y:
							out.append([x, col[i + 1], z, col[i + 3]])
	return out


## Höchste Baumkrone (Szenen-y) im Umkreis r um (x, z), -INF ohne Baum oder ohne gerechnete Zelle.
## Für KI/HUD (z. B. Tiefflug-Warnung) ohne Physik.
func canopy_top(x: float, z: float, r := 6.0) -> float:
	var o := tw.origin() if tw != null else Vector3.ZERO
	var best := -INF
	for t in trees_in(Vector2(x - o.x - r, z - o.z - r), Vector2(x - o.x + r, z - o.z + r), false):
		if Vector2(t[0] + o.x - x, t[2] + o.z - z).length() <= r:
			best = maxf(best, t[3] + o.y)
	return best


## Hat das Flugzeug auf dem Weg prev -> now (Szene) einen Baum gestreift?
func sweep_hit(a: Aircraft, prev: Vector3, now: Vector3) -> bool:
	var d := a.data
	var half_span := maxf(d.wing_box_size.x, d.fuselage_box_size.x) * 0.5
	var half_len := maxf(d.wing_box_size.z, d.fuselage_box_size.z) * 0.5 + absf(d.fuselage_box_center.z)
	var reach := maxf(half_span, half_len) + TREE_RADIUS + 0.5
	var o := tw.origin()
	var lo := Vector2(minf(prev.x, now.x) - o.x - reach, minf(prev.z, now.z) - o.z - reach)
	var hi := Vector2(maxf(prev.x, now.x) - o.x + reach, maxf(prev.z, now.z) - o.z + reach)
	var trees := trees_in(lo, hi)
	if trees.is_empty():
		return false
	checks += trees.size()
	var b := a.global_transform.basis.orthonormalized()
	var bt := b.transposed()
	var boxes := [[d.fuselage_box_center, d.fuselage_box_size * 0.5], [d.wing_box_center, d.wing_box_size * 0.5]]
	var n := maxi(1, int(ceil(prev.distance_to(now) / SUBSTEP)))
	for t in trees:
		var tx: float = t[0] + o.x
		var tz: float = t[2] + o.z
		var y0: float = t[1] + o.y
		var y1: float = t[3] + o.y
		for s in n + 1:
			var c := prev.lerp(now, float(s) / n)
			if Vector2(tx - c.x, tz - c.z).length() > reach:
				continue
			var p0 := bt * (Vector3(tx, y0, tz) - c)
			var p1 := bt * (Vector3(tx, y1, tz) - c)
			for bx in boxes:
				var ext: Vector3 = bx[1] + Vector3.ONE * TREE_RADIUS
				if segment_hits_box(p0 - bx[0], p1 - bx[0], ext):
					return true
	return false


## Strecke p0 -> p1 schneidet die Box [-e, e] (Slab-Test).
static func segment_hits_box(p0: Vector3, p1: Vector3, e: Vector3) -> bool:
	var dir := p1 - p0
	var t0 := 0.0
	var t1 := 1.0
	for ax in 3:
		var s := p0[ax]
		var dd := dir[ax]
		if absf(dd) < 1e-9:
			if s < -e[ax] or s > e[ax]:
				return false
			continue
		var ta := (-e[ax] - s) / dd
		var tb := (e[ax] - s) / dd
		if ta > tb:
			var tmp := ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true
