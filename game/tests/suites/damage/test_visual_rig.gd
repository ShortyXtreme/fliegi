extends TestSuite
## Paket 11: Rig-Animation des Spielmodells und Schadenseffekte (Agent B).

const SUITE := "fast"


func _visual_ac(nation := Nations.BLUE) -> Aircraft:
	var a := Aircraft.create(load(FIGHTER), true)
	a.nation_id = nation
	world.add_child(a)
	a.place_on_ground(world.runway_spawn(), TestWorld.RUNWAY_DIR)
	a.set_physics_process(false)
	return a


func _angle(v: AircraftVisual, part: String) -> float:
	var e: Dictionary = v.rig_parts[part]
	var rel: Basis = (e.rest as Transform3D).basis.inverse() * (e.node as Node3D).transform.basis
	var r: Array = AircraftVisual.RIG[part]
	var q := rel.get_rotation_quaternion()
	return rad_to_deg(q.get_angle()) * signf(q.get_axis().dot(r[0]))


func test_rig_model_loaded() -> Array:
	var a := _visual_ac()
	var r := _visual_ac(Nations.RED)
	var v := a.visual
	var ok := v.using_rig and v.rig_parts.size() >= 16 and r.visual.using_rig and v.fx != null
	return [ok, "Spielmodell geladen=%s, %d Rig-Teile, Gegner-Variante=%s" % [v.using_rig, v.rig_parts.size(), r.visual.using_rig]]


func test_rig_controls_animate() -> Array:
	var a := _visual_ac()
	var v := a.visual
	var t := a.flight.telemetry
	t.commands.aileron = 1.0
	t.commands.elevator = 1.0
	t.commands.rudder = 1.0
	t.commands.flaps = 1.0
	t.gear_extension = 0.0
	t.throttle_actual = 1.0
	v.update_controls(t, 0.1)
	var al := _angle(v, "aileron_L")
	var ar := _angle(v, "aileron_R")
	var el := _angle(v, "elevator")
	var ru := _angle(v, "rudder")
	var fl := _angle(v, "flap_L")
	var g := _angle(v, "gear_main_L")
	var disc: bool = v.rig_parts.prop_disc.node.visible
	var ok := absf(al - 15.0) < 0.1 and absf(ar + 20.0) < 0.1 and absf(el + 25.0) < 0.1 \
		and absf(ru - 25.0) < 0.1 and absf(fl - 40.0) < 0.1 and absf(g - 80.88) < 0.1 and disc
	# klemmendes Höhenruder wird sichtbar
	for i in a.data.surfaces.size():
		if a.data.surfaces[i].name.begins_with("htail"):
			a.flight.modifiers.set_stuck(i, 0.0)
	v.update_controls(t, 0.1)
	var el_stuck := _angle(v, "elevator")
	ok = ok and absf(el_stuck) < 0.1
	return [ok, "Querruder L %.0f° / R %.0f°, Höhenruder %.0f° (klemmt: %.0f°), Seitenruder %.0f°, Klappe %.0f°, Fahrwerk %.1f°, Propellerscheibe %s" % [al, ar, el, el_stuck, ru, fl, g, disc]]


func test_damage_fx_follow_state() -> Array:
	var a := _visual_ac()
	var fx := a.visual.fx
	await _step(1)
	var idle := fx.active_count()
	a.damage.apply_hit(DamageModel.Zone.ENGINE, 50.0, null)
	a.damage.apply_hit(DamageModel.Zone.FUEL_R, 30.0, null)
	a.damage.start_fire(DamageModel.Zone.FUEL_L)
	a.damage.tick(0.1)
	await _step(2)
	var oil := fx.oil.emitting
	var fire: bool = fx.fire[DamageModel.Zone.FUEL_L].smoke.emitting and fx.fire[DamageModel.Zone.FUEL_L].flame.emitting
	var leak: bool = fx.leak[DamageModel.Zone.FUEL_R].emitting
	a.place_on_ground(world.runway_spawn(), TestWorld.RUNWAY_DIR)
	await _step(2)
	var ok := idle == 0 and oil and fire and leak and fx.active_count() == 0
	return [ok, "intakt %d Emitter, Öl %s, Brand %s, Leck %s, nach Neustart %d" % [idle, oil, fire, leak, fx.active_count()]]
