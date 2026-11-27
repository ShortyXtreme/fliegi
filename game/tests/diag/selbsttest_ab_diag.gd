extends SceneTree
## Prüfung Waffen (Audit): Warum trifft der Spieler im Selbsttest A (Gegner 250 m vorn) seltener
## als der Gegner in B? Wiederholt A mit dem echten PlayerController und protokolliert die Lage
## des Ziels im Schützensystem sowie die Ablage der Geschosse in der Zielebene.
## Aufruf: godot --headless --path . --fixed-fps 60 --script res://tests/diag/selbsttest_ab_diag.gd -- [--b] [--gerade]

class StraightPilot extends Controller:
	var fire := false
	func compute_intent(_dt: float) -> PilotIntent:
		var i := PilotIntent.new()
		i.throttle = 0.9
		i.gear_down = false
		i.fire_primary = fire
		return i

var _miss: Array = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase_b := "--b" in args
	var straight := "--gerade" in args
	var g: Game = load("res://world/main.tscn").instantiate()
	root.add_child(g)
	for i in 30:
		await physics_frame
	var pl: Aircraft = g.player_aircraft
	var en: Aircraft = g.ai_aircrafts[0]
	var ep := StraightPilot.new()
	g.add_child(ep)
	en.pilot_seat.possess(ep)
	var pp: StraightPilot = null
	if straight:
		pp = StraightPilot.new()
		g.add_child(pp)
		pl.pilot_seat.possess(pp)
	var dir := Vector3(0, 0, -1)
	var b := Basis.looking_at(dir, Vector3.UP)
	var base := pl.global_position
	base.y = WorldGround.height_at(base.x, base.z) + 1500.0
	for k in range(1, g.ai_aircrafts.size()):
		g.ai_aircrafts[k].place(Transform3D(b, base + Vector3(3000.0 + k * 400.0, 500.0, 0)), 110.0, 0.9, false)
	pl.damage.reset()
	en.damage.reset()
	var shooter := pl
	var target := en
	if phase_b:
		pl.place(Transform3D(b, base), 110.0, 0.9, false)
		en.place(Transform3D(b, base - dir * 250.0), 110.0, 0.9, false)
		ep.fire = true
		shooter = en
		target = pl
	else:
		pl.place(Transform3D(b, base), 110.0, 0.9, false)
		en.place(Transform3D(b, base + dir * 250.0), 110.0, 0.9, false)
		if not straight:
			g.player.reset_state(0.9, false)
			Input.action_press("fire_primary")
		else:
			pp.fire = true
	var hits := [0]
	g.projectiles.hit_resolved.connect(func(sh, tg, z, _d, _wp, _lp, _r):
		if sh == shooter: hits[0] += 1)
	for f in 180:
		await physics_frame
		if f % 20 == 0:
			var lx := shooter.global_transform.affine_inverse() * target.global_position
			var t := shooter.telemetry()
			print("t=%.2f Ziel lokal (%.2f, %.2f, %.1f) Schütze AoA %.2f° Nick %.2f° Ziel-Nick %.2f° Δh %.2f m v %.0f/%.0f Treffer %d" % [f / 60.0,
				lx.x, lx.y, lx.z, rad_to_deg(t.aoa), rad_to_deg(shooter.global_rotation.x),
				rad_to_deg(target.global_rotation.x), target.global_position.y - shooter.global_position.y,
				shooter.linear_velocity.length(), target.linear_velocity.length(), hits[0]])
	Input.action_release("fire_primary")
	print("Treffer %d (Phase %s, %s)" % [hits[0], "B" if phase_b else "A", "gerade" if straight else "PlayerController"])
	quit(0)
