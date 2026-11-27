class_name WorldGround
extends RefCounted
## Schnelle Bodenhöhe ohne Physik (Geschosse, KI-Bodenschutz, HUD).
## Ein Gelände (Paket 12, TerrainWorld) meldet sich mit set_provider(self) an; es muss
## height_at(x, z) -> float anbieten. Ohne Provider gilt flacher Boden bei y = 0
## (TestWorld; deren Kegel-Hügel erfasst nur der Physik-Raycast).

static var provider: Object = null


static func set_provider(p: Object) -> void:
	provider = p


static func clear_provider(p: Object = null) -> void:
	if p == null or provider == p:
		provider = null


static func height_at(x: float, z: float) -> float:
	if provider != null and is_instance_valid(provider):
		return provider.height_at(x, z)
	return 0.0


## M3.8: Wasserspiegel an (x, z), wenn dort Wasser steht (Fluss/Bach), sonst NAN.
## Provider ohne water_level_at (TestWorld): nirgends Wasser.
static func water_level_at(x: float, z: float) -> float:
	if provider != null and is_instance_valid(provider) and provider.has_method("water_level_at"):
		return provider.water_level_at(x, z)
	return NAN


## M3.8: Steht an (x, z) Wasser und liegt y höchstens tol Meter darüber?
static func is_water(x: float, z: float, y := -INF, tol := 3.0) -> bool:
	var lv := water_level_at(x, z)
	return not is_nan(lv) and (y == -INF or y <= lv + tol)
