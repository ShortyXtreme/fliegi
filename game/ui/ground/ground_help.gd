class_name GroundHelp
extends Control
## Kontextabhängige F1-Hilfe (Flug / zu Fuß / Fahren), Belegungen laut M3-Vertrag §2.2.
## help_rows(ctx) ist statisch, damit Paket 14 dieselben Texte auch im Flug-HUD nutzen kann.

const W := 580.0

var context: int = InputBindings.Context.CREW


func _init() -> void:
	name = "GroundHelp"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## Zeilen [Aktion, Tastatur, Pad]; Überschriften mit leeren Tasten.
static func help_rows(ctx: int) -> Array:
	match ctx:
		InputBindings.Context.CREW:
			return [["Gehen", "W A S D", "linker Stick"], ["Umsehen", "Maus", "rechter Stick"],
				["Sprinten", "Shift", "L3"], ["Interagieren (halten)", "E", "A"], ["Ablegen", "G", "B"],
				["Einsteigen", "F", "Y"], ["Befehlsrad (halten)", "Tab", "LB"],
				["Ego / Third-Person", "C", "R3"], ["Hilfe", "F1", "Back"], ["Maus freigeben", "Esc", ""],
				["Alarmstart (Debug)", "F9", ""]]
		InputBindings.Context.DRIVE:
			return [["Gas", "W", "RT"], ["Bremse / rückwärts", "S", "LT"], ["Lenken", "A D", "linker Stick"],
				["Handbremse", "Leertaste", "B"], ["Aussteigen (1 s halten)", "J", "Kreuz ←"],
				["Interagieren", "E", "A"], ["Befehlsrad (halten)", "Tab", "LB"], ["Kamera", "C", "Y"],
				["Hilfe", "F1", "Back"]]
		_:
			return [["Höhenruder", "W S", "linker Stick"], ["Querruder", "A D", "linker Stick"],
				["Seitenruder", "Q E", "LB RB"], ["Gas", "Shift / Strg", "Kreuz ↑ ↓"],
				["Klappen", "F", "A"], ["Bremsen", "B", "B"], ["Fahrwerk", "G", "Kreuz →"],
				["Feuern MG / Kanone", "Leertaste / V", "RT / LT"],
				["Aussteigen im Stand (1 s)", "J", "Kreuz ←"], ["Kamera", "C", "Y"], ["Hilfe", "F1", "Back"]]


static func title(ctx: int) -> String:
	return "STEUERUNG – %s" % String(InputBindings.CONTEXT_NAMES.get(ctx, "")).to_upper()


func panel_height() -> float:
	return 64.0 + help_rows(context).size() * 26.0


func _draw() -> void:
	var rows := help_rows(context)
	HudStyle.draw_panel(self, Rect2(0, 0, W, panel_height()), 12)
	HudStyle.text(self, Vector2(18, 28), title(context), 14, HudStyle.ACCENT, true)
	HudStyle.text(self, Vector2(W - 18, 28), "F1 schließt", 12, HudStyle.DIM, false, 2)
	HudStyle.text(self, Vector2(300, 52), "TASTATUR", 10, HudStyle.DIM)
	HudStyle.text(self, Vector2(440, 52), "PAD", 10, HudStyle.DIM)
	var y := 78.0
	for r in rows:
		HudStyle.text(self, Vector2(18, y), r[0], 15, HudStyle.LABEL)
		HudStyle.text(self, Vector2(300, y), r[1], 15, HudStyle.VALUE, true)
		HudStyle.text(self, Vector2(440, y), r[2], 15, HudStyle.VALUE, true)
		y += 26.0
