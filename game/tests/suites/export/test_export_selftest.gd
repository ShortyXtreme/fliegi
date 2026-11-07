extends TestSuite
## M2.2 Regression: Das EXPORTIERTE Spiel (.pck) muss Treffer in beide Richtungen erzeugen.
## M3: dazu die Boden-Phasen C–E und die Diagnose (Modelle, Animationen, Layout, Lager).
## Hintergrund: Beim Export gingen durch die Text->Binär-Umwandlung die Trefferzonen der
## Marker-Ressource verloren (0 Zonen -> nie ein Treffer), obwohl alle Projekttests grün waren.
## Ablauf: .pck exportieren (Preset „Windows Desktop“), Spiel daraus mit `--selbsttest` starten
## (mit xvfb-run und OpenGL, sonst headless), Ausgabe auswerten.
## Aufruf: tests/run_tests.sh --suite=export   (Pflicht im Build-Schritt, tools/build_windows.sh)
## Optional: Umgebungsvariable FLUGKERN_PCK = fertige .pck prüfen statt neu zu exportieren.

const SUITE := "export"


func test_export_selftest_hits_both_ways() -> Array:
	var godot := OS.get_executable_path()
	var pck := OS.get_environment("FLUGKERN_PCK")
	if pck == "":
		# M3.3: Gesamt-.pck exportieren und wie im Build in 4 Pakete aufteilen
		var dir := OS.get_cache_dir().path_join("flugkern_export_test")
		DirAccess.make_dir_recursive_absolute(dir)
		var full := dir.path_join("gesamt.pck.tmp")
		var out_e := []
		var code_e := OS.execute(godot, ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--export-pack", "Windows Desktop", full], out_e, true)
		if code_e == 0:
			code_e = OS.execute("python3", [ProjectSettings.globalize_path("res://tools/split_pck.py"), full, dir,
					Hud.VERSION, godot], out_e, true)
		pck = dir.path_join("Flugkern.pck")
		if code_e != 0 or not FileAccess.file_exists(pck):
			return [false, "Export/Aufteilung fehlgeschlagen (Code %d) %s" % [code_e, " ".join(out_e)]]
	# M3.3: im Paket-Ordner starten (kein Rückgriff auf Projektdateien), Zusatzpakete über --pakete=
	var args := ["--main-pack", pck, "--selbsttest", "--", "--pakete=" + pck.get_base_dir()]
	var exe := godot
	var out := []
	var code: int
	var pre := ["xvfb-run", "-a", exe, "--rendering-driver", "opengl3"] \
		if OS.execute("sh", ["-c", "command -v xvfb-run"], [], false) == 0 else [exe, "--headless"]
	code = OS.execute("env", ["-C", pck.get_base_dir()] + pre + args, out, true)
	var text := "\n".join(out)
	var lines := []
	for l in text.split("\n"):
		if l.begins_with("Diagnose") or l.contains("_schiesst") or l.begins_with("SELBSTTEST") \
				or l.begins_with("C_") or l.begins_with("D1_") or l.begins_with("D2_") or l.begins_with("D3_") \
				or l.begins_with("E_") or l.begins_with("Phase ") or l.begins_with("FEHLER"):
			lines.append(l.strip_edges())
	var ok := code == 0 and text.contains("SELBSTTEST OK") and not text.contains("Hitbox-Zonen 0 ") \
			and not text.contains("keine Trefferzonen") and not text.contains("Marker-Quelle fallback") \
			and text.contains("C_ki_abfertigung: fertig") and text.contains("E_ki_start") \
			and not text.contains("Animationen 0") and not text.contains("SCRIPT ERROR")
	# M3.3: alle Pakete geladen (Version), jede Datei <= 30 000 000 Byte, Audio-Busse/Streams
	var ok_pk := not text.contains("FEHLT") and text.contains("Flugkern_audio.pck") \
			and text.contains("Streams geladen %d/%d" % [GameAudio.SOUNDS.size(), GameAudio.SOUNDS.size()])
	var sizes := []
	for f in ["Flugkern.pck", "Flugkern_modelle.pck", "Flugkern_karte.pck", "Flugkern_audio.pck"]:
		var fa := FileAccess.open(pck.get_base_dir().path_join(f), FileAccess.READ)
		var n := fa.get_length() if fa != null else -1
		sizes.append("%s %d" % [f, n])
		ok_pk = ok_pk and n > 0 and n <= 30_000_000
	return [ok and ok_pk, "Exit %d | %s | %s" % [code, " | ".join(sizes), " | ".join(lines)]]


## M3.3: Fehlt das Audio-Paket, startet das Spiel stumm; fehlt ein Pflichtpaket, kommt eine
## Fehlermeldung (Code 3) statt eines Absturzes.
func test_export_selftest_missing_packs() -> Array:
	var godot := OS.get_executable_path()
	var pck := OS.get_environment("FLUGKERN_PCK")
	if pck == "":
		pck = OS.get_cache_dir().path_join("flugkern_export_test/Flugkern.pck")
	if not FileAccess.file_exists(pck):
		return [false, "keine exportierten Pakete (erst test_export_selftest_hits_both_ways)"]
	var res := []
	var dbg := ""
	for drop in ["Flugkern_audio.pck", "Flugkern_modelle.pck"]:
		var tmp := OS.get_cache_dir().path_join("flugkern_ohne_" + drop.get_basename())
		DirAccess.make_dir_recursive_absolute(tmp)
		for f in ["Flugkern.pck", "Flugkern_modelle.pck", "Flugkern_karte.pck", "Flugkern_audio.pck"]:
			DirAccess.remove_absolute(tmp.path_join(f))
			if f != drop:
				OS.execute("ln", ["-sf", pck.get_base_dir().path_join(f), tmp.path_join(f)])
		var out := []
		var code := OS.execute("env", ["-C", tmp, godot, "--headless", "--main-pack",
				tmp.path_join("Flugkern.pck"), "--quit-after", "400", "--", "--boden=standard", "--pakete=" + tmp], out, true)
		var text := "\n".join(out)
		dbg = text
		res.append([code, text.contains("SCRIPT ERROR"), text.contains(drop + " FEHLT"),
			text.contains("Streams geladen 0/"), text.contains("Flugkern kann nicht starten")])
	var a: Array = res[0]
	var m: Array = res[1]
	var ok: bool = a[0] == 0 and not a[1] and a[2] and a[3] and m[0] == 3 and not m[1] and m[2] and m[4]
	return [ok, "ohne Audio: Code %d, stumm %s | ohne Modelle: Code %d, Meldung %s %s" % [a[0], a[3], m[0], m[4], dbg.right(200) if not ok else ""]]
