class_name PackLoader
extends RefCounted
## M3.3: Ressourcen-Pakete. Der Windows-Build besteht aus Flugkern.pck (Code, Szenen, UI, Schriften,
## Daten) und den Zusatzpaketen unten (je ≤ 30 MB, tools/split_pck.py). Die Startszene (ui/boot.tscn)
## lädt sie per ProjectSettings.load_resource_pack, bevor Hauptmenü/Spiel Modelle oder Karte brauchen.
## Pflichtpaket fehlt -> Fehlermeldung statt Absturz; Audio fehlt -> stumm.
## Jedes Zusatzpaket enthält res://pack_info/<id>.txt mit der Version (Diagnose).

## [Datei, Kennung, Pflicht]
const PACKS := [["Flugkern_modelle.pck", "modelle", true], ["Flugkern_karte.pck", "karte", true],
	["Flugkern_audio.pck", "audio", false]]
const INFO := "res://pack_info/%s.txt"

## Ergebnis des letzten load_all(): Kennung -> {file, size, version, loaded}
static var status := {}
static var missing_required: Array[String] = []


## Ordner der Pakete: Option `-- --pakete=<ordner>` (Tests/Selbsttest mit Editor-Binary), neben
## --main-pack, sonst neben der .exe (Export). Leer = Projekt läuft aus dem Quellordner.
static func pack_dir(args: PackedStringArray = OS.get_cmdline_args()) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pakete="):
			return a.trim_prefix("--pakete=")
	var i := args.find("--main-pack")
	if i >= 0 and i + 1 < args.size():
		return args[i + 1].get_base_dir()
	if OS.has_feature("template"):
		return OS.get_executable_path().get_base_dir()
	return ""


static func load_all(dir: String = pack_dir()) -> bool:
	status.clear()
	missing_required.clear()
	if dir == "":
		return true
	for p in PACKS:
		var path := dir.path_join(p[0])
		var st := {"file": p[0], "size": 0, "version": "-", "loaded": false}
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			st.size = f.get_length() if f != null else 0
			st.loaded = ProjectSettings.load_resource_pack(path, true)
			if st.loaded and FileAccess.file_exists(INFO % p[1]):
				st.version = FileAccess.get_file_as_string(INFO % p[1]).strip_edges()
		if not st.loaded and p[2]:
			missing_required.append(p[0])
		status[p[1]] = st
	return missing_required.is_empty()


static func diagnostics() -> String:
	if status.is_empty():
		return "Pakete: Quellordner (keine Zusatzpakete nötig)"
	var parts := []
	for k in status:
		var st: Dictionary = status[k]
		parts.append("%s %s" % [st.file, ("%.1f MiB %s" % [st.size / 1048576.0, st.version]) if st.loaded else "FEHLT"])
	return "Pakete: " + ", ".join(parts)
