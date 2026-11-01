class_name TransformHistory
extends RefCounted
## Ringpuffer der letzten Transforms eines Ziels je Physik-Tick (Plan M2 §2, ≈ 1 s).
## Der HitValidator spult damit Ziele auf den Tick eines Trefferberichts zurück.

var capacity := 64
var _ticks := PackedInt64Array()
var _xf: Array[Transform3D] = []
var _head := 0
var _count := 0


func _init(cap := 64) -> void:
	capacity = maxi(cap, 2)
	_ticks.resize(capacity)
	_xf.resize(capacity)


func clear() -> void:
	_head = 0
	_count = 0


## Stand zum Tick ablegen (Ticks aufsteigend; gleicher Tick überschreibt).
func record(tick: int, xf: Transform3D) -> void:
	if _count > 0:
		var last := (_head - 1 + capacity) % capacity
		if _ticks[last] == tick:
			_xf[last] = xf
			return
		if _ticks[last] > tick:
			clear()
	_ticks[_head] = tick
	_xf[_head] = xf
	_head = (_head + 1) % capacity
	_count = mini(_count + 1, capacity)


func size() -> int:
	return _count


func oldest_tick() -> int:
	return _ticks[(_head - _count + capacity) % capacity] if _count > 0 else -1


func newest_tick() -> int:
	return _ticks[(_head - 1 + capacity) % capacity] if _count > 0 else -1


func has(tick: int) -> bool:
	return _index(tick) >= 0


## Transform zum Tick oder null, wenn außerhalb des Verlaufs.
func at(tick: int) -> Variant:
	var i := _index(tick)
	return _xf[i] if i >= 0 else null


func _index(tick: int) -> int:
	if _count == 0:
		return -1
	var newest := newest_tick()
	var back := newest - tick
	if back < 0 or back >= _count:
		return -1
	# lückenlos: direkter Zugriff; sonst suchen
	var i := (_head - 1 - back + capacity * 2) % capacity
	if _ticks[i] == tick:
		return i
	for j in _count:
		var k := (_head - 1 - j + capacity * 2) % capacity
		if _ticks[k] == tick:
			return k
	return -1


## Floating Origin: gespeicherte Transformationen um -delta verschieben.
func shift_origin(delta: Vector3) -> void:
	for i in _xf.size():
		_xf[i].origin -= delta
