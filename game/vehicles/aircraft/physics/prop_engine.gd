class_name PropEngine
extends RefCounted
## Kolbenmotor mit Propeller: Standschub begrenzt, darüber Schub = eta * P / v.
## Lader: volle Leistung bis zur Volldruckhöhe, darüber ∝ Luftdichte (power_factor).
## Gas 0 = Leerlauf (leichter Vorwärtsschub), solange der Motor läuft.

var power: float
var static_thrust: float
var efficiency: float
var response: float
var idle: float
var blend_exp: float
var throttle_actual: float = 0.0
var running: bool = true
var last_thrust: float = 0.0


func _init(d: AircraftData) -> void:
	power = d.engine_power_w
	static_thrust = d.static_thrust_n
	efficiency = d.prop_efficiency
	response = d.throttle_response
	idle = d.idle_throttle
	blend_exp = d.prop_blend_exponent


func update(dt: float, throttle_cmd: float, axial_speed: float, power_factor: float) -> float:
	var target := lerpf(idle, 1.0, clampf(throttle_cmd, 0.0, 1.0)) if running else 0.0
	throttle_actual = move_toward(throttle_actual, target, response * dt)
	var v := maxf(axial_speed, 0.0)
	var t_static := static_thrust * power_factor
	var t_power := efficiency * power * power_factor / maxf(v, 1.0)
	# weiche Minimum-Bildung beider Grenzen
	var inv := pow(pow(1.0 / t_static, blend_exp) + pow(1.0 / t_power, blend_exp), 1.0 / blend_exp)
	last_thrust = throttle_actual / inv
	return last_thrust
