class_name HitDebug
extends Node
## Treffer-Debug (M2.1): sammelt alle Zieltreffer (auch abgelehnte) aus
## ProjectileSystem.hit_resolved und CombatEvents.aircraft_damaged – reine Daten, ohne
## Rendering (HitDebugOverlay zeichnet sie im Debug-Modus F3).
## Schreibt außerdem jedes Ereignis als CSV-Zeile nach user://logs/kampf_YYYYMMDD_HHMMSS.csv
## (unter Windows: %APPDATA%\Godot\app_userdata\Flugkern M2\logs\).

const MAX_ENTRIES := 300
const MARKER_TIME := 1.6
const ARROW_TIME := 2.5
const REJECT_TIME := 4.0
const LOG_DIR := "user://logs"
const ZONE_LABELS := ["Motor", "Tank L", "Tank R", "Flügel L", "Flügel R", "Leitwerk", "Cockpit"]
const RESULT_NAMES := ["OK", "Schütze unbekannt", "Schuss unbekannt", "doppelt", "kein Abzug",
	"Kadenz", "Ziel unbekannt", "Eigentreffer", "Tick in Zukunft", "kein Verlauf", "vor dem Schuss",
	"Flugzeit", "außerhalb Ziel", "Position", "Zone"]

## Eigenes Flugzeug (vom Game/HUD gesetzt; darf beim Neustart wechseln).
var own: Node3D
## Treffer zwischen anderen in der Liste zeigen (Taste F6 im Debug-Modus).
var show_others := false
## Laufzeit (s) seit Start; Zeitstempel der Einträge.
var time := 0.0
## Je Eintrag: {t, shooter, shooter_name, target, target_name, zone, zone_name, damage,
##  nominal, distance, world_point, local_point, result, reason, dir}
var entries: Array[Dictionary] = []
## Abgelehnte Treffer insgesamt.
var rejected_total := 0
var log_enabled := true
var log_path := ""

var _ps: ProjectileSystem
var _bus: CombatEvents
var _last_dmg := {}   # Flugzeug -> tatsächlicher HP-Verlust des laufenden Treffers
var _file: FileAccess


func _ready() -> void:
	name = "HitDebug"
	_connect()


func _exit_tree() -> void:
	if _file != null:
		_file.close()
		_file = null


static func zone_label(z: int) -> String:
	return ZONE_LABELS[z] if z >= 0 and z < ZONE_LABELS.size() else "Rumpf"


static func result_name(r: int) -> String:
	return RESULT_NAMES[r] if r >= 0 and r < RESULT_NAMES.size() else "?"


static func name_of(n: Node) -> String:
	if n == null or not is_instance_valid(n):
		return "?"
	if n.has_meta("display_name"):
		return str(n.get_meta("display_name"))
	return String(n.name)


func _connect() -> void:
	var ps := ProjectileSystem.current
	if ps != _ps and ps != null:
		_ps = ps
		ps.hit_resolved.connect(on_hit_resolved)
	var b := CombatEvents.bus()
	if b != _bus:
		_bus = b
		b.aircraft_damaged.connect(_on_damaged)


func _physics_process(dt: float) -> void:
	tick(dt)


func tick(dt: float) -> void:
	time += dt
	_connect()


func _on_damaged(a: Node, _zone: int, dmg: float, _attacker: Node) -> void:
	_last_dmg[a] = float(_last_dmg.get(a, 0.0)) + dmg


## Öffentlich für Tests: ein Treffer (aus ProjectileSystem.hit_resolved).
func on_hit_resolved(shooter: Node, target: Node, zone: int, nominal: float, world_point: Vector3,
		local_point: Vector3, result: int) -> void:
	var real := float(_last_dmg.get(target, 0.0))
	_last_dmg.erase(target)
	var sp := (shooter as Node3D).global_position if shooter is Node3D and is_instance_valid(shooter) \
			else world_point
	var e := {
		"t": time, "shooter": shooter, "shooter_name": name_of(shooter),
		"target": target, "target_name": name_of(target), "zone": zone, "zone_name": zone_label(zone),
		"damage": real, "nominal": nominal, "distance": sp.distance_to(world_point),
		"world_point": world_point, "local_point": local_point, "result": result,
		"reason": result_name(result), "dir": (sp - world_point),
	}
	entries.append(e)
	if entries.size() > MAX_ENTRIES:
		entries.remove_at(0)
	if result != HitValidator.Result.OK:
		rejected_total += 1
	_log(e)


func _is_own(n) -> bool:
	return own != null and is_instance_valid(own) and n == own


## Eigene (angenommene) Treffer, neueste zuerst.
func mine(n := 8) -> Array:
	return _filter(func(e): return _is_own(e.shooter) and e.result == 0, n)


## Treffer auf das eigene Flugzeug, neueste zuerst.
func received(n := 8) -> Array:
	return _filter(func(e): return _is_own(e.target) and e.result == 0, n)


## Treffer zwischen anderen (KI gegen KI, auf Verbündete).
func others(n := 6) -> Array:
	return _filter(func(e): return not _is_own(e.shooter) and not _is_own(e.target) and e.result == 0, n)


## Abgelehnte Treffer (HitValidator) der letzten REJECT_TIME s.
func rejected_recent() -> Array:
	return _filter(func(e): return e.result != 0 and time - e.t < REJECT_TIME, 20)


## Markierungen an eigenen Treffern: [{target, local_point, text, age}].
func markers() -> Array:
	var out := []
	for e in mine(20):
		var age: float = time - e.t
		if age < MARKER_TIME and is_instance_valid(e.target):
			out.append({"target": e.target, "local_point": e.local_point, "age": age,
				"text": "%s −%d" % [e.zone_name, int(round(e.damage))]})
	return out


## Richtungen erhaltener Treffer (Welt, vom Spieler zum Schützen): [{dir, age, shooter_name}].
func incoming() -> Array:
	var out := []
	var seen := {}
	for e in received(10):
		var age: float = time - e.t
		if age < ARROW_TIME and not seen.has(e.shooter):
			seen[e.shooter] = true
			out.append({"dir": e.dir, "age": age, "shooter_name": e.shooter_name})
	return out


## Zonen-HP als Zahlen: [{zone, name, hp, max}].
static func zone_hp(a: Node) -> Array:
	var out := []
	if a == null or not is_instance_valid(a):
		return out
	var d = a.get("damage")
	if not d is DamageModel:
		return out
	for z in DamageModel.Zone.COUNT:
		out.append({"zone": z, "name": zone_label(z), "hp": d.hp[z], "max": d.hp_max[z]})
	return out


func _filter(f: Callable, n: int) -> Array:
	var out := []
	for k in range(entries.size() - 1, -1, -1):
		var e: Dictionary = entries[k]
		if f.call(e):
			out.append(e)
			if out.size() >= n:
				break
	return out


# --- CSV-Log --------------------------------------------------------------------

## Öffnet die Log-Datei (einmal je Spielstart). Rückgabe: Pfad oder "".
func open_log(stamp := "") -> String:
	if _file != null:
		return log_path
	if stamp == "":
		var d := Time.get_datetime_dict_from_system()
		stamp = "%04d%02d%02d_%02d%02d%02d" % [d.year, d.month, d.day, d.hour, d.minute, d.second]
	DirAccess.make_dir_recursive_absolute(LOG_DIR)
	log_path = "%s/kampf_%s.csv" % [LOG_DIR, stamp]
	_file = FileAccess.open(log_path, FileAccess.WRITE)
	if _file == null:
		push_warning("Treffer-Log nicht schreibbar: %s" % log_path)
		log_path = ""
		return ""
	_file.store_line("zeit_s;schuetze;ziel;zone;schaden;nennschaden;entfernung_m;ergebnis;eigen;x;y;z")
	_file.flush()
	return log_path


func absolute_log_path() -> String:
	return ProjectSettings.globalize_path(log_path) if log_path != "" else ""


func _log(e: Dictionary) -> void:
	if not log_enabled:
		return
	if _file == null and open_log() == "":
		log_enabled = false
		return
	var own_flag := "aus" if _is_own(e.shooter) else ("ein" if _is_own(e.target) else "-")
	var p: Vector3 = e.world_point
	_file.store_line("%.2f;%s;%s;%s;%.1f;%.1f;%.0f;%s;%s;%.1f;%.1f;%.1f" % [e.t, e.shooter_name,
		e.target_name, e.zone_name, e.damage, e.nominal, e.distance, e.reason, own_flag, p.x, p.y, p.z])
	_file.flush()
