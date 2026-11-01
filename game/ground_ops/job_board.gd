class_name JobBoard
extends Node
## M3 Vertrag (Paket 0b, gehört Strang G / Paket 2): Node unter Game, nur Server. Erzeugt
## und vergibt Jobs, schreibt Fortschritt fort, meldet über GroundEvents.
## Spieler und KI rufen dieselbe Funktion request_step(peer, job_id, step, dt) auf
## (offline direkt, später RPC wie HitValidator). Feste Signaturen:
##   add_job(job) -> int, get_job(id), jobs_for(target) -> Array, claim(peer, job_id, worker) -> bool,
##   request_step(peer, job_id, step, dt) -> bool, cancel(job_id), rules: GroundRules

static var current: JobBoard = null

var jobs := {}
var rules: GroundRules = null
var _next_id := 1


func _enter_tree() -> void:
	current = self
	if rules == null:
		rules = GroundRules.for_realism()


func _exit_tree() -> void:
	if current == self:
		current = null


func add_job(job: GroundJob) -> int:
	if not Authority.is_server() or job == null:
		return 0
	job.id = _next_id
	_next_id += 1
	jobs[job.id] = job
	GroundEvents.bus().job_added.emit(job.id, job.kind, job.target)
	return job.id


func get_job(id: int) -> GroundJob:
	return jobs.get(id)


func jobs_for(target: Node) -> Array:
	return jobs.values().filter(func(j): return j.target == target)


func claim(_peer: int, job_id: int, worker: Node) -> bool:
	if not Authority.is_server() or not jobs.has(job_id):
		return false
	var j: GroundJob = jobs[job_id]
	if j.worker != null and j.worker != worker:
		return false
	j.worker = worker
	return true


## Fortschritt am aktuellen Schritt (nur Server). Stub: Prüfungen und Ereignisse, die
## eigentliche Arbeit macht job.step() (Paket 2).
func request_step(_peer: int, job_id: int, step_name: StringName, dt: float) -> bool:
	if not Authority.is_server() or not jobs.has(job_id):
		return false
	var j: GroundJob = jobs[job_id]
	if j.blocked_reason != &"":
		GroundEvents.bus().job_blocked.emit(job_id, j.blocked_reason)
		return false
	if j.is_done() or j.current_step() != step_name:
		return false
	if j.step(step_name, dt, rules):
		j.advance()
	GroundEvents.bus().job_progress.emit(job_id, step_name, j.progress, j.worker)
	if j.is_done():
		GroundEvents.bus().job_done.emit(job_id, j.target)
	return true


func cancel(job_id: int) -> void:
	if Authority.is_server():
		jobs.erase(job_id)
