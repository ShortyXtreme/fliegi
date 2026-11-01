class_name HudContacts
extends RefCounted
## Sammelt die Flugzeuge, die das Spieler-HUD kennt (aus ProjectileSystem.targets()),
## und entscheidet, was sichtbar ist (Plan M2 §8, Entscheidung 2):
## - Feindmarker nur innerhalb der Erkennungsweite (Spotting.can_spot). Der strengere
##   Modus gewinnt: Lobby (MatchRules.spot_mode) oder eigener Flugmodus „Realistisch“.
## - Vorhaltepunkt und Radar-Light nur im Arcade-Modus (und wenn die Lobby sie erlaubt).

const RADAR_RANGE := 3000.0
const LEAD_MAX_RANGE := 1200.0
const LEAD_CONE_DEG := 25.0


static func spot_mode(own: Node) -> int:
	if MatchRules.spot_mode == MatchRules.SpotMode.REALISTIC:
		return MatchRules.SpotMode.REALISTIC
	if own != null and own.get("assist_mode") == FlightAssist.Mode.REALISTIC:
		return MatchRules.SpotMode.REALISTIC
	return MatchRules.SpotMode.ARCADE


static func arcade(own: Node) -> bool:
	return spot_mode(own) == MatchRules.SpotMode.ARCADE


static func lead_allowed(own: Node) -> bool:
	return MatchRules.lead_indicator and arcade(own)


static func radar_allowed(own: Node) -> bool:
	return MatchRules.radar_light and arcade(own)


static func position_of(n: Node3D) -> Vector3:
	return n.get_global_transform_interpolated().origin if n.is_inside_tree() else n.global_position


static func velocity_of(n: Node) -> Vector3:
	var v = n.get("linear_velocity")
	return v if v is Vector3 else Vector3.ZERO


static func is_down(n: Node) -> bool:
	var d = n.get("damage")
	return d != null and d.get("is_destroyed") == true


## Kontakte: [{node, pos, vel, dist, hostile, spotted}] ohne das eigene Flugzeug.
static func collect(own: Node3D, candidates: Array = []) -> Array:
	var nodes := candidates
	if nodes.is_empty():
		for t in ProjectileSystem.targets():
			if t.node != null and is_instance_valid(t.node):
				nodes.append(t.node)
	var res := []
	var mode := spot_mode(own)
	var own_pos := position_of(own)
	var own_nat: int = own.get("nation_id") if own.get("nation_id") != null else Nations.NONE
	for n in nodes:
		if n == own or not (n is Node3D) or n.get("nation_id") == null or is_down(n):
			continue
		var p := position_of(n)
		var c := {"node": n, "pos": p, "vel": velocity_of(n), "dist": own_pos.distance_to(p)}
		c.hostile = Nations.is_hostile(own_nat, n.nation_id)
		c.spotted = c.dist <= Spotting.spot_range(own, n, mode)
		res.append(c)
	return res


## Ziel für den Vorhaltepunkt: nächstes erkanntes Feindflugzeug im Kegel vor der Nase.
static func lead_target(own: Node3D, contacts: Array) -> Dictionary:
	var xf := own.get_global_transform_interpolated() if own.is_inside_tree() else own.global_transform
	var fwd := -xf.basis.z
	var best := {}
	var best_score := INF
	for c in contacts:
		if not c.hostile or not c.spotted or c.dist > LEAD_MAX_RANGE:
			continue
		var ang := rad_to_deg(fwd.angle_to((c.pos as Vector3) - xf.origin))
		if ang > LEAD_CONE_DEG:
			continue
		var score: float = ang * 40.0 + c.dist
		if score < best_score:
			best_score = score
			best = c
	return best


## Vorhalt für das HUD: Punkt (Welt) auf der nötigen Schussrichtung in 500 m Abstand
## (gleiche Entfernung wie das Visierkreuz in hud.gd) und die Lösung selbst.
static func lead_point(own: Node3D, target: Dictionary) -> Dictionary:
	var w = own.get("weapons")
	if w == null or target.is_empty() or not w.has_weapons():
		return {}
	var wd: WeaponDef = w.weapon_of_group()
	if wd == null:
		return {}
	var p := position_of(own)
	var sol := LeadSolver.solve(p, velocity_of(own), target.pos, target.vel,
			wd.muzzle_velocity, wd.ballistic_k, Vector3.ZERO, minf(wd.max_range, LEAD_MAX_RANGE), 4)
	if not sol.valid:
		return {}
	sol.screen_point = p + (sol.dir as Vector3) * 500.0
	return sol


## Kurs (0..360°, Nord = −Z) einer Richtung.
static func heading_of(dir: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(dir.x, -dir.z)), 360.0)


static func display_name(n: Node, own: Node = null) -> String:
	if n == null or not is_instance_valid(n):
		return "—"
	if n == own:
		return "Du"
	if n.has_meta("display_name"):
		return str(n.get_meta("display_name"))
	var nat = n.get("nation_id")
	var id = n.get("entity_id")
	if nat == null:
		return str(n.name)
	return "%s %s" % [Nations.display_name(nat), str(id) if id != null and id != 0 else str(n.name)]
