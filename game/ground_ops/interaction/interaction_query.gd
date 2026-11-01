class_name InteractionQuery
extends RefCounted
## M3 Vertrag (Paket 0b, gehört Strang H / Paket 4): wählt den nächsten Interaktionspunkt
## im Blickkegel (Reichweite RANGE). pick(from, forward, candidates) -> Interactable.

const RANGE := 2.5
const CONE_DEG := 50.0


static func pick(from: Vector3, forward: Vector3, candidates: Array) -> Interactable:
	var best: Interactable = null
	var best_d := INF
	var cos_max := cos(deg_to_rad(CONE_DEG))
	var fwd := Vector3(forward.x, 0.0, forward.z).normalized()
	for c in candidates:
		var it := c as Interactable
		if it == null or not it.is_inside_tree():
			continue
		var to := it.global_position - from
		var d := to.length()
		if d > RANGE or d >= best_d:
			continue
		var flat := Vector3(to.x, 0.0, to.z)
		if flat.length() > 0.3 and fwd != Vector3.ZERO and flat.normalized().dot(fwd) < cos_max:
			continue
		best = it
		best_d = d
	return best
