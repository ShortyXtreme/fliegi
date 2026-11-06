class_name InteractionHint
extends Control
## Mitte unten am Fadenkreuz: Taste + Aktion („[E] halten: Gurt einlegen“), Hinweis bei fehlendem
## Gegenstand („Kiste fehlt“) oder blockiertem Job („Lager leer“), Fortschrittsring beim Halten,
## beim Pumpen zusätzlich die Literanzeige. Daten aus GroundHudData.interaction().

const RING_R := 26.0
const RING_W := 5.0

var data := {}


func _init() -> void:
	name = "InteractionHint"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_data(d: Dictionary) -> void:
	data = d
	visible = bool(d.get("visible", false))
	queue_redraw()


## Ring 0..1 im Uhrzeigersinn ab 12 Uhr.
func _ring(c: Vector2, f: float, col: Color) -> void:
	draw_arc(c, RING_R, 0, TAU, 48, Color(0, 0, 0, 0.45), RING_W + 3, true)
	draw_arc(c, RING_R, 0, TAU, 48, Color(HudStyle.VALUE, 0.14), RING_W, true)
	if f > 0.002:
		draw_arc(c, RING_R, -PI * 0.5, -PI * 0.5 + TAU * clampf(f, 0, 1), maxi(4, int(48 * f)), col,
				RING_W, true)


func _key_cap(pos: Vector2, k: String) -> float:
	return KeyGlyphs.draw_token(self, Vector2(pos.x, pos.y - 7), k, 28, KeyGlyphs.pad)


func _draw() -> void:
	if not visible:
		return
	var c := Vector2.ZERO
	var label: String = data.get("label", "")
	var hold: bool = data.get("hold", false)
	var prog: float = data.get("progress", 0.0)
	var missing: String = data.get("missing", "")
	var blocked: String = data.get("blocked", "")
	var pump: bool = data.get("pump", false)
	var warn := missing != "" or blocked != ""
	# Ring (Halten oder Pumpen)
	if (hold and prog > 0.0) or pump:
		_ring(c, prog, HudStyle.ACCENT if not warn else HudStyle.CAUTION)
		if pump:
			HudStyle.text(self, c + Vector2(0, 6), "%d %%" % int(round(prog * 100)), 13, HudStyle.VALUE, true, 1)
	# Zeile: [Taste] halten: Aktion
	var y := RING_R + 44.0
	if label != "":
		var prefix := "halten: " if hold else ""
		var s := prefix + label
		var tw := HudStyle.text_width(s, 19, true)
		var kw := KeyGlyphs.token_width(String(data.get("key", "")), 28, KeyGlyphs.pad)
		var total := kw + 10.0 + tw
		var bg := Rect2(-total * 0.5 - 14, y - 30, total + 28, 40)
		HudStyle.draw_panel(self, bg, 8)
		var x := -total * 0.5
		_key_cap(Vector2(x, y), String(data.get("key", "")))
		HudStyle.text(self, Vector2(x + kw + 10, y - 1), s, 19, HudStyle.DIM if missing != "" else HudStyle.VALUE, true)
		y += 34.0
	# Literanzeige beim Pumpen
	if pump:
		var lt := "%s / %s" % [GroundHudData.liters(data.get("liters", 0.0)),
				GroundHudData.liters(data.get("liters_target", 0.0))]
		var w := HudStyle.text_width(lt, 22, true) + 32
		HudStyle.draw_panel(self, Rect2(-w * 0.5, y - 26, w, 34), 8)
		HudStyle.text(self, Vector2(0, y - 2), lt, 22, HudStyle.VALUE, true, 1)
		y += 34.0
	# Warnung
	if warn:
		var wt := blocked if blocked != "" else missing
		HudStyle.text(self, Vector2(0, y), wt, 18, HudStyle.WARNING if blocked != "" else HudStyle.CAUTION, true, 1)
