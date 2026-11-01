class_name FuelSystem
extends RefCounted
## Einfaches Treibstoffsystem (Paket 4): zwei Flügeltanks in Litern, Verbrauch nach
## Gasstellung, Leck je Tank. Leer -> Motor steht (DamageModel setzt engine_failed).
## Die Masse koppelt in M2 noch nicht ins Flugmodell (Hook für Paket 14).

const LEFT := 0
const RIGHT := 1

var capacity := PackedFloat32Array([180.0, 180.0])
var liters := PackedFloat32Array([180.0, 180.0])
## Leckrate je Tank (l/s), setzt das DamageModel.
var leak_lps := PackedFloat32Array([0.0, 0.0])
var burn_full_lps := 0.09
var burn_idle_lps := 0.01
## Insgesamt ausgelaufen (l), für Effekte/Statistik.
var leaked_total := 0.0


func setup(cap_per_tank: float, burn_full: float, burn_idle: float) -> void:
	capacity = PackedFloat32Array([cap_per_tank, cap_per_tank])
	burn_full_lps = burn_full
	burn_idle_lps = burn_idle
	refill()


func refill() -> void:
	liters = capacity.duplicate()
	leak_lps.fill(0.0)
	leaked_total = 0.0


func total() -> float:
	return liters[0] + liters[1]


func fraction() -> float:
	return total() / maxf(capacity[0] + capacity[1], 1e-3)


func is_empty() -> bool:
	return total() <= 0.0


func is_leaking() -> bool:
	return (leak_lps[0] > 0.0 and liters[0] > 0.0) or (leak_lps[1] > 0.0 and liters[1] > 0.0)


## Verbrauch und Lecks eines Ticks. Der Motor zieht gleichmäßig aus beiden Tanks
## (aus dem verbliebenen, wenn einer leer ist).
func tick(dt: float, throttle: float, running: bool) -> void:
	for k in 2:
		if leak_lps[k] > 0.0 and liters[k] > 0.0:
			var l := minf(leak_lps[k] * dt, liters[k])
			liters[k] -= l
			leaked_total += l
	if not running:
		return
	var need := lerpf(burn_idle_lps, burn_full_lps, clampf(throttle, 0.0, 1.0)) * dt
	var tanks := 0
	for k in 2:
		if liters[k] > 0.0:
			tanks += 1
	if tanks == 0:
		return
	var share := need / tanks
	var rest := 0.0
	for k in 2:
		if liters[k] > 0.0:
			var take := minf(share, liters[k])
			liters[k] -= take
			rest += share - take
	if rest > 0.0:
		for k in 2:
			var take := minf(rest, liters[k])
			liters[k] -= take
			rest -= take


func to_array() -> PackedFloat32Array:
	return PackedFloat32Array([liters[0], liters[1]])


func from_array(a: PackedFloat32Array) -> void:
	if a.size() >= 2:
		liters[0] = a[0]
		liters[1] = a[1]
