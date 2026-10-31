class_name AeroSurface
extends RefCounted
## Berechnet Auftrieb und Widerstand einer Fläche abhängig vom Anstellwinkel,
## inklusive Strömungsabriss. Rechenweg angelehnt an gasgiant/Aircraft-Physics (MIT),
## eigene Implementierung.
##
## Auftriebskurve (M1.1, weich statt Abbruchkante):
##  - linear bis KNEE vor dem Abrisswinkel, dann tanh-Abrundung (Tangente stetig),
##  - nach dem Abriss Abfall über STALL_BLEND auf ein Plateau von PLATEAU · CL_max,
##  - ab DEEP_START Übergang zur angeströmten ebenen Platte.
##  Der Abriss kostet vor allem Widerstand (STALL_DRAG), der Auftrieb bricht nicht weg.

var def: AeroSurfaceDef
var local_basis: Basis
var area: float
var lift_slope: float        # korrigiert für Streckung
var alpha0: float
var stall_hi: float
var stall_lo: float
var flap_tau: float          # Klappenwirksamkeit (Dünnprofiltheorie)
var induced_k: float

const KNEE := deg_to_rad(4.0)            # Abrundung beginnt 4° vor dem Abriss
const STALL_BLEND := deg_to_rad(7.0)     # CL_max -> Plateau
const INDICATOR_BLEND := deg_to_rad(4.0) # Abriss-Anzeige (Telemetrie stall_amount)
const PLATEAU := 0.75
const DEEP_START := deg_to_rad(30.0)     # x-Winkel, ab dem die ebene Platte übernimmt
const DEEP_BLEND := deg_to_rad(15.0)
const POST_STALL_LIFT := 1.05
const STALL_DRAG := 0.2
## Klappen verschieben den Abrisswinkel (x-Koordinate) um diesen Anteil von Δα:
## Abriss-AoA sinkt um (1 − Anteil)·Δα, CL_max steigt um Anteil·Δα·CLα.
const FLAP_STALL_SHIFT := 0.65

# Letzte Werte (Debug/Telemetrie)
var last_alpha: float = 0.0
var last_stall_t: float = 0.0
var last_force: Vector3 = Vector3.ZERO
var last_lift_coef: float = 0.0


func _init(d: AeroSurfaceDef) -> void:
	def = d
	local_basis = Basis.from_euler(d.rotation_deg * (PI / 180.0))
	area = d.area()
	var ar := d.aspect_ratio
	lift_slope = d.lift_slope * ar / (ar + 2.0 * (ar + 4.0) / (ar + 2.0))
	alpha0 = deg_to_rad(d.zero_lift_aoa_deg)
	stall_hi = deg_to_rad(d.stall_angle_high_deg)
	stall_lo = deg_to_rad(d.stall_angle_low_deg)
	var theta := acos(2.0 * d.flap_fraction - 1.0)
	flap_tau = 1.0 - (theta - sin(theta)) / PI
	induced_k = 1.0 / (PI * ar * 0.8)


## air_world: Anströmung am Flächenort (Weltkoordinaten, = -Bahngeschwindigkeit).
## downwash: Abwindwinkel (rad), um den die Anströmung nach unten gedreht wird.
## Rückgabe: Kraft in Weltkoordinaten.
func compute(air_world: Vector3, body_basis: Basis, rho: float, command: float,
		downwash: float = 0.0) -> Vector3:
	var b := body_basis * local_basis
	var air := b.transposed() * air_world
	air.x = 0.0  # Spannweitige Anteile ignorieren
	var v2 := air.length_squared()
	if v2 < 0.25:
		last_alpha = 0.0
		last_stall_t = 0.0
		last_force = Vector3.ZERO
		last_lift_coef = 0.0
		return Vector3.ZERO
	var vmag := sqrt(v2)
	var alpha := atan2(air.y, air.z) - downwash
	var vdir := Vector3(0.0, sin(alpha), cos(alpha))

	var defl := 0.0
	if def.control_axis != AeroSurfaceDef.ControlAxis.NONE:
		defl = deg_to_rad(def.max_deflection_deg) * clampf(command, -1.0, 1.0) * def.control_sign
	var eff := 1.0 - 0.5 * clampf((absf(defl) - deg_to_rad(10.0)) / deg_to_rad(40.0), 0.0, 1.0)
	var d_alpha := flap_tau * defl * eff
	var x := wrapf(alpha - alpha0 + d_alpha, -PI, PI)
	# Klappen erhöhen Cl_max etwas (Abriss erst bei etwas größerem x).
	# Abrisswinkel sind geometrische Anstellwinkel der Fläche -> in x-Koordinaten umrechnen
	var s_hi := stall_hi - alpha0 + maxf(d_alpha, 0.0) * FLAP_STALL_SHIFT
	var s_lo := stall_lo - alpha0 + minf(d_alpha, 0.0) * FLAP_STALL_SHIFT

	var r: Vector3
	if x >= 0.0:
		r = _branch(x, s_hi, lift_slope)
	else:
		r = _branch(-x, -s_lo, lift_slope)
		r.x = -r.x
	var cl := r.x
	var t_stall := r.y   # 0..1 Abfall auf das Plateau
	var t_deep := r.z    # 0..1 ebene Platte
	var cd_att := def.skin_friction + cl * cl * induced_k \
		+ def.flap_fraction * pow(sin(defl), 2.0) * 1.2
	var cd_fp := def.skin_friction + 1.98 * pow(sin(x), 2.0)
	var cd := lerpf(cd_att + STALL_DRAG * t_stall, cd_fp, t_deep)

	var ax := absf(x)
	var s := s_hi if x >= 0.0 else -s_lo
	var t_ind := _smooth((ax - s) / INDICATOR_BLEND)

	var q := 0.5 * rho * v2
	var lift_dir := vdir.cross(Vector3.RIGHT)
	var f_local := (lift_dir * cl + vdir * cd) * (q * area)
	last_alpha = alpha
	last_stall_t = t_ind
	last_lift_coef = cl
	last_force = b * f_local
	return last_force


## Positiver Ast der Auftriebskurve (x >= 0, s > 0). Rückgabe (cl, t_stall, t_deep).
static func _branch(x: float, s: float, slope: float) -> Vector3:
	var xk := maxf(s - KNEE, 0.0)
	var span := slope * (s - xk)
	var cl_att: float
	if x <= xk:
		cl_att = slope * x
	else:
		cl_att = slope * xk + span * tanh((x - xk) * slope / maxf(span, 1e-4))
	var cl_at_stall := slope * xk + span * tanh(1.0)
	var t_stall := _smooth((x - s) / STALL_BLEND)
	var cl := lerpf(cl_att, PLATEAU * cl_at_stall, t_stall)
	var t_deep := _smooth((x - maxf(DEEP_START, s + STALL_BLEND)) / DEEP_BLEND)
	cl = lerpf(cl, POST_STALL_LIFT * sin(2.0 * x), t_deep)
	return Vector3(cl, t_stall, t_deep)


static func _smooth(u: float) -> float:
	u = clampf(u, 0.0, 1.0)
	return u * u * (3.0 - 2.0 * u)


## Anstellwinkel (Rumpf), bei dem diese Fläche mit Ruder-/Klappenkommando cmd abreißt.
func body_stall_aoa_with(cmd: float) -> float:
	var defl := 0.0
	if def.control_axis != AeroSurfaceDef.ControlAxis.NONE:
		defl = deg_to_rad(def.max_deflection_deg) * clampf(cmd, -1.0, 1.0) * def.control_sign
	var eff := 1.0 - 0.5 * clampf((absf(defl) - deg_to_rad(10.0)) / deg_to_rad(40.0), 0.0, 1.0)
	var d_alpha := flap_tau * defl * eff
	# Abriss bei x = s_hi  ->  alpha = stall_hi - (1 - FLAP_STALL_SHIFT) * d_alpha
	return stall_hi - maxf(d_alpha, 0.0) * (1.0 - FLAP_STALL_SHIFT) - deg_to_rad(def.rotation_deg.x)


## Anstellwinkel (Rumpf), bei dem diese Fläche ohne Ruderausschlag abreißt.
func body_stall_aoa() -> float:
	return stall_hi - deg_to_rad(def.rotation_deg.x)
