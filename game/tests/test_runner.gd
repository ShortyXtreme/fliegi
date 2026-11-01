extends SceneTree
## Headless-Testläufer (M2, Paket 0). Aufruf über tests/run_tests.sh.
## Findet alle Testdateien unter tests/suites/ (rekursiv, *.gd mit extends TestSuite)
## automatisch – neue Tests brauchen KEINE Änderung an dieser Datei.
## Jeder Test bekommt eine frische Welt und frische globale Zustände (CombatEvents,
## Nations, MatchRules, Spotting, WorldGround). Physik mit --fixed-fps 60 deterministisch.
##
## Optionen (nach "--"):
##   --suite=fast|slow|all   Standard fast
##   --only=teil             nur Tests, deren Name "teil" enthält
##   --file=teil             nur Dateien, deren Pfad "teil" enthält
##   --list                  nur auflisten

const SUITES_DIR := "res://tests/suites"

var results: Array = []
var only := ""
var file_filter := ""
var suite := "fast"
var list_only := false


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			only = a.substr(7)
		elif a.begins_with("--suite="):
			suite = a.substr(8)
		elif a.begins_with("--file="):
			file_filter = a.substr(7)
		elif a == "--list":
			list_only = true
	_run.call_deferred()


static func find_suite_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d := DirAccess.open(dir)
	if d == null:
		return out
	var files := Array(d.get_files())
	files.sort()
	for f in files:
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	var dirs := Array(d.get_directories())
	dirs.sort()
	for sub in dirs:
		out.append_array(find_suite_files(dir.path_join(sub)))
	return out


## Testmethoden einer Suite-Instanz in Deklarationsreihenfolge.
static func test_methods(inst: Object) -> PackedStringArray:
	var out := PackedStringArray()
	var scr: Script = inst.get_script()
	for m in scr.get_script_method_list():
		var n: String = m["name"]
		if n.begins_with("test_") and not out.has(n):
			out.append(n)
	return out


static func suite_of(inst: Object, method: String) -> String:
	var consts: Dictionary = (inst.get_script() as Script).get_script_constant_map()
	var per: Dictionary = consts.get("TEST_SUITES", {})
	if per.has(method):
		return per[method]
	return consts.get("SUITE", "fast")


func _run() -> void:
	var t_all := Time.get_ticks_msec()
	for path in find_suite_files(SUITES_DIR):
		if file_filter != "" and not path.contains(file_filter):
			continue
		var scr = load(path)
		if not scr is GDScript or not (scr as GDScript).can_instantiate():
			results.append([path, false, "Skript lädt nicht (Parse-Fehler?)"])
			print("FAIL %-30s Skript lädt nicht" % path.get_file())
			continue
		var inst = scr.new()
		if not inst is TestSuite:
			if inst is Node:
				inst.free()
			continue
		var s: TestSuite = inst
		s.name = path.get_file().get_basename()
		root.add_child(s)
		var methods := test_methods(s)
		for m in methods:
			if only != "" and not m.contains(only):
				continue
			if suite != "all" and suite_of(s, m) != suite:
				continue
			if list_only:
				print("%-5s %-28s %s" % [suite_of(s, m), m, path.get_file()])
				continue
			await _run_one(s, m)
		s.queue_free()
		await process_frame
	if list_only:
		quit(0)
		return
	var failed := results.filter(func(x): return not x[1]).size()
	print("\n%d/%d Tests bestanden (Suite %s, %.1f s)" % [results.size() - failed, results.size(),
		suite, (Time.get_ticks_msec() - t_all) / 1000.0])
	if results.is_empty():
		print("Hinweis: keine Tests ausgewählt (Suite %s)" % suite)
	quit(1 if failed > 0 else 0)


func _reset_globals() -> void:
	CombatEvents.reset()
	Nations.reset()
	MatchRules.reset()
	Spotting.reset()
	WorldGround.clear_provider()
	ProjectileSystem.reset_targets()


func _run_one(s: TestSuite, m: String) -> void:
	_reset_globals()
	var w := s.make_world()
	w.name = "World"
	root.add_child(w)
	var ps := ProjectileSystem.new()
	ps.name = "Projectiles"
	w.add_child(ps)
	s.world = w
	s.projectiles = ps
	await physics_frame
	s.before_each()
	var t0 := Time.get_ticks_msec()
	var r = await s.call(m)
	s.after_each()
	var ok: bool = r is Array and r.size() >= 2 and r[0] == true
	var text: String = str(r[1]) if r is Array and r.size() >= 2 else "ungültige Rückgabe (erwartet [ok, text])"
	results.append([m, ok, text])
	print("%s %-28s %s  (%.1fs)" % ["PASS" if ok else "FAIL", m, text,
		(Time.get_ticks_msec() - t0) / 1000.0])
	w.queue_free()
	s.world = null
	s.projectiles = null
	await process_frame
