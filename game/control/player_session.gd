class_name PlayerSession
extends Node
## M3 (Paket 0a, Stub – Paket 14 verdrahtet ihn in game.gd): Der lokale Mensch mit allen
## seinen Controllern. Er sitzt immer in genau einem Sitz (Flugzeug, Figur, Fahrzeug);
## SeatService fragt beim Sitzwechsel controller_for(role). Je nach besetztem Sitz schaltet
## die Session Eingabe-Kontext, Kamera und HUD um:
##   PILOT/GUNNER/BOMBARDIER -> FLIGHT: CameraRig + Hud.aircraft = Flugzeug
##   CREW                    -> CREW:   crew_camera (CrewCamera, Strang H), Boden-HUD
##   DRIVER/PASSENGER        -> DRIVE:  crew_camera folgt dem Fahrzeug, Boden-HUD
## Aussteigen: flight.exit_requested / drive.exit_requested -> SeatService.request_exit.
## Einsteigen löst die Figur aus (CrewIntent.enter -> SeatService.request_enter).

signal context_changed(context: int)
signal seat_changed(seat: Seat)

var peer_id: int = 1
var flight: PlayerController
var crew: Controller
var drive: DrivePlayerController
## Aktuell besetzter Sitz (oder null).
var seat: Seat = null
var context: int = InputBindings.Context.FLIGHT
## Optional (Paket 14 setzt sie): Flugkamera, Figur-/Fahrzeugkamera, HUD, Boden-HUD.
var camera_rig: CameraRig = null
var crew_camera: Node = null
var hud: Hud = null
var ground_hud: CanvasItem = null
var seat_service: SeatService = null


func _init() -> void:
	peer_id = Authority.local_peer_id()
	flight = PlayerController.new()
	flight.name = "FlightController"
	crew = CrewPlayerController.new()
	crew.name = "CrewController"
	drive = DrivePlayerController.new()
	drive.name = "DriveController"
	for c in [flight, crew, drive]:
		c.peer_id = peer_id
		c.session = self


## Bei einer vorhandenen PlayerController-Instanz (game.gd M2) diese übernehmen.
func adopt_flight(pc: PlayerController) -> void:
	if flight != null and flight != pc and flight.get_parent() == self:
		flight.queue_free()
	flight = pc
	pc.peer_id = peer_id
	pc.session = self


func _ready() -> void:
	for c in [flight, crew, drive]:
		if c.get_parent() == null:
			add_child(c)
	flight.exit_requested.connect(_on_exit_requested)
	drive.exit_requested.connect(_on_exit_requested)
	GroundEvents.bus().seat_changed.connect(_on_bus_seat_changed)


## Controller des Menschen für einen Sitz dieser Rolle (SeatService).
func controller_for(role: int) -> Controller:
	match role:
		Seat.Role.CREW:
			return crew
		Seat.Role.DRIVER, Seat.Role.PASSENGER:
			return drive
	return flight


static func context_for_role(role: int) -> int:
	match role:
		Seat.Role.CREW:
			return InputBindings.Context.CREW
		Seat.Role.DRIVER, Seat.Role.PASSENGER:
			return InputBindings.Context.DRIVE
	return InputBindings.Context.FLIGHT


## Sitz übernehmen (Server; Spielstart/Respawn). Danach Ansicht umschalten.
func take_seat(s: Seat) -> bool:
	if s == null or not s.possess(controller_for(s.role)):
		return false
	apply_view(s)
	return true


## Kamera, HUD und Eingabe-Kontext an den besetzten Sitz anpassen.
func apply_view(s: Seat) -> void:
	seat = s
	var ctx := context_for_role(s.role) if s != null else InputBindings.Context.FLIGHT
	var a := s.vehicle as Aircraft if s != null else null
	if a != null:
		if camera_rig != null:
			camera_rig.target = a
			camera_rig.player = flight
		if hud != null:
			hud.aircraft = a
	_set_active(camera_rig, ctx == InputBindings.Context.FLIGHT)
	_set_active(crew_camera, ctx != InputBindings.Context.FLIGHT)
	_set_active(ground_hud, ctx != InputBindings.Context.FLIGHT)
	if crew_camera != null and s != null and crew_camera.has_method("follow"):
		crew_camera.call("follow", s.vehicle)
	if ctx != context:
		context = ctx
		context_changed.emit(ctx)
	seat_changed.emit(s)


func _set_active(n: Node, on: bool) -> void:
	if n == null:
		return
	n.process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if n is CanvasItem:
		(n as CanvasItem).visible = on
	elif n is Camera3D:
		(n as Camera3D).current = on
	else:
		var cam := n.get_node_or_null("Camera3D") as Camera3D
		if cam != null:
			cam.current = on


func _on_exit_requested() -> void:
	var svc := seat_service if seat_service != null else SeatService.current
	if svc != null and seat != null:
		svc.request_exit(peer_id, seat)


func _on_bus_seat_changed(peer: int, _from: Seat, to: Seat) -> void:
	if peer == peer_id:
		apply_view(to)
