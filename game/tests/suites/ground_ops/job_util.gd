class_name JobTestUtil
extends RefCounted
## Helfer für Job-Tests (Strang G): arbeitet einen Job schrittweise ab wie ein Bearbeiter.


## Arbeitet Job j mit dt ab (Bearbeiter worker, Peer peer), bis fertig oder max_t.
## Beobachtet beim Pumpen den Füllstand (Authentisch). Rückgabe: Spielsekunden.
static func run_job(board: JobBoard, j: GroundJob, worker: Node = null, peer := 1,
		dt := 1.0 / 60.0, max_t := 600.0) -> float:
	var t := 0.0
	if worker != null:
		board.claim(peer, j.id, worker)
	while j.is_open() and t < max_t:
		var s := j.current_step()
		if j.autonomous(s, board.rules):
			if j is RefuelJob and board.rules.pump_watch and j.fill_reached():
				board.request_step(peer, j.id, j.steps[j.step_index + 1], dt)
		elif not board.request_step(peer, j.id, s, dt) and j.blocked_reason != &"":
			break
		board.tick(dt)
		t += dt
	return t


static func make_board(parent: Node, realism: int) -> JobBoard:
	var b := JobBoard.new()
	b.rules = GroundRules.for_realism(realism)
	parent.add_child(b)
	b.set_physics_process(false)
	return b
