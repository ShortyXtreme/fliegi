class_name HudStyle
extends RefCounted
## Gemeinsame Gestaltung des Kampf-HUD: Schrift (Inter, OFL, siehe fonts/OFL.txt),
## Farben, Panel-Hintergrund, Skalierung. Alle Elemente zeichnen über diese Helfer,
## damit das HUD einheitlich aussieht.

const FONT_MEDIUM := "res://ui/combat/fonts/Inter-Medium.otf"
const FONT_SEMIBOLD := "res://ui/combat/fonts/Inter-SemiBold.otf"

# Farben kommen aus dem Epochen-Theme (ui/theme/, HudPalette). Werte unten = Tier I,
# damit auch ohne geladene Palette alles stimmig ist. apply() schaltet um.
const DEFAULT_PALETTE := "res://ui/theme/epoch_t1.tres"
static var BG := Color(0.095, 0.088, 0.066, 0.74)
static var BG_EDGE := Color(0.80, 0.68, 0.42, 0.32)
static var BG_INNER := Color(1, 1, 1, 0.05)
static var LABEL := Color(0.73, 0.69, 0.58)
static var VALUE := Color(0.95, 0.92, 0.84)
static var DIM := Color(0.73, 0.69, 0.58, 0.58)
static var ACCENT := Color(0.86, 0.72, 0.42)
static var CAUTION := Color(0.96, 0.70, 0.26)
static var WARNING := Color(0.90, 0.32, 0.24)
static var OK := Color(0.62, 0.74, 0.40)
static var FRIEND := Color(0.52, 0.68, 0.88)
static var ENEMY := Color(0.92, 0.36, 0.28)
static var SHADOW := Color(0, 0, 0, 0.55)
static var KEY_FACE := Color(0.93, 0.89, 0.78)
static var KEY_TEXT := Color(0.12, 0.11, 0.09)
static var KEY_EDGE := Color(0.55, 0.47, 0.32)
static var RADIUS := 4
static var HEADING_SPACING := 2
## Aktive Palette (null = eingebaute Tier-I-Werte).
static var palette: HudPalette

static var _fonts := {}


static func _static_init() -> void:
	if ResourceLoader.exists(DEFAULT_PALETTE):
		apply(load(DEFAULT_PALETTE))


## Epochen-Theme anwenden (z. B. später je Tier des gesteuerten Flugzeugs).
static func apply(p: HudPalette) -> void:
	if p == null:
		return
	palette = p
	BG = p.bg; BG_EDGE = p.bg_edge; BG_INNER = p.bg_inner_edge; SHADOW = p.shadow
	LABEL = p.label; VALUE = p.value; DIM = p.dim; ACCENT = p.accent
	CAUTION = p.caution; WARNING = p.warning; OK = p.ok; FRIEND = p.friend; ENEMY = p.enemy
	KEY_FACE = p.key_face; KEY_TEXT = p.key_text; KEY_EDGE = p.key_edge
	RADIUS = p.corner_radius; HEADING_SPACING = p.heading_spacing
	_fonts.clear()


## Godot-Theme der aktiven Palette (für Control-Knoten), sonst null.
static func theme() -> Theme:
	return palette.theme if palette != null else null


## Schrift mit Tabellenziffern (Werte springen beim Zählen nicht).
static func font(bold := false, heading := false) -> Font:
	var key := ("h" if heading else "") + ("b" if bold else "m")
	if _fonts.has(key):
		return _fonts[key]
	var base: Font = load(FONT_SEMIBOLD if bold else FONT_MEDIUM)
	var fv := FontVariation.new()
	if base == null:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Inter", "DejaVu Sans", "sans-serif"])
		base = sf
	fv.base_font = base
	fv.opentype_features = {TextServerManager.get_primary_interface().name_to_tag("tnum"): 1}
	if heading:
		fv.spacing_glyph = HEADING_SPACING
	_fonts[key] = fv
	return fv


## Skalierung relativ zu 1080p (0,75 … 1,6).
static func ui_scale(viewport_size: Vector2) -> float:
	return clampf(viewport_size.y / 1080.0, 0.75, 1.6)


## Halbtransparente Tafel mit Messingkante und feiner Innenlinie (Instrumententafel-Anmutung).
static func draw_panel(ci: CanvasItem, rect: Rect2, _radius := 10.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(RADIUS)
	sb.border_color = BG_EDGE
	sb.set_border_width_all(1)
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)
	if rect.size.x > 40 and rect.size.y > 30:
		var inner := rect.grow(-3)
		ci.draw_rect(inner, BG_INNER, false, 1.0)


## Überschrift in gesperrten Versalien (Tafelbeschriftung), pos = Grundlinie.
static func heading(ci: CanvasItem, pos: Vector2, s: String, size: float, col: Color = Color(-1, 0, 0),
		align := 0) -> float:
	var c := LABEL if col.r < 0 else col
	var f := font(true, true)
	var fs := int(round(size))
	var t := s.to_upper()
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos
	if align == 1:
		p.x -= w * 0.5
	elif align == 2:
		p.x -= w
	ci.draw_string(f, p + Vector2(0, 1), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(SHADOW, SHADOW.a * c.a))
	ci.draw_string(f, p, t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, c)
	return w


## Dünne Trennlinie in Messing.
static func rule(ci: CanvasItem, a: Vector2, b: Vector2) -> void:
	ci.draw_line(a, b, Color(BG_EDGE, BG_EDGE.a * 0.8), 1.0)


## Text mit weichem Schatten; align: 0 links, 1 Mitte, 2 rechts (pos = Grundlinie).
static func text(ci: CanvasItem, pos: Vector2, s: String, size: float, col: Color,
		bold := false, align := 0) -> float:
	var f := font(bold)
	var fs := int(round(size))
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var p := pos
	if align == 1:
		p.x -= w * 0.5
	elif align == 2:
		p.x -= w
	ci.draw_string(f, p + Vector2(0, maxf(1.0, size * 0.06)), s, HORIZONTAL_ALIGNMENT_LEFT,
			-1, fs, Color(SHADOW, SHADOW.a * col.a))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
	return w


static func text_width(s: String, size: float, bold := false) -> float:
	return font(bold).get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, int(round(size))).x


## Farbe für einen Zustand 0..1 (1 = heil): grün → gelb → rot, 0 = grau.
static func health_color(f: float) -> Color:
	if f <= 0.001:
		return Color(0.35, 0.35, 0.37, 0.9)
	if f > 0.66:
		return OK
	if f > 0.33:
		return CAUTION
	return WARNING


## Zahl mit schmalem Tausender-Leerzeichen (1 250).
static func thousands(v: float) -> String:
	var n := int(round(absf(v)))
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = " " + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < -0.5 else "") + s + out


## Entfernung kurz: 850 m, 1,4 km.
static func distance(d: float) -> String:
	if d < 1000.0:
		return "%d m" % int(round(d / 10.0) * 10.0)
	return ("%.1f km" % (d / 1000.0)).replace(".", ",")
