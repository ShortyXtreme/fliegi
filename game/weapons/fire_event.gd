class_name FireEvent
extends RefCounted
## Abzugsphase einer Waffengruppe (Netzmodell, Plan M2 §2): Statt jedes Geschoss zu senden,
## überträgt der Schütze nur {shooter_id, gun_group, tick_on, tick_off}; Schusszeiten folgen
## aus der Kadenz. tick_off = -1: Abzug noch gedrückt.

var shooter_id := 0
var gun_group := 0
var tick_on := 0
var tick_off := -1
## Erste Schussnummer der Phase (Server-Buchhaltung, nicht übertragen).
var shot_first := 0


func contains(tick: int) -> bool:
	return tick >= tick_on and (tick_off < 0 or tick < tick_off)


## Dauer in Ticks (offen: bis `now`).
func ticks(now := -1) -> int:
	return (tick_off if tick_off >= 0 else now) - tick_on


## Höchstzahl Schüsse je Waffe in der Phase bis `now` (Kadenz, inkl. Schuss im ersten Tick).
func max_shots(interval: float, dt: float, now := -1) -> int:
	return int(floor(maxi(ticks(now), 0) * dt / interval + 1e-6)) + 1


func to_array() -> Array:
	return [shooter_id, gun_group, tick_on, tick_off]


static func from_array(a: Array) -> FireEvent:
	var e := FireEvent.new()
	e.shooter_id = a[0]
	e.gun_group = a[1]
	e.tick_on = a[2]
	e.tick_off = a[3]
	return e
