extends Node
## M3.3: Startszene. Lädt die Zusatzpakete (PackLoader) und wechselt dann ins Hauptmenü
## (das wiederum Startoptionen wie --selbsttest/--tutorial auswertet). Fehlt ein Pflichtpaket,
## erscheint eine Meldung (headless: Ausgabe und Beenden mit Code 3) statt eines Absturzes.

const MENU := "res://ui/menu/main_menu.tscn"


func _ready() -> void:
	var ok := PackLoader.load_all()
	print("Diagnose " + PackLoader.diagnostics())
	if ok:
		get_tree().change_scene_to_file.call_deferred(MENU)
		return
	var msg := "Flugkern kann nicht starten: Es fehlen Spieldateien\n\n%s\n\nAlle .pck-Dateien gehören in denselben Ordner wie Flugkern.exe." \
		% "\n".join(PackLoader.missing_required)
	printerr("FEHLER: " + msg.replace("\n", " "))
	if DisplayServer.get_name() == "headless":
		get_tree().quit(3)
		return
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.09, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var l := Label.new()
	l.text = msg + "\n\n(Esc zum Beenden)"
	l.add_theme_font_size_override("font_size", 26)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(l)


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed(&"ui_cancel"):
		get_tree().quit()
