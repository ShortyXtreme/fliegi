class_name RepairJob
extends GroundJob
## M3 Stub (Paket 0b, gehört Strang G): Reparatur light: DamageModel.repair(zone, hp) nur für Zonen > 0 HP, ohne Brand.

var zone := DamageModel.Zone.TAIL


func _init() -> void:
	kind = &"repair"
	steps.assign([&"repair"])
