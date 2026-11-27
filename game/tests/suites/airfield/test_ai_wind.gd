extends TestSuite
## M3.8: KI-Start und -Landung bei Wind (Seitenwind, Böen, Stufe Stark). Nutzt die Abläufe aus
## test_ai_takeoff/test_ai_landing (gleiche Abnahme: ohne Schaden, Start ≤ 90 s bis 300 m,
## Landung bis zum Abstellplatz).

const SUITE := "slow"
const TEST_SUITES := {"test_ai_takeoff_crosswind_one": "fast"}
const TERRAIN_SCENE := "res://world/terrain/terrain_world.tscn"

var _to: TestSuite
var _ld: TestSuite


func make_world() -> Node3D:
	return (load(TERRAIN_SCENE) as PackedScene).instantiate()


func before_each() -> void:
	_to = load("res://tests/suites/airfield/test_ai_takeoff.gd").new()
	_ld = load("res://tests/suites/airfield/test_ai_landing.gd").new()
	for s in [_to, _ld]:
		s.world = world
		s.projectiles = projectiles
		add_child(s)


func after_each() -> void:
	for s in [_to, _ld]:
		if s != null and is_instance_valid(s):
			s.queue_free()


## Wind der Stufe Stark mit Böen; Richtung „woher“ fest (Grad), Stärke = obere Grenze.
func _wind(from_deg: float, seed_v: int) -> String:
	Weather.setup(Weather.Level.STARK, seed_v)
	Weather.base_from_deg = from_deg
	Weather.base_speed = Weather.SPEED_RANGE[Weather.Level.STARK].y
	Weather.time = 0.0
	return Weather.describe()


func _tick_weather(n: Node) -> void:
	# Wetter-Zeit läuft wie im Spiel (WeatherDriver)
	var d := WeatherDriver.new()
	n.add_child(d)


func test_ai_takeoff_crosswind_one() -> Array:
	var w := _wind(75.0, 3)
	_tick_weather(world)
	var r: Array = await _to._run_takeoff(1, 3)
	return [r[0], "%s – %s" % [w, r[2]]]


func test_ai_takeoff_wind_5_seeds() -> Array:
	var good := 0
	var fails := []
	for s in 5:
		var w := _wind([-75.0, 75.0, 40.0, -40.0, 0.0][s], 10 + s)
		if s == 0:
			_tick_weather(world)
		var r: Array = await _to._run_takeoff(300 + s, s % 6)
		if r[0]:
			good += 1
		else:
			fails.append("%s: %s" % [w, r[2]])
	return [good >= 4, "%d/5 Starts bei Wind Stark (Seitenwind bis 75°) ok. %s" % [good, " | ".join(fails)]]


func test_ai_landing_wind_5_seeds() -> Array:
	var good := 0
	var fails := []
	var gas := []
	for s in 5:
		var w := _wind([75.0, -75.0, 30.0, -30.0, 60.0][s], 20 + s)
		if s == 0:
			_tick_weather(world)
		var r: Array = await _ld._run_landing(400 + s, s % 6)
		gas.append_array(r[3])
		if r[0]:
			good += 1
		else:
			fails.append("%s: %s" % [w, r[2]])
	return [good >= 4, "%d/5 Landungen bei Wind Stark bis zum Abstellplatz, Durchstarten %d (%s). %s" % [
		good, gas.size(), ",".join(gas), " | ".join(fails)]]
