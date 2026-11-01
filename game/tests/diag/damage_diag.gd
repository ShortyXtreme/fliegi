extends SceneTree
## Diagnose M2.1: Bekommt ein passiver Spieler in der echten Hauptszene Schaden von der KI?
## Aufruf: godot --headless --path . --fixed-fps 60 --script res://tests/diag/damage_diag.gd -- [--sek=120] [--neustart]

var shots := {}
var hits := 0
var dmg_events := 0
var dmg_total := 0.0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sek := 120
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sek="): sek = int(a.substr(6))
	var g: Game = load("res://world/main.tscn").instantiate()
	root.add_child(g)
	await physics_frame
	var pl := g.player_aircraft
	var bus := CombatEvents.bus()
	bus.shot_fired.connect(func(s, _gi, _id): shots[s.name] = shots.get(s.name, 0) + 1)
	bus.hit_confirmed.connect(func(s, t, z, d):
		if t == g.player_aircraft:
			hits += 1
			print("HIT auf Spieler von %s zone %d dmg %.1f" % [s.name if s else "?", z, d]))
	bus.aircraft_damaged.connect(func(a, z, d, at):
		if a == g.player_aircraft:
			dmg_events += 1; dmg_total += d)
	# Spieler: geradeaus in 1500 m über Grund, 4 km vor dem Platz Richtung Rot
	var sc := ScriptedController.new()
	sc.intent.throttle = 0.8
	for a2 in OS.get_cmdline_user_args():
		if a2.begins_with("--gas="): sc.intent.throttle = float(a2.substr(6))
	g.add_child(sc)
	pl.pilot_seat.possess(sc)
	var dir: Vector3 = (g.scenario.field_center(g.scenario.red_field) - g.scenario.field_center(g.scenario.blue_field))
	dir.y = 0; dir = dir.normalized()
	var p: Vector3 = g.scenario.field_center(g.scenario.blue_field) + dir * 4000.0
	p.y = WorldGround.height_at(p.x, p.z) + 1300.0
	pl.place(Transform3D(Basis.looking_at(dir, Vector3.UP), p), 110.0, 0.8, false)
	print("Spieler nation=%d id=%d, Ziele=%d" % [pl.nation_id, pl.entity_id, ProjectileSystem.targets().size()])
	for t in ProjectileSystem.targets():
		print("  Ziel %s id=%d boxes=%s" % [t.node.name, t.id, t.boxes() != null])
	for f in 60 * sek:
		await physics_frame
		if f % 120 == 0 and "--detail" in OS.get_cmdline_user_args():
			for k in g.scenario.brains.size():
				var e2: Aircraft = g.scenario.enemies[k]
				var rel := pl.global_position - e2.global_position
				print("  t=%d %s d=%.0f vE=%.0f vP=%.0f clos=%.1f st=%d err=%.1f nose=%.0f dy=%.0f thr=%.2f gear=%.2f fl=%.2f" % [f/60, e2.name, rel.length(), e2.linear_velocity.length()*3.6, pl.linear_velocity.length()*3.6,
					-(pl.linear_velocity-e2.linear_velocity).dot(rel.normalized()), g.scenario.brains[k].get("state"), g.scenario.brains[k].aim_error_deg, rad_to_deg((-e2.global_basis.z).angle_to(rel)), -rel.y, e2.telemetry().throttle_actual, e2.telemetry().gear_extension, e2.telemetry().commands.flaps if e2.telemetry().commands else -1.0])
		if f % 600 == 0:
			var s := "t=%3ds" % (f / 60)
			for k in g.scenario.brains.size():
				var br: AIPilotBrain = g.scenario.brains[k]
				var e: Aircraft = g.scenario.enemies[k]
				s += " | %s d=%.0f tgt=%s st=%s fw=%s ammo=%d" % [e.name, e.global_position.distance_to(pl.global_position),
					br.target.node.name if br.target != null and br.target.get("node") else str(br.target != null),
					br.get("state"), br.in_fire_window, e.weapons.ammo()]
			print(s, " | rej=%d hpE=%.2f" % [g.projectiles.hits_rejected, pl.damage.hp_fraction(0)])
	print("ERGEBNIS shots=%s hitsOnPlayer=%d dmgEvents=%d dmg=%.1f rejected=%d health=%.3f" % [shots, hits, dmg_events, dmg_total, g.projectiles.hits_rejected, pl.damage.health_fraction()])
	quit(0)
