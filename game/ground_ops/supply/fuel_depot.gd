class_name FuelDepot
extends FuelSource
## M3 (Strang G / Paket 1): Tanklager am Platz.
## Startbestand: aviation 8.000 l, ersatz 3.000 l. HP und Signal destroyed sind Haken für
## Angriffe (M4), in M3 ohne Wirkung. Zustand kompakt über to_array() (Netz).

signal destroyed

const START_AVIATION := 8000.0
const START_ERSATZ := 3000.0

var hp := 500.0
var hp_max := 500.0
var nation_id: int = Nations.NONE
## Lage in Szenenkoordinaten (aus AirfieldLayout.fuel_depot).
var position := Vector3.ZERO


func _init(stock: Dictionary = {}, capacities: Dictionary = {}) -> void:
	if stock.is_empty():
		stock = {FuelSystem.GRADE_AVIATION: START_AVIATION, FuelSystem.GRADE_ERSATZ: START_ERSATZ}
	if capacities.is_empty():
		capacities = stock.duplicate()
	super(stock, capacities)
	label = "Tanklager"


## Haken für M4 (Angriff auf das Lager). In M3 ohne Wirkung auf den Bestand.
func take_damage(amount: float) -> void:
	if not Authority.is_server() or amount <= 0.0 or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		destroyed.emit()
	_changed()


func to_array() -> PackedFloat32Array:
	return PackedFloat32Array([available(FuelSystem.GRADE_AVIATION), available(FuelSystem.GRADE_ERSATZ), hp])


func from_array(a: PackedFloat32Array) -> void:
	if a.size() >= 3:
		liters[FuelSystem.GRADE_AVIATION] = a[0]
		liters[FuelSystem.GRADE_ERSATZ] = a[1]
		hp = a[2]
		changed.emit()
