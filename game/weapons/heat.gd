class_name Heat
extends RefCounted
## Überhitzung und Ladehemmung einer Waffe (Paket 15, optional). Aktiv nur, wenn
## WeaponDef.heat_per_shot > 0. Hitze 0..∞ (1 = heiß); ab 1 kann jeder Schuss mit
## jam_chance_hot klemmen (deterministischer Zufall je Schuss). Eine Hemmung löst sich,
## wenn die Waffe unter CLEAR_LEVEL abgekühlt ist.

const HOT := 1.0
const CLEAR_LEVEL := 0.5

var weapon: WeaponDef
var value := 0.0
var jammed := false


func _init(w: WeaponDef = null) -> void:
	weapon = w


func active() -> bool:
	return weapon != null and weapon.heat_per_shot > 0.0


func reset() -> void:
	value = 0.0
	jammed = false


func cool(dt: float) -> void:
	if not active():
		return
	value = maxf(value - weapon.cool_rate * dt, 0.0)
	if jammed and value < CLEAR_LEVEL:
		jammed = false


func can_fire() -> bool:
	return not jammed


## Nach einem Schuss: Hitze erhöhen, ggf. Hemmung würfeln (seed = Schütze, Waffe, Schuss).
func on_shot(shooter_id: int, gun: int, shot_id: int) -> void:
	if not active():
		return
	value += weapon.heat_per_shot
	if value >= HOT and weapon.jam_chance_hot > 0.0:
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([shooter_id, gun, shot_id, 7])
		if rng.randf() < weapon.jam_chance_hot:
			jammed = true
