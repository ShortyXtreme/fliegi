class_name AmmoBunker
extends AmmoStore
## M3 Stub (Paket 0b, gehört Strang G / Paket 1): Munitionsbunker mit endlichem Bestand
## (Start: 7.92 mm 20.000 Schuss). Auch Munitionswagen nutzen diese Klasse als Vorrat.
## HP und Signal destroyed: Haken für M4. Zustand kompakt über to_array().

signal destroyed
signal changed

const AMMO_792 := &"7.92"
const START_792 := 20000

var stock := {}
var hp := 400.0
var hp_max := 400.0
var nation_id: int = Nations.NONE
var position := Vector3.ZERO


func _init(start: Dictionary = {}) -> void:
	stock = start.duplicate() if not start.is_empty() else {AMMO_792: START_792}


func request(type: StringName, n: int) -> int:
	if not Authority.is_server() or n <= 0:
		return 0
	var got := mini(n, available(type))
	if got > 0:
		stock[type] = available(type) - got
		changed.emit()
	return got


func available(type: StringName) -> int:
	return int(stock.get(type, 0))


func give_back(type: StringName, n: int) -> int:
	if not Authority.is_server() or n <= 0:
		return 0
	stock[type] = available(type) + n
	changed.emit()
	return n


func to_array() -> PackedInt32Array:
	return PackedInt32Array([available(AMMO_792), int(hp)])
