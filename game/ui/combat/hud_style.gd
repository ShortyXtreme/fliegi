class_name HudStyle
extends RefCounted
## Gemeinsame Gestaltung des Kampf-HUD: Schrift (Inter, OFL, siehe fonts/OFL.txt),
## Farben, Panel-Hintergrund, Skalierung. Alle Elemente zeichnen über diese Helfer,
## damit das HUD einheitlich aussieht.

const FONT_MEDIUM := "res://ui/combat/fonts/Inter-Medium.otf"
const FONT_SEMIBOLD := "res://ui/combat/fonts/Inter-SemiBold.otf"

# Farben: ruhig, leicht kühl; Warnungen in Bernstein/Rot.
const BG := Color(0.05, 0.07, 0.09, 0.58)
const BG_EDGE := Color(1, 1, 1, 0.08)
const LABEL := Color(0.62, 0.68, 0.72)
const VALUE := Color(0.94, 0.96, 0.97)
const DIM := Color(0.62, 0.68, 0.72, 0.55)
const ACCENT := Color(0.52, 0.86, 0.74)
const CAUTION := Color(1.0, 0.74, 0.28)
const WARNING := Color(1.0, 0.34, 0.29)
const OK := Color(0.45, 0.85, 0.5)
const FRIEND := Color(0.42, 0.66, 1.0)
const ENEMY := Color(1.0, 0.36, 0.3)
const SHADOW := Color(0, 0, 0, 0.55)

static var _fonts := {}


## Schrift mit Tabellenziffern (Werte springen beim Zählen nicht).
static func font(bold := false) -> Font:
	var key := "b" if bold else "m"
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
	_fonts[key] = fv
	return fv


## Skalierung relativ zu 1080p (0,75 … 1,6).
static func ui_scale(viewport_size: Vector2) -> float:
	return clampf(viewport_size.y / 1080.0, 0.75, 1.6)


## Abgerundetes, halbtransparentes Panel.
static func draw_panel(ci: CanvasItem, rect: Rect2, radius := 10.0) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = BG
	sb.set_corner_radius_all(int(radius))
	sb.border_color = BG_EDGE
	sb.set_border_width_all(1)
	sb.anti_aliasing = true
	ci.draw_style_box(sb, rect)


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
