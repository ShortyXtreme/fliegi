extends TestSuite
## M3.7: Vegetation – Freihaltezonen (Platz, Roll-/Fahrwege, An-/Abflugschneisen), Platzmaske
## für das Gras, Einstellung. Rechnet nur die Plätze (VegetationGen), keine Optik.


func make_world() -> Node3D:
	return TerrainWorld.new()


func _tw() -> TerrainWorld:
	return world as TerrainWorld


func test_vegetation_keepout() -> Array:
	var tw := _tw()
	var g := VegetationGen.create(tw)
	var total := 0
	var bad_inner := 0
	var bad_corridor := 0
	var bad_collide := 0
	var colliders := 0
	for ai in tw.airfield_count():
		var c: Vector3 = tw.airfield(ai).center
		var i0 := int(floor((c.x - 450.0 + g.half) / VegetationGen.CELL))
		var i1 := int(floor((c.x + 450.0 + g.half) / VegetationGen.CELL))
		var j0 := int(floor((c.z - 5200.0 + g.half) / VegetationGen.CELL))
		var j1 := int(floor((c.z + 5200.0 + g.half) / VegetationGen.CELL))
		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var r := g.build_cell(i, j)
				var x0 := i * VegetationGen.CELL - g.half
				var z0 := j * VegetationGen.CELL - g.half
				for s in VegetationGen.SPECIES.size():
					var b: PackedFloat32Array = r.bufs[s]
					for k in range(0, b.size(), VegetationGen.FLOATS):
						total += 1
						var lx := b[k + 3] + x0 - c.x
						var lz := b[k + 11] + z0 - c.z
						if lx > -172.0 and lx < 157.0 and absf(lz) < 778.0:
							bad_inner += 1
						if absf(lz) > 770.0 and absf(lz) < 5200.0 and absf(lx) < 130.0 + 0.12 * (absf(lz) - 770.0):
							bad_corridor += 1
				var col: PackedFloat32Array = r.col
				for k in range(0, col.size(), 4):
					colliders += 1
					var lx := col[k] + x0 - c.x
					var lz := col[k + 2] + z0 - c.z
					if absf(lx) < 215.0 and absf(lz) < 830.0:
						bad_collide += 1
	var ok := total > 200 and colliders > 50 and bad_inner == 0 and bad_corridor == 0 and bad_collide == 0
	return [ok, "Instanzen %d (Kollision %d), im Platz %d, in Schneisen %d, Kollision am Platz %d" % [
		total, colliders, bad_inner, bad_corridor, bad_collide]]


func test_vegetation_airfield_mask() -> Array:
	var tw := _tw()
	var worst_taxi := 0.0
	var worst_park := 0.0
	var worn := 1.0
	var meadow := 0.0
	for ai in tw.airfield_count():
		var l := tw.airfield_layout(ai)
		var img := Vegetation.airfield_mask(l)
		var px := func(p: Vector3) -> Color:
			return img.get_pixel(clampi(int(p.x + Vegetation.AF_HALF.x), 0, img.get_width() - 1),
				clampi(int(p.z + Vegetation.AF_HALF.y), 0, img.get_height() - 1))
		for n in l.taxi_nodes:
			worst_taxi = maxf(worst_taxi, px.call(n).r)
		for p in l.parking_positions:
			worst_park = maxf(worst_park, px.call(p).r)
		worn = minf(worn, px.call(Vector3(0, 0, l.runway_start.z - 120.0)).g)
		meadow = maxf(meadow, px.call(Vector3(185.0, 0, 0)).r)
	var ok := worst_taxi < 0.25 and worst_park < 0.1 and worn > 0.5 and meadow > 0.9
	return [ok, "Gras auf Rollwegen max. %.2f, Abstellplätze max. %.2f, Abnutzung Aufsetzzone min. %.2f, Wiese %.2f" % [
		worst_taxi, worst_park, worn, meadow]]


func test_vegetation_setting() -> Array:
	var o := GameSettings.option("vegetation")
	var ok: bool = not o.is_empty() and o[5] == "mittel" and (o[3] as Array).size() == 4 \
		and DisplayServer.get_name() == "headless" and _tw().vegetation == null
	return [ok, "Option %s, Standard %s, headless ohne Vegetation: %s" % [o[0] if o else "-", o[5] if o else "-",
		_tw().vegetation == null]]
