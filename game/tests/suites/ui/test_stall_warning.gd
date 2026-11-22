extends TestSuite
## M3.4 Strömungsabriss-Warnung: kein Kamera-Rütteln (Standard aus, Einstellung „leicht“),
## Warnton lauter je näher am Abriss, Summer hörbar, Controller-Vibration Standard leicht.


func test_stall_warning_levels() -> Array:
	var t := FlightTelemetry.new()
	t.airspeed = 50.0
	t.stall_aoa = deg_to_rad(15.0)
	var lv := []
	for d in [-3.0, -1.4, -0.8, -0.1]:
		t.aoa = t.stall_aoa + deg_to_rad(d)
		lv.append(Hud.stall_warn_level(t))
	t.stall_amount = 0.6
	lv.append(Hud.stall_warn_level(t))
	t.on_ground = true
	var ground := Hud.stall_warn_level(t)
	var rising: bool = lv[0] == 0.0 and lv[1] > 0.0 and lv[2] > lv[1] and lv[3] > lv[2] and lv[4] == 1.0
	# Summer hat Pegel (nicht stumm)
	var peak := 0.0
	for k in 400:
		peak = maxf(peak, absf(Hud.buzzer_sample(k / 22050.0)))
	return [rising and ground == 0.0 and peak > 0.4, "Pegel %s, am Boden %.1f, Summer-Spitze %.2f" % [
		str(lv.map(func(x): return snappedf(x, 0.01))), ground, peak]]


func test_no_camera_shake_by_default() -> Array:
	var path := GameSettings.PATH
	var backup := FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else ""
	var c := ConfigFile.new()
	c.load(path)
	if c.has_section("m3_4"):
		c.erase_section("m3_4")
	c.save(path)
	GameSettings.apply_runtime()
	var def_shake := CameraRig.shake_mul
	var def_rumble := Hud.rumble_mul
	GameSettings.set_value("kamera_ruetteln", "leicht")
	GameSettings.apply_runtime()
	var light := CameraRig.shake_mul
	if backup == "":
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	else:
		var f := FileAccess.open(path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	GameSettings.apply_runtime()
	var ok := def_shake == 0.0 and light > 0.0 and light <= 0.25 and def_rumble > 0.0 and def_rumble < 0.5
	return [ok, "Rütteln Standard %.2f, leicht %.2f, Vibration Standard %.2f" % [def_shake, light, def_rumble]]
