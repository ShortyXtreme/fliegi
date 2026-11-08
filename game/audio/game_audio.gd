class_name GameAudio
extends RefCounted
## M3.3: Audio-Grundlage. Busse Master/Motor/Waffen/Umgebung/UI (zur Laufzeit angelegt),
## Lautstärken aus GameSettings ([audio] in user://flugkern.cfg), Klänge aus res://assets/audio
## (prozedural erzeugt, tools/gen_audio.py). Fehlen die Klänge (Audio-Paket nicht geladen),
## bleibt das Spiel stumm, läuft aber weiter. Headless: Master stumm.
## Cockpit-Ansicht: Tiefpass auf Motor/Waffen (set_cockpit).

const DIR := "res://assets/audio/%s.ogg"
const BUSES := ["Motor", "Waffen", "Umgebung", "UI"]
## Klang -> Loop?
const SOUNDS := {
	"wind": true, "gear": false, "flaps": false,
	"touchdown": false, "crash": false, "mg_loop": true, "hit_own": false, "hit_enemy": false,
	"explosion": false, "fire": true, "eject": false, "step_grass": false, "truck_idle": true,
	"pump": true, "crate_down": false, "crate_up": false, "hatch": false, "belt": false,
	"tool": true, "enter": false, "alarm_siren": true, "alarm_bell": true, "ambient": true, "ui_click": false,
	"ui_confirm": false, "ui_step": false,
}

## Motor-Klänge je Typ (AircraftData.engine_sound): Drehzahl-Layer als Loops in
## res://assets/audio/engines/<typ>/<layer>.ogg – austauschbar gegen Aufnahmen (gleiche Namen;
## die Bezugsdrehzahl des Layers steht in ENGINE_RPM). Fehlende Layer werden übersprungen.
const ENGINE_DIR := "res://assets/audio/engines/%s/%s.ogg"
const ENGINE_LAYERS := ["idle", "mid", "full"]
const ENGINE_RPM := {"v12": [850.0, 1800.0, 2750.0], "radial": [700.0, 1550.0, 2450.0]}
## Alarmton-Einstellung -> Klang
const ALARM := {"sirene": "alarm_siren", "glocke": "alarm_bell"}

static var _streams := {}
static var _engines := {}
static var _ready := false
static var cockpit := false


static func setup() -> void:
	if _ready:
		return
	_ready = true
	for b in BUSES:
		if AudioServer.get_bus_index(b) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, &"Master")
	for b in ["Motor", "Waffen"]:
		var lpf := AudioEffectLowPassFilter.new()
		lpf.cutoff_hz = 1600.0
		AudioServer.add_bus_effect(AudioServer.get_bus_index(b), lpf)
		AudioServer.set_bus_effect_enabled(AudioServer.get_bus_index(b), 0, false)
	for k in SOUNDS:
		var p := DIR % k
		if ResourceLoader.exists(p):
			var s := load(p) as AudioStreamOggVorbis
			if s != null:
				s.loop = SOUNDS[k]
				_streams[k] = s
	for typ in ENGINE_RPM:
		var layers := []
		for i in ENGINE_LAYERS.size():
			var p := ENGINE_DIR % [typ, ENGINE_LAYERS[i]]
			var s := load(p) as AudioStreamOggVorbis if ResourceLoader.exists(p) else null
			if s != null:
				s.loop = true
				layers.append([s, float(ENGINE_RPM[typ][i])])
		_engines[typ] = layers
	apply_volumes()


static func is_headless() -> bool:
	return DisplayServer.get_name() == "headless"


static func stream(n: String) -> AudioStream:
	return _streams.get(n)


## Drehzahl-Layer eines Motortyps: [[stream, bezugsdrehzahl], …] aufsteigend; unbekannt -> v12.
static func engine_layers(typ: String) -> Array:
	return _engines.get(typ, _engines.get("v12", []))


## Klang des eingestellten Alarmtons.
static func alarm_sound() -> String:
	return ALARM.get(String(GameSettings.get_value("alarmton")), "alarm_siren")


static func loaded_count() -> int:
	return _streams.size()


## Lautstärke 0..1 je Bus aus den Einstellungen; Headless immer stumm.
static func apply_volumes() -> void:
	for pair in [["Master", "vol_master"], ["Motor", "vol_motor"], ["Waffen", "vol_waffen"],
			["Umgebung", "vol_umgebung"], ["UI", "vol_ui"]]:
		var i := AudioServer.get_bus_index(pair[0])
		if i < 0:
			continue
		var v := float(GameSettings.get_value(pair[1]))
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.0001)))
		AudioServer.set_bus_mute(i, v <= 0.001 or (pair[0] == "Master" and is_headless()))


## Cockpit: Motor/Waffen gedämpft und tiefpassgefiltert (geschlossene Haube).
static func set_cockpit(on: bool) -> void:
	if on == cockpit:
		return
	cockpit = on
	for b in ["Motor", "Waffen"]:
		var i := AudioServer.get_bus_index(b)
		if i >= 0 and AudioServer.get_bus_effect_count(i) > 0:
			AudioServer.set_bus_effect_enabled(i, 0, on)


## Diagnose (Selbsttest/Log).
static func diagnostics() -> String:
	var b := []
	for n in ["Master"] + BUSES:
		var i := AudioServer.get_bus_index(n)
		if i >= 0:
			b.append("%s %.0f dB%s" % [n, AudioServer.get_bus_volume_db(i), " stumm" if AudioServer.is_bus_mute(i) else ""])
	var el := 0
	for typ in _engines:
		el += (_engines[typ] as Array).size()
	return "Audio-Busse %d (%s), Streams geladen %d/%d, Motor-Layer %d/%d" % [b.size(), ", ".join(b), _streams.size(),
		SOUNDS.size(), el, ENGINE_RPM.size() * ENGINE_LAYERS.size()]


## Einmal-Klang ohne Position (UI); braucht einen Knoten im Baum.
static func ui(host: Node, n: String) -> void:
	var d: SoundDirector = SoundDirector.instance
	if d != null and is_instance_valid(d) and host != null:
		d.play_2d(n, "UI")
