extends TestSuite
## M3.5: Tastenbelegung – Speichern/Laden, Konflikt (tauschen/abbrechen), Standard wiederherstellen,
## Anzeigen folgen der Belegung (Tasten-Leiste/F1), Einstellungsseite.


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	e.pressed = true
	return e


func test_assign_save_load_restore() -> Array:
	InputBindings.setup()
	KeyRebind.restore_defaults()
	KeyRebind.assign(&"crew_wheel", _key(KEY_R))          # R ist zu Fuß frei
	var now := KeyGlyphs.token(&"crew_wheel", false)
	var help_row: String = GroundHelp.k(&"crew_wheel")
	# Laden: Standard herstellen, dann gespeicherte Datei anwenden
	var c := ConfigFile.new()
	c.load(GameSettings.PATH)
	var saved := String(c.get_value(KeyRebind.SECTION, "crew_wheel", ""))
	KeyRebind._replace_primary(&"crew_wheel", KeyRebind._defaults[&"crew_wheel"].duplicate())
	var before := KeyGlyphs.token(&"crew_wheel", false)
	var n := KeyRebind.load_saved()
	var after := KeyGlyphs.token(&"crew_wheel", false)
	var pad_kept := KeyGlyphs.token(&"crew_wheel", true) == "LB"
	KeyRebind.restore_defaults()
	var back := KeyGlyphs.token(&"crew_wheel", false)
	c = ConfigFile.new()
	c.load(GameSettings.PATH)
	var ok: bool = now == "R" and help_row == "R" and saved == "key:%d" % KEY_R and before == "Tab" and n >= 1 \
		and after == "R" and pad_kept and back == "Tab" and not c.has_section(KeyRebind.SECTION)
	return [ok, "neu %s (F1 %s), gespeichert %s, vorher %s, n %d, geladen %s, Pad LB %s, Standard %s, Abschnitt %s" % [now,
		help_row, saved, before, n, after, pad_kept, back, c.has_section(KeyRebind.SECTION)]]


func test_conflicts_swap_and_contexts() -> Array:
	InputBindings.setup()
	KeyRebind.restore_defaults()
	# E ist zu Fuß „Interagieren“: Funk öffnen auf E -> Konflikt; im Flug ist E Seitenruder (anderer Kontext)
	var c1 := KeyRebind.conflicts(&"crew_wheel", _key(KEY_E))
	var c_radio := KeyRebind.conflicts(&"radio_cmd_1", _key(KEY_E))        # Funk überlappt mit zu Fuß
	var c_free := KeyRebind.conflicts(&"radio_cmd_1", _key(KEY_4))         # Kanal 4 nur in der Kanalliste
	KeyRebind.assign(&"crew_wheel", _key(KEY_E), true)                     # tauschen
	var wheel := KeyGlyphs.token(&"crew_wheel", false)
	var interact := KeyGlyphs.token(&"crew_interact", false)
	var flight_e := KeyGlyphs.token(&"kb_yaw_right", false)
	KeyRebind.restore_defaults()
	var ok: bool = c1 == [&"crew_interact"] and c_radio.has(&"crew_interact") and not c_free.has(&"radio_channel_4") \
		and wheel == "E" and interact == "Tab" and flight_e == "E" and KeyGlyphs.token(&"crew_wheel", false) == "Tab"
	return [ok, "Konflikte %s / Funk %s / frei %s, getauscht Funk %s Interagieren %s, Flug E %s" % [c1, c_radio,
		c_free, wheel, interact, flight_e]]


func test_settings_page_capture() -> Array:
	InputBindings.setup()
	KeyRebind.restore_defaults()
	var m := GameMenu.new()
	world.add_child(m)
	await _step(2)
	m.show_page("keys")
	await _step(2)
	var groups: Array = m.list.items.filter(func(i): return i.get("header", false)).map(func(i): return i.label)
	var ids: Array = m.list.items.map(func(i): return i.id)
	var must := ["key:crew_wheel", "key:radio_channel_1", "key:radio_channel_4", "key:radio_cmd_1", "key:radio_cmd_3",
		"key:radio_back", "key:engine_toggle", "key:crew_interact", "keys_default"]
	var has_all := must.all(func(x): return ids.has(x))
	# Taste umbelegen mit Konflikt -> Konfliktseite -> Abbrechen
	m._on_activated("key:crew_wheel")
	m.capture_event(_key(KEY_E))
	var conflict_page: bool = m.list.items.any(func(i): return i.id == "swap")
	m._on_activated("swap_cancel")
	var unchanged := KeyGlyphs.token(&"crew_wheel", false) == "Tab"
	# ohne Konflikt
	m._on_activated("key:crew_wheel")
	m.capture_event(_key(KEY_R))
	var changed := KeyGlyphs.token(&"crew_wheel", false) == "R"
	m._on_activated("keys_default")
	var restored := KeyGlyphs.token(&"crew_wheel", false) == "Tab"
	# Layout: Werte stehen rechts der Beschriftungsspalte
	var vr: Rect2 = m.list.value_rect(0)
	var layout_ok: bool = vr.position.x >= 28.0 + m.list.label_w and vr.end.x <= m.list.w
	m.queue_free()
	var ok: bool = groups == ["Fliegen", "Boden", "Funk", "Allgemein"] and has_all and conflict_page and unchanged \
		and changed and restored and layout_ok
	return [ok, "Gruppen %s, Pflicht %s, Konflikt %s, abgebrochen %s, neu %s, Standard %s" % [groups, has_all,
		conflict_page, unchanged, changed, restored]]
