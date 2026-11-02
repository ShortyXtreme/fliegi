class_name PlayerService
extends Node
## M3 Paket 14: Verbindet die Interaktionspunkte am Flugzeug (InteractionPoints.for_aircraft,
## svc_*-Marker) mit den Jobs des JobBoards, damit die Spielerfigur dieselben Schritte
## erledigt wie das KI-Personal: E halten = JobBoard.request_step(peer, job, schritt, dt).
## Je Punkt gibt es eine Daueraktion &"service"; Beschriftung und benötigter Gegenstand folgen
## dem aktuellen Schritt des passenden Jobs (Tanken am Tankdeckel, Munition an der MG-Klappe,
## Reparatur am nächsten Punkt). Ansprüche der Figur verfallen nach RELEASE_AFTER s ohne Arbeit,
## dann übernimmt wieder die KI.

const ACTION := &"service"
const RELEASE_AFTER := 1.5
const STEP_LABELS := {
	&"bring": "Tankwagen heranfahren (Schlauch 12 m)", &"ground": "Erden", &"attach": "Schlauch ankoppeln",
	&"pump": "Pumpe stoppen und abkoppeln", &"detach": "Schlauch abkoppeln",
	&"crate": "Gurt aus der Kiste nehmen", &"hatch_open": "MG-Klappe öffnen", &"belt": "Gurt einlegen",
	&"hatch_close": "MG-Klappe schließen", &"charge": "MG durchladen", &"repair": "Reparieren",
}
const ZONE_LABELS := ["Motor", "Tank links", "Tank rechts", "Flügel links", "Flügel rechts",
	"Leitwerk", "Cockpit"]

var board: JobBoard = null
## Zuletzt bearbeitet: job_id -> Zeit (s)
var _last_work := {}
var _time := 0.0
var _attached := {}


func _board() -> JobBoard:
	return board if board != null and is_instance_valid(board) else JobBoard.current


## Punkte am Flugzeug anlegen (einmal) und die Daueraktion anhängen.
func attach(a: Aircraft) -> Dictionary:
	if _attached.has(a):
		return _attached[a]
	var pts := InteractionPoints.for_aircraft(a)
	for m in pts:
		var it: Interactable = pts[m]
		var act := it.add_action(ACTION, "Arbeiten", 0.0, &"")
		act["continuous"] = true
		act["can"] = func(ch): return _can(it, act, ch)
		it.holding.connect(func(id, ch, dt, _p): if id == ACTION: _work(it, ch, dt))
	_attached[a] = pts
	return pts


func _peer(ch: Node) -> int:
	var s = ch.get("crew_seat") if ch != null else null
	return s.controller.peer_id if s is Seat and s.controller != null else -1


## Passender offener Job an diesem Punkt für die Figur (oder null).
func job_for(it: Interactable, ch: Node) -> GroundJob:
	var b := _board()
	var a := it.target as Aircraft
	if b == null or a == null:
		return null
	var r := b.rules
	var best: GroundJob = null
	var best_rank := 99
	for j: GroundJob in b.open_jobs(a):
		if j.worker != null and is_instance_valid(j.worker) and j.worker != ch:
			continue
		var s := j.current_step()
		var rank := 99
		if j is RefuelJob:
			if it.marker == ServiceMarkers.SVC_FUEL_CAP and (s != &"pump" or r.pump_watch):
				rank = 0
		elif j is RearmJob:
			var hatch := ServiceMarkers.SVC_GUN_HATCH_L if j.gun_index % 2 == 0 else ServiceMarkers.SVC_GUN_HATCH_R
			var pt := j.point(s, r)
			if (pt == "" and it.marker == hatch) or pt == it.marker:
				rank = 1
		elif j is RepairJob:
			var pt := j.point(s, r)
			if pt == it.marker or (pt == "" and it.marker != ServiceMarkers.SVC_ENTRY):
				rank = 2
		elif j.point(s, r) == it.marker:
			rank = 3
		if rank < best_rank:
			best_rank = rank
			best = j
	return best


func _needs(j: GroundJob, r: GroundRules) -> StringName:
	var s := j.current_step()
	if j is RefuelJob and s == &"attach" and r.hose_carry and j.hose() != null and not j.hose().is_coupled():
		return CarryItem.HOSE
	if j is RearmJob and s == &"crate" and r.gun_at_cart_s <= 0.0:
		return CarryItem.CRATE
	if j is RepairJob and r.repair_needs_toolbox:
		return CarryItem.TOOL
	return &""


func label_for(j: GroundJob) -> String:
	var s := j.current_step()
	var t: String = STEP_LABELS.get(s, String(s))
	if j is RepairJob:
		var z: int = j.zone
		t = "Reparieren: %s" % (ZONE_LABELS[z] if z < ZONE_LABELS.size() else str(z))
	elif j is RearmJob:
		t += " (MG %s)" % ("links" if j.gun_index % 2 == 0 else "rechts")
		if s == &"crate" and _board().rules.gun_at_cart_s > 0.0:
			t = "Munition laden (MG %s)" % ("links" if j.gun_index % 2 == 0 else "rechts")
	return t


func _can(it: Interactable, act: Dictionary, ch: Node) -> bool:
	var j := job_for(it, ch)
	if j == null:
		return false
	act["label"] = label_for(j)
	act["needs_item"] = _needs(j, _board().rules)
	return true


func _work(it: Interactable, ch: Node, dt: float) -> void:
	var b := _board()
	var j := job_for(it, ch)
	if b == null or j == null:
		return
	var peer := _peer(ch)
	if j.worker != ch and not b.claim(peer, j.id, ch):
		return
	_last_work[j.id] = _time
	var s := j.current_step()
	if j is RefuelJob and s == &"pump":
		s = j.steps[j.step_index + 1]          # Authentisch: selbst abkoppeln
	if j is RearmJob and s == &"crate" and b.rules.gun_at_cart_s <= 0.0:
		var item = ch.get("carried")
		if item is CarryItem and item.kind == CarryItem.CRATE and item.store != null:
			j.store = item.store
	b.request_step(peer, j.id, s, dt)
	if j is RearmJob and j.current_step() != &"crate":
		var item2 = ch.get("carried")
		if item2 is CarryItem and item2.kind == CarryItem.CRATE and item2.store != null \
				and item2.store == j.store and item2.store.available(AmmoBunker.AMMO_792) <= 0:
			var c: CarryItem = ch.call("release_item")   # leere Kiste bleibt nicht in der Hand
			if c != null:
				c.queue_free()
	if ch.get("hold_progress") != null:
		ch.set("hold_progress", j.progress)


func _physics_process(dt: float) -> void:
	_time += dt
	var b := _board()
	if b == null:
		return
	for id in _last_work.keys():
		var j := b.get_job(id)
		if j == null or not j.is_open():
			_last_work.erase(id)
			continue
		if _time - float(_last_work[id]) > RELEASE_AFTER and not j.autonomous(j.current_step(), b.rules):
			if j.worker != null and is_instance_valid(j.worker):
				b.release(id, j.worker)
			_last_work.erase(id)
