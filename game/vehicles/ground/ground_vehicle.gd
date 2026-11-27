class_name GroundVehicle
extends CharacterBody3D
## M3 (Paket 6, Strang H): Bodenfahrzeug mit kinematischem Fahrmodell (Einspurmodell auf
## WorldGround.height_at, ≤ MAX_SPEED, Kollisionskapsel), deterministisch, ohne VehicleBody3D.
## Sitze: driver_seat (DRIVER), passenger_seat (PASSENGER); Eingabe über den PilotIntent des
## Fahrersitzes: throttle (Gas), brakes (Bremse; im Stand nach REVERSE_DELAY = rückwärts),
## yaw (Lenkung -1 links .. +1 rechts). Ohne Fahrer: Feststellbremse.
## Marker: seat_driver, seat_passenger, ground_clip (+ Unterklassen: hose_reel, crate_slot_*).
## Ein Modell (Paket 11) setzt apply_model(node): leere Knoten mit Markernamen überschreiben
## die Ersatzpositionen in markers.

const MAX_SPEED := 35.0 / 3.6
const REVERSE_SPEED := 2.5
## Prüfung Boden: Antrieb wie ein beladener 3-t-Lkw der 1930er (Opel Blitz 3,6-36 S: 3,35 t leer,
## 68–75 PS; Tankwagen beladen ≈ 5–6 t). Unten begrenzt die Haftung (Hinterachsantrieb, ≈ 65 %
## Achslast, μ ≈ 0,4 auf Gras: 0,4 · 0,65 · g ≈ 2,5 m/s², also ≈ 20 % Steigfähigkeit),
## darüber die Leistung (POWER_PER_MASS / v, W/kg an den Rädern). Vorher fest 2,0 m/s² ohne Hang.
const DRIVE_ACCEL := 2.5
const POWER_PER_MASS := 9.0
## Alter Name (Tests/KI): Anfahrbeschleunigung im ersten Gang.
const ACCEL := DRIVE_ACCEL
const REVERSE_ACCEL := 1.2
## Betriebsbremse auf Gras, Trommelbremsen beladen (vorher 6,0; StVZO heute ≥ 5,0 m/s² auf Asphalt).
const BRAKE_DECEL := 4.5
## Rollwiderstand auf Gras (c_rr ≈ 0,035 · g).
const ROLL_DECEL := 0.35
const GRAVITY := 9.81
const MAX_STEER := 0.6
const STEER_RATE := 1.8
## Prüfung Boden: Querbeschleunigung höchstens MAX_LAT_ACCEL (m/s²) – Haftung auf Gras und
## Kippgrenze eines hohen Tankwagens (g · Spur / (2 · Schwerpunkthöhe) ≈ 5 m/s²). Ersetzt den
## festen Lenkanteil HIGH_SPEED_STEER (bei 35 km/h waren es 7 m/s², also kippen/rutschen).
const MAX_LAT_ACCEL := 3.5
## Alt, nur noch Untergrenze des Lenkwinkel-Anteils bei Höchstfahrt.
const HIGH_SPEED_STEER := 0.2
const REVERSE_DELAY := 0.4
const STANDSTILL := 0.05
## Prüfung Boden: Watfähigkeit. Ab WADE_DEPTH Wassertiefe (m) Schritttempo, ab DROWN_DEPTH säuft
## der Motor ab (kein Vortrieb). Opel Blitz: Wattiefe ≈ 0,5–0,6 m.
const WADE_DEPTH := 0.3
const WADE_SPEED := 1.5
const DROWN_DEPTH := 0.8

var driver_seat: Seat
var passenger_seat: Seat
var nation_id: int = Nations.BLUE
## Fahrt längs (m/s, < 0 rückwärts), Gierwinkel (rad, 0 = Front nach -Z), Lenkwinkel (rad).
var speed := 0.0
var heading := 0.0
var steer := 0.0
var wheelbase := 3.6
var track := 1.8
var body_length := 6.0
var body_radius := 1.0
var ground_clear := 0.45
## Marker im Fahrzeug-System (Front -Z, rechts +X).
var markers := {
	ServiceMarkers.SEAT_DRIVER: Vector3(-0.5, 1.6, -2.0),
	ServiceMarkers.SEAT_PASSENGER: Vector3(0.5, 1.6, -2.0),
	ServiceMarkers.GROUND_CLIP: Vector3(0.9, 0.5, 1.5),
}
var seat_points: Array[Interactable] = []
var visual: Node3D
var _brake_hold := 0.0
## Längsneigung (rad, + = Front hoch) aus _fit_to_ground, für den Hangabtrieb.
var _pitch := 0.0
var _shape: CollisionShape3D


func _init() -> void:
	collision_layer = Layers.GROUND_VEHICLE
	collision_mask = Layers.WORLD | Layers.AIRCRAFT | Layers.GROUND_VEHICLE | Layers.CHARACTER
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	driver_seat = _make_seat("DriverSeat", Seat.Role.DRIVER, Vector3(-1.4, 0, -1.0))
	passenger_seat = _make_seat("PassengerSeat", Seat.Role.PASSENGER, Vector3(1.4, 0, -1.0))
	_configure()
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = body_radius
	cap.height = maxf(body_length, body_radius * 2.0 + 0.1)
	_shape.shape = cap
	_shape.rotation.x = PI / 2
	_shape.position.y = ground_clear + body_radius
	add_child(_shape)
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	_build_visual()
	_update_entries()
	for s in [driver_seat, passenger_seat]:
		seat_points.append(InteractionPoints.seat_point(s,
			"Einsteigen (Fahrer)" if s == driver_seat else "Einsteigen (Beifahrer)"))


## Unterklassen: Maße und Marker setzen (vor Kapsel und Optik).
func _configure() -> void:
	pass


func _make_seat(n: String, r: int, entry: Vector3) -> Seat:
	var s := Seat.new()
	s.name = n
	s.role = r
	s.vehicle = self
	s.entry_offset = entry
	add_child(s)
	return s


## Einstieg 0,9 m neben dem Sitzmarker, auf Bodenhöhe.
func _update_entries() -> void:
	var d: Vector3 = markers[ServiceMarkers.SEAT_DRIVER]
	var p: Vector3 = markers[ServiceMarkers.SEAT_PASSENGER]
	driver_seat.entry_offset = Vector3(-track * 0.5 - 0.9, 0.0, d.z)
	passenger_seat.entry_offset = Vector3(track * 0.5 + 0.9, 0.0, p.z)
	for it in seat_points:
		it.position = it.seat.entry_offset


func marker_point(n: String) -> Vector3:
	return markers.get(n, Vector3.ZERO)


## Modell übernehmen: leere Knoten mit Markernamen setzen die Marker.
func apply_model(model: Node3D) -> void:
	for c in visual.get_children():
		c.queue_free()
	visual.add_child(model)
	for n in markers.keys():
		var m := model.find_child(n, true, false) as Node3D
		if m != null:
			markers[n] = global_transform.affine_inverse() * m.global_transform.origin \
				if is_inside_tree() else m.position
	_update_entries()
	_markers_changed()


func _markers_changed() -> void:
	pass


## Auf den Boden setzen (Spawn, Tests): Lage, Richtung, Stillstand.
func place(pos: Vector3, yaw: float) -> void:
	heading = yaw
	speed = 0.0
	steer = 0.0
	_brake_hold = 0.0
	velocity = Vector3.ZERO
	global_position = pos
	_fit_to_ground()


## M3.1: Hindernis für die Wegsuche am Boden (GroundNav).
func _enter_tree() -> void:
	GroundNav.add_mover(self)


func _exit_tree() -> void:
	GroundNav.remove_mover(self)


func _ready() -> void:
	_fit_to_ground()


func _physics_process(dt: float) -> void:
	var i := driver_seat.poll(dt)
	drive(i, dt, driver_seat.controller != null)


## Ein Schritt des Fahrmodells. has_driver = false: Feststellbremse.
func drive(i: PilotIntent, dt: float, has_driver := true) -> void:
	var thr := clampf(i.throttle, 0.0, 1.0) if has_driver else 0.0
	var brk := clampf(i.brakes, 0.0, 1.0) if has_driver else 1.0
	var st := clampf(i.yaw, -1.0, 1.0) if has_driver else 0.0
	# Lenkung: Winkel so begrenzt, dass v² · tan(δ) / L ≤ MAX_LAT_ACCEL
	var steer_max := max_steer_at(absf(speed))
	steer = move_toward(steer, st * steer_max, STEER_RATE * dt)
	# Wasser: Schritttempo, zu tief = Motor abgesoffen
	var depth := water_depth()
	if depth >= DROWN_DEPTH:
		thr = 0.0
	# Längs: vorwärts Gas/Bremse, im Stand Bremse halten = rückwärts
	var standing := absf(speed) < STANDSTILL
	var hb: bool = has_driver and driver_seat.controller != null and driver_seat.controller.get("handbrake") == true
	_brake_hold = _brake_hold + dt if standing and brk > 0.1 and thr < 0.05 and not hb else 0.0
	var a := 0.0
	if speed > STANDSTILL or (standing and thr >= 0.05):
		a = thr * drive_accel(speed) - brk * BRAKE_DECEL
	elif hb and speed < -STANDSTILL:
		a = BRAKE_DECEL   # Handbremse beim Rückwärtsrollen: bremsen, nicht beschleunigen
	elif speed < -STANDSTILL or (standing and _brake_hold >= REVERSE_DELAY and has_driver):
		a = -brk * REVERSE_ACCEL + thr * BRAKE_DECEL
	# Hangabtrieb (nur in Fahrt; im Stand hält der Fahrer bzw. die Feststellbremse)
	if not standing or thr >= 0.05:
		a -= GRAVITY * sin(_pitch)
	var s0 := speed
	speed += a * dt
	if (s0 > 0.0 and speed < 0.0 and a < 0.0 and brk > thr) or (s0 < 0.0 and speed > 0.0 and (thr > 0.0 or hb)):
		speed = 0.0   # Bremsen bis Stillstand, nicht durch null
	speed = move_toward(speed, 0.0, ROLL_DECEL * dt)
	var vmax := MAX_SPEED if depth < WADE_DEPTH else WADE_SPEED
	speed = clampf(speed, -REVERSE_SPEED, vmax)
	if not has_driver and absf(speed) < STANDSTILL:
		speed = 0.0
	# Einspurmodell
	heading = wrapf(heading - speed * tan(steer) / wheelbase * dt, -PI, PI)   # Lenkung + = rechts
	if absf(speed) > 1e-5:
		var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
		velocity = fwd * speed
		var before := global_position
		move_and_slide()
		var moved := global_position - before
		var real := Vector3(moved.x, 0.0, moved.z) / dt
		if get_slide_collision_count() > 0:
			speed = clampf(real.dot(fwd), -REVERSE_SPEED, MAX_SPEED)
	velocity = Vector3.ZERO
	_fit_to_ground()


## Höhe und Neigung aus vier Bodenpunkten (Achsen vorn/hinten, links/rechts).
func _fit_to_ground() -> void:
	var p := global_position
	var fwd := Vector3(-sin(heading), 0.0, -cos(heading))
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var hf := _h(p + fwd * wheelbase * 0.5)
	var hb := _h(p - fwd * wheelbase * 0.5)
	var hl := _h(p - right * track * 0.5)
	var hr := _h(p + right * track * 0.5)
	p.y = (hf + hb + hl + hr) * 0.25
	var pitch := atan2(hf - hb, wheelbase)
	_pitch = pitch
	var roll := atan2(hl - hr, track)
	var b := Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, pitch) * Basis(Vector3.FORWARD, roll)
	global_transform = Transform3D(b, p)


## Vortriebs-Beschleunigung bei Vollgas (m/s²): Haftung/erster Gang unten, Leistung darüber.
static func drive_accel(v: float) -> float:
	return minf(DRIVE_ACCEL, POWER_PER_MASS / maxf(absf(v), 0.5))


## Größter Lenkwinkel bei Fahrt v (m/s) für höchstens MAX_LAT_ACCEL Querbeschleunigung.
func max_steer_at(v: float) -> float:
	if v < 0.5:
		return MAX_STEER
	var lim := atan(MAX_LAT_ACCEL * wheelbase / (v * v))
	return clampf(lim, MAX_STEER * HIGH_SPEED_STEER, MAX_STEER)


## Wassertiefe an der Fahrzeugmitte (m), 0 ohne Wasser.
func water_depth() -> float:
	var p := global_position
	var lv := WorldGround.water_level_at(p.x, p.z)
	if is_nan(lv):
		return 0.0
	return maxf(lv - WorldGround.height_at(p.x, p.z), 0.0)


static func _h(q: Vector3) -> float:
	return WorldGround.height_at(q.x, q.z)


func forward() -> Vector3:
	return Vector3(-sin(heading), 0.0, -cos(heading))


func seat_speed() -> float:
	return absf(speed)


func seat_on_ground() -> bool:
	return true


## Kompakter Zustand (Netz): x, y, z, heading, speed, steer.
func to_array() -> PackedFloat32Array:
	var p := global_position
	return PackedFloat32Array([p.x, p.y, p.z, heading, speed, steer])


func from_array(a: PackedFloat32Array) -> void:
	if a.size() < 6:
		return
	heading = a[3]
	speed = a[4]
	steer = a[5]
	global_position = Vector3(a[0], a[1], a[2])
	_fit_to_ground()


# --- Platzhalter-Optik (bis Paket 11) -----------------------------------------

func _build_visual() -> void:
	_box(Vector3(track + 0.2, 0.5, body_length), Vector3(0, ground_clear + 0.35, 0), Color(0.22, 0.25, 0.2))
	_box(Vector3(track + 0.1, 1.3, 1.6), Vector3(0, ground_clear + 1.2, -body_length * 0.5 + 0.9),
		Color(0.3, 0.34, 0.26))
	for z in [-wheelbase * 0.5, wheelbase * 0.5]:
		for x in [-track * 0.5, track * 0.5]:
			var w := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.45
			c.bottom_radius = 0.45
			c.height = 0.3
			w.mesh = c
			w.rotation.z = PI / 2
			w.position = Vector3(x, 0.45, z)
			w.material_override = _mat(Color(0.08, 0.08, 0.08))
			visual.add_child(w)


func _box(size: Vector3, pos: Vector3, col: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.position = pos
	m.material_override = _mat(col)
	visual.add_child(m)
	return m


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
