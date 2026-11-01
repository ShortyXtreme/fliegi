class_name RearmJob
extends GroundJob
## M3 Stub (Paket 0b, gehört Strang G): Munition je Waffe: Kiste, Klappe, Gurt, Klappe. WeaponSystem.load_gun(i, store, n).

var gun_index := 0
## AmmoBunker oder Vorrat des AmmoCart.
var store: AmmoStore = null


func _init() -> void:
	kind = &"rearm"
	steps.assign([&"crate", &"hatch_open", &"belt", &"hatch_close"])
