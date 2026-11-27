extends SceneTree
## Prüfung Boden/Allgemein: Langzeit-Messung (Speicher- und Knotenlecks) in der echten Hauptszene.
##   godot --headless --path . --fixed-fps 60 --script res://tools/soak.gd -- [Minuten] [csv]
## Standard 30 Spielminuten. Die rote KI startet, patrouilliert, landet und wird von der
## Bodenmannschaft versorgt; alle EJECT_EVERY s steigt der Pilot einer fliegenden roten Maschine aus
## (Fallschirm, Wrack, Neustart), damit auch diese Pfade laufen. Der Spieler steht am Platz.
## Je Spielminute eine Zeile: Objekte, Knoten, verwaiste Knoten, Ressourcen, statischer Speicher (MB),
## Interactables, GroundNav-Hindernisse, Wracks, Trümmer, Jobs, Fallschirme.

const EJECT_EVERY := 240.0

var minutes := 30.0
var csv := ""
var _game: Game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		minutes = float(args[0])
	if args.size() > 1:
		csv = args[1]
	_run.call_deferred()


func _count(n: Node, cls: String) -> int:
	var c := 1 if n.get_class() == cls or (n.get_script() != null and n.get_script().get_global_name() == cls) else 0
	for k in n.get_children():
		c += _count(k, cls)
	return c


func _row(t: float) -> String:
	var jobs := 0
	if JobBoard.current != null and is_instance_valid(JobBoard.current):
		jobs = JobBoard.current.jobs.size()
	return "%.0f,%d,%d,%d,%d,%.1f,%d,%d,%d,%d,%d,%d,%d" % [t,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		Interactable.all().size(), GroundNav.movers.size() + GroundNav.walkers.size(),
		Wreck.active.size(), Debris.active.size(), jobs, _count(root, "Parachute"),
		GroundCrewBrain.all.size()]


func _run() -> void:
	var g: Game = (load("res://world/main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	_game = g
	for k in 2:
		await physics_frame
	var lines := PackedStringArray(["t_s,objekte,knoten,verwaist,ressourcen,speicher_mb,interactables,nav,wracks,truemmer,jobs,fallschirme,crew"])
	lines.append(_row(0.0))
	print(lines[0])
	print(lines[1])
	var frames := int(minutes * 3600.0)
	var next_eject := EJECT_EVERY
	var ejects := 0
	var t0 := Time.get_ticks_msec()
	for f in range(1, frames + 1):
		await physics_frame
		var t := f / 60.0
		if t >= next_eject:
			next_eject += EJECT_EVERY
			for a: Aircraft in g.ai_aircrafts:
				var tel := a.telemetry()
				if not a.damage.is_destroyed and not tel.on_ground and tel.height_agl > 150.0:
					if a.damage.eject(true):
						ejects += 1
					break
		if f % 3600 == 0:
			var r := _row(t)
			lines.append(r)
			print("%s   (Echtzeit %.0f s, Ausstiege %d)" % [r, (Time.get_ticks_msec() - t0) / 1000.0, ejects])
	if csv != "":
		var fa := FileAccess.open(csv, FileAccess.WRITE)
		if fa != null:
			fa.store_string("\n".join(lines) + "\n")
	g.queue_free()
	await process_frame
	await process_frame
	print("Ende: Knoten nach Freigabe %d, verwaist %d" % [Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)])
	quit(0)
