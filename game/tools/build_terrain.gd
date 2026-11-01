extends SceneTree
## Erzeugt die Höhenkarte der Prototyp-Karte (Paket 12) und speichert sie als Ressource.
## Aufruf (aus game/): godot --headless --path . --script res://tools/build_terrain.gd [-- seed]

const OUT := "res://world/terrain/data/terrain_main.res"


func _initialize() -> void:
	var s := 1916
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		s = int(args[0])
	var t0 := Time.get_ticks_msec()
	var gen := TerrainGenerator.new(s)
	var td := gen.build()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT.get_base_dir()))
	var err := ResourceSaver.save(td, OUT, ResourceSaver.FLAG_COMPRESS)
	var size := FileAccess.get_file_as_bytes(OUT).size()
	print("Gelände (Seed %d) in %.1f s erzeugt: %s, %.1f MB, Fehler %d" % [s, (Time.get_ticks_msec() - t0) / 1000.0, OUT, size / 1048576.0, err])
	for a in td.airfields:
		print("  Flugplatz %s: %s" % [a.name, a.center])
	for t in td.targets:
		print("  Ziel %s: %s" % [t.name, t.pos])
	if OS.has_environment("TERRAIN_PREVIEW"):
		_preview(td, OS.get_environment("TERRAIN_PREVIEW"))
	quit(0 if err == OK else 1)


## Übersichtsbild (Schummerung + Maske) zur Kontrolle.
func _preview(td: TerrainData, path: String) -> void:
	var hs := td.decode_heights()
	var mask := td.decode_mask()
	var n := td.samples
	var r := 1024
	var img := Image.create(r, r, false, Image.FORMAT_RGB8)
	var step := (n - 1) / r
	for j in r:
		for i in r:
			var gi := clampi(i * step, 1, n - 2)
			var gj := clampi(j * step, 1, n - 2)
			var h := hs[gj * n + gi]
			var shade := clampf(0.75 + (hs[gj * n + gi - 1] - hs[gj * n + gi + 1]) * 0.03 + (hs[(gj - 1) * n + gi] - hs[(gj + 1) * n + gi]) * 0.03, 0.2, 1.3)
			var m := mask.get_pixel(i, j)
			var c := Color(0.45, 0.6, 0.3).lerp(Color(0.75, 0.68, 0.4), m.a * 0.6)
			c = c.lerp(Color(0.15, 0.3, 0.12), m.r).lerp(Color(0.2, 0.35, 0.6), m.b).lerp(Color(0.8, 0.8, 0.8), m.g)
			c = c.lerp(Color(0.6, 0.55, 0.5), clampf((h - 450.0) / 400.0, 0.0, 1.0))
			img.set_pixel(i, j, c * shade)
	img.save_png(path)
