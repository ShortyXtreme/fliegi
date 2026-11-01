extends TestSuite
## Waffen-Effekte (Paket 10): headless aus, Pools begrenzt, Leuchtspuren aus der Lese-Schnittstelle.

var _fx: WeaponFx


func after_each() -> void:
	if _fx and is_instance_valid(_fx):
		_fx.queue_free()
	_fx = null


func _make_fx(build := true) -> WeaponFx:
	_fx = WeaponFx.new()
	_fx.projectiles = projectiles
	world.add_child(_fx)
	if build:
		_fx.build()
	return _fx


func test_headless_disabled() -> Array:
	var fx := _make_fx(false)
	await _step(2)
	var ok := not fx.enabled and not fx.is_processing() and fx.get_child_count() == 0
	return [ok, "enabled %s, process %s, Kinder %d" % [fx.enabled, fx.is_processing(), fx.get_child_count()]]


func test_tracers_from_read_interface() -> Array:
	var fx := _make_fx()
	var w: WeaponDef = load("res://weapons/data/mg_t1.tres")
	var shooter := Node3D.new()
	world.add_child(shooter)
	for i in 50:
		projectiles.spawn(shooter, 0, i, Vector3(0, 500, -i), Vector3(0, 0, -800), w)
	fx.update_tracers()
	var want := projectiles.tracer_slots().size()
	var first := fx.tracer_count
	var nodes_before := fx.get_child_count()
	for i in 200:
		projectiles.spawn(shooter, 0, 50 + i, Vector3(0, 500, -i), Vector3(0, 0, -800), w)
	fx.update_tracers()
	var ok := want == 10 and first == want \
		and fx.tracers.multimesh.visible_instance_count == fx.tracer_count \
		and fx.tracer_count == projectiles.tracer_slots().size() and fx.get_child_count() == nodes_before
	shooter.free()
	return [ok, "Spuren %d (erwartet %d), danach %d, Knoten konstant %d" % [want, 10,
		fx.tracer_count, nodes_before]]


func test_tracer_transform() -> Array:
	var xf := WeaponFx.tracer_transform(Vector3(1, 2, 3), Vector3(0, 0, -800), 1.0)
	var fresh := WeaponFx.tracer_transform(Vector3.ZERO, Vector3(0, 0, -800), 0.0)
	var z := xf.basis.z
	var ok := xf.origin == Vector3(1, 2, 3) and absf(z.length() - 32.0) < 0.01 and z.z > 0.0 \
		and absf(xf.basis.x.dot(z)) < 1e-4 and fresh.basis.z.length() <= 1.01
	return [ok, "Länge %.1f m (frisch %.1f m), Richtung %s" % [z.length(), fresh.basis.z.length(), z.normalized()]]


func test_muzzle_light_pool() -> Array:
	var fx := _make_fx()
	var a := _spawn(false, 600.0, 80.0, 0.7)
	await _step(1)
	for i in 30:
		fx.on_shot_fired(a, i % 2, i)
	fx._update_flashes(0.01)
	var lit := fx.active_lights()
	for k in 4:
		fx._update_flashes(0.1)
	var after := fx.active_lights()
	var ok := fx.lights.size() == WeaponFx.MAX_LIGHTS and lit == WeaponFx.MAX_LIGHTS and after == 0 \
		and fx.flashes_started == 30
	return [ok, "Lichter %d/%d aktiv, danach %d" % [lit, fx.lights.size(), after]]


func test_impact_pools() -> Array:
	var fx := _make_fx()
	var a := _spawn(false, 600.0, 80.0, 0.7)
	var nodes := fx.get_child_count()
	for i in 40:
		fx.on_impact(0, a.global_position, Vector3(0, 0, -700), ProjectileSystem.Impact.TARGET, a, 0)
		fx.on_impact(0, Vector3(i, 0, 0), Vector3(0, -50, -700), ProjectileSystem.Impact.GROUND, null, -1)
	fx.on_impact(0, Vector3.ZERO, Vector3.ZERO, ProjectileSystem.Impact.EXPIRED, null, -1)
	var ok := fx.impacts_started == 80 and fx.get_child_count() == nodes \
		and fx.sparks.size() == WeaponFx.SPARK_POOL and fx.dust.size() == WeaponFx.DUST_POOL
	return [ok, "Einschläge %d, Knoten konstant %d" % [fx.impacts_started, nodes]]


func test_signals_connected() -> Array:
	var fx := _make_fx()
	fx._connect_sources()
	var a := _spawn(false, 600.0, 80.0, 0.7)
	CombatEvents.bus().shot_fired.emit(a, 0, 1)
	projectiles.impact.emit(0, Vector3.ZERO, Vector3(0, -1, 0), ProjectileSystem.Impact.GROUND, null, -1)
	return [fx.flashes_started == 1 and fx.impacts_started == 1,
		"Blitze %d, Einschläge %d" % [fx.flashes_started, fx.impacts_started]]
