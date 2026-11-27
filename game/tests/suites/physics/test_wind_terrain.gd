extends TestSuite
## M3.9: Wind über dem echten Gelände (TerrainWorld): Windgitter (Rauigkeit Wald/Wasser/Felder,
## Hangwind, Lee, Tal), Thermik bei Tag, Kosten einer Abfrage (Ziel < 0,05 ms je Flugzeug und Tick).

const TERRAIN_SCENE := "res://world/terrain/terrain_world.tscn"


func make_world() -> Node3D:
	return (load(TERRAIN_SCENE) as PackedScene).instantiate()


func after_each() -> void:
	Weather.reset()


func _setup(lvl: int, from: float, spd: float) -> void:
	Weather.setup(lvl, 4)
	Weather.base_from_deg = from
	Weather.base_speed = spd
	Weather.front_time = INF
	Weather.trend = 0.0
	Weather.time = 300.0


func test_wind_grid_built() -> Array:
	var wt := Weather.terrain
	if wt == null:
		return [false, "kein Windgitter angemeldet"]
	var zmin := INF
	var zmax := 0.0
	var smin := INF
	var smax := -INF
	var chan := 0.0
	for k in wt.ln_z0.size():
		zmin = minf(zmin, exp(wt.ln_z0[k]))
		zmax = maxf(zmax, exp(wt.ln_z0[k]))
		smin = minf(smin, wt.src[k])
		smax = maxf(smax, wt.src[k])
		chan = maxf(chan, Vector2(wt.ax_c[k], wt.ax_s[k]).length())
	# Bauzeit (ohne Cache)
	var t0 := Time.get_ticks_usec()
	var tw: TerrainWorld = world
	var w2 := WindTerrain.new()
	w2._build(tw.data, tw.heights)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0
	var ok := zmin < 0.03 and zmax > 0.3 and smin < 0.3 and smax > 0.8 and chan > 0.5 and ms < 1500.0
	return [ok, "z0 %.3f–%.2f m, Thermik-Eignung %.2f–%.2f, Kanalisierung bis %.2f, Bauzeit %.0f ms" % [
		zmin, zmax, smin, smax, chan, ms]]


## Stichprobe über die Karte (Stark, Wind aus Nordwest): Hangauf- und -abwinde, Lee mit stärkerer
## Turbulenz und schwächerem Mittelwind, Wald turbulenter als Wiese, Tal lenkt um.
func test_terrain_effects() -> Array:
	_setup(Weather.Level.STARK, -40.0, 8.5)
	var s := WindSample.new()
	var up := 0.0
	var down := 0.0
	var lee_n := 0
	var lee_sig := 0.0
	var free_sig := 0.0
	var free_n := 0
	var chan_max := 0.0
	var forest_i := []
	var grass_i := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 4000:
		var x := rng.randf_range(-18000.0, 18000.0)
		var z := rng.randf_range(-18000.0, 18000.0)
		var h := WorldGround.height_at(x, z)
		Weather.sample(s, Vector3(x, h + 40.0, z), 40.0)
		up = maxf(up, s.orographic)
		down = minf(down, s.orographic)
		chan_max = maxf(chan_max, s.channel)
		if s.lee > 0.6:
			lee_n += 1
			lee_sig += s.sigma.x / maxf(s.mean.length(), 0.1)
		elif s.lee == 0.0 and s.z0 < 0.06:
			free_n += 1
			free_sig += s.sigma.x / maxf(s.mean.length(), 0.1)
		if s.z0 > 0.5:
			forest_i.append(s.sigma.x)
		elif s.z0 < 0.05 and s.lee == 0.0:
			grass_i.append(s.sigma.x)
	var fi := _mean(forest_i)
	var gi := _mean(grass_i)
	var li := lee_sig / maxf(lee_n, 1)
	var ni := free_sig / maxf(free_n, 1)
	var ok := up > 1.0 and down < -1.0 and lee_n > 10 and li > ni * 1.5 and fi > gi * 1.2 and chan_max > 0.3
	return [ok, "Hangwind +%.1f / %.1f m/s, Lee-Punkte %d (Intensität %.2f gegen frei %.2f), σu Wald %.2f / Wiese %.2f m/s, Tal bis %.0f %%" % [
		up, down, lee_n, li, ni, fi, gi, chan_max * 100.0]]


static func _mean(a: Array) -> float:
	var s := 0.0
	for v in a:
		s += v
	return s / maxf(a.size(), 1)


## Thermik am Nachmittag (Schwach): einzelne Aufwinde bis ~2 m/s in 400 m, im Mittel kaum Netto-Steigen,
## über Wasser kein Aufwind; ohne Wind (Aus) nichts.
func test_thermals() -> Array:
	_setup(Weather.Level.SCHWACH, 0.0, 2.0)
	var s := WindSample.new()
	var mx := 0.0
	var sum := 0.0
	var n := 0
	for i in 120:
		for j in 120:
			var x := -12000.0 + i * 80.0
			var z := -12000.0 + j * 80.0
			var h := WorldGround.height_at(x, z)
			Weather.sample(s, Vector3(x, h + 400.0, z), 400.0)
			mx = maxf(mx, s.thermal)
			sum += s.thermal
			n += 1
	var mean := sum / n
	Weather.reset()
	Weather.sample(s, Vector3(0, 400, 0), 400.0)
	var off := s.thermal == 0.0 and s.total == Vector3.ZERO
	var ok := mx > 1.0 and mx < 4.5 and absf(mean) < 0.35 and off
	return [ok, "Thermik Schwach in 400 m: max %.1f m/s, Mittel %+.2f m/s; Aus: %s" % [mx, mean, off]]


## Kosten: Abfrage mit Rollböe je Flugzeug und Tick, über Gelände, gemischte Höhen.
func test_query_cost() -> Array:
	_setup(Weather.Level.NORMAL, 20.0, 5.0)
	var s := WindSample.new()
	var pts := []
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in 200:
		var x := rng.randf_range(-15000.0, 15000.0)
		var z := rng.randf_range(-15000.0, 15000.0)
		pts.append(Vector3(x, WorldGround.height_at(x, z) + rng.randf_range(2.0, 2500.0), z))
	var n := 0
	var t0 := Time.get_ticks_usec()
	for rep in 25:
		for p: Vector3 in pts:
			Weather.sample(s, p, NAN, Vector3.RIGHT, 10.0)
			n += 1
	var us := float(Time.get_ticks_usec() - t0) / n
	var ok := us < 50.0
	return [ok, "Weather.sample mit Rollböe und Gelände: %.1f µs je Abfrage (%d Abfragen, Ziel < 50 µs)" % [us, n]]
