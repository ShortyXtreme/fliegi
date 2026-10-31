class_name PilotIntent
extends RefCounted
## Was der Insasse eines Pilotensitzes "will". Mensch und KI liefern dasselbe.
## Konvention: pitch +1 = Nase hoch, roll +1 = nach rechts rollen,
## yaw +1 = Nase nach rechts. throttle/flaps/brakes jeweils 0..1.

## Tasten-Bits in to_array()[8] (M2).
const BIT_FIRE_PRIMARY := 1
const BIT_FIRE_SECONDARY := 2
const BIT_EJECT := 4

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
## M2: Abzug Primärwaffen (MGs), solange true.
var fire_primary: bool = false
## M2: Abzug Sekundärwaffen (später Kanonen/Bomben), solange true.
var fire_secondary: bool = false
## M2: Notausstieg gewünscht. Der Controller setzt das Bit erst nach 1 s Halten;
## das Flugzeug reagiert auf die steigende Flanke (Server prüft, ob erlaubt).
var eject: bool = false


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
	fire_primary = o.fire_primary
	fire_secondary = o.fire_secondary
	eject = o.eject


func button_bits() -> int:
	return (BIT_FIRE_PRIMARY if fire_primary else 0) \
		| (BIT_FIRE_SECONDARY if fire_secondary else 0) \
		| (BIT_EJECT if eject else 0)


func set_button_bits(bits: int) -> void:
	fire_primary = bits & BIT_FIRE_PRIMARY != 0
	fire_secondary = bits & BIT_FIRE_SECONDARY != 0
	eject = bits & BIT_EJECT != 0


## Für späteres Netz-Replizieren (M3). Index 7 = Fahrwerk, 8 = Tasten-Bits (M2).
func to_array() -> PackedFloat32Array:
	return PackedFloat32Array([pitch, roll, yaw, throttle, flaps, brakes, assist_mode,
		1.0 if gear_down else 0.0, float(button_bits())])


static func from_array(a: PackedFloat32Array) -> PilotIntent:
	var i := PilotIntent.new()
	i.pitch = a[0]; i.roll = a[1]; i.yaw = a[2]
	i.throttle = a[3]; i.flaps = a[4]; i.brakes = a[5]
	i.assist_mode = int(a[6])
	if a.size() > 7:
		i.gear_down = a[7] > 0.5
	if a.size() > 8:
		i.set_button_bits(int(a[8]))
	return i.clamp_values()
