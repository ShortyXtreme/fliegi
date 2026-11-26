extends TestSuite
## M3.5 Funkgerät: Kanäle als Daten, zweistufige Bedienung (Kanal 1–4, Befehl 1–4) über die
## InputMap-Aktionen, zurück/schließen, Kanalwechsel, letzter Kanal gespeichert, Antwortzeilen je
## Kanal, Anfrage an einen Spieler, Pad-A/B gehören dem offenen Funkgerät.


func _hud(a: Node) -> GroundHud:
	InputBindings.setup()
	var g := GroundHud.create(null)
	world.add_child(g)
	g.set_context(InputBindings.Context.CREW)
	g.aircraft_list = [a] if a != null else []
	return g


func _press(g: GroundHud, action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	g.radio_input(ev)


func test_channels_as_data() -> Array:
	var chs := RadioChannel.default_channels()
	var names: Array = chs.map(func(c): return c.name)
	var counts: Array = chs.map(func(c): return c.commands.size())
	var labels: Array = (chs[0] as RadioChannel).commands.map(func(c): return c.label)
	var ok: bool = names == ["Tankwart", "Munition", "Reparatur", "Bodenpersonal"] and counts == [4, 4, 4, 3] \
		and labels == ["Tankwagen rufen", "Tankwagen wegschicken", "Volltanken", "Status?"] \
		and chs.all(func(c): return c.number >= 1 and c.freq != "" and c.role != &"")
	return [ok, "Kanäle %s, Befehle %s, Kanal 1 %s" % [names, counts, labels]]


func test_two_stage_keys() -> Array:
	var a := _spawn(true)
	var g := _hud(a)
	await _step(2)
	var got := []
	g.command_receiver = func(cmd: int, t: Node): got.append([cmd, t])
	RadioPanel.save_last(0)
	_press(g, &"crew_wheel")                         # öffnen: Kanalliste, Kanal 1 markiert
	var open1 := g.radio.is_open and g.radio.stage == RadioPanel.Stage.CHANNELS and g.radio.current == 0
	_press(g, &"radio_channel_2")                    # Kanal 2 Munition
	var st2 := g.radio.stage == RadioPanel.Stage.COMMANDS and g.radio.channel().id == &"ammo"
	_press(g, &"radio_back")                         # zurück zur Kanalliste
	var back1 := g.radio.is_open and g.radio.stage == RadioPanel.Stage.CHANNELS
	_press(g, &"radio_channel_1")
	_press(g, &"radio_next")                         # Pfeil rechts -> Kanal 2
	_press(g, &"radio_prev")                         # zurück auf Kanal 1
	_press(g, &"radio_cmd_3")                        # Volltanken
	var closed := not g.radio.is_open
	_press(g, &"crew_wheel")
	var last := g.radio.current                      # zuletzt benutzter Kanal markiert
	_press(g, &"release_mouse")                      # Esc schließt
	var esc := not g.radio.is_open
	_press(g, &"crew_wheel")
	_press(g, &"radio_back")                         # in der Kanalliste: schließen
	var back_close := not g.radio.is_open
	var ok: bool = open1 and st2 and back1 and closed and got == [[GroundCrewBrain.Command.FUEL_ONLY, a]] \
		and last == 0 and RadioPanel.load_last() == 0 and esc and back_close
	g.queue_free()
	return [ok, "offen %s, Kanal 2 %s, zurück %s, Befehle %s, letzter Kanal %d, Esc %s" % [open1, st2, back1,
		str(got), last, esc]]


func test_answers_per_channel_and_request() -> Array:
	var a := _spawn(true)
	var g := _hud(a)
	await _step(2)
	g._on_crew_report("Fange an zu tanken.", null, &"fuel")
	g._on_crew_report("Linke Seite fertig.", null, &"ammo")
	var fuel_log: Array = g.channel_by_id(&"fuel").log.map(func(e): return e.text)
	var ammo_log: Array = g.channel_by_id(&"ammo").log.map(func(e): return e.text)
	# Status? (ohne Dispatch: „Keine Verbindung“), Anfrage an einen Spieler (Rolle besetzt)
	var rep := g.channel_by_id(&"repair")
	rep.operator_peer = 7
	var req := []
	rep.request_sent.connect(func(_c, cmd, _t): req.append(cmd.id))
	var n := rep.send(rep.commands[2], a)
	g.radio.open()
	g.radio.select_channel(0)
	var lines: Array = g.radio.body_lines().map(func(x): return x[0])
	var ok: bool = fuel_log == ["Tankwart: Fange an zu tanken."] and ammo_log == ["Munitionswart: Linke Seite fertig."] \
		and n == 1 and req == [&"repair"] and lines.has("Tankwart: Fange an zu tanken.") \
		and not lines.has("Munitionswart: Linke Seite fertig.")
	g.queue_free()
	return [ok, "Tankwart %s, Munition %s, Anfrage %s, Zeilen Kanal 1 %s" % [fuel_log, ammo_log, req, lines]]


## M3.6: Funk-Klang beim Senden (Befehl gewählt) und beim Empfang (Antwort), abschaltbar;
## die erzeugten Klänge sind nicht leer und nicht übersteuert.
func test_radio_sounds() -> Array:
	var a := _spawn(true)
	var g := _hud(a)
	await _step(2)
	var was := RadioPanel.beep_on
	RadioPanel.beep_on = true
	g.radio.open()
	g.radio.choose(1)
	g.radio.choose(4)                  # Kanal 1, „Status?“ -> Senden
	await _step(2)
	g._on_crew_report("Fange an zu tanken.", null, &"fuel")   # Empfang
	var on: Dictionary = g.radio.sounds.duplicate()
	RadioPanel.beep_on = false
	g.radio.open()
	g.radio.choose(1)
	g.radio.choose(4)
	g._on_crew_report("Halb voll.", null, &"fuel")
	var off: Dictionary = g.radio.sounds.duplicate()
	RadioPanel.beep_on = was
	var peaks := []
	for k in ["senden", "empfang"]:
		var d := RadioPanel.make_radio_stream(k).data
		var pk := 0
		for i in range(0, d.size(), 2):
			pk = maxi(pk, absi(d.decode_s16(i)))
		peaks.append(pk)
	var ok: bool = on.senden >= 1 and on.empfang >= 1 and off == on and peaks.all(func(p): return p > 1000 and p < 32000)
	g.queue_free()
	return [ok, "an %s, aus %s, Spitzen %s" % [on, off, peaks]]


func test_pad_capture_and_rough_status() -> Array:
	var a := _spawn(true)
	var g := _hud(a)
	await _step(2)
	g.radio.open()
	await _step(2)
	var cap := RadioPanel.pad_capture
	g.radio.close()
	await _step(2)
	var free := not RadioPanel.pad_capture
	var words := [GroundCrewDispatch.rough(0.0), GroundCrewDispatch.rough(0.5), GroundCrewDispatch.rough(0.75),
		GroundCrewDispatch.rough(1.0)]
	var ok: bool = cap and free and words == ["leer", "etwa halb", "etwa drei Viertel", "voll"]
	g.queue_free()
	return [ok, "Pad gefangen %s/frei %s, Worte %s" % [cap, free, words]]
