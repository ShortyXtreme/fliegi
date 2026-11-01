extends TestSuite
## Kampf-HUD (Paket 9) und Flug-Panel: Smoke-Tests headless mit Fake-Daten.

var _hud: Hud


func after_each() -> void:
	CombatHud.replace_legacy_text = false
	if _hud and is_instance_valid(_hud):
		_hud.queue_free()
	_hud = null


func _make_hud(a: Aircraft) -> Hud:
	_hud = Hud.new()
	_hud.aircraft = a
	world.add_child(_hud)
	return _hud


func test_flight_panel_data() -> Array:
	var a := _spawn(false, 900.0, 80.0, 0.7)
	await _step(5)
	var d := FlightPanel.gather(a, null, null, false)
	var ok: bool = absf(d.speed_kmh - 288.0) < 25.0 and absf(d.altitude - 900.0) < 5.0 \
		and d.fps == -1 and d.gear >= 0.99 and d.has("warnings")
	# Fahrwerk draußen bei 288 km/h ist erlaubt; Warnliste ohne Überdrehzahl
	var dbg := FlightPanel.gather(a, null, null, true)
	return [ok and dbg.fps >= 0, "Fahrt %.0f km/h, Höhe %.0f m, Warnungen %s" % [d.speed_kmh,
		d.altitude, str(d.warnings)]]


func test_flight_panel_warnings() -> Array:
	var a := _spawn(false, 900.0, 110.0, 0.7)
	await _step(3)
	var d := FlightPanel.gather(a, null, null)
	var texts := []
	for w in d.warnings:
		texts.append(w[0])
	var over := texts.any(func(s): return String(s).begins_with("FAHRWERK ZU SCHNELL"))
	return [over, "Warnungen bei 396 km/h mit Fahrwerk: %s" % str(texts)]


func test_hud_contains_panel_and_hides_legacy() -> Array:
	var a := _spawn(false, 900.0, 80.0, 0.7)
	var h := _make_hud(a)
	await _step(2)
	var ok1: bool = h.combat != null and h.combat.flight_panel != null
	var info: Label = h.get("_info")
	var before := info.visible
	CombatHud.replace_legacy_text = true
	await _step(2)
	return [ok1 and before and not info.visible and not h.combat.flight_panel.data.is_empty(),
		"Panel da: %s, altes HUD vorher %s / nachher %s" % [ok1, before, info.visible]]


func test_format_helpers() -> Array:
	var a := HudStyle.thousands(1250.0)
	var b := HudStyle.distance(846.0)
	var c := HudStyle.distance(1430.0)
	var ok := a == "1 250" and b == "850 m" and c == "1,4 km" and FlightPanel.dec(-2.26) == "-2,3"
	return [ok, "%s | %s | %s | %s" % [a, b, c, FlightPanel.dec(-2.26)]]
