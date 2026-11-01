class_name GroundEvents
extends RefCounted
## M3 (Paket 0a): Ereignis-Bus für den Bodenbetrieb (Vertrag – Signaturen nur in Paket 14
## ändern). Zugriff: GroundEvents.bus().job_done.connect(...). Gesendet wird nur auf dem
## Server (JobBoard, SeatService, Lager); ab Netz repliziert. Parameter sind Nodes bzw.
## Ids, für Logs/Netz zählt entity_id bzw. job_id.

## Neuer Job (JobBoard). kind = Klassenname ("refuel", "rearm", "repair", "load_ordnance"),
## target = Flugzeug/Fahrzeug.
signal job_added(job_id: int, kind: StringName, target: Node)
## Fortschritt eines Schritts (0..1). worker = Figur/KI oder null.
signal job_progress(job_id: int, step: StringName, progress: float, worker: Node)
signal job_done(job_id: int, target: Node)
## Job blockiert, reason z. B. &"depot_empty", &"item_missing", &"engine_running".
signal job_blocked(job_id: int, reason: StringName)
## Lagerbestand geändert (FuelDepot/AmmoBunker). depot = Lager-Node.
signal depot_changed(depot: Node)
## Abfertigung einer Maschine abgeschlossen (seconds = Dauer, helpers = KI-Helfer).
signal turnaround(aircraft: Node, seconds: float, helpers: int)
## Sitzwechsel über SeatService (from/to dürfen null sein).
signal seat_changed(peer: int, from_seat: Seat, to_seat: Seat)
## Alarmstart: Countdown gestartet (s) bzw. beendet.
signal alarm_started(seconds: float)
signal alarm_ended(success: bool)

static var _bus: GroundEvents = null


static func bus() -> GroundEvents:
	if _bus == null:
		_bus = GroundEvents.new()
	return _bus


## Neuer Bus ohne Verbindungen (Testläufer vor jedem Test, Partie-Neustart).
static func reset() -> void:
	_bus = GroundEvents.new()
