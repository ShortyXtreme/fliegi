class_name FuelSource
extends RefCounted
## M3 (Strang G / Paket 1): Treibstoffquelle (Lager, Tankwagen).
## Feste Signaturen: draw(grade, l) -> float, deposit(grade, l) -> float,
## available(grade) -> float, capacity(grade) -> float, total(), Signal changed.
## Mengen-Erhalt: Jeder Liter, den draw() liefert, fehlt danach in available().
## Nur der Server ändert Bestände (Authority.is_server()).

signal changed

## Liter je Sorte (FuelSystem.GRADE_AVIATION / GRADE_ERSATZ).
var liters := {}
var caps := {}
## Anzeigename (Hinweise, Lagerleiste).
var label := "Tank"


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
		_changed()
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
		_changed()
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


func is_empty(grade: StringName = &"") -> bool:
	if grade == &"":
		return total() <= 0.0001
	return available(grade) <= 0.0001


## Sorte für eine Entnahme: bevorzugt prefer, sonst Ersatz als Rückfall (wenn erlaubt).
## Leer: &"" (Job blockiert mit Hinweis „Lager leer“).
func pick_grade(prefer: StringName = FuelSystem.GRADE_AVIATION, allow_fallback := true) -> StringName:
	if not is_empty(prefer):
		return prefer
	if allow_fallback:
		for g in [FuelSystem.GRADE_AVIATION, FuelSystem.GRADE_ERSATZ]:
			if not is_empty(g):
				return g
	return &""


## Umfüllen in eine andere Quelle (Tankwagen am Lager). Rest geht zurück. Rückgabe: Liter.
func transfer_to_source(dest: FuelSource, grade: StringName, l: float) -> float:
	var got := draw(grade, l)
	if got <= 0.0:
		return 0.0
	var put := dest.deposit(grade, got)
	if put < got:
		deposit(grade, got - put)
	return put


## Ins Flugzeug füllen (FuelSystem.add). Was der Tank nicht annimmt, geht zurück.
func transfer_to_tank(fuel: FuelSystem, grade: StringName, l: float) -> float:
	if fuel == null:
		return 0.0
	var got := draw(grade, minf(l, fuel.space()))
	if got <= 0.0:
		return 0.0
	var acc := fuel.add(got, grade)
	if acc < got:
		deposit(grade, got - acc)
	return acc


func to_array() -> PackedFloat32Array:
	return PackedFloat32Array([available(FuelSystem.GRADE_AVIATION), available(FuelSystem.GRADE_ERSATZ)])


func _changed() -> void:
	changed.emit()
	GroundEvents.bus().depot_changed.emit(self)
