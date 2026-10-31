class_name PilotIntent
extends RefCounted
## Was der Insasse eines Pilotensitzes "will". Mensch und KI liefern dasselbe.
## Konvention: pitch +1 = Nase hoch, roll +1 = nach rechts rollen,
## yaw +1 = Nase nach rechts. throttle/flaps/brakes jeweils 0..1.

var pitch: float = 0.0
var roll: float = 0.0
var yaw: float = 0.0
var throttle: float = 0.0
var flaps: float = 0.0
var brakes: float = 0.0
## Fahrwerk: true = ausfahren/ausgefahren lassen, false = einfahren.
var gear_down: bool = true
## Gewünschter Hilfen-Modus (FlightAssist.Mode). Der Server darf ihn übersteuern.
var assist_mode: int = 0


func clamp_values() -> PilotIntent:
	pitch = clampf(pitch, -1.0, 1.0)
	roll = clampf(roll, -1.0, 1.0)
	yaw = clampf(yaw, -1.0, 1.0)
	throttle = clampf(throttle, 0.0, 1.0)
	flaps = clampf(flaps, 0.0, 1.0)
	brakes = clampf(brakes, 0.0, 1.0)
	return self


func copy_from(o: PilotIntent) -> void:
	pitch = o.pitch; roll = o.roll; yaw = o.yaw
	throttle = o.throttle; flaps = o.flaps; brakes = o.brakes
	gear_down = o.gear_down
	assist_mode = o.assist_mode


## Für späteres Netz-Replizieren (M3).
func to_array() -> PackedFloat32Array:
	return PackedFloat32Array([pitch, roll, yaw, throttle, flaps, brakes, assist_mode,
		1.0 if gear_down else 0.0])


static func from_array(a: PackedFloat32Array) -> PilotIntent:
	var i := PilotIntent.new()
	i.pitch = a[0]; i.roll = a[1]; i.yaw = a[2]
	i.throttle = a[3]; i.flaps = a[4]; i.brakes = a[5]
	i.assist_mode = int(a[6])
	if a.size() > 7:
		i.gear_down = a[7] > 0.5
	return i.clamp_values()
