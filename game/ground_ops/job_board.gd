class_name JobBoard
extends Node
## M3 (Strang G / Paket 2): Node unter Game, nur Server. Erzeugt und vergibt Jobs, schreibt
## Fortschritt fort, meldet über GroundEvents. Spieler und KI rufen dieselbe Funktion
## request_step(peer, job_id, step, dt) auf (offline direkt, später RPC wie HitValidator).
## Feste Signaturen:
##   add_job(job) -> int, get_job(id), jobs_for(target) -> Array, claim(peer, job_id, worker) -> bool,
##   request_step(peer, job_id, step, dt) -> bool, cancel(job_id), rules: GroundRules
##
## Prüfungen in request_step: Server, Job offen, Peer passt zum Bearbeiter, Schritt ist der
## aktuelle (oder der nächste nach einem überspringbaren), Figur steht am Servicepunkt
## (rules.work_range), dt begrenzt auf MAX_DT. Arbeitsfaktor: Spieler 1, KI work_mul
## (rules.ai_work_mul), im Alarm ×rules.alarm_work_mul. Autonome Schritte (Pumpen) laufen in tick().

const MAX_DT := 0.25

static var current: JobBoard = null

var jobs := {}
var rules: GroundRules = null
## Alarmstart aktiv: KI arbeitet schneller (Turnaround setzt das).
var alarm := false
var _next_id := 1
var _recheck_t := 0.0


func _enter_tree() -> void:
	current = self
	if rules == null:
		rules = GroundRules.for_realism()


func _exit_tree() -> void:
	if current == self:
		current = null


func _physics_process(dt: float) -> void:
	tick(dt)


func add_job(job: GroundJob) -> int:
	if not Authority.is_server() or job == null:
		return 0
	if rules == null:
		rules = GroundRules.for_realism()
	job.id = _next_id
	_next_id += 1
	if job.has_method("configure"):
		job.configure(rules)
	jobs[job.id] = job
	GroundEvents.bus().job_added.emit(job.id, job.kind, job.target)
	if job.blocked_reason != &"":
		GroundEvents.bus().job_blocked.emit(job.id, job.blocked_reason)
	return job.id


func get_job(id: int) -> GroundJob:
	return jobs.get(id)


func jobs_for(target: Node) -> Array:
	return jobs.values().filter(func(j): return j.target == target)


## Offene Jobs (nicht fertig, nicht abgebrochen), optional nur für target.
func open_jobs(target: Node = null) -> Array:
	return jobs.values().filter(func(j): return j.is_open() and (target == null or j.target == target))


func claim(peer: int, job_id: int, worker: Node) -> bool:
	if not Authority.is_server() or not jobs.has(job_id):
		return false
	var j: GroundJob = jobs[job_id]
	if not j.is_open():
		return false
	if j.worker != null and is_instance_valid(j.worker) and j.worker != worker:
		return false
	var wp := _peer_of(worker)
	if wp >= 0 and wp != peer:
		return false
	j.worker = worker
	return true


func release(job_id: int, worker: Node) -> void:
	var j: GroundJob = jobs.get(job_id)
	if Authority.is_server() and j != null and j.worker == worker:
		j.worker = null


## Fortschritt am Schritt (nur Server). Rückgabe: true = angenommen.
func request_step(peer: int, job_id: int, step_name: StringName, dt: float) -> bool:
	if not Authority.is_server() or not jobs.has(job_id):
		return false
	var j: GroundJob = jobs[job_id]
	if j.worker != null and is_instance_valid(j.worker):
		var wp := _peer_of(j.worker)
		if wp >= 0 and wp != peer:
			return false
	j.recheck(rules)
	if j.blocked_reason != &"":
		GroundEvents.bus().job_blocked.emit(job_id, j.blocked_reason)
		return false
	if not j.is_open():
		return false
	if j.current_step() != step_name:
		var nxt := j.step_index + 1
		if nxt < j.steps.size() and j.steps[nxt] == step_name and j.can_skip(j.current_step(), rules):
			j.on_skip(j.current_step(), rules)
			j.advance()
		else:
			return false
	if j.autonomous(step_name, rules):
		return true
	var pt := j.point(step_name, rules)
	if pt != "" and not _at_point(j, pt):
		return false
	dt = clampf(dt, 0.0, MAX_DT)
	var eff := dt * work_mul_of(j.worker)
	j.elapsed += dt
	var finished := j.step(step_name, eff, rules)
	if j.blocked_reason != &"":
		GroundEvents.bus().job_blocked.emit(job_id, j.blocked_reason)
		return false
	if finished:
		j.advance()
		_flush(j)
	GroundEvents.bus().job_progress.emit(job_id, step_name, j.progress, j.worker)
	_check_done(j)
	return true


## Autonome Schritte (Pumpen), Blockaden neu prüfen. Nur Server.
func tick(dt: float) -> void:
	if not Authority.is_server() or rules == null:
		return
	_recheck_t += dt
	var do_recheck := _recheck_t >= 0.5
	if do_recheck:
		_recheck_t = 0.0
	for j: GroundJob in jobs.values():
		if not j.is_open():
			continue
		if do_recheck and j.blocked_reason != &"":
			j.recheck(rules)
		if j.blocked_reason == &"" and j.autonomous(j.current_step(), rules) and j.has_method("pump"):
			var s := j.current_step()
			if j.pump(dt, rules):
				j.advance()
				_flush(j)
			GroundEvents.bus().job_progress.emit(j.id, s, j.progress, j.worker)
			_check_done(j)


func cancel(job_id: int) -> void:
	if not Authority.is_server() or not jobs.has(job_id):
		return
	var j: GroundJob = jobs[job_id]
	j.cancelled = true
	j.cleanup()
	jobs.erase(job_id)


## Fertige und abgebrochene Jobs einer Maschine entfernen (nach dem Start).
func clear_finished(target: Node = null) -> void:
	for id in jobs.keys():
		var j: GroundJob = jobs[id]
		if not j.is_open() and (target == null or j.target == target):
			jobs.erase(id)


## Arbeitsfaktor des Bearbeiters: Spieler 1, KI work_mul, im Alarm ×alarm_work_mul.
func work_mul_of(worker: Node) -> float:
	if worker == null or not is_instance_valid(worker):
		return 1.0
	var c := _controller_of(worker)
	var m := 1.0
	var ai := false
	if worker.get("work_mul") != null:
		m = float(worker.get("work_mul"))
		ai = true
	elif c != null and c.get("work_mul") != null:
		m = float(c.get("work_mul"))
		ai = c.is_ai()
	elif c != null and c.is_ai():
		m = rules.ai_work_mul
		ai = true
	if ai and alarm:
		m *= rules.alarm_work_mul
	return m


## Arbeitet hier KI-Personal (für Helferzahl und Wertung)?
func is_ai_worker(worker: Node) -> bool:
	if worker == null or not is_instance_valid(worker):
		return false
	var c := _controller_of(worker)
	return c.is_ai() if c != null else worker.get("work_mul") != null


# --- Abfertigung anlegen --------------------------------------------------------

## Legt die Jobs für eine Maschine an (bestehende offene gleicher Art bleiben).
## opts: fuel (bool), ammo (bool), repair (bool), fuel_target (0..1), priority (int),
## fuel_node (Node3D der Quelle, z. B. Tankwagen). Rückgabe: neue Job-Ids.
func plan_service(a: Aircraft, fuel_src: FuelSource, ammo_store: AmmoStore, opts := {}) -> Array:
	var ids := []
	if not Authority.is_server() or a == null:
		return ids
	var prio: int = opts.get("priority", 0)
	var open := open_jobs(a)
	if opts.get("fuel", true) and fuel_src != null:
		var ft: float = opts.get("fuel_target", 1.0)
		var has := open.any(func(j): return j is RefuelJob)
		var f := a.damage.fuel
		if not has and f.total() < (f.capacity[0] + f.capacity[1]) * ft - 0.5:
			var rj := RefuelJob.new()
			rj.target = a
			rj.source = fuel_src
			rj.target_fraction = ft
			rj.source_node = opts.get("fuel_node", null)
			rj.priority = prio
			ids.append(add_job(rj))
	if opts.get("ammo", true) and ammo_store != null:
		for i in a.weapons.gun_count():
			var has_g := open.any(func(j): return j is RearmJob and j.gun_index == i)
			if not has_g and a.weapons.gun_ammo(i) < a.weapons.gun_capacity(i):
				var mj := RearmJob.new()
				mj.target = a
				mj.gun_index = i
				mj.store = ammo_store
				mj.priority = prio
				ids.append(add_job(mj))
	if opts.get("repair", true):
		ids.append_array(_plan_repair(a, prio, open))
	return ids


func _plan_repair(a: Aircraft, prio: int, open: Array) -> Array:
	var ids := []
	for z in DamageModel.Zone.COUNT:
		if not a.damage.can_repair(z):
			continue
		if open.any(func(j): return j is RepairJob and j.zone == z):
			continue
		var rj := RepairJob.new()
		rj.target = a
		rj.zone = z
		rj.priority = prio
		ids.append(add_job(rj))
	return ids


## Ist die Maschine fertig versorgt (keine offenen Jobs)?
func is_serviced(a: Node) -> bool:
	return open_jobs(a).is_empty()


# --- intern ---------------------------------------------------------------------

## Schritte ohne Dauer und ohne Servicepunkt sofort abschließen (Vereinfacht: ein Tastendruck).
func _flush(j: GroundJob) -> void:
	var guard := 0
	while j.is_open() and guard < 16:
		guard += 1
		var s := j.current_step()
		if j.autonomous(s, rules) or j.duration(s, rules) > 0.0:
			return
		if not j.step(s, 0.0, rules):
			if j.blocked_reason != &"":
				GroundEvents.bus().job_blocked.emit(j.id, j.blocked_reason)
			return
		j.advance()


func _check_done(j: GroundJob) -> void:
	if j.is_done() and not j.cancelled:
		j.cleanup()
		GroundEvents.bus().job_done.emit(j.id, j.target)


func _at_point(j: GroundJob, pt: String) -> bool:
	var w := j.worker as Node3D
	if w == null or not is_instance_valid(w):
		return true          # Sim-LOD (abstrakt) oder ohne Figur: Wege laufen getaktet
	var a := j.target as Aircraft
	if a == null:
		return true
	return w.global_position.distance_to(a.service_point(pt)) <= rules.work_range


func _controller_of(worker: Node) -> Controller:
	if worker is Controller:
		return worker
	var seat = worker.get("crew_seat")
	if seat is Seat and seat.controller != null:
		return seat.controller
	return null


## Peer des Bearbeiters (-1 = unbekannt, 0 = KI/Server).
func _peer_of(worker: Node) -> int:
	if worker == null or not is_instance_valid(worker):
		return -1
	var c := _controller_of(worker)
	return c.peer_id if c != null else -1
