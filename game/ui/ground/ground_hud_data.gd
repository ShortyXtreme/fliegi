class_name GroundHudData
extends RefCounted
## Reine Datensammlung für das Boden-HUD (Paket 13). Keine Zeichnung, keine Zustandsänderung –
## alles lässt sich headless mit Fake-Daten testen.

## Statuspanel erscheint, wenn die Figur ≤ 15 m von einer Maschine entfernt ist.
const STATUS_RANGE := 15.0

const KIND_TEXT := {&"refuel": "Tanken", &"rearm": "Munition", &"repair": "Reparatur",
	&"load_ordnance": "Bomben"}
const STEP_TEXT := {&"bring": "Tankwagen holen", &"ground": "Erden", &"attach": "Ankoppeln",
	&"pump": "Pumpen", &"detach": "Abkoppeln", &"crate": "Kiste holen", &"hatch_open": "Klappe öffnen",
	&"belt": "Gurt einlegen", &"charge": "Durchladen", &"hatch_close": "Klappe schließen",
	&"repair": "Reparieren", &"load": "Laden"}


## Taste je Aktion: [Tastatur, Pad] laut Vertrag §2.2.
const KEYS := {&"interact": ["E", "A"], &"enter": ["F", "Y"], &"drop": ["G", "B"],
	&"wheel": ["Tab", "LB"], &"help": ["F1", "Back"]}


static func key(action: StringName, pad: bool) -> String:
	var k: Array = KEYS.get(action, ["?", "?"])
	return k[1] if pad else k[0]


static func missing_text(item_kind: StringName) -> String:
	return "%s fehlt" % CarryItem.LABELS.get(item_kind, "Gegenstand")


static func grade_text(mix: float) -> String:
	if mix < 0.02:
		return "Benzin"
	if mix > 0.98:
		return "Ersatz"
	return "Gemisch (%d %% Ersatz)" % int(round(mix * 100.0))


## 167 s → „2:47“.
static func clock(s: float) -> String:
	var t := int(ceil(maxf(s, 0.0)))
	return "%d:%02d" % [t / 60, t % 60]


static func liters(l: float) -> String:
	return "%s l" % HudStyle.thousands(l)


## Name eines Bearbeiters: „Du“, Anzeigename, Knotenname oder „frei“.
static func worker_name(w: Node, me: Node) -> String:
	if w == null or not is_instance_valid(w):
		return "frei"
	if me != null and w == me:
		return "Du"
	var dn = w.get("display_name")
	if dn != null and str(dn) != "":
		return str(dn)
	return String(w.name)


static func aircraft_name(a: Node) -> String:
	if a == null:
		return "–"
	var p = a.get("pilot")
	if p != null and p is Object and p.get("display_name") != null:
		return str(p.get("display_name"))
	var nid = a.get("nation_id")
	var n: String = Nations.NAMES[nid] if nid != null and Nations.is_valid(nid) else "Maschine"
	var eid = a.get("entity_id")
	return "%s %d" % [n, maxi(int(eid) if eid != null else 1, 1)]


## Zustand einer Maschine: {name, fuel_l, fuel_cap, fuel_frac, grade, grade_mix, guns: [{label, ammo, cap}],
## zones, health, jobs: [{text, step, progress, worker, blocked}]}.
static func aircraft_status(a: Node, board: JobBoard = null, me: Node = null) -> Dictionary:
	var d := {"name": aircraft_name(a), "fuel_l": 0.0, "fuel_cap": 0.0, "fuel_frac": 0.0,
		"grade": "Benzin", "grade_mix": 0.0, "guns": [], "zones": PackedFloat32Array(), "health": 1.0,
		"jobs": []}
	if a == null or not is_instance_valid(a):
		return d
	var dm = a.get("damage")
	if dm != null:
		var f: FuelSystem = dm.fuel
		if f != null:
			d.fuel_l = f.total()
			var cap := 0.0
			for c in f.capacity:
				cap += c
			d.fuel_cap = cap
			d.fuel_frac = f.total() / maxf(cap, 1e-3)
			d.grade_mix = f.grade_mix
			d.grade = grade_text(f.grade_mix)
		var z := PackedFloat32Array()
		for i in DamageModel.Zone.COUNT:
			z.append(dm.hp_fraction(i))
		d.zones = z
		d.health = dm.health_fraction()
	var w = a.get("weapons")
	if w != null:
		var n: int = w.gun_count()
		for i in n:
			var lbl := ("L" if i == 0 else "R") if n == 2 else "MG %d" % (i + 1)
			d.guns.append({"label": lbl, "ammo": w.gun_ammo(i), "cap": w.gun_capacity(i)})
	if board == null:
		board = JobBoard.current
	if board != null and is_instance_valid(board):
		d.jobs = jobs_of(board, a, me)
	return d


static func jobs_of(board: JobBoard, a: Node, me: Node = null) -> Array:
	var out := []
	for j in board.jobs_for(a):
		var job := j as GroundJob
		if job == null or job.cancelled or job.is_done():
			continue
		var text: String = KIND_TEXT.get(job.kind, String(job.kind))
		if job is RearmJob:
			var gi: int = (job as RearmJob).gun_index
			text += " L" if gi == 0 else (" R" if gi == 1 else " %d" % (gi + 1))
		var st := job.current_step()
		var e := {"text": text, "step": STEP_TEXT.get(st, String(st)), "progress": job.progress,
			"worker": worker_name(job.worker, me), "mine": me != null and job.worker == me,
			"blocked": GroundJob.block_text(job.blocked_reason) if job.blocked_reason != &"" else ""}
		out.append(e)
	return out


## Lagerbestand: {aviation, aviation_cap, ersatz, ersatz_cap, ammo, ammo_cap} (-1 = unbekannt).
static func stock(depot: FuelSource, bunker: AmmoStore) -> Dictionary:
	var d := {"aviation": -1.0, "aviation_cap": 0.0, "ersatz": -1.0, "ersatz_cap": 0.0,
		"ammo": -1, "ammo_cap": AmmoBunker.START_792}
	if depot != null:
		d.aviation = depot.available(FuelSystem.GRADE_AVIATION)
		d.aviation_cap = depot.capacity(FuelSystem.GRADE_AVIATION)
		d.ersatz = depot.available(FuelSystem.GRADE_ERSATZ)
		d.ersatz_cap = depot.capacity(FuelSystem.GRADE_ERSATZ)
	if bunker != null:
		d.ammo = bunker.available(AmmoBunker.AMMO_792)
	return d


## Nächste Maschine innerhalb range um pos (oder null).
static func nearest_aircraft(pos: Vector3, list: Array, range_m := STATUS_RANGE) -> Node3D:
	var best: Node3D = null
	var bd := range_m
	for a in list:
		if a == null or not is_instance_valid(a) or not (a is Node3D):
			continue
		var dd := (a as Node3D).global_position.distance_to(pos)
		if dd <= bd:
			bd = dd
			best = a
	return best


## Hinweis am Interaktionspunkt der Figur: {visible, key, label, missing, blocked, hold, progress,
## pump, liters, liters_target}. Liest CrewCharacter.focus/current_action/hold_progress und den JobBoard.
static func interaction(ch: Node, board: JobBoard, pad: bool) -> Dictionary:
	var d := {"visible": false, "key": "", "label": "", "missing": "", "blocked": "", "hold": false,
		"progress": 0.0, "pump": false, "liters": 0.0, "liters_target": 0.0}
	if ch == null or not is_instance_valid(ch):
		return d
	var focus = ch.get("focus")
	if focus == null or not is_instance_valid(focus):
		return d
	var it := focus as Interactable
	var act: Dictionary = ch.call("current_action") if ch.has_method("current_action") else {}
	var act_key := &"interact"
	var from_hint := act.is_empty()
	if from_hint:
		act = it.hint_for(ch)
		if not act.is_empty() and act.id == InteractionPoints.ENTER:
			act_key = &"enter"
	if board == null:
		board = JobBoard.current
	# Blockierter Job an diesem Punkt (Lager leer, Schlauch reicht nicht …)
	var pump_job: RefuelJob = null
	if board != null and is_instance_valid(board) and it.target != null:
		for j in board.jobs_for(it.target):
			var job := j as GroundJob
			if job == null or job.cancelled or job.is_done():
				continue
			var here := job.point(job.current_step(), board.rules) == it.marker
			if job.blocked_reason != &"" and here:
				d.blocked = GroundJob.block_text(job.blocked_reason)
			if job is RefuelJob and job.current_step() == &"pump" and (here or it.marker == "svc_fuel_cap"):
				pump_job = job
	if act.is_empty() and d.blocked == "" and pump_job == null:
		return d
	d.visible = true
	if not act.is_empty():
		d.key = key(act_key, pad)
		d.label = String(act.get("label", ""))
		d.hold = float(act.get("hold_s", 0.0)) > 0.0 or bool(act.get("continuous", false))
		var miss: StringName = act.get("missing", &"") if from_hint else &""
		if miss != &"":
			d.missing = missing_text(miss)
	var hp = ch.get("hold_progress")
	d.progress = float(hp) if hp != null else 0.0
	if pump_job != null:
		d.pump = true
		d.liters = pump_job.pumped
		d.liters_target = pump_job.pumped + maxf(pump_job.liters_needed(), 0.0)
		d.progress = d.liters / maxf(d.liters_target, 1.0)
	return d
