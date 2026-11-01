class_name InteractionPoints
extends RefCounted
## M3 (Paket 5, Strang H): legt Interaktionspunkte an Markern an.
## seat_point(seat): Punkt am Einstieg (Aktion &"enter", Taste F, CrewCharacter.try_enter).
## for_aircraft(a): Punkte svc_fuel_cap, svc_gun_hatch_L/R, svc_engine (ohne Aktionen –
## die hängen die Jobs von Strang G an) und svc_entry mit dem Pilotensitz.

const ENTER := &"enter"


static func seat_point(s: Seat, label := "Einsteigen", parent: Node3D = null) -> Interactable:
	var it := Interactable.new()
	it.name = "Seat_%s" % s.name
	it.seat = s
	it.target = s.vehicle
	it.marker = ServiceMarkers.SVC_ENTRY if s.vehicle is Aircraft else ServiceMarkers.SEAT_DRIVER
	it.add_action(ENTER, label, 0.0, &"", func(_c): return not s.is_human_occupied())
	it.position = s.entry_offset
	var host := parent if parent != null else s.vehicle
	host.add_child(it)
	return it


## Punkt an einem Marker des Flugzeugs (lokale Position aus ServiceMarkers).
static func aircraft_point(a: Node3D, marker: String) -> Interactable:
	var it := Interactable.new()
	it.name = "Svc_" + marker
	it.marker = marker
	it.target = a
	it.position = ServiceMarkers.aircraft_point(a, marker)
	a.add_child(it)
	return it


static func for_aircraft(a: Aircraft) -> Dictionary:
	var out := {}
	for m in [ServiceMarkers.SVC_FUEL_CAP, ServiceMarkers.SVC_GUN_HATCH_L,
			ServiceMarkers.SVC_GUN_HATCH_R, ServiceMarkers.SVC_ENGINE]:
		out[m] = aircraft_point(a, m)
	out[ServiceMarkers.SVC_ENTRY] = seat_point(a.pilot_seat, "Einsteigen (Pilot)")
	return out
