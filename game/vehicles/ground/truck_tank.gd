class_name TruckTank
extends FuelSource
## M3 (Paket 6, Strang H): Tank des Tankwagens. Eine gemeinsame Kapazität für alle Sorten
## (2.000 l), und nur eine Sorte zugleich: Eine andere Sorte nimmt er erst leer an.

var total_capacity := 2000.0


func _init(start_l := 2000.0, grade: StringName = FuelSystem.GRADE_AVIATION, cap := 2000.0) -> void:
	total_capacity = cap
	super({grade: clampf(start_l, 0.0, cap)} if start_l > 0.0 else {}, {})


## Platz für die Sorte: Gesamtkapazität minus Inhalt; fremde Sorte im Tank = 0.
func capacity(g: StringName) -> float:
	var other := total() - available(g)
	if other > 0.001:
		return available(g)
	return total_capacity


## Sorte des Inhalts (leer: aviation).
func grade() -> StringName:
	for g in liters:
		if float(liters[g]) > 0.001:
			return g
	return FuelSystem.GRADE_AVIATION


func space() -> float:
	return maxf(total_capacity - total(), 0.0)
