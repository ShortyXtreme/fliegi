class_name TestSuite
extends Node
## Basisklasse für Testdateien in tests/suites/ (auch Unterordner, z. B. tests/suites/weapons/).
## Der Läufer findet jede *.gd dort automatisch, instanziiert sie und ruft alle Methoden
## "test_*" auf (Reihenfolge wie in der Datei). Jede Testmethode gibt [ok: bool, text: String]
## zurück und darf await benutzen. Vor jedem Test baut der Läufer eine frische Welt
## (make_world(), Standard TestWorld) mit einem ProjectileSystem darin.
##
## Suite wählen: in der Datei  const SUITE := "slow"  (Standard "fast").
## Einzelne Tests abweichend:  const TEST_SUITES := {"test_lange_sache": "slow"}
## Aufruf: tests/run_tests.sh [--suite=fast|slow|all] [--only=teilname] [--file=teilname]

const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"

## Aktuelle Testwelt (vom Läufer gesetzt).
var world: Node3D
## Geschosse der Testwelt (vom Läufer gesetzt).
var projectiles: ProjectileSystem


## Welt für einen Test. Überschreiben z. B. für TerrainWorld oder eine Duell-Arena.
func make_world() -> Node3D:
	return TestWorld.new()


## Optionale Hooks je Test.
func before_each() -> void:
	pass


func after_each() -> void:
	pass


# --- Helfer (aus dem M1-Läufer) -------------------------------------------------

func _spawn(on_ground := true, alt := 600.0, speed := 0.0, throttle := 0.0) -> Aircraft:
	var a := Aircraft.create(load(FIGHTER), false)
	world.add_child(a)
	if on_ground:
		a.place_on_ground(world.runway_spawn(), TestWorld.RUNWAY_DIR)
	else:
		var b := Basis.looking_at(TestWorld.RUNWAY_DIR, Vector3.UP)
		a.place(Transform3D(b, Vector3(0, alt, 0)), speed, throttle)
	return a


func _seat(a: Aircraft, logic: Callable) -> ScriptedController:
	var c := ScriptedController.new()
	c.logic = logic
	a.add_child(c)
	a.pilot_seat.possess(c)
	return c


func _step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


static func kmh(v: float) -> float:
	return v * 3.6
