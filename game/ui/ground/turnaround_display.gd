class_name TurnaroundDisplay
extends Control
## Abfertigungszeit (läuft, danach Sterne + Bestzeit für einige Sekunden) und Alarm-Banner
## („Roter Verband im Anflug – 2:47“). Liest Turnaround (Strang G) bzw. GroundEvents.

const W := 280.0
const RESULT_SHOW := 8.0
const ALARM_W := 520.0

## Abfertigung: {running, elapsed, best (-1 = keine), stars, new_best, result_t}
var timer := {}
## Alarm: Restzeit in s (< 0 = kein Alarm)
var alarm_left := -1.0
var alarm_text := "Roter Verband im Anflug"
var _pulse := 0.0
var alarm_banner: Control


func _init() -> void:
	name = "TurnaroundDisplay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alarm_banner = Control.new()
	alarm_banner.name = "AlarmBanner"
	alarm_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alarm_banner.draw.connect(_draw_alarm)


func tick(dt: float) -> void:
	_pulse = fmod(_pulse + dt, 1.0)
	queue_redraw()
	alarm_banner.visible = alarm_left >= 0.0
	alarm_banner.queue_redraw()


func timer_visible() -> bool:
	return bool(timer.get("running", false)) or float(timer.get("result_t", 0.0)) > 0.0


func _stars(x: float, y: float, n: int) -> void:
	for i in 3:
		var c := Vector2(x + i * 26, y)
		var pts := PackedVector2Array()
		for k in 10:
			var r := 10.0 if k % 2 == 0 else 4.2
			var a := -PI * 0.5 + k * TAU / 10.0
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, HudStyle.CAUTION if i < n else Color(HudStyle.VALUE, 0.14))


func _draw() -> void:
	if not timer_visible():
		return
	var running: bool = timer.get("running", false)
	var h := 84.0
	HudStyle.draw_panel(self, Rect2(0, 0, W, h), 10)
	HudStyle.heading(self, Vector2(14, 20), "ABFERTIGUNG" if running else "ABFERTIGUNG FERTIG", 10)
	var t: float = timer.get("elapsed", 0.0)
	HudStyle.text(self, Vector2(14, 56), GroundHudData.clock(t), 32, HudStyle.VALUE if running else HudStyle.ACCENT, true)
	var best: float = timer.get("best", -1.0)
	HudStyle.text(self, Vector2(W - 14, 76), "Bestzeit " + (GroundHudData.clock(best) if best > 0 else "–"), 13,
			HudStyle.LABEL, false, 2)
	if not running:
		_stars(W - 74, 44, int(timer.get("stars", 0)))
		if timer.get("new_best", false):
			HudStyle.text(self, Vector2(W - 14, 20), "NEUE BESTZEIT", 11, HudStyle.CAUTION, true, 2)


func _draw_alarm() -> void:
	if alarm_left < 0.0:
		return
	var b := alarm_banner
	var s := "%s – %s" % [alarm_text, GroundHudData.clock(alarm_left)]
	var w := maxf(ALARM_W, HudStyle.text_width(s, 24, true) + 60)
	var r := Rect2(-w * 0.5, 0, w, 46)
	var sb := StyleBoxFlat.new()
	var a := 0.72 + 0.18 * (0.5 + 0.5 * cos(_pulse * TAU))
	sb.bg_color = Color(0.34, 0.09, 0.05, a)
	sb.border_color = Color(HudStyle.WARNING, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(HudStyle.RADIUS)
	sb.anti_aliasing = true
	b.draw_style_box(sb, r)
	HudStyle.text(b, Vector2(0, 32), s, 24, HudStyle.VALUE, true, 1)
