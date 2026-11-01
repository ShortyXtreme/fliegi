class_name PilotRecord
extends RefCounted
## Pilot eines Spielers/KI innerhalb der Partie (GDD §6.1). Nur Datenstruktur
## (Paket 6, Agent B). XP werden erst bei Landung am eigenen Platz gutgeschrieben
## (xp_pending -> xp_banked). Stirbt der Pilot, verfallen die offenen XP.

static var _next_id := 1

var id: int
var level := 1
var xp_banked := 0
## Offene XP-Einträge {"amount": int, "reason": String}.
var xp_pending: Array = []
var alive := true
## Zustand für SpawnManager/HUD.
var ejected := false
## Simulations-Ausfallzeit nach Ausstieg (s), vom SpawnManager gezählt.
var downtime := 0.0


func _init() -> void:
	id = _next_id
	_next_id += 1


## Level-Hooks (M2 neutral). Spotting nutzt zusätzlich Spotting.crew_level_mul(level).
func dispersion_mul() -> float:
	return 1.0


func spot_range_mul() -> float:
	return Spotting.crew_level_mul(level)


func add_xp(amount: int, reason := "") -> void:
	if alive and amount > 0:
		xp_pending.append({"amount": amount, "reason": reason})


func pending_total() -> int:
	var s := 0
	for e in xp_pending:
		s += int(e.amount)
	return s


## Landung am eigenen Platz: offene XP gutschreiben.
func bank_xp() -> int:
	var s := pending_total()
	xp_banked += s
	xp_pending.clear()
	return s


func on_ejected() -> void:
	ejected = true


func on_killed() -> void:
	alive = false
	xp_pending.clear()
