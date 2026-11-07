class_name AircraftSound
extends Node3D
## M3.3: Geräusche eines Flugzeugs (Kind des Aircraft, 3D mit Doppler): Motor-Loop (Pitch/
## Lautstärke aus Gas und Fahrt; Blau Sternmotor, Gegner Reihenmotor), Fahrtwind, MG-Feuer
## (solange Schüsse kommen), Fahrwerk, Klappen, Aufsetzen, Bauchlandung, Brand.
## Entfernte Flugzeuge (> SoundDirector.CULL_AIRCRAFT) werden angehalten.

var aircraft: Aircraft
var director: SoundDirector
var last_shot := -100000
var engine: AudioStreamPlayer3D
var wind: AudioStreamPlayer3D
var mg: AudioStreamPlayer3D
var fire: AudioStreamPlayer3D
## Zustand für Ereignis-Erkennung
var _gear_cmd = null
var _flaps := -1.0
var _wheels := -1
var _belly := false
var _air_t := 0.0
## Aktueller Drehzahl-Anteil 0..1 (Tests)
var rpm := 0.0


func _ready() -> void:
	name = "Sound"
	var enemy := aircraft.nation_id != Nations.BLUE
	engine = _loop("engine_inline" if enemy else "engine_radial", "Motor", 30.0)
	wind = _loop("wind", "Motor", 12.0)
	mg = _loop("mg_loop", "Waffen", 30.0)
	fire = _loop("fire", "Waffen", 10.0)


func _loop(n: String, bus: String, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = GameAudio.stream(n)
	p.bus = bus
	p.unit_size = unit
	p.max_distance = SoundDirector.CULL_AIRCRAFT
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	add_child(p)
	return p


static func _run(p: AudioStreamPlayer3D, on: bool) -> void:
	if p.stream == null:
		return
	if on and not p.playing:
		p.play(randf() * 0.5)
	elif not on and p.playing:
		p.stop()


func _physics_process(dt: float) -> void:
	if aircraft == null or not is_instance_valid(aircraft) or aircraft.flight == null:
		return
	var t := aircraft.flight.telemetry
	var cam := director.cam if director != null else null
	var far := cam != null and cam.global_position.distance_to(aircraft.global_position) > SoundDirector.CULL_AIRCRAFT
	var dead := aircraft.damage != null and (aircraft.damage.is_destroyed or aircraft.damage.engine_dead)
	# Motor: Leerlauf 0,55 … Vollgas 1,6 (Fahrtwind treibt den Propeller mit)
	rpm = clampf(0.25 + 0.6 * t.throttle_actual + 0.15 * clampf(t.airspeed / 120.0, 0.0, 1.0), 0.0, 1.0)
	_run(engine, not far and not dead)
	engine.pitch_scale = lerpf(0.55, 1.6, rpm)
	engine.volume_db = lerpf(-10.0, 2.0, rpm)
	# Fahrtwind
	var w := clampf((t.airspeed - 12.0) / 110.0, 0.0, 1.0)
	_run(wind, not far and w > 0.02)
	wind.volume_db = linear_to_db(maxf(w, 0.001)) - 2.0
	wind.pitch_scale = 0.7 + 0.7 * w
	# MG: solange in den letzten 120 ms geschossen wurde
	_run(mg, not far and Time.get_ticks_msec() - last_shot < 120)
	# Brand
	_run(fire, not far and aircraft.damage != null and aircraft.damage.is_burning())
	if far:
		return
	var pos := aircraft.global_position
	# Fahrwerk / Klappen (Kommando-Wechsel)
	if _gear_cmd != null and _gear_cmd != t.gear_down_cmd and not t.gear_blocked:
		director.play_3d("gear", pos, "Motor", -4.0, 1.0, 8.0)
	_gear_cmd = t.gear_down_cmd
	var fl := t.commands.flaps
	if _flaps >= 0.0 and absf(fl - _flaps) > 0.05:
		director.play_3d("flaps", pos, "Motor", -6.0, 1.0, 8.0)
	_flaps = fl
	# Aufsetzen (nach mindestens 0,5 s in der Luft) und Bauchlandung
	if t.wheels_in_contact == 0:
		_air_t += dt
	if _wheels == 0 and t.wheels_in_contact > 0 and _air_t > 0.5:
		var hard := clampf(-t.climb_rate / 4.0, 0.2, 1.0)
		director.play_3d("touchdown", pos, "Motor", linear_to_db(hard), 1.0, 10.0)
	if t.wheels_in_contact > 0:
		_air_t = 0.0
	_wheels = t.wheels_in_contact
	if t.belly_contact and not _belly and t.airspeed > 8.0:
		director.play_3d("crash", pos, "Motor", 0.0, 1.0, 14.0)
	_belly = t.belly_contact
