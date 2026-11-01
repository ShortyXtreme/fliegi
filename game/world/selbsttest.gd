class_name Selbsttest
extends Node
## M2.2: Treffer-Selbsttest im laufenden Hauptspiel (Startoption `--selbsttest`).
## Phase A: Gegner 250 m vor dem Spieler, der Spieler feuert 3 s über die echte Eingabe-
## Aktion „fire_primary“. Phase B: Gegner 250 m hinter dem Spieler feuert 3 s.
## Zählt Geschosse, Segmenttests, Trefferberichte (akzeptiert/abgelehnt) und Schaden,
## schreibt ins Godot-Log und nach user://logs/selbsttest_*.txt und beendet das Spiel
## (Exit-Code 0 = Treffer in beide Richtungen, sonst 1).

const DIST := 250.0
const FIRE_TIME := 3.0
const SETTLE := 1.0

## Gerader Flug mit festem Gas, optional Dauerfeuer.
class StraightPilot extends Controller:
	var fire := false
	func compute_intent(_dt: float) -> PilotIntent:
		var i := PilotIntent.new()
		i.throttle = 0.9
		i.gear_down = false
		i.fire_primary = fire
		return i

var game: Node
var _t := 0.0
var _phase := 0
var _enemy: Aircraft
var _pilot := StraightPilot.new()
var _lines: PackedStringArray = []
# Zähler je Phase: [geschosse, segmenttests, berichte, akzeptiert, abgelehnt, schaden]
var _c := {}
var _seg0 := 0
var _phase_key := ""


static func requested() -> bool:
	return "--selbsttest" in OS.get_cmdline_args() or "--selbsttest" in OS.get_cmdline_user_args()


func _ready() -> void:
	process_physics_priority = 1000
	add_child(_pilot)
	var ps: ProjectileSystem = game.projectiles
	ps.spawned.connect(func(_s): _count("geschosse"))
	ps.hit_resolved.connect(_on_hit)
	CombatEvents.bus().aircraft_damaged.connect(_on_damaged)
	_log("Selbsttest %s gestartet (Renderer %s, Bildrate frei: %s)" % [Hud.VERSION,
			RenderingServer.get_current_rendering_driver_name(), str(Engine.max_fps == 0)])


func _count(k: String, v := 1.0) -> void:
	if _phase_key == "":
		return
	var d: Dictionary = _c[_phase_key]
	d[k] = d.get(k, 0.0) + v


func _on_hit(_sh: Node, _tg: Node, _z: int, _dmg: float, _wp: Vector3, _lp: Vector3, res: int) -> void:
	_count("berichte")
	_count("akzeptiert" if res == HitValidator.Result.OK else "abgelehnt")


func _on_damaged(_a: Node, _z: int, dmg: float, _att: Node) -> void:
	_count("schaden", dmg)


func _physics_process(dt: float) -> void:
	_t += dt
	match _phase:
		0:
			if _t >= SETTLE:
				_start("A_spieler_schiesst", false)
		1:
			if _t >= FIRE_TIME:
				Input.action_release("fire_primary")
				_finish_phase()
				_start("B_gegner_schiesst", true)
		2:
			if _t >= FIRE_TIME:
				_pilot.fire = false
				_finish_phase()
				_done()


func _start(key: String, enemy_fires: bool) -> void:
	_phase += 1
	_t = 0.0
	_phase_key = key
	_c[key] = {}
	var pl: Aircraft = game.player_aircraft
	var enemies: Array = game.ai_aircrafts
	_enemy = enemies[0]
	var dir := Vector3(0, 0, -1)
	var b := Basis.looking_at(dir, Vector3.UP)
	var base := pl.global_position
	base.y = WorldGround.height_at(base.x, base.z) + 1500.0
	# Übrige Gegner weit weg parken, damit sie nicht stören.
	for k in range(1, enemies.size()):
		var e: Aircraft = enemies[k]
		e.place(Transform3D(b, base + Vector3(3000.0 + k * 400.0, 500.0, 0)), 110.0, 0.9, false)
	_enemy.pilot_seat.possess(_pilot)
	_pilot.fire = enemy_fires
	pl.damage.reset()
	_enemy.damage.reset()
	if enemy_fires:
		pl.place(Transform3D(b, base), 110.0, 0.9, false)
		_enemy.place(Transform3D(b, base - dir * DIST), 110.0, 0.9, false)
	else:
		pl.place(Transform3D(b, base), 110.0, 0.9, false)
		_enemy.place(Transform3D(b, base + dir * DIST), 110.0, 0.9, false)
	game.player.reset_state(0.9, false)
	if not enemy_fires:
		Input.action_press("fire_primary")
	_seg0 = game.projectiles.segment_tests


func _finish_phase() -> void:
	_count("segmenttests", float(game.projectiles.segment_tests - _seg0))
	var d: Dictionary = _c[_phase_key]
	_log("%s: Geschosse %d, Segmenttests %d, Trefferberichte %d, akzeptiert %d, abgelehnt %d, Schaden %.1f" % [
			_phase_key, int(d.get("geschosse", 0)), int(d.get("segmenttests", 0)),
			int(d.get("berichte", 0)), int(d.get("akzeptiert", 0)), int(d.get("abgelehnt", 0)),
			float(d.get("schaden", 0.0))])
	_phase_key = ""


func _done() -> void:
	var a: Dictionary = _c["A_spieler_schiesst"]
	var b: Dictionary = _c["B_gegner_schiesst"]
	var ok: bool = a.get("akzeptiert", 0) > 0 and b.get("akzeptiert", 0) > 0 \
			and a.get("schaden", 0.0) > 0.0 and b.get("schaden", 0.0) > 0.0
	_log("SELBSTTEST %s" % ("OK" if ok else "FEHLGESCHLAGEN"))
	DirAccess.make_dir_recursive_absolute("user://logs")
	var path := "user://logs/selbsttest_%s.txt" % Time.get_datetime_string_from_system().replace(":", "").replace("-", "").replace("T", "_")
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_lines) + "\n")
		f.close()
		print("Selbsttest-Ergebnis: ", ProjectSettings.globalize_path(path))
	get_tree().quit(0 if ok else 1)


func _log(s: String) -> void:
	_lines.append(s)
	print(s)
