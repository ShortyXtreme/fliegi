extends SceneTree
## Diagnose: Bewegung nach dem Spawn auf der Piste bei Gas 0 (Tester: "rollt rückwärts").
## Aufruf: godot --headless --path . --fixed-fps 60 --script res://tests/diag/spawn_diag.gd

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var w := TestWorld.new()
	root.add_child(w)
	await physics_frame
	var a := Aircraft.create(load("res://vehicles/aircraft/data/fighter_t1.tres"), false)
	w.add_child(a)
	a.place_on_ground(w.runway_spawn(), TestWorld.RUNWAY_DIR)
	var pc := PlayerController.new()
	a.add_child(pc)
	a.pilot_seat.possess(pc)
	var p0 := a.global_position
	var fwd := TestWorld.RUNWAY_DIR
	var min_v := 0.0
	for f in 60 * 8:
		await physics_frame
		var t := a.telemetry()
		var vf := a.linear_velocity.dot(fwd)
		min_v = minf(min_v, vf)
		if f % 15 == 0 or f < 10:
			print("f=%3d vfwd=%+.3f dpos=%+.3f y=%.3f pitch=%.2f thrust=%.1f wheels=%d brake=%.2f loads=%s" % [f, vf,
				(a.global_position - p0).dot(fwd), a.global_position.y,
				rad_to_deg(asin(-a.global_transform.basis.z.y)), t.thrust, t.wheels_in_contact,
				t.commands.brakes, a.flight.gear.loads])
	print("min vfwd ", min_v, "  Weg ", (a.global_position - p0).dot(fwd))
	quit(0)
