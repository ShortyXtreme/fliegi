extends TestSuite
## M3.9: Windmodell – Grenzschicht-Profil und Rauigkeit, Drehung mit der Höhe, Turbulenz-Statistik
## (Varianz und Längenskala grob wie Dryden), Determinismus, räumliche Kohärenz, Rollböe,
## Wetterentwicklung/Front mit Funkmeldung, Wind aus = exakt kein Wind, Wetterhahn am Boden.


func after_each() -> void:
	Weather.reset()


func _setup(lvl := Weather.Level.NORMAL, s := 11, from := 0.0, spd := 5.0) -> void:
	Weather.setup(lvl, s)
	Weather.base_from_deg = from
	Weather.base_speed = spd
	Weather.front_time = INF
	Weather.trend = 0.0
	Weather.time = 100.0


func test_profile_roughness_veer() -> Array:
	# Untergrund: 10 m über Wasser > Gras > Feld > Wald (mit Verdrängung), in der Mischungshöhe gleich
	var f_w := Weather._profile(10.0, 0.001, 0.0)
	var f_g := Weather._profile(10.0, 0.03, 0.0)
	var f_f := Weather._profile(10.0, 0.1, 0.0)
	var f_wald := Weather._profile(25.0, 1.0, 10.0)
	var f_g25 := Weather._profile(25.0, 0.03, 0.0)
	var b_w := Weather._profile(60.0, 0.001, 0.0)
	var b_wald := Weather._profile(60.0, 1.0, 10.0)
	var order := f_w > f_g and f_g > f_f and f_wald < f_g25 * 0.8 and absf(b_w - b_wald) < 1e-4
	# Drehung mit der Höhe (ohne Gelände): oben ~25° rechts herum
	_setup(Weather.Level.NORMAL, 3, 0.0, 5.0)
	var s := WindSample.new()
	Weather.sample(s, Vector3(0, 10, 0), 10.0)
	var lo := s.mean
	Weather.sample(s, Vector3(0, 1500, 0), 1500.0)
	var hi := s.mean
	var from_lo := rad_to_deg(atan2(-lo.x, lo.z))
	var from_hi := rad_to_deg(atan2(-hi.x, hi.z))
	var veer := from_hi - from_lo
	var ratio := hi.length() / lo.length()
	var ok := order and veer > 20.0 and veer < 30.0 and absf(ratio - Weather.MAX_FACTOR) < 0.05
	return [ok, "10 m: Wasser %.2f, Gras %.2f, Feld %.2f; 25 m Wald %.2f / Gras %.2f; 60 m gleich %s; Drehung 10 m→1,5 km %+.0f°, Stärke ×%.2f" % [
		f_w, f_g, f_f, f_wald, f_g25, absf(b_w - b_wald) < 1e-4, veer, ratio]]


## Längs-Turbulenz entlang einer Linie in Windrichtung (eingefrorenes Feld, feste Zeit):
## normierte Streuung ≈ 1, integrale Längenskala im Bereich der Dryden-Skala.
func _series(agl: float, comp: int, dx: float, n: int) -> PackedFloat32Array:
	var s := WindSample.new()
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var p := Vector3(1234.0, agl, -20000.0 + i * dx)
		Weather.sample(s, p, agl)
		var m := s.mean.normalized()
		var v := 0.0
		if comp == 0:
			v = s.turb.dot(m) / maxf(s.sigma.x, 1e-6)
		else:
			v = s.turb.y / maxf(s.sigma.z, 1e-6)
		out[i] = v
	return out


static func _stats(x: PackedFloat32Array, dx: float) -> Vector2:
	var n := x.size()
	var m := 0.0
	for v in x:
		m += v
	m /= n
	var var_ := 0.0
	for v in x:
		var_ += (v - m) * (v - m)
	var_ /= n
	var l := 0.0
	for lag in range(0, n / 4):
		var c := 0.0
		var cnt := 0
		for i in range(0, n - lag, 3):
			c += (x[i] - m) * (x[i + lag] - m)
			cnt += 1
		c /= cnt * var_
		if c <= 0.0:
			break
		l += c * dx
	return Vector2(sqrt(var_), l)


func test_turbulence_statistics_dryden() -> Array:
	_setup(Weather.Level.NORMAL, 21, 0.0, 5.0)
	var ok := true
	var txt := []
	for agl in [10.0, 40.0, 150.0, 400.0]:
		var lu := Weather._len_u(agl)
		var lw := Weather._len_w(agl) * 0.5   # integrale Skala der Vertikalkomponente (Dryden) = Lw/2
		var dxu := maxf(lu / 12.0, 1.0)
		var dxw := maxf(lw / 12.0, 1.0)
		var su := _stats(_series(agl, 0, dxu, 3000), dxu)
		var sw := _stats(_series(agl, 1, dxw, 3000), dxw)
		var r_u := su.y / lu
		var r_w := sw.y / lw
		var good := su.x > 0.7 and su.x < 1.35 and sw.x > 0.7 and sw.x < 1.35 and r_u > 0.35 and r_u < 2.5 \
			and r_w > 0.35 and r_w < 3.0
		ok = ok and good
		txt.append("%.0f m: σu %.2f L %.0f/%.0f m, σw %.2f L %.0f/%.0f m%s" % [agl, su.x, su.y, lu, sw.x, sw.y, lw,
			"" if good else " (!)"])
	# absolute Stärke in 10 m über Gras: σu/U ≈ 1/ln(10/0,03) ≈ 0,17 (+ Konvektion)
	var s := WindSample.new()
	Weather.sample(s, Vector3(0, 10, 0), 10.0)
	var iu := s.sigma.x / s.mean.length()
	ok = ok and iu > 0.14 and iu < 0.3
	return [ok, "Turbulenzintensität 10 m %.2f; %s" % [iu, "; ".join(txt)]]


func test_determinism_and_coherence() -> Array:
	_setup(Weather.Level.STARK, 5, 30.0, 8.0)
	Weather.time = 777.0
	var p := Vector3(500, 120, 300)
	var a := Weather.wind_at_agl(p, 120.0)
	var b := Weather.wind_at_agl(p, 120.0)
	_setup(Weather.Level.STARK, 5, 30.0, 8.0)
	Weather.time = 777.0
	var c := Weather.wind_at_agl(p, 120.0)
	_setup(Weather.Level.STARK, 6, 30.0, 8.0)
	Weather.time = 777.0
	var d := Weather.wind_at_agl(p, 120.0)
	var det := a == b and a == c and a != d
	# Kohärenz: Korrelation der Böen in 8 m Abstand hoch, in 3 km Abstand klein
	_setup(Weather.Level.STARK, 5, 30.0, 8.0)
	var near := _corr(Vector3(8, 0, 0), 120.0)
	var far := _corr(Vector3(3000, 0, 2000), 120.0)
	# Windsack und Flugzeug: gleicher Ort, gleiche Zeit → gleiche Böe (gleiches Feld)
	var ok := det and near > 0.85 and absf(far) < 0.3
	return [ok, "deterministisch %s (Seed anders: %s), Korrelation 8 m %.2f, 3,6 km %.2f" % [a == b and a == c, a != d, near, far]]


func _corr(off: Vector3, agl: float) -> float:
	var s := WindSample.new()
	var xs := PackedFloat32Array()
	var ys := PackedFloat32Array()
	for i in 600:
		Weather.time = 100.0 + i * 0.7
		var p := Vector3(-800.0 + i * 13.0, agl, 200.0 + i * 3.0)
		Weather.sample(s, p, agl)
		xs.append(s.turb.x + s.turb.z)
		Weather.sample(s, p + off, agl)
		ys.append(s.turb.x + s.turb.z)
	var mx := 0.0
	var my := 0.0
	for i in xs.size():
		mx += xs[i]
		my += ys[i]
	mx /= xs.size()
	my /= ys.size()
	var sxy := 0.0
	var sxx := 0.0
	var syy := 0.0
	for i in xs.size():
		sxy += (xs[i] - mx) * (ys[i] - my)
		sxx += (xs[i] - mx) * (xs[i] - mx)
		syy += (ys[i] - my) * (ys[i] - my)
	return sxy / sqrt(sxx * syy)


## Gust-Faktor über die Zeit am Windsack (7 m, Gras): Böen bis ~+40…+70 % über dem Mittel.
func test_gust_factor_surface() -> Array:
	_setup(Weather.Level.NORMAL, 8, 0.0, 5.0)
	var p := Vector3(0, 7, 0)
	var sum := 0.0
	var mx := 0.0
	var n := 0
	var peaks := []
	for k in 6000:
		Weather.time = 1000.0 + k * 0.1
		var w := Weather.wind_at_agl(p, 7.0)
		var h := Vector2(w.x, w.z).length()
		sum += h
		n += 1
		mx = maxf(mx, h)
		if k % 1000 == 999:
			peaks.append(mx)
			mx = 0.0
	var mean := sum / n
	var g := 0.0
	for pk in peaks:
		g += pk / mean
	g /= peaks.size()
	var ok := g > 1.3 and g < 1.9
	return [ok, "10-min-Mittel %.1f m/s in 7 m, mittlerer Böenfaktor (100-s-Spitzen) %.2f" % [mean, g]]


func test_roll_gust_and_aus() -> Array:
	_setup(Weather.Level.STARK, 9, 0.0, 8.0)
	var s := WindSample.new()
	var mx := 0.0
	var sq := 0.0
	for i in 2000:
		Weather.sample(s, Vector3(i * 4.0, 60.0, 50.0), 60.0, Vector3.RIGHT, 10.0)
		mx = maxf(mx, absf(s.roll_grad))
		sq += s.roll_grad * s.roll_grad
	var rms := sqrt(sq / 2000.0)
	# Rollrate, die die Böe bei 50 m/s auslöst, grob: p ≈ roll_grad (Antisymmetrischer Anstellwinkel)
	Weather.reset()
	Weather.sample(s, Vector3(0, 60, 0), 60.0, Vector3.RIGHT, 10.0)
	var off := s.total == Vector3.ZERO and s.roll_grad == 0.0 and Weather.wind_at(Vector3(5, 100, 5)) == Vector3.ZERO
	var ok := rms > 0.005 and rms < 0.1 and mx < 0.4 and off
	return [ok, "Rollböe Stark in 60 m: RMS %.3f 1/s, max %.3f 1/s; Wind aus: kein Wind %s" % [rms, mx, off]]


func test_weather_evolution_front_report() -> Array:
	var seed_f := -1
	for s in 200:
		Weather.setup(Weather.Level.NORMAL, s)
		if Weather.front_time != INF:
			seed_f = s
			break
	if seed_f < 0:
		return [false, "keine Partie mit Front in 200 Seeds"]
	var tf := Weather.front_time
	var before := Weather.from_deg_at(tf - 1200.0)
	var after := Weather.from_deg_at(tf + 1200.0)
	var sector_ok := true
	for k in 120:
		var d := Weather.from_deg_at(k * 90.0)
		sector_ok = sector_ok and absf(d) <= Weather.DIR_SECTOR + 22.0
	# Funk: Driver meldet die Front und spätere Drehung
	var drv := WeatherDriver.new()
	world.add_child(drv)
	Weather.time = tf - 1500.0
	drv._last_state = Weather.report_state(Weather.time)
	var msgs := []
	var t := tf - 1500.0
	while t < tf + 1500.0:
		Weather.time = t
		var m := drv.check_changes()
		if m != "":
			msgs.append(m)
		t += 15.0
	drv.queue_free()
	var turned := after - before
	var front_msg := msgs.any(func(m): return String(m).contains("Front"))
	var n_fronts := 0
	var cnt := 0
	for s in 100:
		Weather.setup(Weather.Level.NORMAL, s)
		if Weather.front_time != INF:
			n_fronts += 1
		cnt += 1
	var ok := turned > Weather.front_veer - 15.0 and turned < Weather.front_veer + 15.0 and sector_ok and front_msg \
		and n_fronts > 15 and n_fronts < 60 and msgs.size() < 8
	return [ok, "Seed %d: Front nach %.0f min, dreht %+.0f° (soll %+.0f°), Sektor %s; Meldungen %s; Fronten in %d/100 Partien" % [
		seed_f, tf / 60.0, turned, Weather.front_veer, sector_ok, msgs, n_fronts]]


func test_change_report_text() -> Array:
	Weather.set_steady(0.0, 5.0)
	Weather.steady = false
	var a := Weather.change_report([6, 2, 0], [7, 3, 0])
	var b := Weather.change_report([6, 3, 0], [6, 2, 0])
	var c := Weather.change_report([5, 2, 0], [6, 3, 1])
	var d := Weather.change_report([5, 2, 0], [5, 2, 0])
	var ok := a == "Wind dreht auf Nordwest, frischt auf" and b == "Wind flaut ab" \
		and c == "Front zieht durch, Wind dreht auf West, frischt auf, böig" and d == ""
	return [ok, "„%s“, „%s“, „%s“, „%s“" % [a, b, c, d]]


## Wetterhahn: Spornradflugzeug rollt mit 22 m/s bei Seitenwind aus Ost (8 m/s), Seitenruder
## neutral → dreht nach rechts in den Wind (ohne Wind geradeaus); mit Knüppel gezogen (Sporn am
## Boden, FAA-Technik) und einem einfachen Seitenruder-Regler bleibt es beherrschbar.
func test_weathervane_on_ground() -> Array:
	var res := []
	for c in [[0.0, false], [8.0, false], [8.0, true]]:
		if c[0] > 0.0:
			Weather.set_steady(90.0, c[0])
		else:
			Weather.reset()
		var a := _spawn(true)
		a.linear_velocity = -a.global_transform.basis.z * 22.0
		var h0 := a.global_transform.basis.z
		var ctl: bool = c[1]
		var maxdev := [0.0]
		_seat(a, func(_v, i: PilotIntent, _dt):
			i.throttle = 0.45
			if ctl:
				i.pitch = 0.6
				var hz := a.global_transform.basis.z
				var err := atan2(h0.cross(hz).y, h0.dot(hz))          # + = Nase links
				var r := -a.telemetry().angular_velocity_local.y      # + = nach rechts
				i.yaw = clampf(err * 3.0 - r * 1.2, -1.0, 1.0)
				maxdev[0] = maxf(maxdev[0], absf(rad_to_deg(err))))
		await _step(240)
		var h1 := a.global_transform.basis.z
		var yaw := rad_to_deg(atan2(h0.cross(h1).y, h0.dot(h1)))
		res.append(-yaw if not ctl else maxdev[0])   # positiv = Nase nach rechts (Ost)
		a.queue_free()
		await _step(1)
	Weather.reset()
	var ok: bool = absf(res[0]) < 3.0 and res[1] > 4.0 and res[2] < 25.0
	return [ok, "Heading-Änderung in 4 s bei 22 m/s: ohne Wind %+.1f°, 8 m/s von rechts ohne Ruder %+.1f° (in den Wind), mit Seitenruder-Regler max. Abweichung %.1f°" % [
		res[0], res[1], res[2]]]
