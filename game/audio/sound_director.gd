class_name SoundDirector
extends Node
## M3.3: verteilt alle Spielgeräusche. Hängt sich an neu entstehende Knoten (Flugzeuge, Wagen,
## Figuren, Tragegegenstände, Tutorial) und an die Ereignis-Busse (CombatEvents, GroundEvents).
## Welt-Geräusche als AudioStreamPlayer3D (Doppler über die Kamera), UI/Alarm als 2D.
## Stimmenbegrenzung: Einmal-Klänge aus festen Pools (POOL_3D/POOL_2D, ältester wird ersetzt),
## Dauerklänge entfernter Quellen werden angehalten (CULL_*).

const POOL_3D := 12
const POOL_2D := 6
const CULL_AIRCRAFT := 3500.0
const CULL_GROUND := 120.0
const STEP_LEN := 0.8           # m je Schritt (Gehen)

static var instance: SoundDirector

## Spieler-Flugzeug (Treffer am eigenen Flugzeug = 2D).
var player: Node3D
var cam: Camera3D
var aircraft := {}              # Aircraft -> AircraftSound
var vehicles := {}              # GroundVehicle -> AudioStreamPlayer3D
var walkers := {}               # CrewCharacter -> [letzte Pos, Weg]
var activity := {}              # "id|step" -> [AudioStreamPlayer3D, Restzeit]
var _seen_steps := {}
var _pool3: Array[AudioStreamPlayer3D] = []
var _pool2: Array[AudioStreamPlayer] = []
var _i3 := 0
var _i2 := 0
var _ambient: AudioStreamPlayer
var _siren: AudioStreamPlayer
var _siren_t := 0.0
var _cbus: CombatEvents
var _gbus: GroundEvents
## Zähler (Tests/Diagnose): Klangname -> Anzahl gespielt
var played := {}


func _enter_tree() -> void:
	name = "SoundDirector"
	instance = self
	GameAudio.setup()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
		p.unit_size = 14.0
		p.max_distance = 2500.0
		add_child(p)
		_pool3.append(p)
	for k in POOL_2D:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool2.append(p)
	_ambient = _loop2d("ambient", "Umgebung", -14.0)
	_siren = _loop2d("siren", "Umgebung", -6.0)
	get_tree().node_added.connect(_on_node_added)
	for n in get_tree().root.find_children("*", "", true, false):
		_on_node_added(n)


func _loop2d(n: String, bus: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = GameAudio.stream(n)
	p.bus = bus
	p.volume_db = db
	add_child(p)
	return p


## Einmal-Klang ohne Position.
func play_2d(n: String, bus: String, db := 0.0, pitch := 1.0) -> void:
	played[n] = int(played.get(n, 0)) + 1
	var s := GameAudio.stream(n)
	if s == null:
		return
	var p := _pool2[_i2]
	_i2 = (_i2 + 1) % _pool2.size()
	p.stream = s
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pitch
	p.play()


## Einmal-Klang an einer Weltposition (älteste Stimme wird ersetzt).
func play_3d(n: String, pos: Vector3, bus: String, db := 0.0, pitch := 1.0, unit := 14.0) -> void:
	played[n] = int(played.get(n, 0)) + 1
	var s := GameAudio.stream(n)
	if s == null:
		return
	if cam != null and cam.global_position.distance_to(pos) > 3000.0:
		return
	var p := _pool3[_i3]
	_i3 = (_i3 + 1) % _pool3.size()
	p.stream = s
	p.bus = bus
	p.volume_db = db
	p.pitch_scale = pitch
	p.unit_size = unit
	p.global_position = pos
	p.play()


func voices() -> int:
	var n := 0
	for p in _pool3:
		n += 1 if p.playing else 0
	for p in _pool2:
		n += 1 if p.playing else 0
	return n


# --- Anhängen ----------------------------------------------------------------------------

func _on_node_added(n: Node) -> void:
	if n is Aircraft:
		if not aircraft.has(n):
			var s := AircraftSound.new()
			s.aircraft = n
			s.director = self
			aircraft[n] = s
			n.add_child.call_deferred(s)
	elif n is GroundVehicle:
		if not vehicles.has(n):
			var p := _make_loop3d("truck_idle", "Umgebung", -6.0)
			vehicles[n] = p
			n.add_child.call_deferred(p)
	elif n is CrewCharacter:
		walkers[n] = [Vector3.INF, 0.0]
	elif n is CarryItem:
		var it := n as CarryItem
		it.picked_up.connect(func(_c): play_3d("crate_up", _pos(it), "Umgebung", -4.0, randf_range(0.9, 1.1), 6.0))
		it.dropped.connect(func(_c): play_3d("crate_down", _pos(it), "Umgebung", -2.0, randf_range(0.9, 1.1), 6.0))
	elif n is Tutorial:
		var t := n as Tutorial
		t.step_changed.connect(func(i): if i > 0: play_2d("ui_step", "UI", -4.0))
		t.finished.connect(func(ok): if ok: play_2d("ui_step", "UI", -2.0, 1.12))


func _make_loop3d(n: String, bus: String, db: float, unit := 10.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = GameAudio.stream(n)
	p.bus = bus
	p.volume_db = db
	p.unit_size = unit
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	p.max_distance = 400.0
	return p


static func _pos(n: Node) -> Vector3:
	return (n as Node3D).global_position if n is Node3D and n.is_inside_tree() else Vector3.ZERO


func _connect_buses() -> void:
	var cb := CombatEvents.bus()
	if cb != _cbus:
		_cbus = cb
		cb.shot_fired.connect(_on_shot)
		cb.hit_confirmed.connect(_on_hit)
		cb.aircraft_destroyed.connect(func(v, _k, _c): play_3d("explosion", _pos(v), "Waffen", 4.0, randf_range(0.85, 1.05), 40.0))
		cb.pilot_ejected.connect(func(a, _p): play_3d("eject", _pos(a), "Waffen", 0.0, 1.0, 20.0))
	var gb := GroundEvents.bus()
	if gb != _gbus:
		_gbus = gb
		gb.job_progress.connect(_on_job_progress)
		gb.seat_changed.connect(_on_seat_changed)
		gb.alarm_started.connect(func(sec):
			_siren_t = maxf(sec, 8.0)
			played["siren"] = int(played.get("siren", 0)) + 1
			if _siren.stream != null and not _siren.playing:
				_siren.play())
		gb.alarm_ended.connect(func(_ok): _siren_t = minf(_siren_t, 1.5))


func _on_shot(shooter: Node, _g: int, _id: int) -> void:
	var s: AircraftSound = aircraft.get(shooter)
	if s != null:
		s.last_shot = Time.get_ticks_msec()


func _on_hit(shooter: Node, target: Node, _zone: int, damage: float) -> void:
	if target == player and damage > 0.0:
		play_2d("hit_own", "Waffen", -2.0, randf_range(0.9, 1.1))
	elif shooter == player and target != player:
		play_3d("hit_enemy", _pos(target), "Waffen", 2.0, randf_range(0.9, 1.15), 60.0)


func _on_seat_changed(_peer: int, from_seat: Seat, to_seat: Seat) -> void:
	var s := to_seat if to_seat != null else from_seat
	if s != null and s.get_parent() is Node3D:
		play_3d("enter", _pos(s.get_parent()), "Umgebung", -3.0, randf_range(0.9, 1.1), 6.0)


const STEP_LOOPS := {&"pump": "pump", &"repair": "tool"}
const STEP_SHOTS := {&"hatch_open": "hatch", &"hatch_close": "hatch", &"attach": "hatch", &"detach": "hatch",
	&"ground": "hatch", &"charge": "hatch", &"crate": "crate_down", &"belt": "belt"}


func _on_job_progress(job_id: int, step: StringName, _progress: float, worker: Node) -> void:
	if not (worker is Node3D) or not worker.is_inside_tree():
		return
	var pos := _pos(worker)
	var key := "%d|%s" % [job_id, step]
	if STEP_LOOPS.has(step):
		var a: Array = activity.get(key, [])
		if a.is_empty():
			var p := _make_loop3d(STEP_LOOPS[step], "Umgebung", -4.0, 6.0)
			add_child(p)
			p.global_position = pos
			if p.stream != null:
				p.play()
			played[STEP_LOOPS[step]] = int(played.get(STEP_LOOPS[step], 0)) + 1
			a = [p, 0.0]
			activity[key] = a
		a[1] = 0.4
		(a[0] as Node3D).global_position = pos
	elif STEP_SHOTS.has(step) and not _seen_steps.has(key):
		_seen_steps[key] = true
		play_3d(STEP_SHOTS[step], pos, "Umgebung", -2.0, randf_range(0.92, 1.08), 6.0)


# --- Laufend -----------------------------------------------------------------------------

func _process(dt: float) -> void:
	_connect_buses()
	cam = get_viewport().get_camera_3d()
	if cam != null:
		cam.doppler_tracking = Camera3D.DOPPLER_TRACKING_PHYSICS_STEP
	var rig := cam.get_parent() as CameraRig if cam != null else null
	GameAudio.set_cockpit(rig != null and rig.mode == CameraRig.Mode.COCKPIT)
	_update_ambient()
	_update_vehicles()
	_update_steps()
	for k in activity.keys():
		var a: Array = activity[k]
		a[1] -= dt
		if a[1] <= 0.0:
			(a[0] as Node).queue_free()
			activity.erase(k)
	if _siren_t > 0.0:
		_siren_t -= dt
		_siren.volume_db = -6.0 + linear_to_db(clampf(_siren_t / 1.5, 0.001, 1.0))
		if _siren_t <= 0.0:
			_siren.stop()
	for a in aircraft.keys():
		if not is_instance_valid(a):
			aircraft.erase(a)


func _update_ambient() -> void:
	if _ambient.stream == null:
		return
	var agl := 0.0
	if cam != null:
		var p := cam.global_position
		agl = p.y - WorldGround.height_at(p.x, p.z)
	var v := clampf(1.0 - (agl - 20.0) / 200.0, 0.0, 1.0)
	if v <= 0.01:
		if _ambient.playing:
			_ambient.stop()
		return
	_ambient.volume_db = -14.0 + linear_to_db(v)
	if not _ambient.playing:
		_ambient.play()


func _update_vehicles() -> void:
	for v in vehicles.keys():
		if not is_instance_valid(v):
			vehicles.erase(v)
			continue
		var p: AudioStreamPlayer3D = vehicles[v]
		var gv := v as GroundVehicle
		var on := p.stream != null and gv.driver_seat != null and (gv.driver_seat.controller != null \
				or absf(gv.speed) > 0.2) and (cam == null or cam.global_position.distance_to(gv.global_position) < CULL_GROUND)
		if on != p.playing:
			if on:
				p.play()
			else:
				p.stop()
		if on:
			p.pitch_scale = 0.85 + clampf(absf(gv.speed) / 12.0, 0.0, 0.7)


func _update_steps() -> void:
	for w in walkers.keys():
		if not is_instance_valid(w):
			walkers.erase(w)
			continue
		var c := w as CrewCharacter
		if not c.is_inside_tree() or not c.visible or c.in_seat != null:
			walkers[w] = [Vector3.INF, 0.0]
			continue
		var p := c.global_position
		var st: Array = walkers[w]
		if st[0] != Vector3.INF and c.is_on_floor():
			var d := Vector2(p.x - st[0].x, p.z - st[0].z).length()
			if d < 2.0:
				st[1] += d
		st[0] = p
		if st[1] >= STEP_LEN:
			st[1] = 0.0
			if cam == null or cam.global_position.distance_to(p) < 40.0:
				play_3d("step_grass", p, "Umgebung", -8.0, randf_range(0.85, 1.15), 4.0)
