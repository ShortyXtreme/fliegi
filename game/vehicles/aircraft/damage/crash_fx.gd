class_name CrashFx
extends Node3D
## M3.5: Aufschlagstelle eines abgestürzten Flugzeugs: Explosion (Feuerball, Blitz, Erdbrocken),
## Krater-Decal und Rauchsäule; Ton „explosion“ + „crash“ (SoundDirector). Bleibt lifetime
## Sekunden, dann verschwindet sie (Rauch klingt vorher aus). Höchstens MAX_ACTIVE Stellen.
## Headless nur der Knoten (Zählung/Lebensdauer), keine Effekte.

const MAX_ACTIVE := 8
const DEFAULT_LIFE := 75.0
static var active: Array = []
static var _crater_tex: GradientTexture2D

var lifetime := DEFAULT_LIFE
var age := 0.0
var _column: GPUParticles3D
var _flash: OmniLight3D
var _fire_snd: AudioStreamPlayer3D


## Aufschlag bei pos (Weltkoordinaten). burning: Rauchsäule schwarz + Brand länger.
static func impact(parent: Node, pos: Vector3, burning := true, life := DEFAULT_LIFE) -> CrashFx:
	if parent == null:
		return null
	var c := CrashFx.new()
	c.name = "CrashSite"
	c.lifetime = life
	parent.add_child(c)
	var g := WorldGround.height_at(pos.x, pos.z)
	c.global_position = Vector3(pos.x, g if absf(pos.y - g) < 8.0 else pos.y, pos.z)
	if DisplayServer.get_name() != "headless":
		c._build(burning)
	var sd := SoundDirector.instance if SoundDirector.instance != null and is_instance_valid(SoundDirector.instance) else null
	if sd != null:
		sd.play_3d("explosion", pos, "Waffen", 6.0, randf_range(0.7, 0.85), 60.0)
		sd.play_3d("crash", pos, "Motor", 2.0, 0.8, 30.0)
	active.append(c)
	active = active.filter(func(x): return is_instance_valid(x) and not x.is_queued_for_deletion())
	while active.size() > MAX_ACTIVE:
		var old: CrashFx = active.pop_front()
		old.queue_free()
	return c


func _exit_tree() -> void:
	active.erase(self)


func _build(burning: bool) -> void:
	# Krater (dunkler verbrannter Fleck, auf den Boden projiziert)
	var dec := Decal.new()
	dec.size = Vector3(14.0, 6.0, 14.0)
	dec.texture_albedo = _crater()
	dec.modulate = Color(0.16, 0.12, 0.09)
	dec.albedo_mix = 0.95
	dec.position = Vector3(0, 1.0, 0)
	dec.rotation.y = randf() * TAU
	add_child(dec)
	# Feuerball + Erdbrocken (einmalig)
	var ball := DamageFx._particles(48, 1.1, Color(1.0, 0.55, 0.15, 1.0), 4.5, Vector2(6.0, 16.0),
		Vector3(0, 3.0, 0), 3.0, true)
	(ball.process_material as ParticleProcessMaterial).spread = 80.0
	ball.one_shot = true
	ball.explosiveness = 0.9
	ball.emitting = true
	add_child(ball)
	ball.position = Vector3(0, 1.5, 0)
	var dirt := DamageFx._particles(40, 2.2, Color(0.22, 0.17, 0.12, 1.0), 1.1, Vector2(10.0, 22.0),
		Vector3(0, -9.8, 0), 1.6)
	(dirt.process_material as ParticleProcessMaterial).spread = 60.0
	dirt.one_shot = true
	dirt.explosiveness = 0.95
	dirt.emitting = true
	add_child(dirt)
	dirt.position = Vector3(0, 0.5, 0)
	_flash = OmniLight3D.new()
	_flash.light_color = Color(1.0, 0.6, 0.25)
	_flash.light_energy = 12.0
	_flash.omni_range = 60.0
	_flash.position = Vector3(0, 4, 0)
	add_child(_flash)
	# Rauchsäule (lang, steigt hoch)
	var col := Color(0.04, 0.04, 0.04, 0.8) if burning else Color(0.3, 0.29, 0.27, 0.6)
	_column = DamageFx._particles(120, 9.0, col, 5.0, Vector2(2.0, 4.0), Vector3(0.6, 2.2, 0.0), 4.0)
	(_column.process_material as ParticleProcessMaterial).spread = 12.0
	_column.emitting = true
	add_child(_column)
	_column.position = Vector3(0, 1.0, 0)
	if burning:
		var fl := DamageFx.make_flame()
		fl.emitting = true
		fl.amount = 48
		fl.name = "Flame"
		add_child(fl)
		fl.position = Vector3(0, 0.8, 0)
		var s := GameAudio.stream("fire")
		if s != null:
			_fire_snd = AudioStreamPlayer3D.new()
			_fire_snd.stream = s
			_fire_snd.bus = "Waffen"
			_fire_snd.unit_size = 10.0
			_fire_snd.max_distance = 300.0
			_fire_snd.volume_db = -2.0
			add_child(_fire_snd)
			_fire_snd.play()


static func _crater() -> GradientTexture2D:
	if _crater_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1.0))
		g.set_color(1, Color(1, 1, 1, 0.0))
		g.add_point(0.45, Color(1, 1, 1, 0.85))
		_crater_tex = GradientTexture2D.new()
		_crater_tex.gradient = g
		_crater_tex.fill = GradientTexture2D.FILL_RADIAL
		_crater_tex.fill_from = Vector2(0.5, 0.5)
		_crater_tex.fill_to = Vector2(1.0, 0.5)
		_crater_tex.width = 128
		_crater_tex.height = 128
	return _crater_tex


func _process(dt: float) -> void:
	age += dt
	if _flash != null:
		_flash.light_energy = maxf(0.0, 12.0 * (1.0 - age / 0.8))
		if age > 0.8:
			_flash.queue_free()
			_flash = null
	if _column != null:
		# Säule nach 2/3 der Zeit ausklingen lassen, Flammen nach 30 s
		_column.emitting = age < lifetime * 0.66
		var fl := get_node_or_null("Flame") as GPUParticles3D
		if fl != null:
			fl.emitting = age < 30.0
		if _fire_snd != null and age > 30.0:
			_fire_snd.queue_free()
			_fire_snd = null
	if age >= lifetime:
		queue_free()
