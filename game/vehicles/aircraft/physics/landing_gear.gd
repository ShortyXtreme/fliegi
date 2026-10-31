class_name LandingGear
extends RefCounted
## Raycast-Fahrwerk: Feder/Dämpfer je Rad, Roll-/Seitenreibung, Bremsen, Heckradlenkung.
## M1.1: Einziehfahrwerk (extension 0 = eingefahren, 1 = ausgefahren und verriegelt),
## Bauchkufen für Landungen mit eingefahrenem Fahrwerk.
## Die Bodenkraft wirkt entlang der Bodennormalen (nicht der Rumpf-Hochachse), sonst
## schiebt die 12°-Dreipunktlage das stehende Flugzeug nach hinten.

const LONG_STIFFNESS := 2.0   # (N pro N Radlast) pro m/s Schlupf (Rollreibung)
const BRAKE_STIFFNESS := 5.0  # steiler: Bremse hält das stehende Flugzeug (Haftreibung)
const LAT_STIFFNESS := 2.0
const BELLY_SPRING := 140000.0
const BELLY_DAMPER := 14000.0
const BELLY_FRICTION := 0.65

var wheels: Array[WheelDef] = []
var data: AircraftData
var compression: PackedFloat32Array
var contact: Array[bool] = []
var loads: PackedFloat32Array
var belly_comp: PackedFloat32Array
## 0 = eingefahren, 1 = ausgefahren.
var extension: float = 1.0
var target_down: bool = true
## true, wenn Einfahren wegen Gewicht auf den Rädern verweigert wird.
var blocked: bool = false
var belly_contacts: int = 0


func _init(d: AircraftData) -> void:
	data = d
	wheels = d.wheels
	compression.resize(wheels.size())
	loads.resize(wheels.size())
	contact.resize(wheels.size())
	contact.fill(false)
	belly_comp.resize(d.belly_points.size())


## Gewicht auf dem (einziehbaren) Hauptfahrwerk.
func has_weight_on_wheels() -> bool:
	for i in wheels.size():
		if wheels[i].retractable and contact[i] and loads[i] > 50.0:
			return true
	return false


func _update_extension(dt: float, want_down: bool) -> void:
	blocked = false
	if not want_down and has_weight_on_wheels():
		# Sicherung: Einfahren unter Last verweigern (Fahrwerk bleibt, wo es ist).
		blocked = true
		target_down = true
		return
	target_down = want_down
	var rate := 1.0 / maxf(data.gear_transition_time, 0.1)
	extension = move_toward(extension, 1.0 if want_down else 0.0, rate * dt)


func integrate(state: PhysicsDirectBodyState3D, cmd: ControlCommands, exclude: Array[RID],
		debug) -> int:
	var dt := state.step
	_update_extension(dt, cmd.gear_down)
	var xf := state.transform
	var basis := xf.basis
	var space := state.get_space_state()
	var down := -basis.y
	var speed := state.linear_velocity.length()
	var n_contacts := 0
	# Überschlagschutz: Nase tiefer als ~2° unter der Dreipunktlage -> Bremsen lösen
	var brake_scale := 1.0
	if cmd.anti_nose_over:
		var pitch_up := asin(clampf(-basis.z.y, -1.0, 1.0))
		brake_scale = clampf((pitch_up - deg_to_rad(3.0)) / deg_to_rad(5.0), 0.0, 1.0)
		# Im Stand (Parkbremse) darf voll gebremst werden.
		brake_scale = maxf(brake_scale, 1.0 - clampf(speed / 3.0, 0.0, 1.0))
	for i in wheels.size():
		var w := wheels[i]
		# Eingezogene oder sich bewegende Räder tragen nicht.
		if w.retractable and extension < 0.999:
			compression[i] = 0.0
			loads[i] = 0.0
			contact[i] = false
			continue
		var top := xf * w.position
		var length := w.rest_length + w.radius
		var q := PhysicsRayQueryParameters3D.create(top, top + down * length)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			compression[i] = 0.0
			loads[i] = 0.0
			contact[i] = false
			continue
		var c := length - top.distance_to(hit.position)
		var c_rate := (c - compression[i]) / dt
		compression[i] = c
		var n_force := w.spring * c + w.damper * c_rate
		if c > w.rest_length:  # Federbein auf Anschlag
			n_force += (c - w.rest_length) * w.spring * 8.0
		n_force = maxf(n_force, 0.0)
		var normal: Vector3 = hit.normal
		# Radlast wirkt senkrecht zum Boden (Rad überträgt keine Längskraft außer Reibung).
		var n_ground := n_force
		loads[i] = n_ground
		contact[i] = true
		n_contacts += 1

		var r: Vector3 = hit.position - xf.origin
		var v := state.linear_velocity + state.angular_velocity.cross(r)
		var steer := deg_to_rad(w.steer_max_deg) * cmd.rudder * clampf(1.0 - speed / 45.0, 0.25, 1.0)
		var fwd := (-basis.z).rotated(basis.y, steer)
		var fwd_g := (fwd - normal * fwd.dot(normal)).normalized()
		var side_g := fwd_g.cross(normal)
		var v_long := v.dot(fwd_g)
		var v_lat := v.dot(side_g)
		var mu_roll := w.rolling_friction
		var mu_brake := w.brake_friction * cmd.brakes * brake_scale if w.has_brake else 0.0
		var f_long := -clampf(v_long * n_ground * LONG_STIFFNESS, -mu_roll * n_ground, mu_roll * n_ground) \
			- clampf(v_long * n_ground * BRAKE_STIFFNESS, -mu_brake * n_ground, mu_brake * n_ground)
		var f_lat := -clampf(v_lat * n_ground * LAT_STIFFNESS, -w.lateral_friction * n_ground,
			w.lateral_friction * n_ground)
		var f := normal * n_ground + fwd_g * f_long + side_g * f_lat
		state.apply_force(f, r)
		if debug != null:
			debug.append([hit.position, f, Color(0.2, 0.6, 1.0)])
	_belly(state, exclude, debug)
	return n_contacts


## Bauchkufen: Rumpf rutscht mit starker Reibung (Landung mit eingefahrenem Fahrwerk).
func _belly(state: PhysicsDirectBodyState3D, exclude: Array[RID], debug) -> void:
	belly_contacts = 0
	var pts := data.belly_points
	if pts.is_empty():
		return
	var xf := state.transform
	var space := state.get_space_state()
	var dt := state.step
	for i in pts.size():
		var p := xf * pts[i]
		var top := p + Vector3.UP * 1.0
		var q := PhysicsRayQueryParameters3D.create(top, p + Vector3.DOWN * 0.05)
		q.exclude = exclude
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			belly_comp[i] = 0.0
			continue
		var normal: Vector3 = hit.normal
		var hp: Vector3 = hit.position
		var depth: float = (hp - p).dot(normal)
		if depth <= 0.0:
			belly_comp[i] = 0.0
			continue
		var rate := (depth - belly_comp[i]) / dt
		belly_comp[i] = depth
		var n := maxf(BELLY_SPRING * depth + BELLY_DAMPER * rate, 0.0)
		var r: Vector3 = hit.position - xf.origin
		var v := state.linear_velocity + state.angular_velocity.cross(r)
		var v_t := v - normal * v.dot(normal)
		var vt := v_t.length()
		var f := normal * n
		if vt > 1e-3:
			f -= v_t / vt * minf(BELLY_FRICTION * n, vt * n * 20.0)
		state.apply_force(f, r)
		belly_contacts += 1
		if debug != null:
			debug.append([hit.position, f, Color(1.0, 0.3, 0.2)])


func reset(gear_down: bool = true) -> void:
	compression.fill(0.0)
	loads.fill(0.0)
	contact.fill(false)
	belly_comp.fill(0.0)
	extension = 1.0 if gear_down else 0.0
	target_down = gear_down
	blocked = false
	belly_contacts = 0
