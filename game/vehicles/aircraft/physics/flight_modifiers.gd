class_name FlightModifiers
extends RefCounted
## Kopplung Schaden -> Flugphysik (Vertrag Paket 0). Gehört inhaltlich Agent B (DamageModel
## schreibt), gelesen wird es NUR von FlightModel/AeroSurface/PropEngine an festen Stellen:
##   AeroSurface.compute(..., lift_mul(i), drag_add(i))   Auftrieb/Widerstand je Fläche
##   control_command(i, cmd)                               Ruderwirkung, klemmendes Ruder
##   PropEngine.update(..., mods)                          engine_power_mul, engine_failed
##   FlightModel: extra_drag_area                          zusätzlicher Rumpfwiderstand
## Index i = Index der Fläche in AircraftData.surfaces (AeroSurface.index).
## Neutralwerte (1 / 0 / frei) ändern die Flugphysik bitgenau nicht.

var lift: PackedFloat32Array = []        # Auftriebsfaktor je Fläche (1 = intakt)
var drag: PackedFloat32Array = []        # Zusatz-Widerstandsbeiwert je Fläche (0 = intakt)
var control: PackedFloat32Array = []     # Ruderwirksamkeit je Fläche (1 = intakt)
var stuck: PackedByteArray = []          # 1 = Ruder klemmt bei stuck_value
var stuck_value: PackedFloat32Array = [] # Kommando, bei dem das Ruder klemmt (-1..1)
## Motorleistung (Lader, Schaden), multipliziert mit dem Höhenfaktor.
var engine_power_mul := 1.0
## Motor steht (Festfressen, kein Treibstoff, Brand).
var engine_failed := false
## Zusätzliche Widerstandsfläche Cd·A (m²), z. B. Einschusslöcher.
var extra_drag_area := 0.0


func setup(surface_count: int) -> void:
	lift.resize(surface_count)
	drag.resize(surface_count)
	control.resize(surface_count)
	stuck.resize(surface_count)
	stuck_value.resize(surface_count)
	reset()


func reset() -> void:
	lift.fill(1.0)
	drag.fill(0.0)
	control.fill(1.0)
	stuck.fill(0)
	stuck_value.fill(0.0)
	engine_power_mul = 1.0
	engine_failed = false
	extra_drag_area = 0.0


func lift_mul(i: int) -> float:
	return lift[i]


func drag_add(i: int) -> float:
	return drag[i]


## Effektives Ruderkommando der Fläche i.
func control_command(i: int, cmd: float) -> float:
	if stuck[i] != 0:
		return stuck_value[i]
	return cmd * control[i]


func set_stuck(i: int, value: float) -> void:
	stuck[i] = 1
	stuck_value[i] = clampf(value, -1.0, 1.0)


func release_stuck(i: int) -> void:
	stuck[i] = 0


func is_neutral() -> bool:
	if engine_power_mul != 1.0 or engine_failed or extra_drag_area != 0.0:
		return false
	for i in lift.size():
		if lift[i] != 1.0 or drag[i] != 0.0 or control[i] != 1.0 or stuck[i] != 0:
			return false
	return true
