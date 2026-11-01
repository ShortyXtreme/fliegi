class_name InteractionQuery
extends RefCounted
## M3 (Paket 4, Strang H): wählt den nächsten Interaktionspunkt im Blickkegel
## (Reichweite RANGE). pick(from, forward, candidates) -> Interactable.
## Wertung: Abstand plus Winkel-Aufschlag, damit der Punkt in Blickrichtung gewinnt,
## wenn zwei Punkte fast gleich weit weg sind. Ganz nahe Punkte (< NEAR) zählen immer.

const RANGE := 2.5
const CONE_DEG := 50.0
const NEAR := 0.4
## Höchster Höhenunterschied Augenhöhe/Boden ↔ Punkt (Tragfläche, Tankdeckel).
const MAX_DY := 2.6
## Meter Aufschlag je Radiant Abweichung von der Blickrichtung.
const ANGLE_WEIGHT := 1.0


static func pick(from: Vector3, forward: Vector3, candidates: Array) -> Interactable:
	var best: Interactable = null
	var best_score := INF
	var cos_max := cos(deg_to_rad(CONE_DEG))
	var fwd := Vector3(forward.x, 0.0, forward.z).normalized()
	for c in candidates:
		var it := c as Interactable
		if it == null or not it.is_inside_tree() or not it.enabled or not it.is_visible_in_tree():
			continue
		var to := it.global_position - from
		if absf(to.y) > MAX_DY:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		var d := flat.length()
		if d > RANGE:
			continue
		var ang := 0.0
		if d > NEAR and fwd != Vector3.ZERO:
			var cs := flat.normalized().dot(fwd)
			if cs < cos_max:
				continue
			ang = acos(clampf(cs, -1.0, 1.0))
		var score := d + ang * ANGLE_WEIGHT
		if score < best_score:
			best = it
			best_score = score
	return best


## Bequem: alle registrierten Punkte (Interactable.all()).
static func pick_any(from: Vector3, forward: Vector3) -> Interactable:
	return pick(from, forward, Interactable.all())
