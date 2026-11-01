extends TestSuite
## M3 Paket 9a: KI rollt vom Abstellplatz, wartet auf die Piste und startet.
## Abnahme: 10 Seeds ≥ 9/10 ohne Schaden, ≤ 90 s von „Rollen“ bis 300 m über Grund.

const SUITE := "slow"
const TEST_SUITES := {"test_ai_takeoff_one": "fast"}
const TERRAIN_SCENE := "res://world/terrain/terrain_world.tscn"
const U := preload("res://tests/suites/airfield/airfield_util.gd")


func make_world() -> Node3D:
	return (load(TERRAIN_SCENE) as PackedScene).instantiate()


## Ein Start: [ok, Sekunden Rollen->300 m, Text]
func _run_takeoff(seed: int, spot: int) -> Array:
	var t := world as TerrainWorld
	var br := U.ai_at_parking(t, 1, spot, seed)
	var a := br.get_vehicle() as Aircraft
	var ph := br.airfield
	var crashed := [false]
	a.crashed.connect(func(_x): crashed[0] = true)
	var taxi_t := -1.0
	var up_t := -1.0
	var trace := OS.has_environment("TRACE")
	var hp0 := a.damage.health_fraction()
	for f in 60 * 170:
		await get_tree().physics_frame
		var tm := f / 60.0
		if taxi_t < 0.0 and ph.phase == AirfieldPhases.Phase.TAXI_OUT:
			taxi_t = tm
		if trace and f % 60 == 0:
			print("  t=%3d %s" % [f / 60, U.trace_line(a, ph)])
		if taxi_t >= 0.0 and a.telemetry().height_agl >= 300.0:
			up_t = tm - taxi_t
			break
		if crashed[0] or a.damage.outcome == DamageModel.Outcome.CRASHED:
			break
	var dmg := a.damage.health_fraction() < hp0 - 1e-4
	var ok: bool = up_t > 0.0 and up_t <= 90.0 and not crashed[0] and not dmg
	var txt := "Seed %d Platz %d: %s %.0f s, Schaden %s, Phase %s" % [seed, spot,
		"300 m nach" if up_t > 0 else "nicht oben,", up_t, dmg or crashed[0], ph.phase_name()]
	a.queue_free()
	return [ok, up_t, txt]


func test_ai_takeoff_one() -> Array:
	var r := await _run_takeoff(_env_int("SEED", 1), _env_int("SPOT", 3))
	return [r[0], r[2]]


func test_ai_takeoff_10_seeds() -> Array:
	var good := 0
	var worst := 0.0
	var fails := []
	for s in 10:
		var r := await _run_takeoff(100 + s, s % 6)
		if r[0]:
			good += 1
			worst = maxf(worst, r[1])
		else:
			fails.append(r[2])
	return [good >= 9, "%d/10 Starts ok, längster %.0f s. %s" % [good, worst, " | ".join(fails)]]


static func _env_int(n: String, d: int) -> int:
	return int(OS.get_environment(n)) if OS.has_environment(n) else d
