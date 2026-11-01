class_name FuelSource
extends RefCounted
## M3 Vertrag (Paket 0b, gehört Strang G / Paket 1): Treibstoffquelle (Lager, Tankwagen).
## Feste Signaturen: draw(grade, l) -> float, deposit(grade, l) -> float,
## available(grade) -> float, capacity(grade) -> float, Signal changed.
## Mengen-Erhalt: Jeder Liter, den draw() liefert, fehlt danach in available().

signal changed

## Liter je Sorte (FuelSystem.GRADE_AVIATION / GRADE_ERSATZ).
var liters := {}
var caps := {}


func _init(stock: Dictionary = {}, capacities: Dictionary = {}) -> void:
	for g in stock:
		liters[g] = float(stock[g])
	for g in capacities:
		caps[g] = float(capacities[g])


## Bis zu l Liter der Sorte entnehmen. Rückgabe: gelieferte Liter.
func draw(grade: StringName, l: float) -> float:
	if not Authority.is_server() or l <= 0.0:
		return 0.0
	var got := minf(l, available(grade))
	if got > 0.0:
		liters[grade] = available(grade) - got
		changed.emit()
	return got


## Liter einlagern (z. B. Rest aus dem Schlauch, Tankwagen am Lager entleeren).
## Rückgabe: angenommene Liter (begrenzt durch capacity).
func deposit(grade: StringName, l: float) -> float:
	if not Authority.is_server() or l <= 0.0:
		return 0.0
	var room := capacity(grade) - available(grade)
	var put := minf(l, maxf(room, 0.0))
	if put > 0.0:
		liters[grade] = available(grade) + put
		changed.emit()
	return put


func available(grade: StringName) -> float:
	return float(liters.get(grade, 0.0))


## Kapazität je Sorte (ohne Angabe: unbegrenzt).
func capacity(grade: StringName) -> float:
	return float(caps.get(grade, INF))


func total() -> float:
	var t := 0.0
	for g in liters:
		t += float(liters[g])
	return t
