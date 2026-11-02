class_name CrewCharacter
extends CharacterBody3D
## M3 (Paket 4, Strang H): Figur zu Fuß. Ist ein „Fahrzeug“ mit einem Sitz
## Seat.Role.CREW (crew_seat). Gehen 1,6 m/s, Sprint 4,5 m/s, folgt WorldGround.height_at.
## Trageplatz carried (Kiste, Schlauchende, Kanister, Werkzeug; Paket 5).
## SeatService-Haken: on_entered_seat(seat), on_exited_seat(seat, pos).
##
## Steuerung nur über den CrewIntent des Sitzes (Mensch: CrewPlayerController, KI:
## GroundCrewBrain). Bewegung relativ zur Blickrichtung look_yaw (0 = Blick nach -Z).
## Kinematisch und deterministisch: waagerecht move_and_slide (Kollision mit Flugzeugen,
## Fahrzeugen, Gebäuden), senkrecht exakt auf height_at. Die Kapsel schwebt CAPSULE_LIFT
## über dem Boden, damit sie das Gelände nicht berührt.
##
## Animations-Schnittstelle für Paket 12: anim_state (AnimState) und anim_speed (m/s);
## ist anim_tree gesetzt (AnimationTree mit StateMachine unter "parameters/playback"),
## reist die Figur zu den Zuständen ANIM_NAMES und setzt "parameters/speed" falls vorhanden.

signal focus_changed(it: Interactable)
signal anim_state_changed(state: int)
signal view_toggle_requested
signal action_performed(it: Interactable, action_id: StringName)
signal carried_changed(item: Node)
signal seat_request_result(result: int, seat: Seat)

enum AnimState { IDLE, WALK, RUN, CARRY, HOSE, WORK, ENTER }
const ANIM_NAMES: Array[StringName] = [&"idle", &"walk", &"run", &"carry", &"hose", &"work", &"enter"]

const WALK_SPEED := 1.6
const SPRINT_SPEED := 4.5
const ACCEL := 12.0
const TURN_RATE := 10.0
const EYE_HEIGHT := 1.62
const CHEST_HEIGHT := 1.1
const CAPSULE_RADIUS := 0.3
const CAPSULE_HEIGHT := 1.6
const CAPSULE_LIFT := 0.15
const RUN_THRESHOLD := 2.4
const ENTER_ANIM_TIME := 0.8

var crew_seat: Seat
var nation_id: int = Nations.BLUE
## Getragener Gegenstand (CarryItem) oder null.
var carried = null
## Sitz, in dem die Figur gerade sitzt (null = zu Fuß).
var in_seat: Seat = null

## Körper-Gierwinkel (rad, 0 = Blick nach -Z) und Blick aus dem Intent.
var heading := 0.0
var look_yaw := 0.0
var look_pitch := 0.0
## Ego-Sicht: Körper dreht immer mit dem Blick (setzt CrewCamera).
var face_look := false

var focus: Interactable = null
var working := false
var hold_t := 0.0
var hold_progress := 0.0
var _hold_key := ""
var _hold_done := false
## Nach einer ausgelösten Aktion erst Taste loslassen (keine Kettenauslösung).
var _await_release := false

var anim_state: int = AnimState.IDLE
var anim_speed := 0.0
var anim_tree: AnimationTree = null
var _enter_anim_t := 0.0

var visual: Node3D
var carry_point: Node3D
var hand_r: Node3D
var hand_l: Node3D
var _shape: CollisionShape3D


func _init() -> void:
	collision_layer = Layers.CHARACTER
	collision_mask = Layers.WORLD | Layers.AIRCRAFT | Layers.GROUND_VEHICLE
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	crew_seat = Seat.new()
	crew_seat.name = "CrewSeat"
	crew_seat.role = Seat.Role.CREW
	crew_seat.vehicle = self
	add_child(crew_seat)
	_shape = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = CAPSULE_RADIUS
	cap.height = CAPSULE_HEIGHT
	_shape.shape = cap
	_shape.position.y = CAPSULE_LIFT + CAPSULE_HEIGHT * 0.5
	add_child(_shape)
	_build_placeholder()


## Platzhalter bis Paket 12: Kapsel-Körper, Kopf, Mütze, Nase in Blickrichtung.
func _build_placeholder() -> void:
	visual = Node3D.new()
	visual.name = "Visual"
	add_child(visual)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.32, 0.36, 0.28) if nation_id == Nations.BLUE else Color(0.4, 0.3, 0.25)
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.85, 0.68, 0.55)
	var body := MeshInstance3D.new()
	var bm := CapsuleMesh.new()
	bm.radius = 0.24
	bm.height = 1.35
	body.mesh = bm
	body.material_override = cloth
	body.position.y = 0.72
	visual.add_child(body)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.13
	hm.height = 0.26
	head.mesh = hm
	head.material_override = skin
	head.position.y = 1.56
	visual.add_child(head)
	var capm := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(0.24, 0.06, 0.3)
	capm.mesh = cm
	capm.material_override = cloth
	capm.position = Vector3(0, 1.67, -0.04)
	visual.add_child(capm)
	carry_point = _marker(ServiceMarkers.CARRY, Vector3(0, 1.0, -0.42))
	hand_r = _marker(ServiceMarkers.HAND_R, Vector3(0.22, 0.95, -0.35))
	hand_l = _marker(ServiceMarkers.HAND_L, Vector3(-0.22, 0.95, -0.35))


## Paket 14: Modell (characters/crew/anim/crew_model.tscn) statt Platzhalter. Übernimmt den
## AnimationTree (Zustände wie ANIM_NAMES). Rückgabe: Anzahl MeshInstance3D im Modell.
func apply_model(model: Node3D) -> int:
	if model == null:
		return 0
	for c in visual.get_children():
		visual.remove_child(c)
		c.queue_free()
	model.name = "Model"
	visual.add_child(model)
	var at := model.find_child("AnimationTree", true, false) as AnimationTree
	if at != null:
		at.active = true
		anim_tree = at
		var s := anim_state
		anim_state = -1
		set_anim_state(s)
	return model.find_children("*", "MeshInstance3D", true, false).size()


func _marker(n: String, p: Vector3) -> Node3D:
	var m := Node3D.new()
	m.name = n
	m.position = p
	add_child(m)
	return m


func _ready() -> void:
	_snap_to_ground()


func _physics_process(dt: float) -> void:
	if in_seat != null:
		return
	step(crew_seat.poll_crew(dt), dt)


## Ein Simulationsschritt mit Intent (auch direkt aus Tests aufrufbar).
func step(i: CrewIntent, dt: float) -> void:
	look_yaw = i.look_yaw
	look_pitch = i.look_pitch
	if i.view_toggle:
		view_toggle_requested.emit()
	_update_focus()
	_update_interact(i, dt)
	_update_move(i, dt)
	_after_step(i, dt)
	_update_anim(dt)


## Paket 5: Ablegen (G) und Einsteigen (F) als Flanken aus dem Intent.
func _after_step(i: CrewIntent, _dt: float) -> void:
	if i.drop and carried != null:
		drop_item()
	if i.enter:
		try_enter()


# --- Tragen (Paket 5) ----------------------------------------------------------

## Nur Server: Gegenstand aufnehmen (Hände müssen frei sein).
func pick_up(item: CarryItem) -> bool:
	if not Authority.is_server() or item == null or carried != null:
		return false
	if item.holder != null or item.locked:
		return false
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	carry_point.add_child(item)
	item.position = Vector3.ZERO
	item.rotation = Vector3.ZERO
	carried = item
	item.on_picked(self)
	carried_changed.emit(item)
	return true


## Nur Server: Gegenstand vor die Füße legen. Rückgabe: der Gegenstand (oder null).
func drop_item() -> CarryItem:
	var item := release_item()
	if item == null:
		return null
	var p := global_position + yaw_forward(heading) * 0.6
	p = item.constrain(p)
	_world_host().add_child(item)
	item.global_position = Vector3(p.x, WorldGround.height_at(p.x, p.z), p.z)
	item.rotation = Vector3(0.0, heading, 0.0)
	return item


## Nur Server: Gegenstand aus der Hand lösen, ohne ihn abzulegen (Verbraucher übernimmt,
## z. B. Schlauch ankoppeln, Kiste in den Wagen). Der Gegenstand hat danach keinen Eltern-Knoten.
func release_item() -> CarryItem:
	if not Authority.is_server() or carried == null or not is_instance_valid(carried):
		carried = null
		return null
	var item: CarryItem = carried
	carried = null
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	item.on_dropped(self)
	carried_changed.emit(null)
	return item


func _world_host() -> Node:
	var host: Node = self
	while host.get_parent() != null and host.get_parent() != get_tree().root:
		host = host.get_parent()
	return host if host != self else get_parent()


# --- Einsteigen (Paket 5) ------------------------------------------------------

## Nächster Sitz-Punkt (Interactable mit seat) in Seat.ENTRY_RANGE, Blickrichtung bevorzugt.
func seat_candidate() -> Seat:
	var best: Seat = null
	var best_s := INF
	var fwd := yaw_forward(look_yaw)
	for it in Interactable.all():
		if it.seat == null or not it.enabled or it.seat.is_human_occupied():
			continue
		var to := it.seat.entry_position() - global_position
		var d := Vector2(to.x, to.z).length()
		if d > Seat.ENTRY_RANGE:
			continue
		var s := d + (1.0 - Vector3(to.x, 0, to.z).normalized().dot(fwd)) * 0.5
		if s < best_s:
			best_s = s
			best = it.seat
	return best


## F: über SeatService einsteigen. Getragenes wird vorher abgelegt.
func try_enter(s: Seat = null) -> int:
	var seat_t := s if s != null else seat_candidate()
	var svc := SeatService.current
	var res := SeatService.Result.INVALID
	if seat_t != null and svc != null and crew_seat.controller != null:
		if carried != null:
			drop_item()
		res = svc.request_enter(crew_seat.controller.peer_id, self, seat_t)
	seat_request_result.emit(res, seat_t)
	return res


# --- Bewegung ------------------------------------------------------------------

func _update_move(i: CrewIntent, dt: float) -> void:
	var target_speed := current_max_speed(i.sprint)
	var fwd := yaw_forward(look_yaw)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var mv := i.move.limit_length(1.0)
	var want := (right * mv.x + fwd * mv.y) * target_speed
	if working:
		want = Vector3.ZERO
	var hv := Vector3(velocity.x, 0.0, velocity.z).move_toward(want, ACCEL * dt)
	velocity = hv
	if hv.length_squared() > 1e-6:
		move_and_slide()
		velocity.y = 0.0
	_constrain_position()
	_snap_to_ground()
	# Körper drehen: Ego bzw. Arbeiten -> Blick, sonst Laufrichtung
	var face := heading
	if face_look or working:
		face = look_yaw
	elif want.length_squared() > 0.01:
		face = atan2(-want.x, -want.z)
	heading = rotate_toward(heading, face, TURN_RATE * dt)
	rotation = Vector3(0.0, heading, 0.0)


## Höchsttempo: Gehen bzw. Sprint, mal Lastfaktor des getragenen Gegenstands.
func current_max_speed(sprint: bool) -> float:
	var mul := 1.0
	var can_sprint := true
	if carried != null and is_instance_valid(carried):
		mul = float(carried.get("speed_mul"))
		can_sprint = bool(carried.get("can_sprint"))
	return (SPRINT_SPEED if sprint and can_sprint else WALK_SPEED) * mul


## Haken für Leinen (Schlauch, Paket 5): carried.constrain(pos) begrenzt die Position.
func _constrain_position() -> void:
	if carried != null and is_instance_valid(carried) and carried.has_method("constrain"):
		var p: Vector3 = carried.call("constrain", global_position)
		global_position = Vector3(p.x, global_position.y, p.z)


func _snap_to_ground() -> void:
	var p := global_position
	p.y = WorldGround.height_at(p.x, p.z)
	global_position = p


static func yaw_forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))


## Blickrichtung (mit Nicken), Augenhöhe.
func look_dir() -> Vector3:
	var f := yaw_forward(look_yaw)
	return (f * cos(look_pitch) + Vector3.UP * sin(look_pitch)).normalized()


func eye_position() -> Vector3:
	return global_position + Vector3.UP * EYE_HEIGHT


# --- Interaktion ---------------------------------------------------------------

func _update_focus() -> void:
	var f := InteractionQuery.pick(global_position + Vector3.UP * CHEST_HEIGHT,
		yaw_forward(look_yaw), Interactable.all())
	if f != focus:
		focus = f
		focus_changed.emit(f)


## Aktion, die „Interagieren“ gerade auslösen würde (oder leer).
func current_action() -> Dictionary:
	if focus == null:
		return {}
	for a in focus.actions_for(self):
		if a.id != InteractionPoints.ENTER:     # Einsteigen läuft über F (try_enter)
			return a
	return {}


func _update_interact(i: CrewIntent, dt: float) -> void:
	if not i.interact:
		_await_release = false
	var a := current_action() if i.interact and not _await_release else {}
	if a.is_empty():
		_reset_hold()
		return
	var key := "%d:%s" % [focus.get_instance_id(), a.id]
	if key != _hold_key:
		_reset_hold()
		_hold_key = key
	if _hold_done:
		return
	var hs := float(a.hold_s)
	hold_t += dt
	var cont: bool = a.get("continuous", false)
	hold_progress = clampf(hold_t / hs, 0.0, 1.0) if hs > 0.0 else 1.0
	if cont:
		hold_progress = 0.0   # Dauer-Aktion (Pumpen, Befüllen): nur holding, nie fertig
	working = hs > 0.0 or cont
	var it := focus
	it.holding.emit(a.id, self, dt, hold_progress)
	if hold_progress >= 1.0 and not _hold_done:
		_hold_done = true
		_await_release = true
		working = false
		it.performed.emit(a.id, self)
		action_performed.emit(it, a.id)


func _reset_hold() -> void:
	_hold_key = ""
	hold_t = 0.0
	hold_progress = 0.0
	_hold_done = false
	working = false


## Paket 12/Jobs: Dauerarbeit (z. B. Pumpen) von außen anzeigen.
func set_working(on: bool) -> void:
	working = on


# --- Animation -----------------------------------------------------------------

func _update_anim(dt: float) -> void:
	anim_speed = Vector3(velocity.x, 0.0, velocity.z).length()
	_enter_anim_t = maxf(_enter_anim_t - dt, 0.0)
	var s := AnimState.IDLE
	var kind := StringName(carried.get("kind")) if carried != null and is_instance_valid(carried) else &""
	if _enter_anim_t > 0.0:
		s = AnimState.ENTER
	elif working:
		s = AnimState.WORK
	elif kind == &"hose":
		s = AnimState.HOSE
	elif kind != &"":
		s = AnimState.CARRY
	elif anim_speed > RUN_THRESHOLD:
		s = AnimState.RUN
	elif anim_speed > 0.2:
		s = AnimState.WALK
	set_anim_state(s)


func set_anim_state(s: int) -> void:
	if s == anim_state:
		_push_anim_speed()
		return
	anim_state = s
	anim_state_changed.emit(s)
	if anim_tree != null:
		var pb = anim_tree.get("parameters/playback")
		if pb is AnimationNodeStateMachinePlayback:
			(pb as AnimationNodeStateMachinePlayback).travel(ANIM_NAMES[s])
	_push_anim_speed()


func _push_anim_speed() -> void:
	if anim_tree != null and anim_tree.get("parameters/speed") != null:
		anim_tree.set("parameters/speed", anim_speed)


## Ego-Sicht: Körper ausblenden (CrewCamera), Gegenstand bleibt sichtbar.
func set_ego(on: bool) -> void:
	face_look = on
	if visual != null:
		visual.visible = not on


# --- Sitze (SeatService) -------------------------------------------------------

func on_entered_seat(s: Seat) -> void:
	in_seat = s
	visible = false
	collision_layer = 0
	velocity = Vector3.ZERO
	_reset_hold()
	process_mode = Node.PROCESS_MODE_DISABLED


func on_exited_seat(_s: Seat, pos: Vector3) -> void:
	in_seat = null
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = Layers.CHARACTER
	visible = true
	global_position = pos
	_snap_to_ground()
	velocity = Vector3.ZERO
	_enter_anim_t = ENTER_ANIM_TIME
	set_anim_state(AnimState.ENTER)


func seat_speed() -> float:
	return Vector3(velocity.x, 0.0, velocity.z).length()


func seat_on_ground() -> bool:
	return true
