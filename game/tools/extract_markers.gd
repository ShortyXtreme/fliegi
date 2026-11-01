extends SceneTree
## Marker-Extraktion (Paket 3): liest dmg_*, gun_*, hardpoint_* und weitere Punkte aus dem
## spielfertigen GLB und speichert sie als AircraftMarkers-.tres (Flugzeug-Koordinaten).
## Aufruf (im Ordner game/):
##   godot --headless --path . --script res://tools/extract_markers.gd -- \
##     [--glb=../art/models/fighter_t1_game.glb] [--out=res://vehicles/aircraft/data/markers/fighter_t1_markers.tres] \
##     [--rot-y=180] [--offset=0,0,0]
## Modell (rig.json): Nase +Z, linker Flügel +X -> Spiel: Nase -Z, also 180° um Y.

const DEFAULT_GLB := "vehicles/aircraft/models/fighter_t1_game.glb"
const DEFAULT_OUT := "res://vehicles/aircraft/data/markers/fighter_t1_markers.tres"
const FIGHTER := "res://vehicles/aircraft/data/fighter_t1.tres"


func _initialize() -> void:
	var glb := DEFAULT_GLB
	var out := DEFAULT_OUT
	var rot_y := 180.0
	var offset := Vector3.ZERO
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--glb="):
			glb = a.substr(6)
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--rot-y="):
			rot_y = float(a.substr(8))
		elif a.begins_with("--offset="):
			var p := a.substr(9).split(",")
			offset = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if not glb.begins_with("res://") and not glb.begins_with("/"):
		glb = ProjectSettings.globalize_path("res://").path_join(glb).simplify_path()
	var xf := Transform3D(Basis(Vector3.UP, deg_to_rad(rot_y)), offset)
	var m := AircraftMarkers.from_glb(glb, xf, load(FIGHTER))
	if m == null:
		printerr("Extraktion fehlgeschlagen: ", glb)
		quit(1)
		return
	m.source = "art/models/" + glb.get_file()
	var err := ResourceSaver.save(m, out)
	print("Marker: %d Zonen, %d Waffen, %d Außenlasten, %d Punkte -> %s (%s)" % [
		m.zone_names.size(), m.gun_names.size(), m.hardpoint_names.size(), m.points.size(), out, error_string(err)])
	quit(0 if err == OK else 1)
