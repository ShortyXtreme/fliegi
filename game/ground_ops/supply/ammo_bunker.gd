class_name AmmoBunker
extends AmmoStore
## M3 (Strang G / Paket 1): Munitionsbunker mit endlichem Bestand
## (Start: 7,92 mm 20.000 Schuss). Auch Munitionswagen und die getragene Kiste nutzen diese
## Klasse als Vorrat. HP und Signal destroyed: Haken für M4. Zustand kompakt über to_array().
## Typname wie WeaponDef.ammo_type (&"7.92mm").

signal destroyed
signal changed

const AMMO_792 := &"7.92mm"
const START_792 := 20000

var stock := {}
var hp := 400.0
var hp_max := 400.0
var nation_id: int = Nations.NONE
var position := Vector3.ZERO
var label := "Munitionsbunker"


func _init(start: Dictionary = {}) -> void:
	stock = start.duplicate() if not start.is_empty() else {AMMO_792: START_792}


func request(type: StringName, n: int) -> int:
	if not Authority.is_server() or n <= 0:
		return 0
	var got := mini(n, available(type))
	if got > 0:
		stock[type] = available(type) - got
		_changed()
	return got


func available(type: StringName) -> int:
	return int(stock.get(type, 0))


func give_back(type: StringName, n: int) -> int:
	if not Authority.is_server() or n <= 0:
		return 0
	stock[type] = available(type) + n
	_changed()
	return n


func total() -> int:
	var t := 0
	for k in stock:
		t += int(stock[k])
	return t


func is_empty(type: StringName = AMMO_792) -> bool:
	return available(type) <= 0


## Haken für M4. In M3 ohne Wirkung auf den Bestand.
func take_damage(amount: float) -> void:
	if not Authority.is_server() or amount <= 0.0 or hp <= 0.0:
		return
	hp = maxf(hp - amount, 0.0)
	if hp <= 0.0:
		destroyed.emit()
	_changed()


func to_array() -> PackedInt32Array:
	return PackedInt32Array([available(AMMO_792), int(hp)])


func from_array(a: PackedInt32Array) -> void:
	if a.size() >= 2:
		stock[AMMO_792] = a[0]
		hp = a[1]
		changed.emit()


func _changed() -> void:
	changed.emit()
	GroundEvents.bus().depot_changed.emit(self)
