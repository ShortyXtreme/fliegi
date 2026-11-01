class_name HitSound
extends Node
## M2.1: prozeduraler Treffer-Ton. Eigener Treffer: kurzes helles „Tick“.
## Getroffen werden: dumpfer Schlag (Rauschen + tiefer Ton). Headless stumm, zählt aber mit.

const RATE := 22050.0

var own: Node
var own_hits := 0
var received_hits := 0

var _player: AudioStreamPlayer
var _gen: AudioStreamGeneratorPlayback
var _tick_env := 0.0
var _thud_env := 0.0
var _ph := 0.0
var _lp := 0.0
var _bus: CombatEvents


func _ready() -> void:
	name = "HitSound"
	if DisplayServer.get_name() == "headless":
		return
	var g := AudioStreamGenerator.new()
	g.mix_rate = RATE
	g.buffer_length = 0.08
	_player = AudioStreamPlayer.new()
	_player.stream = g
	_player.volume_db = -6.0
	add_child(_player)
	_player.play()
	_gen = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _connect() -> void:
	var b := CombatEvents.bus()
	if b != _bus:
		_bus = b
		b.hit_confirmed.connect(on_hit)


func on_hit(shooter: Node, target: Node, _zone: int, damage: float) -> void:
	if own == null or not is_instance_valid(own):
		return
	if shooter == own and target != own:
		own_hits += 1
		_tick_env = 1.0
	elif target == own and damage > 0.0:
		received_hits += 1
		_thud_env = 1.0


func _process(_dt: float) -> void:
	_connect()
	if _gen == null:
		return
	var n := _gen.get_frames_available()
	for k in n:
		_ph += 1.0 / RATE
		_lp = lerpf(_lp, randf_range(-1.0, 1.0), 0.08)
		var s := sin(_ph * TAU * 1900.0) * _tick_env * 0.32 \
				+ (sin(_ph * TAU * 95.0) * 0.6 + _lp * 1.8) * _thud_env * 0.45
		_tick_env *= 0.9968   # ≈ 15 ms Abfall
		_thud_env *= 0.9985   # ≈ 30 ms
		_gen.push_frame(Vector2(s, s))
