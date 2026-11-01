class_name RepairJob
extends GroundJob
## M3 (Strang G / Paket 3): Reparatur light. DamageModel.repair(zone, hp) mit rules.repair_hps,
## nur für Zonen > 0 HP ohne Brand (Flügelbruch, Brand, Abschuss: blockiert „Nicht reparierbar“).
## Authentisch: nur mit Werkzeugkiste (Figur trägt sie, oder toolbox = true im Sim-LOD).

var zone := DamageModel.Zone.TAIL
## Werkzeugkiste vorhanden (Sim-LOD/KI setzt das; die Figur über carried).
var toolbox := false
var repaired := 0.0

const ZONE_POINT := {
	DamageModel.Zone.ENGINE: ServiceMarkers.SVC_ENGINE,
	DamageModel.Zone.FUEL_L: ServiceMarkers.SVC_GUN_HATCH_L,
	DamageModel.Zone.WING_L: ServiceMarkers.SVC_GUN_HATCH_L,
	DamageModel.Zone.FUEL_R: ServiceMarkers.SVC_GUN_HATCH_R,
	DamageModel.Zone.WING_R: ServiceMarkers.SVC_GUN_HATCH_R,
	DamageModel.Zone.COCKPIT: ServiceMarkers.SVC_ENTRY,
}


func _init() -> void:
	kind = &"repair"
	steps.assign([&"repair"])


func missing_hp() -> float:
	var a := aircraft()
	if a == null:
		return 0.0
	return maxf(a.damage.hp_max[zone] - a.damage.hp[zone], 0.0)


func duration(_s: StringName, r: GroundRules) -> float:
	return missing_hp() / maxf(r.repair_hps, 0.01)


## Heck hat keinen eigenen Marker: kein Servicepunkt (Prüfung entfällt).
func point(_s: StringName, _r: GroundRules) -> String:
	return ZONE_POINT.get(zone, "")


func step(step_name: StringName, dt: float, rules: GroundRules) -> bool:
	if step_name != current_step() or blocked_reason != &"":
		return false
	var a := aircraft()
	if a == null:
		block(&"no_target")
		return false
	if missing_hp() <= 0.001:
		progress = 1.0
		return true
	if not a.damage.can_repair(zone):
		block(&"not_repairable")
		return false
	if rules.repair_needs_toolbox and not has_toolbox():
		block(&"toolbox_missing")
		return false
	var before := repaired + missing_hp()
	repaired += a.damage.repair(zone, rules.repair_hps * maxf(dt, 0.0))
	progress = clampf(repaired / maxf(before, 0.001), 0.0, 1.0)
	return missing_hp() <= 0.001


func has_toolbox() -> bool:
	if toolbox:
		return true
	if worker == null or not is_instance_valid(worker):
		return false
	var c = worker.get("carried")
	if c == null:
		return false
	if c is StringName or c is String:
		return String(c).to_lower().contains("toolbox") or String(c).to_lower().contains("werkzeug")
	if c is Object and c.get("item_kind") != null:
		return String(c.get("item_kind")) == "toolbox"
	return c is Node and String(c.name).to_lower().contains("toolbox")


func recheck(_r: GroundRules) -> void:
	var a := aircraft()
	match blocked_reason:
		&"toolbox_missing":
			if has_toolbox():
				blocked_reason = &""
		&"no_target":
			if a != null:
				blocked_reason = &""
		&"not_repairable":
			if a != null and (a.damage.can_repair(zone) or missing_hp() <= 0.001):
				blocked_reason = &""
