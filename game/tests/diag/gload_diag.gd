extends SceneTree
## Prüfung Schaden (Audit): Welche g-Last erreicht der Jäger beim vollen Ziehen (Arcade/Realistisch)?
## Grundlage für die Bruchlast beschädigter Flügel. Aufruf:
## godot --headless --path . --fixed-fps 60 --script res://tests/diag/gload_diag.gd

const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var w := TestWorld.new()
	root.add_child(w)
	await physics_frame
	for mode in [FlightAssist.Mode.ARCADE, FlightAssist.Mode.REALISTIC]:
		for v in [110.0, 150.0, 190.0, 230.0]:
			var a := Aircraft.create(load(FIGHTER), false)
			w.add_child(a)
			var c := ScriptedController.new()
			c.intent.throttle = 1.0
			c.intent.gear_down = false
			c.intent.assist_mode = mode
			a.add_child(c)
			a.pilot_seat.possess(c)
			a.place(Transform3D(Basis.looking_at(Vector3(0, 0, -1), Vector3.UP), Vector3(0, 3000, 0)), v, 1.0, false)
			for i in 20:
				await physics_frame
			c.intent.pitch = 1.0
			var gmax := 0.0
			var gsum := 0.0
			for i in 180:
				await physics_frame
				gmax = maxf(gmax, a.telemetry().g_load)
				if i >= 60:
					gsum += a.telemetry().g_load
			print("Modus %d v0 %.0f m/s: g max %.1f, Mittel 1–3 s %.1f" % [mode, v, gmax, gsum / 120.0])
			a.queue_free()
			await physics_frame
	quit(0)
