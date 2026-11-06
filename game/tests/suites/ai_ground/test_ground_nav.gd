extends TestSuite
## M3.1: Wegsuche des Bodenpersonals und der Wagen (GroundNav). Echte Abfertigung mit
## AirfieldOps (2 KI-Mechaniker mit Figur, Tankwagen, Munitionswagen) auf flachem Boden:
## niemand durchdringt Flugzeug, Wagen oder Gebäude; Abfertigung mit 2 Helfern ≤ 1:45 min.

const CENTER := Vector3(700, 0, -250)    # Jolt: WorldBoundary nur ±1000 m
## Figur gilt als „im Hindernis“, wenn ihr Mittelpunkt tiefer als 0,05 m in der Box liegt
## (Kapselradius 0,3 m: Mindestabstand Mitte–Box ≥ 0,25 m wäre Berührung).
const CREW_MIN := 0.25
const C_LIMIT := 105.0


func after_each() -> void:
	GroundCrewBrain.player_probe = Callable()


func _ops(spot: int) -> Dictionary:
	var l := AirfieldLayout.make_default(0, TerrainWorld.RUNWAY_LENGTH, TerrainWorld.RUNWAY_WIDTH, Nations.BLUE)
	l.center = CENTER
	var board := JobBoard.new()
	board.rules = GroundRules.for_realism(MatchRules.GroundRealism.STANDARD)
	world.add_child(board)
	var host := Node3D.new()
	world.add_child(host)
	var a := Aircraft.create(load(FIGHTER), false)
	a.nation_id = Nations.BLUE
	host.add_child(a)
	var xf := l.parking_transform(spot)
	a.place_on_ground(xf.origin, -xf.basis.z, false, ServiceState.make(0.15, 0.0))
	var ops := AirfieldOps.new()
	world.add_child(ops)
	ops.setup(l, board, host, [])
	GroundCrewBrain.player_probe = func(): return [a.global_position]
	return {l = l, board = board, host = host, a = a, ops = ops}


func _free(s: Dictionary) -> void:
	for br in GroundCrewBrain.all.duplicate():
		var bd: Node = br.body()
		(bd if bd != null else br).queue_free()
	for k in ["ops", "host", "board"]:
		s[k].queue_free()
	await _step(2)


## Kleinster waagerechter Abstand (m) von p zur Box (Mitte waagerecht projiziert, Achse
## basis.x, halbe Länge längs mal cos(Neigung)); negativ = innen.
static func _box_dist(p: Vector3, xf: Transform3D, h: Vector3) -> float:
	var o := GroundNav._box(xf, Vector3.ZERO, Vector2(h.x, h.z))
	return GroundNav.dist_to(o, p.x, p.z)


func _boxes(s: Dictionary) -> Array:
	var out := []          # [{name, xf, h}]
	var a: Aircraft = s.a
	for c in a.get_children():
		if c is CollisionShape3D and c.shape is BoxShape3D:
			out.append({name = "Flugzeug", xf = a.global_transform * c.transform, h = (c.shape as BoxShape3D).size * 0.5})
	var nose := a.data.fuselage_box_center - Vector3(0, 0, a.data.fuselage_box_size.z * 0.5 + 0.25)
	out.append({name = "Propeller", xf = a.global_transform * Transform3D(Basis(), nose), h = Vector3(1.4, 0, 0.3)})
	for v in [s.ops.truck, s.ops.cart]:
		var gv: GroundVehicle = v
		out.append({name = gv.name, xf = gv.global_transform, h = Vector3(1.0, 1.0, gv.body_length * 0.5), node = gv})
	for m in s.ops.find_children("*", "", false, false):
		if m is Node3D and m.name in ["fuel_depot", "ammo_bunker", "hangar"]:
			var bb := GroundNav.model_aabb(m)
			out.append({name = m.name, xf = m.global_transform * Transform3D(Basis(), bb.get_center()), h = bb.size * 0.5})
	return out


## Echte Physik-Ticks bis versorgt; misst Mindestabstände. Rückgabe: Kennzahlen.
func _run(s: Dictionary) -> Dictionary:
	var a: Aircraft = s.a
	var board: JobBoard = s.board
	var ops: AirfieldOps = s.ops
	var t := 0.0
	var crew_min := INF
	var crew_hit := ""
	var veh_min := INF
	var veh_hit := ""
	var done := false
	while t < 200.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		var boxes := _boxes(s)
		if OS.has_environment("NAVDBG") and int(t * 60) % 300 == 0:
			print("NAVDBG t=%.0f jobs=%s" % [t, str(board.open_jobs(a).map(func(j): return "%s:%s:%.2f:%s:%s" % [j.kind, j.current_step(), j.progress, j.worker.name if j.worker else "-", j.blocked_reason]))])
			for br: GroundCrewBrain in ops.brains:
				print("NAVDBG   %s st=%d pos=%s veh=%s mv=%s legs=%s path=%s" % [br.body().name, br.state, s.l.to_local(br.position_now()).snapped(Vector3.ONE * 0.1), br.in_vehicle() != null, br._intent.move,
					str(br._legs.map(func(l): return [l.keys().size(), s.l.to_local(l.pos).snapped(Vector3.ONE * 0.1) if l.has("pos") else 0])),
					str(Array(br._nav_path).map(func(q): return s.l.to_local(q).snapped(Vector3.ONE * 0.1)))])
		for br: GroundCrewBrain in ops.brains:
			if br.in_vehicle() != null:
				continue
			var p: Vector3 = br.body().global_position
			for b in boxes:
				var d := _box_dist(p, b.xf, b.h)
				if d < crew_min:
					crew_min = d
					crew_hit = "%s %s (%.0f s, Schritt %s)" % [br.body().name, b.name, t, br._leg_for]
		# Wagen gegen Flugzeug: Ecken und Mittellinie des Wagens
		for v in [ops.truck, ops.cart]:
			var gv: GroundVehicle = v
			var hl := gv.body_length * 0.5
			for lp in [Vector3(0.9, 0, hl), Vector3(-0.9, 0, hl), Vector3(0.9, 0, -hl), Vector3(-0.9, 0, -hl),
					Vector3(0, 0, hl), Vector3(0, 0, -hl), Vector3.ZERO]:
				var p: Vector3 = gv.global_transform * lp
				for b in boxes:
					if b.get("node") == gv:
						continue
					var d := _box_dist(p, b.xf, b.h)
					if d < veh_min:
						veh_min = d
						veh_hit = "%s/%s (%.0f s)" % [gv.name, b.name, t]
		if t > 2.0 and board.is_serviced(a) and a.damage.fuel.fraction() > 0.97 \
				and a.weapons.ammo() == a.weapons.ammo_max():
			done = true
			break
	return {t = t, done = done, crew_min = crew_min, crew_hit = crew_hit, veh_min = veh_min, veh_hit = veh_hit}


## Abfertigung mit 2 Mechanikern, Tankwagen und Munitionswagen: kein Durchdringen.
func test_turnaround_no_penetration() -> Array:
	var res := []
	var ok := true
	for spot in [0, 5]:
		var s: Dictionary = await _ops(spot)
		var r: Dictionary = await _run(s)
		await _free(s)
		var good: bool = r.done and r.crew_min >= CREW_MIN and r.veh_min >= 0.5
		ok = ok and good
		res.append("Platz %d: %s %.0f s, Figur min %.2f m (%s), Wagen min %.2f m (%s)" % [spot,
			"fertig" if r.done else "NICHT fertig", r.t, r.crew_min, r.crew_hit, r.veh_min, r.veh_hit])
	return [ok, "; ".join(res)]


## Weg um ein abgestelltes Flugzeug und eine Halle: frei, deterministisch, länger als gerade.
func test_path_around_obstacles() -> Array:
	var a := _spawn(true)
	var hall := Node3D.new()
	world.add_child(hall)
	hall.global_position = a.global_position + Vector3(-20, 0, 0)
	GroundNav.register_static(hall, Vector3.ZERO, Vector2(5, 12))
	await _step(2)
	var from := a.global_position + Vector3(-30, 0, 2)
	var to := a.global_position + Vector3(9, 0, 1)
	from.y = 0.0
	to.y = 0.0
	var obs := GroundNav.obstacles()
	var p1 := GroundNav.find_path(obs, from, to, GroundNav.CREW_CLEAR)
	var p2 := GroundNav.find_path(obs, from, to, GroundNav.CREW_CLEAR)
	var ok := p1 == p2 and p1.size() >= 2 and p1[p1.size() - 1].is_equal_approx(to)
	var prev := from
	var worst := INF
	for q in p1:
		ok = ok and GroundNav.segment_free(obs, prev, q, 0.3)
		for k in 11:
			var m := prev.lerp(q, k / 10.0)
			worst = minf(worst, GroundNav.min_dist(obs, m.x, m.z))
		prev = q
	var l := GroundNav.path_length(obs, from, to, GroundNav.CREW_CLEAR)
	ok = ok and l > from.distance_to(to) + 2.0
	# Ziel im Rumpf: Weg endet an der nächsten freien Stelle (≤ 3 m, Arbeitsabstand)
	var cap := a.service_point(ServiceMarkers.SVC_FUEL_CAP)
	var p3 := GroundNav.find_path(obs, from, cap, GroundNav.CREW_CLEAR)
	var end := p3[p3.size() - 1]
	var end_d := Vector2(end.x - cap.x, end.z - cap.z).length()
	ok = ok and end_d <= 2.6 and GroundNav.min_dist(obs, end.x, end.z) >= GroundNav.CREW_CLEAR - 0.3
	hall.queue_free()
	a.queue_free()
	return [ok, "%d Wegpunkte, Mindestabstand %.2f m, Länge %.1f m (gerade %.1f m), Tankdeckel: Ende %.2f m daneben" % [
		p1.size(), worst, l, from.distance_to(to), end_d]]


## Wagen bremst vor Flugzeug und Figur im Fahrweg, nicht vor seitlichen Hindernissen.
func test_vehicle_brakes_for_obstacle() -> Array:
	var tr := FuelTruck.create(100.0)
	world.add_child(tr)
	tr.place(Vector3(300, 0, 300), 0.0)
	var br := GroundCrewBrain.new()
	world.add_child(br)
	await _step(1)
	var fwd := tr.forward()
	var a := _spawn(true)
	a.global_position = tr.global_position + fwd * 9.0 + Vector3(0, a.global_position.y, 0)
	await _step(1)
	var front := br._drive_blocked(tr, 40.0)
	a.global_position = tr.global_position + fwd * 9.0 + Vector3(-fwd.z, 0, fwd.x) * 9.0 + Vector3(0, a.global_position.y, 0)
	await _step(1)
	var side := br._drive_blocked(tr, 40.0)
	var ch := CrewCharacter.new()
	world.add_child(ch)
	ch.global_position = tr.global_position + fwd * 5.0
	await _step(1)
	var walker := br._drive_blocked(tr, 40.0)
	for n in [ch, a, br, tr]:
		n.queue_free()
	return [front and not side and walker, "Flugzeug vorn: %s, seitlich: %s, Figur vorn: %s" % [front, side, walker]]
