extends SceneTree
## M3.3: Packt die von tools/split_pck.py entpackten Dateien mit PCKPacker in die Ressourcen-Pakete.
## Argument: manifest.json {ziel.pck: [[res://pfad, quelldatei], ...]}


func _initialize() -> void:
	var mf: String = OS.get_cmdline_user_args()[0]
	var jobs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(mf))
	var code := 0
	for pck in jobs:
		var p := PCKPacker.new()
		if p.pck_start(pck) != OK:
			code = 1
			continue
		for e in jobs[pck]:
			if p.add_file(e[0], e[1]) != OK:
				printerr("Fehler: ", e[0])
				code = 1
		p.flush()
	quit(code)
