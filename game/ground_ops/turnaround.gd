class_name Turnaround
extends RefCounted
## M3 (Strang G / Paket 3): Abfertigungszeit einer Maschine, Alarmstart-Countdown,
## Zeitwertung und Bestzeit (user://). Meldet GroundEvents.turnaround / alarm_started / alarm_ended.
##
## Ablauf: start(a) beim Abstellen; tick(dt) läuft mit (mit board: Helfer zählen, bei
## auto_finish fertig, sobald keine offenen Jobs mehr da sind); finish() liefert die Zeit.
## Alarm: start_alarm(s) setzt den JobBoard in den Alarm (KI ×1,25) und legt die
## Schnellabfertigung an (Munition zuerst, dann 50 % Treibstoff).

const BEST_PATH := "user://abfertigung_bestzeit.cfg"
## Richtzeiten Plan §2 (s) je Stufe: [solo, mit 2 KI-Helfern].
const REFERENCE := [[50.0, 30.0], [195.0, 100.0], [330.0, 165.0]]
## Wertung: Anteil der Richtzeit für 3/2/1 Sterne.
const STAR_LIMITS := [0.85, 1.0, 1.25]
const ALARM_DEFAULT_S := 180.0

var aircraft: Node = null
var elapsed := 0.0
var running := false
var helpers := 0
## Alarm: Restzeit (s), < 0 = kein Alarm.
var alarm_left := -1.0
var alarm_success := false
var auto_finish := true
var best_path := BEST_PATH
var board: JobBoard = null
var realism := -1
var last_stars := 0
var last_best := false
var _helper_set := {}


func start(a: Node) -> void:
	aircraft = a
	elapsed = 0.0
	running = true
	helpers = 0
	_helper_set.clear()


func tick(dt: float) -> void:
	if running:
		elapsed += dt
		if board != null and is_instance_valid(board):
			for j: GroundJob in board.jobs_for(aircraft):
				if j.worker != null and is_instance_valid(j.worker) and board.is_ai_worker(j.worker) \
						and not _helper_set.has(j.worker):
					_helper_set[j.worker] = true
			helpers = _helper_set.size()
			if auto_finish and elapsed > 0.0 and board.is_serviced(aircraft) and not board.jobs_for(aircraft).is_empty():
				finish()
	if alarm_left > 0.0:
		alarm_left = maxf(alarm_left - dt, 0.0)
		if alarm_left <= 0.0:
			_end_alarm(false)


func finish() -> float:
	if not running:
		return elapsed
	running = false
	last_stars = stars(elapsed, helpers, realism)
	last_best = save_best(elapsed, helpers, realism)
	GroundEvents.bus().turnaround.emit(aircraft, elapsed, helpers)
	if alarm_left > 0.0:
		_end_alarm(true)
	return elapsed


# --- Alarmstart -----------------------------------------------------------------

## Alarm auslösen: Countdown, KI schneller, Schnellabfertigung für a (falls angegeben).
func start_alarm(seconds: float = ALARM_DEFAULT_S, a: Aircraft = null, src: FuelSource = null,
		store: AmmoStore = null) -> Array:
	alarm_left = seconds
	alarm_success = false
	var ids := []
	if board != null:
		board.alarm = true
		if a != null:
			ids = quick_service(board, a, src, store)
	GroundEvents.bus().alarm_started.emit(seconds)
	return ids


func alarm_active() -> bool:
	return alarm_left > 0.0


func _end_alarm(success: bool) -> void:
	alarm_success = success
	alarm_left = -1.0
	if board != null and is_instance_valid(board):
		board.alarm = false
	GroundEvents.bus().alarm_ended.emit(success)


## Schnellabfertigung: volle Munition (zuerst), 50 % Treibstoff, keine Reparatur.
## Bestehende offene Jobs der Maschine bekommen Alarm-Priorität.
static func quick_service(b: JobBoard, a: Aircraft, src: FuelSource, store: AmmoStore) -> Array:
	var prio := GroundCrewBrain.Priority.ALARM * 10
	var ids := b.plan_service(a, src, store, {"fuel_target": 0.5, "repair": false, "priority": prio})
	for j: GroundJob in b.open_jobs(a):
		j.priority = prio + (1 if j is RearmJob else 0)
		if j is RefuelJob:
			j.target_fraction = minf(j.target_fraction, 0.5)
	return ids


# --- Wertung --------------------------------------------------------------------

static func reference_time(helper_count: int, r: int = -1) -> float:
	if r < 0:
		r = MatchRules.ground_realism
	var ref: Array = REFERENCE[clampi(r, 0, 2)]
	var h := clampi(helper_count, 0, 2)
	return lerpf(ref[0], ref[1], h / 2.0)


## 0–3 Sterne nach Richtzeit (Plan §2).
static func stars(seconds: float, helper_count: int, r: int = -1) -> int:
	var q := seconds / reference_time(helper_count, r)
	for i in STAR_LIMITS.size():
		if q <= STAR_LIMITS[i]:
			return 3 - i
	return 0


func best_time(helper_count: int, r: int = -1) -> float:
	var cf := ConfigFile.new()
	if cf.load(best_path) != OK:
		return -1.0
	return float(cf.get_value(_section(r), "h%d" % clampi(helper_count, 0, 2), -1.0))


## Bestzeit speichern, wenn besser. Rückgabe: true = neue Bestzeit.
func save_best(seconds: float, helper_count: int, r: int = -1) -> bool:
	var cf := ConfigFile.new()
	cf.load(best_path)
	var key := "h%d" % clampi(helper_count, 0, 2)
	var old := float(cf.get_value(_section(r), key, -1.0))
	if old > 0.0 and old <= seconds:
		return false
	cf.set_value(_section(r), key, seconds)
	cf.save(best_path)
	return true


static func _section(r: int) -> String:
	return MatchRules.ground_realism_name(r)
