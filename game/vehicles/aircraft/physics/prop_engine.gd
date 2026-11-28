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
## M3.11: abgegebene Wellenleistung (W) und Anteil an der Nennleistung (Verbrauch, Drehmoment).
var shaft_power: float = 0.0
var power_fraction: float = 0.0
## M3.11: Kühlmitteltemperatur (°C) und Kühlerklappe (0..1).
var coolant_temp: float = 80.0
var radiator: float = 0.5
var _d: AircraftData


func _init(d: AircraftData) -> void:
	_d = d
	power = d.engine_power_w
	static_thrust = d.static_thrust_n
	efficiency = d.prop_efficiency
	response = d.throttle_response
	idle = d.idle_throttle
	blend_exp = d.prop_blend_exponent


## mods: Schadens-Hook (FlightModifiers) – engine_power_mul, engine_failed. null = intakt.
func update(dt: float, throttle_cmd: float, axial_speed: float, power_factor: float,
		mods: FlightModifiers = null) -> float:
	var on := running
	if mods != null:
		power_factor *= mods.engine_power_mul
		on = on and not mods.engine_failed
	power_factor *= heat_power_mul()
	var target := lerpf(idle, 1.0, clampf(throttle_cmd, 0.0, 1.0)) if on else 0.0
	throttle_actual = move_toward(throttle_actual, target, response * dt)
	var v := maxf(axial_speed, 0.0)
	shaft_power = power * power_factor * throttle_actual if on else 0.0
	power_fraction = shaft_power / maxf(power, 1.0)
	if power_factor <= 1e-4:
		last_thrust = 0.0
		return 0.0
	var t_static := static_thrust * power_factor
	var t_power := efficiency * power * power_factor / maxf(v, 1.0)
	# weiche Minimum-Bildung beider Grenzen
	var inv := pow(pow(1.0 / t_static, blend_exp) + pow(1.0 / t_power, blend_exp), 1.0 / blend_exp)
	last_thrust = throttle_actual / inv
	return last_thrust


## M3.11: Leistungsabfall durch Überhitzung: ab coolant_hot linear bis −40 % bei +20 K.
func heat_power_mul() -> float:
	if _d == null or coolant_temp <= _d.coolant_hot:
		return 1.0
	return clampf(1.0 - 0.4 * (coolant_temp - _d.coolant_hot) / 20.0, 0.6, 1.0)


## M3.11: Kühlung je Tick. Wärmezufuhr = Anteil der Wellenleistung; Abgabe = Leitwert ×
## Klappe × (Kühlluft/Bezug)^0,8 × (T − T_Luft). Kühlluft = Fahrt + halber Strahlzuwachs
## (Kühler teils im Propellerstrahl). Thermostat öffnet die Klappe zwischen open_from und
## open_full. Rückgabe: Klappenstellung.
func update_cooling(dt: float, airspeed: float, wash_dv: float, t_air_c: float) -> float:
	var d := _d
	radiator = clampf(d.radiator_flap_min + (1.0 - d.radiator_flap_min) * (coolant_temp - d.radiator_open_from) \
			/ maxf(d.radiator_open_full - d.radiator_open_from, 0.1), d.radiator_flap_min, 1.0)
	var v_cool := maxf(airspeed, 0.0) + 0.5 * maxf(wash_dv, 0.0)
	var flow := maxf(pow(v_cool / d.radiator_ref_speed, 0.8), 0.3)
	var h := d.radiator_conductance * radiator * flow
	var q_in := d.coolant_heat_fraction * shaft_power
	coolant_temp += (q_in - h * (coolant_temp - t_air_c)) / d.coolant_heat_capacity * dt
	return radiator
