class_name RefuelJob
extends GroundJob
## M3 Stub (Paket 0b, gehört Strang G): Tanken: nimmt aus FuelSource.draw(grade, l) und gibt an FuelSystem.add(l, grade).

## Quelle (FuelDepot oder Tank des FuelTruck) und Sorte.
var source: FuelSource = null
var grade: StringName = FuelSystem.GRADE_AVIATION
## Ziel-Füllstand 0..1 (Befehl „Schnellabfertigung“: 0,5).
var target_fraction := 1.0


func _init() -> void:
	kind = &"refuel"
	steps.assign([&"bring", &"ground", &"attach", &"pump", &"detach"])
