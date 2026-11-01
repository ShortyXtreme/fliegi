extends TestSuite
## M3 Paket 8: Bodenplan-Daten (Platz Blau/Rot) und exklusive Pistenvergabe.

const SUITE := "fast"
const TERRAIN_SCENE := "res://world/terrain/terrain_world.tscn"


func make_world() -> Node3D:
	return (load(TERRAIN_SCENE) as PackedScene).instantiate()


func test_layout_files_and_graph() -> Array:
	var t := world as TerrainWorld
	var ok := true
	var out := []
	for i in 2:
		var p := "res://ground_ops/airfield/data/airfield_%d.tres" % i
		var file_ok := ResourceLoader.exists(p)
		var l := t.airfield_layout(i)
		var nat_ok := l.nation_id == int(t.airfield(i).get("nation", -1))
		var paths := 0
		for k in l.parking_count():
			var a := l.taxi_path(l.parking_nodes[k], l.hold_node)
			var b := l.taxi_path(l.exit_nodes[0], l.parking_in_nodes[k])
			if a.size() >= 2 and b.size() >= 2:
				paths += 1
		var rw := l.taxi_path(l.hold_node, l.runway_node).size() >= 2
		var conn := l.is_connected_graph()
		var good := file_ok and nat_ok and conn and rw and paths == l.parking_count() \
			and l.parking_count() >= 4 and l.exit_nodes.size() >= 2 \
			and l.parking_in_nodes.size() == l.parking_count()
		ok = ok and good
		out.append("%d: Datei %s, Nation %d, %d Plätze, %d/%d Wege, zusammenhängend %s" % [
			i, file_ok, l.nation_id, l.parking_count(), paths, l.parking_count(), conn])
	return [ok, "; ".join(out)]


## Abstellplätze: ≥ 30 m Abstand, weg von Piste (≥ 15 m vom Rand) und Hangars.
func test_parking_clearance() -> Array:
	var l := (world as TerrainWorld).airfield_layout(0)
	var min_d := INF
	for a in l.parking_count():
		for b in range(a + 1, l.parking_count()):
			min_d = minf(min_d, l.parking_positions[a].distance_to(l.parking_positions[b]))
	var rw_clear := INF
	var hangar_clear := INF
	var sz := l.runway_start.z
	for p in l.parking_positions:
		rw_clear = minf(rw_clear, absf(p.x) - l.runway_width * 0.5)
		for h in 3:
			var hc := Vector3(-80, 0, sz - 120 - h * 48)
			var dx := maxf(absf(p.x - hc.x) - 12.0, 0.0)
			var dz := maxf(absf(p.z - hc.z) - 15.0, 0.0)
			hangar_clear = minf(hangar_clear, Vector2(dx, dz).length())
	var tw_clear := INF
	for n in l.taxi_nodes:
		if n.x < -1.0 and absf(n.z) < 450.0:
			tw_clear = minf(tw_clear, absf(n.x) - l.runway_width * 0.5)
	var ok := min_d >= 30.0 and rw_clear >= 15.0 and hangar_clear >= 12.0 and tw_clear >= 5.0
	return [ok, "Abstand %.0f m, Pistenrand %.0f m, Hangar %.0f m, Rollweg–Piste %.0f m" % [
		min_d, rw_clear, hangar_clear, tw_clear]]


func test_runway_exclusive() -> Array:
	var rc := RunwayControl.find_or_create(world, 0)
	var same := RunwayControl.find_or_create(world, 0) == rc
	var a := Node.new()
	var b := Node.new()
	world.add_child(a)
	world.add_child(b)
	var r1 := rc.request(a)
	var r2 := rc.request(b)
	var r3 := rc.request(a)
	rc.release(b)          # fremde Freigabe wirkt nicht
	var still := rc.holds(a)
	rc.release(a)
	var r4 := rc.request(b)
	Authority.simulate_client = true
	rc.release(b)
	var c_req := rc.request(a)
	Authority.simulate_client = false
	b.free()
	var freed := rc.is_free()
	var ok := same and r1 and not r2 and r3 and still and r4 and not c_req and freed
	return [ok, "A=%s B=%s A erneut=%s, fremde Freigabe hält=%s, B nach Freigabe=%s, Client=%s, entfernt frei=%s" % [
		r1, r2, r3, still, r4, c_req, freed]]
