extends SceneTree
## Prüfung Waffen/Schaden (Audit): Ballistik-Tabelle, Treffer bis Abschuss je Anflugrichtung.
## Aufruf: godot --headless --path . --fixed-fps 60 --script res://tests/diag/weapons_diag.gd
## Ausgabe nur Text; ändert nichts am Spiel.

const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var w: WeaponDef = load("res://weapons/data/mg_t1.tres")
	print("== Ballistik %s: v0 %.0f m/s, k %.6f 1/m, Masse %.1f g, %d/min" % [w.display_name,
			w.muzzle_velocity, w.ballistic_k, w.projectile_mass * 1000.0, w.rpm])
	print("Entf.  Flugzeit  Fall    v_rest  E_kin")
	for d in [100, 200, 250, 300, 400, 500, 750, 1000, 1500]:
		var v := Ballistics.speed_at(d, w.muzzle_velocity, w.ballistic_k)
		print("%5d  %6.3f s %5.2f m %6.0f  %5.0f J" % [d, Ballistics.time_of_flight(d, w.muzzle_velocity, w.ballistic_k),
				Ballistics.drop(d, w.muzzle_velocity, w.ballistic_k), v, 0.5 * w.projectile_mass * v * v])
	# Cd aus k bei Meereshöhe
	var area := PI * pow(w.caliber_mm * 0.0005, 2.0)
	print("Cd (rho 1,225) = %.3f" % [2.0 * w.ballistic_k * w.projectile_mass / (1.225 * area)])
	# Konvergenz
	var lo: WeaponLoadout = load("res://weapons/data/loadout_fighter_t1.tres")
	for dist in [150.0, 250.0, 400.0]:
		var dirs := lo.aim_directions(250.0)
		var s := "Konvergenz 250 m, Abstand zur Visierlinie bei %.0f m:" % dist
		for k in lo.mounts.size():
			var m := lo.mounts[k]
			var c := Ballistics.cross_plane(m.position, dirs[k] * w.muzzle_velocity, w.ballistic_k, 1.0 / 60.0,
					lo.sight_position + Vector3(0, 0, -dist), Vector3(0, 0, -1))
			var p: Vector3 = c.point
			s += " (%.2f, %.2f)" % [p.x - lo.sight_position.x, p.y - lo.sight_position.y]
		print(s)
	print("Feuerdauer: %.1f s (%d Schuss je Waffe)" % [lo.mounts[0].ammo * w.shot_interval(), lo.mounts[0].ammo])
	# Integrationsgenauigkeit und Tickraten-Unabhängigkeit: Punkt bei 500/1000 m
	for hz in [30.0, 60.0, 120.0, 6000.0]:
		var c := Ballistics.cross_plane(Vector3.ZERO, Vector3(0, 0, -w.muzzle_velocity), w.ballistic_k, 1.0 / hz,
				Vector3(0, 0, -500), Vector3(0, 0, -1))
		var c2 := Ballistics.cross_plane(Vector3.ZERO, Vector3(0, 0, -w.muzzle_velocity), w.ballistic_k, 1.0 / hz,
				Vector3(0, 0, -1000), Vector3(0, 0, -1))
		print("Tick %5.0f Hz: 500 m t=%.4f s Fall %.3f m | 1000 m t=%.4f s Fall %.3f m" % [hz, c.time, -c.point.y, c2.time, -c2.point.y])
	# Dichte nach Höhe (Flugmodell): k müsste mit rho skalieren
	for alt in [0.0, 1500.0, 3000.0, 5000.0]:
		var rho := FlightModel.air_density(alt)
		var kk := w.ballistic_k * rho / 1.225
		print("Höhe %4.0f m: rho %.3f -> k %.6f, v(500) %.0f statt %.0f m/s, Fall(500) %.2f statt %.2f m" % [alt, rho, kk,
				Ballistics.speed_at(500, w.muzzle_velocity, kk), Ballistics.speed_at(500, w.muzzle_velocity, w.ballistic_k),
				Ballistics.drop(500, w.muzzle_velocity, kk), Ballistics.drop(500, w.muzzle_velocity, w.ballistic_k)])
	# Rückstoß (Impuls je s, Geschoss + ~1/3 Pulvergas)
	print("Rückstoß je Waffe ≈ %.0f N (m·v0·Kadenz ×1,3)" % [w.projectile_mass * w.muzzle_velocity * w.rpm / 60.0 * 1.3])
	# Treffer bis Abschuss
	var a := Aircraft.create(load(FIGHTER), false)
	root.add_child(a)
	a.set_physics_process(false)
	var hb := a.damage.hitboxes
	print("Hitboxen: %d, Radius %.2f" % [hb.box_count(), hb.bounding_radius])
	var aspects := {
		"hinten (6 Uhr)": Vector3(0, 0.05, 1).normalized(),
		"hinten-oben 15°": Vector3(0, 0.26, 1).normalized(),
		"seitlich 90°": Vector3(1, 0.05, 0).normalized(),
		"schräg 45°": Vector3(0.7, 0.1, 0.7).normalized(),
		"frontal": Vector3(0, 0.02, -1).normalized(),
		"von oben": Vector3(0.0, 1, 0.2).normalized(),
	}
	var sigma_m := 1.0   # Streukreis am Ziel (m, je Achse): Streuung + Zielfehler
	for key in aspects:
		var from: Vector3 = aspects[key]
		var kills := []
		var causes := {}
		var zone_hits := PackedInt32Array()
		zone_hits.resize(DamageModel.Zone.COUNT)
		var shots_total := 0
		var hits_total := 0
		for trial in 40:
			a.damage.reset()
			var rng := RandomNumberGenerator.new()
			rng.seed = trial * 7919 + 13
			var hits := 0
			var shots := 0
			var up := Vector3.UP if absf(from.y) < 0.9 else Vector3.RIGHT
			var r := from.cross(up).normalized()
			var u := r.cross(from).normalized()
			while not a.damage.is_destroyed and shots < 4000:
				shots += 1
				var off := r * rng.randfn(0.0, sigma_m) + u * rng.randfn(0.0, sigma_m)
				var p0 := from * 30.0 + off
				var p1 := -from * 30.0 + off
				var h := hb.intersect_segment(p0, p1)
				if h.is_empty():
					continue
				hits += 1
				zone_hits[h.zone] += 1
				a.damage.apply_hit(h.zone, w.damage * float(h.get("damage_mul", 1.0)) if "--mul" in OS.get_cmdline_user_args() else w.damage, null)
			kills.append(hits)
			causes[a.damage.destroy_cause] = causes.get(a.damage.destroy_cause, 0) + 1
			shots_total += shots
			hits_total += hits
		kills.sort()
		var zs := ""
		for z in DamageModel.Zone.COUNT:
			zs += "%s %.0f%% " % [DamageModel.ZONE_NAMES[z], 100.0 * zone_hits[z] / maxf(hits_total, 1)]
		print("%-16s Treffer bis Abschuss: Median %d (10%% %d, 90%% %d), Trefferquote %.0f%%, Ursachen %s | %s" % [key,
				kills[kills.size() / 2], kills[4], kills[35], 100.0 * hits_total / maxf(shots_total, 1), causes, zs])
	quit(0)
