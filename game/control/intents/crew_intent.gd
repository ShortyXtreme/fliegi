class_name CrewIntent
extends RefCounted
## M3 (Paket 0a): Was eine Figur zu Fuß „will“ (Sitz Seat.Role.CREW). Mensch
## (CrewPlayerController) und KI (GroundCrewBrain) liefern dasselbe.
## Konvention: move.x +1 = nach rechts, move.y +1 = nach vorn (relativ zur Blickrichtung),
## Länge ≤ 1. look_yaw/look_pitch = absolute Blickrichtung in rad (Welt, yaw 0 = -Z,
## +yaw = nach links drehen wie Basis.rotated(UP, yaw); pitch +1 = nach oben).
## Fahrzeuge (Tankwagen, Munitionswagen) nutzen weiter den PilotIntent.

const BIT_SPRINT := 1
const BIT_INTERACT := 2      # gehalten (Fortschritt läuft, solange gesetzt)
const BIT_DROP := 4          # Gegenstand ablegen (Flanke)
const BIT_ENTER := 8         # Einsteigen in den Sitz am nächsten Punkt (Flanke)
const BIT_WHEEL_OPEN := 16   # Befehlsrad offen (gehalten)
const BIT_VIEW_TOGGLE := 32  # Ego/Third umschalten (Flanke)

var move: Vector2 = Vector2.ZERO
var look_yaw: float = 0.0
var look_pitch: float = 0.0
var sprint: bool = false
var interact: bool = false
var drop: bool = false
var enter: bool = false
var wheel_open: bool = false
## Gewählter Eintrag im Befehlsrad (-1 = keiner). Gilt beim Loslassen von wheel_open.
var wheel_choice: int = -1
var view_toggle: bool = false


func clamp_values() -> CrewIntent:
	move = move.limit_length(1.0)
	look_yaw = wrapf(look_yaw, -PI, PI)
	look_pitch = clampf(look_pitch, -1.4, 1.4)
	wheel_choice = maxi(wheel_choice, -1)
	return self


func copy_from(o: CrewIntent) -> void:
	move = o.move
	look_yaw = o.look_yaw
	look_pitch = o.look_pitch
	set_button_bits(o.button_bits())
	wheel_choice = o.wheel_choice


func button_bits() -> int:
	return (BIT_SPRINT if sprint else 0) | (BIT_INTERACT if interact else 0) \
		| (BIT_DROP if drop else 0) | (BIT_ENTER if enter else 0) \
		| (BIT_WHEEL_OPEN if wheel_open else 0) | (BIT_VIEW_TOGGLE if view_toggle else 0)


func set_button_bits(bits: int) -> void:
	sprint = bits & BIT_SPRINT != 0
	interact = bits & BIT_INTERACT != 0
	drop = bits & BIT_DROP != 0
	enter = bits & BIT_ENTER != 0
	wheel_open = bits & BIT_WHEEL_OPEN != 0
	view_toggle = bits & BIT_VIEW_TOGGLE != 0


## Netz-Replikation: [move.x, move.y, look_yaw, look_pitch, wheel_choice, Tasten-Bits].
func to_array() -> PackedFloat32Array:
	return PackedFloat32Array([move.x, move.y, look_yaw, look_pitch, float(wheel_choice),
		float(button_bits())])


static func from_array(a: PackedFloat32Array) -> CrewIntent:
	var i := CrewIntent.new()
	if a.size() >= 6:
		i.move = Vector2(a[0], a[1])
		i.look_yaw = a[2]
		i.look_pitch = a[3]
		i.wheel_choice = int(a[4])
		i.set_button_bits(int(a[5]))
	return i.clamp_values()
