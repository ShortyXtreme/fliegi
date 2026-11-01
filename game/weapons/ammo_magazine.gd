class_name AmmoMagazine
extends RefCounted
## Munitionsvorrat einer Waffe.

var ammo_type: StringName = &""
var capacity := 0
var count := 0


func _init(type: StringName = &"", cap := 0) -> void:
	ammo_type = type
	capacity = maxi(cap, 0)
	count = capacity


## Bis zu n Schuss entnehmen. Rückgabe: entnommene Menge.
func take(n := 1) -> int:
	var got := mini(n, count)
	count -= got
	return got


func is_empty() -> bool:
	return count <= 0


## Aus einem AmmoStore auffüllen. Rückgabe: nachgefüllte Menge.
func refill(store: Object) -> int:
	var need := capacity - count
	if need <= 0 or store == null or not store.has_method("request"):
		return 0
	var got := clampi(int(store.request(ammo_type, need)), 0, need)
	count += got
	return got


## Sofort voll (Neustart am Platz).
func fill() -> void:
	count = capacity
