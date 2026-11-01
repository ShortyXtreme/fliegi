extends TestSuite
## M3 Paket 10: Spawn am Boden für Spieler und KI (SpawnManager), Startzustand nach
## MatchRules, kein Spawn in der Luft, 3 KI-Maschinen gleichzeitig ohne Kollision.

const SUITE := "fast"
const TEST_SUITES := {"test_three_ai_take_off_without_collision": "slow"}
const TERRAIN_SCENE := "res://world/terrain/terrain_world.tscn"
const U := preload("res://tests/suites/airfield/airfield_util.gd")

var _delay := 0.0


func make_world() -> Node3D:
	return (load(TERRAIN_SCENE) as PackedScene).instantiate()


func before_each() -> void:
	_delay = MatchRules.respawn_delay


func after_each() -> void:
	MatchRules.respawn_delay = _delay


func _sm() -> SpawnManager:
	var sm := SpawnManager.new()
	world.add_child(sm)
	return sm


func _on_ground_at(a: Aircraft, l: AirfieldLayout, spot: int) -> bool:
	var p := l.parking_transform(spot).origin
	var d := Vector2(a.global_position.x - p.x, a.global_position.z - p.z).length()
	var h := a.global_position.y - p.y
	return d < 1.0 and absf(h - a.data.ground_height) < 0.3 and a.linear_velocity.length() < 0.5


## Spieler-Maschine: erster Start 50 %/voll, nach Abschuss am Abstellplatz 15 %/0,
## nach Landung Restzustand – nie in der Luft.
func test_player_respawn_on_ground() -> Array:
	var t := world as TerrainWorld
	var l := t.airfield_layout(0)
	var sm := _sm()
	MatchRules.respawn_delay = 0.5
	var a := Aircraft.create(load(FIGHTER), false)
	world.add_child(a)
	var c := _seat(a, func(_ac, i: PilotIntent, _dt): i.brakes = 1.0)
	sm.register_ground(a, c, l)
	var s0 := sm.spawn_on_ground(a, l, MatchRules.StartKind.FIRST)
	await _step(30)
	var first_ok := _on_ground_at(a, l, s0) and absf(a.telemetry().fuel_fraction - 0.5) < 0.01 \
		and AirfieldPhases.ammo_fraction(a) > 0.99 and a.telemetry().on_ground
	# Abschuss: in die Luft setzen, Treffer melden -> Neustart am Boden
	a.place(Transform3D(Basis.IDENTITY, a.global_position + Vector3(0, 400, 0)), 80.0, 0.8, false)
	CombatEvents.bus().aircraft_destroyed.emit(a, null, 0)
	for f in 90:
		await get_tree().physics_frame
	await _step(20)
	var s1 := s0
	for s in l.parking_count():
		if _on_ground_at(a, l, s):
			s1 = s
	var loss_ok := _on_ground_at(a, l, s1) and absf(a.telemetry().fuel_fraction - 0.15) < 0.01 \
		and AirfieldPhases.ammo_fraction(a) < 0.01 and a.telemetry().height_agl < 3.0
	var loss_fuel := a.telemetry().fuel_fraction
	var loss_ammo := AirfieldPhases.ammo_fraction(a)
	# Nach Landung: Restzustand (33 % Treibstoff, Munition 40 %) bleibt
	a.damage.fuel.set_fraction(0.33)
	a.weapons.set_ammo_fraction(0.4)
	sm.respawn_after_landing(a)
	await _step(20)
	var land_ok := absf(a.telemetry().fuel_fraction - 0.33) < 0.01 \
		and absf(AirfieldPhases.ammo_fraction(a) - 0.4) < 0.02 and a.telemetry().on_ground
	var ok := first_ok and loss_ok and land_ok
	return [ok, "Erststart Platz %d %s (50 %%/voll), nach Abschuss %s (Tank %.0f %%, Munition %.0f %%), nach Landung %s" % [
		s0, first_ok, loss_ok, loss_fuel * 100.0, loss_ammo * 100.0, land_ok]]


## KI: Spawn am Boden setzt die Flugplatz-Phasen auf PARKED; drei Maschinen
## bekommen drei verschiedene freie Plätze.
func test_ai_spawn_distinct_spots() -> Array:
	var t := world as TerrainWorld
	var l := t.airfield_layout(1)
	var sm := _sm()
	var spots := []
	var parked := 0
	for k in 3:
		var a := Aircraft.create(load(FIGHTER), false)
		a.nation_id = Nations.RED
		world.add_child(a)
		var br := AIPilotBrain.new()
		a.add_child(br)
		a.pilot_seat.possess(br)
		sm.register_ground(a, br, l)
		spots.append(sm.spawn_on_ground(a, l, MatchRules.StartKind.FIRST))
		if br.airfield != null and br.airfield.phase == AirfieldPhases.Phase.PARKED:
			parked += 1
	await _step(30)
	var distinct: bool = spots[0] != spots[1] and spots[1] != spots[2] and spots[0] != spots[2]
	var ok: bool = distinct and parked == 3 and not (-1 in spots)
	return [ok, "Plätze %s, PARKED %d/3" % [str(spots), parked]]


## Drei KI-Maschinen rollen gleichzeitig los: keine Berührung (Abstand am Boden ≥ 12 m),
## die Piste nutzt immer nur eine, alle steigen auf 300 m ohne Schaden.
func test_three_ai_take_off_without_collision() -> Array:
	var t := world as TerrainWorld
	var l := t.airfield_layout(1)
	var sm := _sm()
	var planes: Array[Aircraft] = []
	var brains: Array[AIPilotBrain] = []
	var crashed := [0]
	for k in 3:
		var a := Aircraft.create(load(FIGHTER), false)
		a.nation_id = Nations.RED
		world.add_child(a)
		var br := AIPilotBrain.new()
		br.rng_seed = 50 + k
		a.add_child(br)
		a.pilot_seat.possess(br)
		sm.register_ground(a, br, l)
		sm.spawn_on_ground(a, l, MatchRules.StartKind.FIRST, [1, 3, 4][k])
		a.damage.fuel.set_fraction(0.8)       # Mindestmenge erfüllt: alle rollen sofort
		a.crashed.connect(func(_x): crashed[0] += 1)
		planes.append(a)
		brains.append(br)
	var min_d := INF
	var max_on_rw := 0
	var up := [false, false, false]
	var tm := 0.0
	for f in 60 * 300:
		await get_tree().physics_frame
		tm = f / 60.0
		var on_rw := 0
		for k in 3:
			var a := planes[k]
			var p := l.to_local(a.global_position)
			if a.telemetry().on_ground and absf(p.x) < l.runway_width * 0.5 and absf(p.z) < 450.0 \
					and a.telemetry().airspeed > 12.0:
				on_rw += 1
			if a.telemetry().height_agl > 300.0:
				up[k] = true
			for j in range(k + 1, 3):
				var b := planes[j]
				if a.telemetry().height_agl < 5.0 or b.telemetry().height_agl < 5.0:
					min_d = minf(min_d, a.global_position.distance_to(b.global_position))
		max_on_rw = maxi(max_on_rw, on_rw)
		if up[0] and up[1] and up[2]:
			break
	var dmg := 0
	for a in planes:
		if a.damage.health_fraction() < 0.999:
			dmg += 1
	var all_up: bool = up[0] and up[1] and up[2]
	var ok: bool = all_up and min_d >= 12.0 and max_on_rw <= 1 and crashed[0] == 0 and dmg == 0
	return [ok, "alle oben %s nach %.0f s, min. Abstand am Boden %.1f m, gleichzeitig auf der Piste max. %d, Schäden %d, Crash %d" % [
		all_up, tm, min_d, max_on_rw, dmg, crashed[0]]]
