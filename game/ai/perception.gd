class_name AIPerception
extends RefCounted
## Wahrnehmung der Kampf-KI (Plan §4, Entscheidung 2).
## - Feind nur, wenn Nations.is_hostile(eigene, fremde Nation).
## - Sichtweite = Spotting.spot_range(viewer, target) × Kegelfaktor: vorne größer,
##   hinten kleiner (toter Winkel unter/hinter dem Heck).
## - Reaktionsverzögerung: ein Ziel gilt erst als erkannt, wenn es reaction_time lang
##   ununterbrochen sichtbar war; Position/Geschwindigkeit werden aus einem um
##   reaction_time verzögerten Puffer gelesen (KI reagiert auf "alte" Bilder).
## Deterministisch: zählt eigene Ticks, keine Uhrzeit.

## Frontkegel (halber Öffnungswinkel) und Faktor auf die Sichtweite.
const FRONT_CONE_DEG := 60.0
const FRONT_MUL := 1.25
## Heckkegel (ab diesem Winkel zur Nase) und Faktor.
const REAR_CONE_DEG := 150.0
const REAR_MUL := 0.5
## Puffertiefe in Ticks (reicht für 1,5 s bei 60 Hz).
const BUFFER := 96
## Ziel bleibt so lange (s) "im Gedächtnis", nachdem es aus der Sicht verschwand.
const MEMORY := 4.0

## Wahrgenommenes Ziel (verzögert).
class Contact:
	var node: Node3D
	var pos := Vector3.ZERO
	var vel := Vector3.ZERO
	var acc := Vector3.ZERO
	var visible_time := 0.0
	var lost_time := 0.0
	var known := false
	var _ring_pos := PackedVector3Array()
	var _ring_vel := PackedVector3Array()
	var _n := 0

	func _init(n: Node3D) -> void:
		node = n
		_ring_pos.resize(BUFFER)
		_ring_vel.resize(BUFFER)

	func push(p: Vector3, v: Vector3) -> void:
		_ring_pos[_n % BUFFER] = p
		_ring_vel[_n % BUFFER] = v
		_n += 1

	## Vom (verzögerten) Bild um t Sekunden hochgerechnet – so schätzt ein Pilot, wo das
	## Ziel jetzt ist; Manöverwechsel sieht er trotzdem erst nach der Reaktionszeit.
	func extrapolated(t: float) -> Vector3:
		return pos + vel * t + acc * (0.5 * t * t)

	## Zustand von vor `delay` Ticks (gekappt auf die Pufferlänge).
	func sample(delay: int, dt: float) -> void:
		var d := clampi(delay, 0, mini(_n - 1, BUFFER - 2))
		var i := (_n - 1 - d) % BUFFER
		var j := (_n - 2 - d + BUFFER) % BUFFER
		pos = _ring_pos[i]
		vel = _ring_vel[i]
		if _n - d >= 2:
			acc = acc.lerp((_ring_vel[i] - _ring_vel[j]) / dt, 0.2)

var owner: Node3D
var reaction_time := 0.5
## Bekannte Ziele: Node -> Contact
var contacts := {}
## Optional feste Kandidatenliste (Tests); sonst ProjectileSystem.targets().
var candidates: Array = []


func _init(o: Node3D, reaction := 0.5) -> void:
	owner = o
	reaction_time = reaction


func _candidates() -> Array:
	if not candidates.is_empty():
		return candidates
	var out := []
	for t in ProjectileSystem.targets():
		if t.node != null and is_instance_valid(t.node):
			out.append(t.node)
	return out


static func nation_of(n: Object) -> int:
	var v = n.get("nation_id") if n != null else null
	return v if v is int else Nations.NONE


## Feind laut Diplomatie-Matrix und nicht zerstört.
func is_enemy(n: Node3D) -> bool:
	if n == null or n == owner or not is_instance_valid(n) or not n.is_inside_tree():
		return false
	if not Nations.is_hostile(nation_of(owner), nation_of(n)):
		return false
	var d = n.get("damage")
	return not (d != null and d.get("is_destroyed") == true)


## Sichtweite in Richtung des Ziels (Spotting × Kegel).
func view_range(n: Node3D) -> float:
	var r := Spotting.spot_range(owner, n)
	var to := n.global_position - owner.global_position
	if to.length() < 1.0:
		return r
	var ang := rad_to_deg((-owner.global_transform.basis.z).angle_to(to))
	if ang <= FRONT_CONE_DEG:
		return r * FRONT_MUL
	if ang >= REAR_CONE_DEG:
		return r * REAR_MUL
	return r


func can_see(n: Node3D) -> bool:
	return owner.global_position.distance_to(n.global_position) <= view_range(n)


## Einmal je Physik-Tick.
func update(dt: float) -> void:
	var delay := int(round(reaction_time / dt))
	var seen := {}
	for n in _candidates():
		if not is_enemy(n):
			continue
		seen[n] = true
		var c: Contact = contacts.get(n)
		if c == null:
			c = Contact.new(n)
			contacts[n] = c
		var v: Vector3 = n.get("linear_velocity") if n is RigidBody3D else Vector3.ZERO
		c.push(n.global_position, v)
		if can_see(n):
			c.visible_time += dt
			c.lost_time = 0.0
			if c.visible_time >= reaction_time:
				c.known = true
		else:
			c.visible_time = 0.0
			c.lost_time += dt
			if c.lost_time > MEMORY:
				c.known = false
		c.sample(delay, dt)
	for n in contacts.keys():
		if not seen.has(n):
			contacts.erase(n)


## Nächstes erkanntes Ziel (oder null).
func best_target() -> Contact:
	var best: Contact = null
	var best_d := INF
	for c in contacts.values():
		if not c.known:
			continue
		var d := owner.global_position.distance_to(c.pos)
		if d < best_d:
			best_d = d
			best = c
	return best
