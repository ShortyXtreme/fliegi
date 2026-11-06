class_name TutorialOffer
extends Control
## Angebot beim allerersten Start (M3.2): „Neu hier? Geführtes Tutorial“. Enter / A startet
## (Szene neu mit Game.tutorial_mode), Rücktaste / B überspringt. Wird nur einmal gezeigt
## (user://tutorial.cfg, offered).

signal answered(start: bool)

const W := 610.0
const H := 170.0


func _init() -> void:
	name = "TutorialOffer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 30


func _input(event: InputEvent) -> void:
	var yes: bool = (event is InputEventKey and event.pressed and not event.echo
			and (event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER)) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A)
	var no: bool = (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_BACKSPACE) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B)
	if yes or no:
		get_viewport().set_input_as_handled()
		answer(yes)


func answer(start: bool) -> void:
	Tutorial.save_progress("offered", true)
	answered.emit(start)
	queue_free()


func _process(_dt: float) -> void:
	var vs := get_viewport_rect().size
	var s := HudStyle.ui_scale(vs)
	scale = Vector2(s, s)
	position = (vs - Vector2(W, H) * s) * 0.5 - Vector2(0, vs.y * 0.12)
	queue_redraw()


func _draw() -> void:
	HudStyle.draw_panel(self, Rect2(0, 0, W, H))
	draw_rect(Rect2(1, 1, W - 2, H - 2), Color(HudStyle.BG, 0.6))
	HudStyle.heading(self, Vector2(24, 34), "Neu hier?", 12, HudStyle.ACCENT)
	HudStyle.text(self, Vector2(24, 72), "Geführtes Tutorial starten", 28, HudStyle.VALUE, true)
	HudStyle.text(self, Vector2(24, 100), "Starten, Kämpfen, Landen, Abfertigen – ca. 10 Minuten, jederzeit abbrechbar.",
			14, HudStyle.LABEL)
	var p := KeyGlyphs.pad
	var x := 24.0
	x += KeyGlyphs.draw_spec(self, Vector2(x, 138), "A" if p else "Enter", 26, p) + 8
	x += HudStyle.text(self, Vector2(x, 145), "Tutorial", 19, HudStyle.VALUE, true) + 28
	x += KeyGlyphs.draw_spec(self, Vector2(x, 138), "B" if p else "Rücktaste", 26, p) + 8
	HudStyle.text(self, Vector2(x, 145), "Freies Spiel", 19, HudStyle.VALUE, true)
