extends TestSuite
## M3 Paket 0b: TerrainWorld.airfield_layout(i) liefert einen Bodenplan je Platz
## (Ersatzplan, bis Paket 8 die .tres anlegt). Suite "fast".

const SUITE := "fast"
const TERRAIN_SCENE := "res://world/terrain/terrain_world.tscn"


func make_world() -> Node3D:
	return (load(TERRAIN_SCENE) as PackedScene).instantiate()


func test_airfield_layout_contract() -> Array:
	var t := world as TerrainWorld
	var out := []
	var ok := t.airfield_count() >= 2
	for i in t.airfield_count():
		var l := t.airfield_layout(i)
		var rs := l.to_scene(l.runway_start)
		var xf := l.parking_transform(0)
		var ground := absf(xf.origin.y - t.height_at(xf.origin.x, xf.origin.z)) < 0.01
		var connected := l.taxi_neighbors(l.hold_node).size() >= 2 and l.parking_nodes.size() == l.parking_count()
		ok = ok and l.parking_count() >= 3 and rs.distance_to(t.runway_start(i)) < 0.5 and ground and connected \
			and l.airfield_index == i and t.airfield_layout(i) == l
		out.append("%d: %d Plätze, Piste %.1f m daneben" % [i, l.parking_count(), rs.distance_to(t.runway_start(i))])
	return [ok, ", ".join(out)]
