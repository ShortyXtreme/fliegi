extends SceneTree
## M3.9: Winddaten für Diagramme (docs/screens_m3/m3_9_wind_profil.png, tools/plot_wind.py).
## godot --headless --path . --script res://tools/wind_dump.gd -- <out.csv-Präfix>
## Schreibt <präfix>_profil.csv (Höhenprofil je Untergrund), <präfix>_zeit.csv (Windsack 7 m über
## 30 min und Großwetter über 3 h mit Front) und <präfix>_flug.csv (Böen entlang einer Flugbahn).

var prefix := "user://wind"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		prefix = args[0]
	_run.call_deferred()


func _run() -> void:
	# Profil (ohne Gelände, Normal 5 m/s): Untergrund über z0/d
	Weather.setup(Weather.Level.NORMAL, 3)
	Weather.base_speed = 5.0
	var f := FileAccess.open(prefix + "_profil.csv", FileAccess.WRITE)
	f.store_line("h,wasser,gras,feld,wald,drehung")
	var h := 2.0
	while h <= 1500.0:
		var s := WindSample.new()
		Weather.time = 0.0
		Weather.front_time = INF
		Weather.sample(s, Vector3(0, h, 0), h)
		var veer := rad_to_deg(atan2(-s.mean.x, s.mean.z)) - Weather.from_deg_at(0.0)
		f.store_line("%.1f,%.3f,%.3f,%.3f,%.3f,%.2f" % [h, 5.0 * Weather._profile(h, 0.001, 0.0),
			5.0 * Weather._profile(h, 0.03, 0.0), 5.0 * Weather._profile(h, 0.1, 0.0),
			5.0 * Weather._profile(h, 1.0, 10.0), veer])
		h *= 1.08
	f.close()
	# Zeitreihe Windsack (7 m, Gras) über 30 min, 0,2 s; Großwetter 3 h mit Front
	var seed_f := 0
	for sd in 200:
		Weather.setup(Weather.Level.NORMAL, sd)
		if Weather.front_time != INF and Weather.front_time < 7000.0:
			seed_f = sd
			break
	Weather.setup(Weather.Level.NORMAL, seed_f)
	var g := FileAccess.open(prefix + "_zeit.csv", FileAccess.WRITE)
	g.store_line("t,boden7m,mittel10m,richtung")
	var t := 0.0
	while t < 1800.0:
		Weather.time = t
		var w := Weather.wind_at_agl(Vector3(0, 7, 0), 7.0)
		g.store_line("%.1f,%.3f,%.3f,%.2f" % [t, Vector2(w.x, w.z).length(), Weather.mean_speed_at(t), Weather.from_deg_at(t)])
		t += 0.2
	g.close()
	var g2 := FileAccess.open(prefix + "_wetter.csv", FileAccess.WRITE)
	g2.store_line("t,mittel10m,richtung,front")
	t = 0.0
	while t < 10800.0:
		g2.store_line("%.0f,%.3f,%.2f,%.3f" % [t, Weather.mean_speed_at(t), Weather.from_deg_at(t), Weather.front_progress(t)])
		t += 30.0
	g2.close()
	# Flugbahn: 100 m/s quer zum Wind, 30 s, in 30 m und 300 m
	Weather.setup(Weather.Level.NORMAL, 5)
	Weather.base_from_deg = 0.0
	Weather.base_speed = 5.0
	Weather.front_time = INF
	var k := FileAccess.open(prefix + "_flug.csv", FileAccess.WRITE)
	k.store_line("t,u30,w30,u300,w300,thermik300")
	var s2 := WindSample.new()
	t = 0.0
	while t < 30.0:
		Weather.time = 500.0 + t
		var row := [t]
		for alt in [30.0, 300.0]:
			Weather.sample(s2, Vector3(-1500.0 + t * 100.0, alt, 0.0), alt)
			row.append(s2.turb.z)
			row.append(s2.turb.y)
		row.append(s2.thermal)
		k.store_line("%.2f,%.3f,%.3f,%.3f,%.3f,%.3f" % row)
		t += 0.05
	k.close()
	print("Winddaten geschrieben: ", prefix, " (Front-Seed ", seed_f, ")")
	quit()
