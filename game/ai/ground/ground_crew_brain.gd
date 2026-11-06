class_name GroundCrewBrain
extends Controller
## M3 (Strang G / Paket 7a): KI-Bodenpersonal. Nimmt Jobs vom JobBoard nach Priorität
## (Alarm > Spieler-Maschine > KI-Maschine > Wagen nachfüllen, bei Gleichstand der kürzere Weg),
## geht zum Servicepunkt und ruft dieselbe Funktion wie der Spieler: JobBoard.request_step().
## Hält PROP_ZONE Abstand zum laufenden Propeller (bricht die Arbeit ab und geht raus).
##
## Zwei Darstellungen über dieselben Job-Schritte:
## - Voll: steuert die Figur (seat.vehicle, z. B. CrewCharacter) über den CrewIntent.
## - Sim-LOD (abstract_mode): ist kein Spieler im Umkreis LOD_RANGE, laufen die Wege als
##   getaktete Zeiten (Abstand / Gehtempo); die Figur springt ans Ziel, ihre Physik ruht.
## Mit Fahrzeugen (dispatch.fuel_truck / ammo_cart) steigt das Personal ein und fährt sie selbst
## (voll: PilotIntent über compute_intent, Sim-LOD: getaktete Fahrzeit); ohne Fahrzeug läuft der Weg
## „Tankwagen holen“ als Zeit. Befehlsrad: command(cmd, target) bzw. GroundCrewBrain.issue().

enum Command { FULL_SERVICE, FUEL_ONLY, AMMO_ONLY, QUICK_SERVICE, TRUCK_TO_ME, FOLLOW, REPAIR, PAUSE }
const COMMAND_LABELS := ["Voll abfertigen", "Nur tanken", "Nur Munition", "Schnellabfertigung",
	"Tankwagen zu mir", "Folgen", "Reparieren", "Zurück/Pause"]
enum Priority { REFILL_VEHICLE, AI_AIRCRAFT, PLAYER_AIRCRAFT, ALARM }
const PROP_ZONE := 5.0
const LOD_RANGE := 2000.0
const ARRIVE_R := 1.0
const PROP_THROTTLE := 0.05
const SPRINT_FROM := 25.0
const SPRINT_SPEED := 4.5
const TRUCK_STOP := 8.0         # „Tankwagen zu mir“: Halteabstand
const TRUCK_PARK := 7.0         # Tankwagen zum Tanken: Abstand zum Tankdeckel (Schlauch 12 m)
const CART_PARK := 6.0
const CART_MAX := 15.0          # Munitionswagen weiter weg: erst hinfahren
const DRIVE_ARRIVE := 2.5
const VIA_ARRIVE := 5.0
const WALK_ROUTE_MIN := 30.0
## Festlaufen (Figur schiebt gegen Wand/Fahrzeug): seitlich ausweichen.
const STUCK_SPEED := 0.3
const STUCK_TIME := 0.4
const STUCK_ARRIVE := 2.6
const SIDESTEP_TIME := 1.2
var _stuck_t := 0.0
var _side_t := 0.0
var _side_sign := 1.0
var _last_pos := Vector3.ZERO
const FOLLOW_DIST := 3.0
## M3.1 Wegsuche: Wegpunkt erreicht, Prüftakt, Abstand zu anderem Personal.
const NAV_REACH := 0.7
const NAV_END_R := 0.45
const NAV_CHECK := 0.5
const CROWD_R := 1.0
const SAFE_R := 0.35
var _nav_path := PackedVector3Array()
var _nav_goal := Vector3.INF
var _nav_check := 0.0
## Wagen steht vor einem Hindernis (s, Diagnose).
var blocked_t := 0.0

enum State { IDLE, TRAVEL, WORK, CLEAR }

## Alle aktiven Brains (Propellerzone frei? Sim-LOD).
static var all: Array = []
## Liefert die Positionen der Spieler (Sim-LOD). Standard: aktive Kamera.
static var player_probe: Callable = Callable()

var work_mul := 0.8
var job_id := 0
var abstract_mode := false
## -1 = automatisch (LOD_RANGE), 0 = immer voll, 1 = immer Sim-LOD.
var force_mode := -1
var board: JobBoard = null
var dispatch: GroundCrewDispatch = null
var state := State.IDLE
## Position im Sim-LOD (bzw. zuletzt bekannte Position der Figur).
var sim_pos := Vector3.ZERO
var work_time := 0.0
var travel_time := 0.0
## Befehlsfilter (Paket 7b), Standard: alles.
var command_kind := Command.FULL_SERVICE
var command_target: Node = null

var _intent := CrewIntent.new()
var _goal := Vector3.ZERO
var _legs: Array = []          # [{pos: Vector3, wait: float, teleport: bool}]
var _leg_left := -1.0
var _leg_for := ""             # "<job>:<step>", für den die Wege berechnet sind
var _carrying := false
var _work_mul_set := false
var _board_fixed := false
var _char: Node3D = null
var _drive_goal = null          # Vector3 oder null
var _drive_intent := PilotIntent.new()


func _enter_tree() -> void:
	_board_fixed = _board_fixed or board != null
	if not all.has(self):
		all.append(self)


func _exit_tree() -> void:
	all.erase(self)


func _physics_process(dt: float) -> void:
	think(dt)


func rules() -> GroundRules:
	return _board().rules if _board() != null else GroundRules.for_realism()


## Die Figur (CrewCharacter), auch während sie in einem Fahrzeug sitzt.
func body() -> Node3D:
	if _char != null and is_instance_valid(_char):
		return _char
	if seat != null and seat.role == Seat.Role.CREW and seat.vehicle != null:
		_char = seat.vehicle
		return _char
	return null


## Fahrzeug, das gerade gefahren wird (oder null).
func in_vehicle() -> GroundVehicle:
	if seat != null and seat.role == Seat.Role.DRIVER:
		return seat.vehicle as GroundVehicle
	return null


func position_now() -> Vector3:
	var v := in_vehicle()
	if v != null:
		return v.global_position
	var b := body()
	return b.global_position if b != null and is_instance_valid(b) and not abstract_mode else sim_pos


## Einträge für das Befehlsrad: [{id, label}].
static func wheel_entries() -> Array:
	var out := []
	for i in COMMAND_LABELS.size():
		out.append({id = i, label = COMMAND_LABELS[i]})
	return out


## Befehl an das Personal (Befehlsrad). Job-Befehle gehen an alle in crew (leer = alle),
## „Tankwagen zu mir“ und „Folgen“ an die nächste Figur. Rückgabe: Anzahl angenommen.
static func issue(cmd: int, target: Node, crew: Array = []) -> int:
	var list: Array = crew if not crew.is_empty() else all.duplicate()
	list = list.filter(func(b): return is_instance_valid(b))
	if list.is_empty():
		return 0
	if cmd == Command.TRUCK_TO_ME or cmd == Command.FOLLOW:
		var ref := Vector3.ZERO
		var first: GroundCrewBrain = list[0]
		if cmd == Command.TRUCK_TO_ME and first.dispatch != null and first.dispatch.fuel_truck != null:
			ref = first.dispatch.fuel_truck.global_position
		elif target is Node3D:
			ref = target.global_position
		list.sort_custom(func(a, b): return a.position_now().distance_to(ref) < b.position_now().distance_to(ref))
		return 1 if list[0].command(cmd, target) else 0
	var n := 0
	for b in list:
		if b.command(cmd, target):
			n += 1
	return n


## Befehl aus dem Befehlsrad (nur Server). target = Zielmaschine (Job-Befehle), Ziel für
## „Tankwagen zu mir“/„Folgen“ (Node3D). FULL_SERVICE mit null = zurück zur Automatik.
func command(cmd: int, target: Node) -> bool:
	if not Authority.is_server() or cmd < 0 or cmd >= COMMAND_LABELS.size():
		return false
	var b := _board()
	if b == null:
		return false
	if cmd in [Command.TRUCK_TO_ME, Command.FOLLOW] and not (target is Node3D):
		return false
	if cmd == Command.TRUCK_TO_ME and (dispatch == null or dispatch.fuel_truck == null):
		return false
	_release_mine()
	_drop_focus()
	command_kind = cmd
	command_target = target
	match cmd:
		Command.FULL_SERVICE, Command.FUEL_ONLY, Command.AMMO_ONLY, Command.REPAIR, Command.QUICK_SERVICE:
			if target is Aircraft and dispatch != null:
				dispatch.plan_for(target, cmd)
		Command.TRUCK_TO_ME:
			var t := dispatch.fuel_truck
			var goal: Vector3 = target.global_position
			var away := t.global_position - goal
			away.y = 0.0
			if away.length_squared() < 0.01:
				away = Vector3.RIGHT
			_legs = _route_drives([{drive = t, pos = goal + away.normalized() * TRUCK_STOP}])
			_leg_for = "cmd"
	return true


func compute_intent(_dt: float) -> PilotIntent:
	var i := _drive_intent
	i.throttle = 0.0
	i.brakes = 0.0
	i.yaw = 0.0
	var v := in_vehicle()
	if v == null or _drive_goal == null:
		if v != null and v.seat_speed() > 0.1:
			i.brakes = 1.0
		return i
	var to: Vector3 = _drive_goal - v.global_position
	to.y = 0.0
	var d := to.length()
	var fwd := v.forward()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var ang := atan2(to.dot(right), to.dot(fwd))
	i.yaw = clampf(ang * 2.0, -1.0, 1.0)
	var want := clampf(d * 0.5, 0.0, GroundVehicle.MAX_SPEED * 0.8)
	if absf(ang) > 1.0:
		want = minf(want, 3.0)
	if d < DRIVE_ARRIVE:
		want = 0.0
	# M3.1: vor Hindernissen (Flugzeug, Wagen, Gebäude, Figur) im Fahrweg bremsen
	if want > 0.0 and _drive_blocked(v, d):
		want = 0.0
		if v.speed > 0.05:
			i.brakes = 1.0
		return i
	if v.speed < want - 0.3:
		i.throttle = 0.8
	elif v.speed > want + 0.4 or (want == 0.0 and v.speed > 0.1):
		i.brakes = 0.8
	return i


## Liegt im Fahrweg (Breite des Wagens + Saum, Länge Bremsweg + 2,5 m; vor dem Ziel höchstens
## bis zur Endlage der Front) ein Hindernis?
func _drive_blocked(v: GroundVehicle, d_goal: float) -> bool:
	var via: bool = not _legs.is_empty() and _legs[0].get("via", false)
	var hl := v.body_length * 0.5
	var reach := maxf(v.speed, 0.0) ** 2 / (2.0 * GroundVehicle.BRAKE_DECEL * 0.7) + 2.5
	if not via:
		reach = minf(reach, d_goal - hl + 0.5)
	if reach <= 0.0:
		return false
	var fwd := v.forward()
	fwd.y = 0.0
	fwd = fwd.normalized()
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var hw := maxf(v.body_radius, 1.12) + 0.3
	var obs := GroundNav.obstacles([v, body()], false, true)
	var k := 0.0
	while k <= reach:
		var c := v.global_position + fwd * (hl + k)
		for lat in [-hw, 0.0, hw]:
			if GroundNav.min_dist(obs, c.x + right.x * lat, c.z + right.z * lat) < 0.2:
				blocked_t += get_physics_process_delta_time()
				return true
		k += 0.7
	blocked_t = 0.0
	return false


func compute_crew_intent(_dt: float) -> CrewIntent:
	return _intent


# --- Denken -----------------------------------------------------------------------

func think(dt: float) -> void:
	if not Authority.is_server():
		return
	var b := _board()
	if b == null:
		return
	if not _work_mul_set:
		_work_mul_set = true
		if is_equal_approx(work_mul, 0.8):
			work_mul = b.rules.ai_work_mul
	_update_lod()
	var bd := body()
	if bd != null and is_instance_valid(bd) and not abstract_mode:
		sim_pos = bd.global_position
	_intent.move = Vector2.ZERO
	_intent.sprint = false
	if _leg_for == "cmd":
		if _legs.is_empty():
			_leg_for = ""
			command_kind = Command.FULL_SERVICE
			command_target = null
		else:
			_run_legs(dt)
			return
	if in_vehicle() != null and (_legs.is_empty() or not _legs[0].has("drive")) and _legs_need_exit():
		_exit_vehicle()
		return
	match command_kind:
		Command.PAUSE:
			state = State.IDLE
			if dispatch != null:
				_go_to(dispatch.crew_spawn, dt)
			return
		Command.FOLLOW:
			_follow(dt)
			return
	if _avoid_props(dt):
		return
	var j := b.get_job(job_id)
	if j != null and j.blocked_reason != &"" and not _fixable(j):
		b.release(j.id, _worker_node())
		j = null
	if j == null or not j.is_open() or not _job_allowed(j):
		_drop_focus()
		j = _pick_job()
		if j == null:
			state = State.IDLE
			return
	_work_on(j, dt)


func _work_on(j: GroundJob, dt: float) -> void:
	var b := _board()
	var r := b.rules
	var s := j.current_step()
	if j.autonomous(s, r):
		if j is RefuelJob and j.dest_source != null:
			if r.pump_watch and j.fill_reached():
				b.request_step(peer_id, j.id, j.steps[j.step_index + 1], dt)
			elif not r.pump_watch:
				_drop_focus(false)
			return
		if j is RefuelJob and r.pump_watch:
			if _go_to(j.aircraft().service_point(ServiceMarkers.SVC_FUEL_CAP), dt) and j.fill_reached():
				b.request_step(peer_id, j.id, j.steps[j.step_index + 1], dt)
			return
		_drop_focus(false)       # Pumpe läuft allein: nächsten Job nehmen, Anspruch bleibt
		var nxt := _pick_job()
		if nxt != null and nxt != j:
			_work_on(nxt, dt)
		return
	var key := "%d:%s" % [j.id, s]
	if key != _leg_for:
		_leg_for = key
		_legs = _plan_legs(j, s)
		_leg_left = -1.0
	if not _legs.is_empty():
		_run_legs(dt)
		return
	state = State.WORK
	_face(j)
	var before := j.step_index
	if b.request_step(peer_id, j.id, s, dt):
		work_time += dt
	if j.step_index != before:
		if j is RearmJob:
			_carrying = j.current_step() in [&"hatch_open", &"belt"]
		if j.is_done():
			_carrying = false
			_drop_focus()


func _pick_job() -> GroundJob:
	var b := _board()
	var best: GroundJob = null
	var best_score := -INF
	var here := position_now()
	for j: GroundJob in b.open_jobs():
		if (j.blocked_reason != &"" and not _fixable(j)) or not _job_allowed(j):
			continue
		var mine := j.worker == _worker_node()
		if j.worker != null and is_instance_valid(j.worker) and not mine:
			continue
		if j.autonomous(j.current_step(), b.rules) and not (j is RefuelJob and b.rules.pump_watch):
			continue
		var a := j.aircraft()
		var refill: bool = j is RefuelJob and j.dest_source != null
		if not refill and (a == null or prop_danger(a) or (dispatch != null and not dispatch.is_parked(a))):
			continue
		if refill and (dispatch == null or j.target != dispatch.fuel_truck):
			continue
		var d := here.distance_to(_rough_pos(j))
		if not mine and _idle_other_closer(j, d):
			continue
		# Priorität zuerst, dann längste Kette (Pumpzeit zählt doppelt: läuft parallel), dann Weg.
		var score := j.priority * 1000.0 + _job_length(j, b.rules) - d / maxf(b.rules.walk_speed, 0.1) \
			+ (500.0 if mine else 0.0)
		if score > best_score:
			best_score = score
			best = j
	if best != null and b.claim(peer_id, best.id, _worker_node()):
		job_id = best.id
		_leg_for = ""
		return best
	return null


## Steht ein anderes freies Personal deutlich näher (> 10 s Weg), überlässt man ihm den Job.
func _idle_other_closer(j: GroundJob, d: float) -> bool:
	var p := _rough_pos(j)
	for o in all:
		if o == self or not is_instance_valid(o) or o.job_id != 0 or o._board() != _board() \
				or o.command_kind == Command.PAUSE or not o._job_allowed(j):
			continue
		if (d - o.position_now().distance_to(p)) / SPRINT_SPEED > 10.0:
			return true
	return false


func _job_length(j: GroundJob, r: GroundRules) -> float:
	var t := 0.0
	for i in range(j.step_index, j.steps.size()):
		var st: StringName = j.steps[i]
		t += j.duration(st, r) * (2.0 if j.autonomous(st, r) else 1.0)
	return t


func _job_allowed(j: GroundJob) -> bool:
	match command_kind:
		Command.PAUSE: return false
		Command.FUEL_ONLY: return j is RefuelJob
		Command.AMMO_ONLY: return j is RearmJob
		Command.REPAIR: return j is RepairJob
		Command.FOLLOW, Command.TRUCK_TO_ME: return false
	if command_target != null and is_instance_valid(command_target) and j.target != command_target:
		return false
	return true


func _drop_focus(release_claim := true) -> void:
	var b := _board()
	if release_claim and b != null and job_id != 0:
		var j := b.get_job(job_id)
		if j != null and j.is_open() and j.progress <= 0.0 and not j.autonomous(j.current_step(), b.rules) \
				and j.step_index == 0:
			b.release(job_id, _worker_node())
	job_id = 0
	_leg_for = ""
	_legs.clear()


## Arbeiter für den JobBoard: die Figur (Positionsprüfung) oder ohne Figur der Brain selbst.
func _worker_node() -> Node:
	var bd := body()
	return bd if bd != null and is_instance_valid(bd) else self


# --- Wege -------------------------------------------------------------------------

## Wege zum Schritt: Liste von Zielen; wait = feste Zeit (z. B. Tankwagen fahren).
func _plan_legs(j: GroundJob, s: StringName) -> Array:
	return _route_drives(_plan_legs_raw(j, s))


## Paket 14: Fahrten über die Fahrspur des Platzes (dispatch.drive_route), damit Wagen nicht
## quer durch Hallen oder abgestellte Maschinen fahren. Zwischenpunkte: {drive, pos, via = true}.
func _route_drives(legs: Array) -> Array:
	if dispatch == null or not dispatch.has_method("drive_route"):
		return legs
	var out := []
	var at := {}
	var cur := position_now()
	for leg in legs:
		if leg.has("drive") and not leg.get("via", false):
			var v: GroundVehicle = leg.drive
			var from: Vector3 = at.get(v, v.global_position)
			for p in dispatch.drive_route(from, leg.pos):
				out.append({drive = v, pos = p, via = true})
			at[v] = leg.pos
			cur = leg.pos
		elif leg.has("pos"):
			cur = leg.pos
		out.append(leg)
	return out


## Nach dem Einsteigen: Zwischenpunkte ab der aktuellen Wagenposition neu bestimmen (die Wege
## wurden evtl. geplant, als der Wagen noch woanders stand).
func _reroute(v: GroundVehicle) -> void:
	if dispatch == null or not dispatch.has_method("drive_route"):
		return
	while not _legs.is_empty() and _legs[0].get("drive") == v and _legs[0].get("via", false):
		_legs.pop_front()
	if _legs.is_empty() or _legs[0].get("drive") != v:
		return
	var pts: Array = dispatch.drive_route(v.global_position, _legs[0].pos)
	pts.reverse()
	for p in pts:
		_legs.push_front({drive = v, pos = p, via = true})


func _plan_legs_raw(j: GroundJob, s: StringName) -> Array:
	var r := _board().rules
	var a := j.aircraft()
	var legs := []
	if j is RefuelJob and j.dest_source != null and j.target is GroundVehicle:
		# Paket 14: Wagen nachfüllen – Wagen zum Lager fahren, dort an der Trommel arbeiten.
		var tv := j.target as GroundVehicle
		if s == &"bring" and not j.source_in_reach(r):
			legs.append({drive = tv, pos = _depot_fill_pos(tv, dispatch.depot if dispatch != null else j.source)})
		var at := tv.global_position + tv.global_transform.basis.x * 1.8
		if position_now().distance_to(at) > ARRIVE_R + 1.0 or not legs.is_empty():
			legs.append({pos = at, wait = 0.0, teleport = false})
		return legs
	if a == null:
		return legs
	if j is RefuelJob:
		var cap := a.service_point(ServiceMarkers.SVC_FUEL_CAP)
		if s == &"bring":
			var hose_from := cap + _away(a, cap) * r.hose_walk_m
			var truck := j.source_node as GroundVehicle
			if truck != null:
				if not j.source_in_reach(r):
					var need: float = j.liters_needed()
					var depot := dispatch.depot if dispatch != null else null
					if r.truck_fill_first and depot != null and truck.has_method("fill_from") \
							and truck.tank.available(j.grade) < need:
						var dp := _depot_fill_pos(truck, depot)
						legs.append({drive = truck, pos = dp})
						legs.append({fill = truck, src = depot, grade = j.grade, need = need})
					legs.append({drive = truck, pos = _vehicle_spot(a, cap, false)})
				legs.append({pos = cap, wait = 0.0, teleport = false})
				return legs
			if not r.truck_at_spot and j.source_node == null:
				var tp := _truck_pos()
				legs.append({pos = tp, wait = 0.0, teleport = false})
				var drive := r.mount_s + tp.distance_to(hose_from) / maxf(r.truck_speed, 0.1)
				if r.truck_fill_first:
					drive += j.liters_needed() / maxf(r.truck_fill_lps, 0.1)
				legs.append({pos = hose_from, wait = drive, teleport = true})
			else:
				legs.append({pos = hose_from, wait = 0.0, teleport = false})
			legs.append({pos = cap, wait = 0.0, teleport = false})
		elif j.duration(s, r) > 0.0:
			legs.append({pos = cap, wait = 0.0, teleport = false})
	elif j is RearmJob:
		var pt := j.point(&"belt", r)
		var hatch := a.service_point(pt if pt != "" else ServiceMarkers.SVC_GUN_HATCH_L)
		if s == &"crate":
			var cart := dispatch.ammo_cart if dispatch != null else null
			if cart != null and is_instance_valid(cart) and j.store == cart.store:
				if _flat_dist(cart.global_position, hatch) > CART_MAX:
					var cs := _vehicle_spot(a, hatch, true)
					legs.append({drive = cart, pos = cs})
					var to_h := hatch - cs
					to_h.y = 0.0
					legs.append({pos = cs + to_h.normalized() * 2.5, wait = 0.0, teleport = false})
				else:
					legs.append({pos = cart.global_position + (hatch - cart.global_position).normalized() * 2.0,
						wait = 0.0, teleport = false})
			else:
				legs.append({pos = _cart_pos(a, hatch, r), wait = 0.0, teleport = false})
		elif j.point(s, r) != "":
			legs.append({pos = a.service_point(j.point(s, r)), wait = 0.0, teleport = false})
	elif j is RepairJob:
		if r.repair_needs_toolbox and not j.has_toolbox():
			# Werkzeugkiste vom Munitionswagen holen (Haken: echte CarryItem-Aufnahme, Paket 7b/14).
			legs.append({pos = _cart_pos(a, _repair_pos(j, a), r), wait = 0.0, teleport = false, toolbox = true})
		legs.append({pos = _repair_pos(j, a), wait = 0.0, teleport = false})
	# Schon da? Dann keine Wege.
	if legs.size() == 1 and legs[0].wait <= 0.0 and position_now().distance_to(legs[0].pos) <= ARRIVE_R:
		legs.clear()
	return legs


func _run_legs(dt: float) -> void:
	state = State.TRAVEL
	var leg: Dictionary = _legs[0]
	if leg.has("drive"):
		_run_drive(leg, dt)
		return
	if leg.has("fill"):
		_run_fill(leg, dt)
		return
	if in_vehicle() != null:
		_exit_vehicle()
		return
	if leg.wait > 0.0 or abstract_mode:
		if _leg_left < 0.0:
			var t: float = leg.wait
			if abstract_mode and not leg.teleport:
				t += _walk_time(_nav_len(position_now(), leg.pos))
			_leg_left = t
		_leg_left -= dt
		travel_time += dt
		if _leg_left <= 0.0:
			_place(leg.pos)
			_arrive()
		return
	travel_time += dt
	if _go_to(leg.pos, dt):
		_arrive()


## Ziel eines Wegs erreicht. Werkzeugkisten-Weg: danach hat der Job die Kiste.
func _arrive() -> void:
	var leg: Dictionary = _legs.pop_front()
	_leg_left = -1.0
	if leg.get("toolbox", false):
		var j := _board().get_job(job_id)
		if j is RepairJob:
			j.toolbox = true
			j.recheck(_board().rules)


## Blockade, die das Personal selbst beheben kann (Werkzeugkiste holen).
func _fixable(j: GroundJob) -> bool:
	return j.blocked_reason == &"toolbox_missing" and j is RepairJob


## Volle Darstellung: Figur steuern. Rückgabe: angekommen.
func _go_to(p: Vector3, _dt: float) -> bool:
	var here := position_now()
	var d := Vector3(p.x - here.x, 0.0, p.z - here.z)
	if d.length() <= ARRIVE_R * 0.8:
		return true
	if abstract_mode or body() == null:
		_place(p)
		return true
	# M3.1: Wegsuche (GroundNav) um Flugzeuge, Wagen, Gebäude und Propellerzonen
	var tgt = _nav_target(p, here)
	if tgt == null:
		_nav_goal = Vector3.INF
		_stuck_t = 0.0
		_side_t = 0.0
		return true          # Ziel liegt im Hindernis-Saum: an der letzten freien Stelle angekommen
	var dn := Vector3(tgt.x - here.x, 0.0, tgt.z - here.z)
	if dn.length_squared() < 1e-6:
		dn = d
	var dir := dn.normalized() + _prop_push(here) + _crowd_push(here)
	dir.y = 0.0
	if dir.length_squared() < 1e-6:
		dir = dn.normalized()
	dir = dir.normalized()
	# Paket 14: festgelaufen -> eine Weile seitlich ausweichen (gleiche Seite, bis es klappt)
	var cb := body() as CharacterBody3D
	if cb != null:
		var dt := get_physics_process_delta_time()
		var moved := _flat_dist(cb.global_position, _last_pos)
		_last_pos = cb.global_position
		var moving := moved > STUCK_SPEED * dt
		_stuck_t = 0.0 if moving else _stuck_t + dt
		if _stuck_t > STUCK_TIME and d.length() <= STUCK_ARRIVE:
			_stuck_t = 0.0
			_side_t = 0.0
			return true          # Ziel liegt im Flugzeug/Fahrzeug: nah genug (JobBoard: work_range)
		if _stuck_t > STUCK_TIME:
			_stuck_t = 0.0
			_nav_goal = Vector3.INF          # neu planen
			if _side_t > 0.0:
				_side_sign = -_side_sign
			_side_t = SIDESTEP_TIME
		if _side_t > 0.0:
			_side_t -= dt
			dir = (dir * 0.3 + dir.cross(Vector3.UP) * _side_sign).normalized()
	# M3.1: nie in ein Hindernis hinein (Ausweichen, Gedränge, Seitschritt): Richtung drehen
	# oder stehen bleiben
	var safe := _safe_dir(here, dir)
	if safe == Vector3.ZERO:
		_intent.move = Vector2.ZERO
		return false
	dir = safe
	_intent.look_yaw = atan2(-dir.x, -dir.z)
	_intent.move = Vector2(0.0, 1.0)
	_intent.sprint = d.length() > SPRINT_FROM and not _carrying
	return false


## Richtung (oder gedreht bis ±180°), die den Abstand zu Hindernissen nicht unter SAFE_R
## drückt; Vector3.ZERO = keine.
func _safe_dir(here: Vector3, dir: Vector3) -> Vector3:
	var obs := GroundNav.obstacles([], true)
	var lim := minf(GroundNav.min_dist(obs, here.x, here.z), SAFE_R)
	for ang in [0.0, 0.5, -0.5, 1.0, -1.0, 1.57, -1.57, 2.2, -2.2, 3.14]:
		var dd := dir.rotated(Vector3.UP, ang * _side_sign)
		if GroundNav.min_dist(obs, here.x + dd.x * 0.25, here.z + dd.z * 0.25) >= lim - 0.01:
			return dd
	return Vector3.ZERO


## Nächster Wegpunkt zu p (Szene) oder null = am Ende eines verkürzten Wegs angekommen.
## Neu geplant wird bei neuem Ziel und alle NAV_CHECK s, wenn der nächste Abschnitt blockiert ist.
func _nav_target(p: Vector3, here: Vector3):
	var dt := get_physics_process_delta_time()
	_nav_check -= dt
	var obs: Array = []
	if _flat_dist(p, _nav_goal) > 0.3 or _nav_path.is_empty():
		obs = _nav_obstacles()
		_nav_path = GroundNav.find_path(obs, here, p, GroundNav.CREW_CLEAR)
		_nav_goal = p
		_nav_check = NAV_CHECK
	elif _nav_check <= 0.0:
		_nav_check = NAV_CHECK
		obs = _nav_obstacles()
		var last := _nav_path.size() == 1
		if not GroundNav.segment_free(obs, here, _nav_path[0], GroundNav.CREW_CLEAR * 0.5, 0.6 if last else 0.0):
			_nav_path = GroundNav.find_path(obs, here, p, GroundNav.CREW_CLEAR)
	while _nav_path.size() > 1 and _flat_dist(here, _nav_path[0]) < NAV_REACH:
		_nav_path.remove_at(0)
	var q := _nav_path[0]
	if _nav_path.size() == 1 and _flat_dist(q, p) > 0.3 and _flat_dist(here, q) <= NAV_END_R:
		return null
	return q


func _nav_obstacles() -> Array:
	return GroundNav.obstacles([], true)


func _nav_len(from: Vector3, to: Vector3) -> float:
	return GroundNav.path_length(GroundNav.obstacles([], true), from, to, GroundNav.CREW_CLEAR)


## Steht die Figur in einem Hindernis-Saum (z. B. im Fahrweg eines Wagens), zur nächsten freien
## Stelle gehen.
func _step_aside(_dt: float) -> void:
	if abstract_mode or body() == null:
		return
	var here := position_now()
	var obs := _nav_obstacles()
	if GroundNav.min_dist(obs, here.x, here.z) >= GroundNav.CREW_CLEAR - 0.05:
		return
	var q = GroundNav.free_near(obs, here, GroundNav.CREW_CLEAR + 0.2, here)
	if q == null:
		return
	var d := Vector3(q.x - here.x, 0.0, q.z - here.z)
	if d.length() < 0.05:
		return
	var dir := _safe_dir(here, d.normalized())
	if dir != Vector3.ZERO:
		_intent.look_yaw = atan2(-dir.x, -dir.z)
		_intent.move = Vector2(0.0, 1.0)


## Abstand zu anderem Personal (nicht ineinander laufen).
func _crowd_push(here: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for br in all:
		if br == self or not is_instance_valid(br) or br.in_vehicle() != null or br.abstract_mode:
			continue
		var d := Vector3(here.x, 0.0, here.z) - Vector3(br.position_now().x, 0.0, br.position_now().z)
		var l := d.length()
		if l < CROWD_R and l > 0.01:
			push += d / l * (CROWD_R - l) * 1.5
	return push


func _place(p: Vector3) -> void:
	sim_pos = p
	if in_vehicle() != null:
		return
	var bd := body()
	if bd != null and is_instance_valid(bd):
		bd.global_position = p
		if bd is CharacterBody3D:
			bd.velocity = Vector3.ZERO


func _speed() -> float:
	var r := _board().rules
	return r.walk_speed * (r.crate_speed_mul if _carrying else 1.0)


## Gehzeit wie in der vollen Darstellung: über SPRINT_FROM m Sprint, danach Gehen.
func _walk_time(d: float) -> float:
	if _carrying or d <= SPRINT_FROM:
		return d / _speed()
	return (d - SPRINT_FROM) / SPRINT_SPEED + SPRINT_FROM / _speed()


func _face(j: GroundJob) -> void:
	var a := j.aircraft()
	if a == null:
		return
	var d := a.global_position - position_now()
	if Vector2(d.x, d.z).length() > 0.1:
		_intent.look_yaw = atan2(-d.x, -d.z)


func _truck_pos() -> Vector3:
	if dispatch != null:
		return dispatch.truck_pos
	return position_now()


func _cart_pos(a: Aircraft, hatch: Vector3, r: GroundRules) -> Vector3:
	if dispatch != null and dispatch.has_cart_pos:
		return dispatch.cart_pos
	return hatch + _away(a, hatch) * r.crate_walk_m


func _repair_pos(j: RepairJob, a: Aircraft) -> Vector3:
	var pt := j.point(&"repair", _board().rules)
	if pt != "":
		return a.service_point(pt)
	return a.global_transform * Vector3(1.2, 0.0, 4.0)       # Heck (+Z), seitlich


func _rough_pos(j: GroundJob) -> Vector3:
	var a := j.aircraft()
	if a == null:
		return position_now()
	if j is RefuelJob and j.current_step() == &"bring" and j.source_node != null and is_instance_valid(j.source_node) \
			and not j.source_in_reach(_board().rules):
		return j.source_node.global_position
	if j is RefuelJob and j.current_step() == &"bring" and not _board().rules.truck_at_spot and j.source_node == null:
		return _truck_pos()
	return a.global_position


## Waagerechte Richtung vom Flugzeug weg (seitlich des Servicepunkts).
## Paket 14: Halteplatz für Tankwagen (cart = false) bzw. Munitionswagen an der Seite zur
## Fahrspur (dispatch.vehicle_spot), sonst wie bisher vom Servicepunkt weg.
func _vehicle_spot(a: Aircraft, p: Vector3, cart: bool) -> Vector3:
	if dispatch != null and dispatch.has_method("vehicle_spot"):
		var v = dispatch.vehicle_spot(a, cart)
		if v is Vector3:
			return v
	return p + _away(a, p) * (CART_PARK if cart else TRUCK_PARK)


func _away(a: Aircraft, p: Vector3) -> Vector3:
	var d := p - a.global_position
	d.y = 0.0
	if d.length_squared() < 0.01:
		d = a.global_transform.basis.x
		d.y = 0.0
	return d.normalized()


# --- Propellerzone ----------------------------------------------------------------

## Dreht der Propeller (Motor läuft und Pilot sitzt drin, Gas oder Fahrt)?
static func prop_danger(a: Aircraft) -> bool:
	if a == null or not is_instance_valid(a) or a.flight == null or a.flight.engine == null:
		return false
	if not a.flight.engine.running or a.damage.is_destroyed:
		return false
	return a.pilot_seat.is_human_occupied() or a.flight.engine.throttle_actual > PROP_THROTTLE \
		or a.seat_speed() > 0.5


## Ist die Propellerzone von a frei von Bodenpersonal? (Haken für AirfieldPhases / Start)
static func zone_clear(a: Aircraft) -> bool:
	var e := a.service_point(ServiceMarkers.SVC_ENGINE)
	for br in all:
		if is_instance_valid(br) and _flat_dist(br.position_now(), e) < PROP_ZONE:
			return false
	return true


static func _flat_dist(p: Vector3, q: Vector3) -> float:
	return Vector2(p.x - q.x, p.z - q.z).length()


## Steht die Figur in der Zone eines drehenden Propellers, geht sie raus; ihre Jobs an dieser
## Maschine gibt sie frei. Rückgabe: true = mit Ausweichen beschäftigt.
func _avoid_props(dt: float) -> bool:
	if in_vehicle() != null:
		return false
	var b := _board()
	var j := b.get_job(job_id)
	if j != null and prop_danger(j.aircraft()):
		_drop_focus()
		for oj: GroundJob in b.open_jobs(j.aircraft()):
			if oj.worker == _worker_node():
				b.release(oj.id, _worker_node())
	var here := position_now()
	for a in _danger_aircraft():
		var e: Vector3 = a.service_point(ServiceMarkers.SVC_ENGINE)
		if _flat_dist(here, e) < PROP_ZONE + 0.5:
			state = State.CLEAR
			var out := Vector3(here.x - e.x, 0.0, here.z - e.z)
			if out.length_squared() < 0.01:
				out = a.global_transform.basis.x
			var goal := e + out.normalized() * (PROP_ZONE + 1.5)
			goal.y = here.y
			if abstract_mode or body() == null:
				_place(goal)
			else:
				_go_to(goal, dt)
			return true
	return false


func _danger_aircraft() -> Array:
	var out := []
	var seen := {}
	var src: Array = []
	if dispatch != null:
		src = dispatch._watched()
	var b := _board()
	for j: GroundJob in b.jobs.values():
		src.append(j.target)
	for a in src:
		if a is Aircraft and not seen.has(a) and prop_danger(a):
			seen[a] = true
			out.append(a)
	return out


func _prop_push(here: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for a in _danger_aircraft():
		var e: Vector3 = a.service_point(ServiceMarkers.SVC_ENGINE)
		var d := Vector3(here.x - e.x, 0.0, here.z - e.z)
		var l := d.length()
		if l < PROP_ZONE + 3.0 and l > 0.01:
			push += d / l * (PROP_ZONE + 3.0 - l)
	return push


# --- Sim-LOD ----------------------------------------------------------------------

func _update_lod() -> void:
	var want: bool
	if force_mode >= 0:
		want = force_mode == 1
	else:
		want = true
		var here := position_now()
		for p in _player_positions():
			if here.distance_to(p) <= LOD_RANGE:
				want = false
				break
	if body() == null:
		want = true
	if want != abstract_mode:
		abstract_mode = want
		_leg_left = -1.0
		var bd := body()
		if bd != null and is_instance_valid(bd):
			bd.set_physics_process(not abstract_mode)


func _player_positions() -> Array:
	if player_probe.is_valid():
		return player_probe.call()
	var vp := get_viewport()
	var cam := vp.get_camera_3d() if vp != null else null
	return [cam.global_position] if cam != null else []


func _board() -> JobBoard:
	if board != null and is_instance_valid(board):
		return board
	if _board_fixed:
		return null           # zugewiesener Board ist weg: nichts tun
	return JobBoard.current


# --- Fahrzeuge (Paket 7b) ------------------------------------------------------

func _run_drive(leg: Dictionary, dt: float) -> void:
	var v: GroundVehicle = leg.drive
	var r := _board().rules
	if v == null or not is_instance_valid(v):
		_legs.pop_front()
		return
	if in_vehicle() != v:
		if in_vehicle() != null:
			_exit_vehicle()
			return
		if v.driver_seat.controller != null and v.driver_seat.controller != self:
			_step_aside(dt)                            # jemand anderes fährt: warten (nicht im Fahrweg)
			return
		var entry := v.driver_seat.entry_position()
		if not abstract_mode and body() != null and not _go_to(entry, dt):
			return
		if abstract_mode or body() == null:
			if _leg_left < 0.0:
				_leg_left = _walk_time(_nav_len(position_now(), entry))
			_leg_left -= dt
			travel_time += dt
			if _leg_left > 0.0:
				return
			_place(entry)
		_leg_left = -1.0
		if not _enter(v.driver_seat):
			_legs.pop_front()
		else:
			_reroute(v)
		return
	travel_time += dt
	if abstract_mode:
		if _leg_left < 0.0:
			_leg_left = r.mount_s + _flat_dist(v.global_position, leg.pos) / maxf(r.truck_speed, 0.1)
		_leg_left -= dt
		if _leg_left > 0.0:
			return
		var dir: Vector3 = leg.pos - v.global_position
		v.place(leg.pos, atan2(-dir.x, -dir.z) if Vector2(dir.x, dir.z).length() > 0.1 else v.heading)
		_leg_left = -1.0
		_drive_goal = null
		_legs.pop_front()
		_after_drive()
		return
	_drive_goal = leg.pos
	if leg.get("via", false):
		if _flat_dist(v.global_position, leg.pos) <= VIA_ARRIVE:
			_legs.pop_front()
		return
	if _flat_dist(v.global_position, leg.pos) <= DRIVE_ARRIVE and v.seat_speed() < 0.3:
		_drive_goal = null
		_legs.pop_front()
		_after_drive()


## Nach der Fahrt: aussteigen, wenn als Nächstes nicht weitergefahren/befüllt wird.
func _after_drive() -> void:
	if _legs_need_exit():
		_exit_vehicle()


func _legs_need_exit() -> bool:
	return _legs.is_empty() or not (_legs[0].has("drive") or _legs[0].has("fill"))


## Tankwagen am Lager befüllen (FuelTruck.fill_from, Mengen-Erhalt bei Strang H).
func _run_fill(leg: Dictionary, dt: float) -> void:
	var v = leg.fill
	travel_time += dt
	var got: float = v.fill_from(leg.src, leg.grade, dt)
	var have: float = v.tank.available(leg.grade)
	if have >= leg.need - 0.5 or v.tank.space() <= 0.5 or got <= 0.0:
		_legs.pop_front()
		_after_drive()


func _depot_fill_pos(truck: GroundVehicle, depot: FuelSource) -> Vector3:
	var p = depot.get("position")
	var dp: Vector3 = p if p is Vector3 else truck.global_position
	var d := truck.global_position - dp
	d.y = 0.0
	if d.length_squared() < 0.01:
		d = Vector3.RIGHT
	return dp + d.normalized() * 6.0


func _enter(s: Seat) -> bool:
	var ch := body()
	if ch == null:
		return s.controller == null and s.possess(self)
	if SeatService.current != null:
		return SeatService.current.request_enter(peer_id, ch, s) == SeatService.Result.OK
	var cs: Seat = ch.get("crew_seat")
	if s.controller != null:
		return false
	cs.release()
	s.possess(self)
	if ch.has_method("on_entered_seat"):
		ch.call("on_entered_seat", s)
	else:
		ch.visible = false
	return true


func _exit_vehicle() -> bool:
	var v := in_vehicle()
	if v == null:
		return true
	_drive_goal = null
	if v.seat_speed() >= Seat.MAX_SWITCH_SPEED:
		return false
	var ch := body()
	if ch != null and SeatService.current != null:
		var ok := SeatService.current.request_exit(peer_id, v.driver_seat) == SeatService.Result.OK
		if ok:
			sim_pos = ch.global_position
		return ok
	var pos := v.driver_seat.entry_position()
	v.driver_seat.release()
	if ch != null:
		(ch.get("crew_seat") as Seat).possess(self)
		if ch.has_method("on_exited_seat"):
			ch.call("on_exited_seat", v.driver_seat, pos)
		else:
			ch.visible = true
			ch.global_position = pos
	sim_pos = pos
	return true


## Folgen: in FOLLOW_DIST hinter dem Ziel bleiben.
func _follow(dt: float) -> void:
	var t := command_target as Node3D
	if t == null or not is_instance_valid(t):
		command_kind = Command.FULL_SERVICE
		command_target = null
		return
	state = State.TRAVEL
	if in_vehicle() != null:
		_exit_vehicle()
		return
	var tp := t.global_position
	if _flat_dist(position_now(), tp) > FOLLOW_DIST:
		var d := position_now() - tp
		d.y = 0.0
		_go_to(tp + d.normalized() * (FOLLOW_DIST - 0.5), dt)
	else:
		state = State.IDLE


## Eigene Ansprüche freigeben (Befehl, Pause); laufendes Pumpen bleibt beim Job.
func _release_mine() -> void:
	var b := _board()
	if b == null:
		return
	for j: GroundJob in b.open_jobs():
		if j.worker == _worker_node() and not j.autonomous(j.current_step(), b.rules):
			b.release(j.id, _worker_node())
