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
## Wege ohne Fahrzeug (Tankwagen holen) laufen in beiden Darstellungen als Zeit (Paket 7b: KI fährt).
## Befehle (command) folgen in Paket 7b.

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


func body() -> Node3D:
	return get_vehicle()


func position_now() -> Vector3:
	var b := body()
	return b.global_position if b != null and is_instance_valid(b) and not abstract_mode else sim_pos


## Befehl aus dem Befehlsrad (target = Zielmaschine oder null). Paket 7b.
func command(_cmd: int, _target: Node) -> bool:
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
		if a == null or prop_danger(a) or (dispatch != null and not dispatch.is_parked(a)):
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
	var r := _board().rules
	var a := j.aircraft()
	var legs := []
	if a == null:
		return legs
	if j is RefuelJob:
		var cap := a.service_point(ServiceMarkers.SVC_FUEL_CAP)
		if s == &"bring":
			var hose_from := cap + _away(a, cap) * r.hose_walk_m
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
	if leg.wait > 0.0 or abstract_mode:
		if _leg_left < 0.0:
			var t: float = leg.wait
			if abstract_mode and not leg.teleport:
				t += _walk_time(_flat_dist(position_now(), leg.pos))
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
	var dir := d.normalized() + _prop_push(here)
	dir.y = 0.0
	if dir.length_squared() < 1e-6:
		dir = d.normalized()
	dir = dir.normalized()
	_intent.look_yaw = atan2(-dir.x, -dir.z)
	_intent.move = Vector2(0.0, 1.0)
	_intent.sprint = d.length() > SPRINT_FROM and not _carrying
	return false


func _place(p: Vector3) -> void:
	sim_pos = p
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
	if j is RefuelJob and j.current_step() == &"bring" and not _board().rules.truck_at_spot and j.source_node == null:
		return _truck_pos()
	return a.global_position


## Waagerechte Richtung vom Flugzeug weg (seitlich des Servicepunkts).
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
