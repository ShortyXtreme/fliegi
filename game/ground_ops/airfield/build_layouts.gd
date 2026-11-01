extends SceneTree
## Erzeugt ground_ops/airfield/data/airfield_<i>.tres aus AirfieldLayout.make_default()
## (Platz 0 Blau, Platz 1 Rot). Aufruf:
##   godot --headless --path game --script res://ground_ops/airfield/build_layouts.gd

func _initialize() -> void:
	var nations := [Nations.BLUE, Nations.RED]
	for i in nations.size():
		var l := AirfieldLayout.make_default(i, TerrainWorld.RUNWAY_LENGTH, TerrainWorld.RUNWAY_WIDTH, nations[i])
		var p := "res://ground_ops/airfield/data/airfield_%d.tres" % i
		var err := ResourceSaver.save(l, p)
		print("%s: %d Plätze, %d Knoten, Fehler %d" % [p, l.parking_count(), l.taxi_nodes.size(), err])
	quit()
