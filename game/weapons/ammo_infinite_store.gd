class_name InfiniteAmmoStore
extends AmmoStore
## Unbegrenztes Lager am Platz (M2). Zählt nur mit, wie viel ausgegeben wurde.

var issued := {}


func request(type: StringName, n: int) -> int:
	n = maxi(n, 0)
	issued[type] = int(issued.get(type, 0)) + n
	return n


func available(_type: StringName) -> int:
	return 1 << 30


func give_back(type: StringName, n: int) -> int:
	n = maxi(n, 0)
	issued[type] = int(issued.get(type, 0)) - n
	return n
