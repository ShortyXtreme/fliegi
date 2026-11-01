extends SceneTree
## Sichtprüfung HUD + Effekte mit Fake-Daten (kein Teil des Spiels).
## xvfb-run -s "-screen 0 1920x1080x24" godot --path . --rendering-driver opengl3 \
##   --resolution 1920x1080 --script res://ui/combat/preview/hud_preview.gd -- <out_dir>

var out_dir := "user://"
var game: Game


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	_run.call_deferred()


func _shot(file: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(out_dir.path_join(file))
	print("gespeichert: ", out_dir.path_join(file))


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _enemy(nm: String, pos: Vector3, dir: Vector3, id: int) -> Aircraft:
	var d: AircraftData = game.ai_aircraft.data
	var a := Aircraft.create(d)
	a.name = nm
	a.nation_id = Nations.RED
	a.entity_id = id
	game.add_child(a)
	a.place(Transform3D(Basis.looking_at(dir, Vector3.UP), pos), 85.0, 0.8, false)
	return a


func _run() -> void:
	CombatHud.replace_legacy_text = true
	game = load("res://world/main.tscn").instantiate()
	root.add_child(game)
	await _frames(5)
	game.hud.toggle_help()
	var pa := game.player_aircraft
	var b := Basis.looking_at(Vector3(0, 0, -1), Vector3.UP)
	pa.place(Transform3D(b, Vector3(0, 800, 0)), 95.0, 0.85, false)
	game.player.reset_state(0.85)
	game.player.parking_brake = false
	game.player.gear_down = false
	game.ai_aircraft.entity_id = 5
	game.ai_aircraft.place(Transform3D(b, Vector3(0, 900, -6000)), 82.0, 0.8, false)
	var e2 := _enemy("Rot2", Vector3(30, 830, -330), Vector3(-0.1, 0, -1), 2)
	var e3 := _enemy("Rot3", Vector3(-1400, 900, 600), Vector3(1, 0, 0), 3)
	var e4 := _enemy("Rot4", Vector3(1800, 760, -2400), Vector3(-1, 0, 0), 4)
	await _frames(30)
	await _shot("hud_flight.png")
	# Kampf: Feuern, Treffer, Abschuss, eigener Schaden, Notausstieg gesperrt
	Input.action_press("fire_primary")
	var bus := CombatEvents.bus()
	await _frames(14)
	bus.aircraft_destroyed.emit(e4, pa, CombatEvents.Cause.WING_BROKEN)
	bus.pilot_ejected.emit(e3, null)
	bus.aircraft_destroyed.emit(game.ai_aircraft, null, CombatEvents.Cause.CRASH)
	pa.damage.apply_hit(DamageModel.Zone.WING_L, 120.0, e3)
	pa.damage.apply_hit(DamageModel.Zone.TAIL, 90.0, e3)
	pa.damage.apply_hit(DamageModel.Zone.FUEL_R, 25.0, e3)
	pa.eject_requested.emit(pa, false)
	await _frames(8)
	bus.hit_confirmed.emit(pa, e2, DamageModel.Zone.ENGINE, 10.0)
	game.hud.combat.overlay.hit_t = 10.0   # Software-Rendering ist langsam: Anzeige festhalten
	game.hud.combat.overlay.eject_locked_t = 10.0
	print("Vorhalt-Ziel: ", not game.hud.combat.overlay.lead_target.is_empty(), " Lösung: ", not game.hud.combat.overlay.lead.is_empty())
	await _shot("hud_combat.png")
	Input.action_release("fire_primary")
	quit(0)
