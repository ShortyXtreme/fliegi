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
		pck = OS.get_cache_dir().path_join("flugkern_export_test.pck")
		var out_e := []
		var code_e := OS.execute(godot, ["--headless", "--path", ProjectSettings.globalize_path("res://"),
				"--export-pack", "Windows Desktop", pck], out_e, true)
		if code_e != 0 or not FileAccess.file_exists(pck):
			return [false, "Export fehlgeschlagen (Code %d)" % code_e]
	var args := ["--main-pack", pck, "--selbsttest"]
	var exe := godot
	var out := []
	var code: int
	if OS.execute("sh", ["-c", "command -v xvfb-run"], [], false) == 0:
		code = OS.execute("xvfb-run", PackedStringArray(["-a", godot, "--rendering-driver", "opengl3"] + args), out, true)
	else:
		code = OS.execute(exe, PackedStringArray(["--headless"] + args), out, true)
	var text := "\n".join(out)
	var lines := []
	for l in text.split("\n"):
		if l.begins_with("Diagnose") or l.contains("_schiesst") or l.begins_with("SELBSTTEST") \
				or l.begins_with("C_") or l.begins_with("D1_") or l.begins_with("D2_") or l.begins_with("D3_") \
				or l.begins_with("E_") or l.begins_with("Phase "):
			lines.append(l.strip_edges())
	var ok := code == 0 and text.contains("SELBSTTEST OK") and not text.contains("Hitbox-Zonen 0 ") \
			and not text.contains("keine Trefferzonen") and not text.contains("Marker-Quelle fallback") \
			and text.contains("C_ki_abfertigung: fertig") and text.contains("E_ki_start") \
			and not text.contains("Animationen 0") and not text.contains("SCRIPT ERROR")
	return [ok, "Exit %d | %s" % [code, " | ".join(lines)]]
