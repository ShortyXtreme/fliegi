class_name RiverNet
extends RefCounted
## M3.8: Gewässernetz (Hauptfluss + Bäche) als Mittellinien mit Wasserspiegel und halber
## Wasserbreite je Punkt. Erzeugt von TerrainGenerator, gespeichert in TerrainData.waters,
## zur Laufzeit von TerrainWorld (Wasserflächen, Abfragen über WorldGround), VegetationGen
## (nichts im Wasser, Ufergehölz) und den Tests genutzt.
## Koordinaten: Gelände (Kartenmitte 0). Punkte laufen flussabwärts.
##
## Ein Lauf: {name, kind (KIND_RIVER | KIND_STREAM), pts: PackedVector2Array,
##   level: PackedFloat32Array (Wasserspiegel m), hw: PackedFloat32Array (halbe Wasserbreite m),
##   flow: float (Strömung m/s), into: int (Index des Laufs, in den er mündet, -1 = keiner)}
## Die Wasserkante liegt dort, wo das Gelände den Wasserspiegel schneidet; das Profil im
## Generator ist so gebaut, dass das bei Abstand hw zur Mittellinie geschieht.

enum { KIND_RIVER, KIND_STREAM }
const BUCKET := 200.0
## Abfrageradius: weiter als das von einem Segment entfernt gilt „kein Gewässer in der Nähe“.
const REACH := 160.0

var courses: Array[Dictionary] = []
var _half := 20000.0
var _nb := 0
var _buckets: Array = []   # je Zelle PackedInt32Array [kurs, segment, kurs, segment, …]


static func from_data(waters: Array, size_m: float) -> RiverNet:
	var n := RiverNet.new()
	for w in waters:
		n.courses.append(w)
	n.build_index(size_m)
	return n


func build_index(size_m: float) -> void:
	_half = size_m * 0.5
	_nb = int(ceil(size_m / BUCKET))
	_buckets.clear()
	_buckets.resize(_nb * _nb)
	for ci in courses.size():
		var pts: PackedVector2Array = courses[ci].pts
		var cum := PackedFloat32Array([0.0])
		for si in pts.size() - 1:
			cum.append(cum[si] + pts[si].distance_to(pts[si + 1]))
		courses[ci]["cum"] = cum
		for si in pts.size() - 1:
			var a := pts[si]
			var b := pts[si + 1]
			var i0 := _bi(minf(a.x, b.x) - REACH)
			var i1 := _bi(maxf(a.x, b.x) + REACH)
			var j0 := _bi(minf(a.y, b.y) - REACH)
			var j1 := _bi(maxf(a.y, b.y) + REACH)
			for j in range(j0, j1 + 1):
				for i in range(i0, i1 + 1):
					var k := j * _nb + i
					if _buckets[k] == null:
						_buckets[k] = PackedInt32Array()
					var arr: PackedInt32Array = _buckets[k]
					arr.append(ci)
					arr.append(si)
					_buckets[k] = arr


func _bi(v: float) -> int:
	return clampi(int(floor((v + _half) / BUCKET)), 0, _nb - 1)


## Nächster Lauf an (x, z) (Gelände-Koordinaten), nur innerhalb REACH.
## Ergebnis leer oder {course, seg, t, dist (zur Mittellinie), edge (dist − hw, < 0 = im
## Wasser), level, hw, dir (Vector2 flussabwärts), s (Laufmeter ab Quelle, genähert)}.
func query(x: float, z: float, only_course := -1) -> Dictionary:
	if _nb == 0:
		return {}
	var arr = _buckets[_bi(z) * _nb + _bi(x)]
	if arr == null:
		return {}
	var p := Vector2(x, z)
	var best := INF
	var bc := -1
	var bs := -1
	var bt := 0.0
	var list: PackedInt32Array = arr
	for k in range(0, list.size(), 2):
		var ci := list[k]
		if only_course >= 0 and ci != only_course:
			continue
		var si := list[k + 1]
		var pts: PackedVector2Array = courses[ci].pts
		var a := pts[si]
		var ab := pts[si + 1] - a
		var l2 := ab.length_squared()
		var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0) if l2 > 1e-6 else 0.0
		var hw: float = lerpf(courses[ci].hw[si], courses[ci].hw[si + 1], t)
		# nach Wasserkante vergleichen (breiter Fluss gewinnt an der Mündung)
		var e := p.distance_to(a + ab * t) - hw
		if e < best:
			best = e
			bc = ci
			bs = si
			bt = t
	if bc < 0:
		return {}
	var c: Dictionary = courses[bc]
	var cp: PackedVector2Array = c.pts
	var a2 := cp[bs]
	var b2 := cp[bs + 1]
	var hw2: float = lerpf(c.hw[bs], c.hw[bs + 1], bt)
	var d := p.distance_to(a2.lerp(b2, bt))
	if d > REACH:
		return {}
	return {"course": bc, "seg": bs, "t": bt, "dist": d, "edge": d - hw2,
		"level": lerpf(c.level[bs], c.level[bs + 1], bt), "hw": hw2,
		"dir": (b2 - a2).normalized(), "s": lerpf(c.cum[bs], c.cum[bs + 1], bt)}


## Wasserspiegel an (x, z), wenn der Punkt im Wasserlauf liegt (Abstand < hw), sonst NAN.
## Ob dort wirklich Wasser steht, entscheidet zusätzlich die Bodenhöhe (water_depth).
func level_at(x: float, z: float) -> float:
	var q := query(x, z)
	if q.is_empty() or float(q.edge) >= 0.0:
		return NAN
	return q.level


## Wasserkanten-Abstand (m, < 0 im Wasser), INF wenn kein Gewässer in der Nähe.
func edge_dist(x: float, z: float) -> float:
	var q := query(x, z)
	return INF if q.is_empty() else float(q.edge)


func course_count(kind := -1) -> int:
	var n := 0
	for c in courses:
		if kind < 0 or int(c.kind) == kind:
			n += 1
	return n


## Gesamtlänge eines Laufs (m).
func course_length(ci: int) -> float:
	var cum: PackedFloat32Array = courses[ci].cum
	return cum[cum.size() - 1]
