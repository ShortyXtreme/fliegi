class_name RadioPanel
extends Control
## M3.5: Funkgerät unten rechts (statt Befehlsrad), zweistufig wie das Funkmenü in DCS:
## Funk-Taste öffnet die Kanalliste (zuletzt benutzter Kanal markiert) → Ziffer 1–4 wählt den Kanal
## → Ziffer 1–3 führt den Befehl aus. Zurück (Rücktaste / B) = Kanalliste, Funk-Taste oder Esc
## schließt. Pfeil ←/→ bzw. LB/RB wechselt den Kanal, Steuerkreuz ↑↓ + A wählt am Controller.
## Kein Mauszwang, Bewegen bleibt frei. Kanäle als Daten (RadioChannel), Antwortzeilen je Kanal,
## Aktivitätspunkt am Kanal, wenn dort gerade jemand arbeitet. Tasten aus der aktuellen Belegung.
## Zeichnet in 1080p-Einheiten; GroundHud setzt position (rechte untere Ecke) und scale.

signal command_chosen(channel: RadioChannel, cmd: RadioCommand)

const W := 380.0
const PAD := 14.0
const ROW_H := 27.0
const HEAD_H := 54.0
const ANSWERS := 3
const ANSWER_SHOW := 10.0
const CFG_SECTION := "m3_5"
const CFG_KEY := "funk_kanal"
## Olivgrünes Gehäuse, Messingrahmen (Tier I), Skalenfenster bernstein.
const OLIVE := Color(0.20, 0.23, 0.14, 0.93)
const OLIVE_DARK := Color(0.11, 0.13, 0.07, 0.96)
const BRASS := Color(0.80, 0.64, 0.32)
const DIAL := Color(1.0, 0.72, 0.30)

enum Stage { CHANNELS, COMMANDS }

## Pad-Tasten A/B gehören dem offenen Funkgerät (CrewPlayerController/DrivePlayerController).
static var pad_capture := false
## Funk-Klang beim Senden und Empfangen (Einstellung „Funk-Klang“, Standard an).
static var beep_on := true
var _beep: AudioStreamPlayer

var channels: Array = []
var is_open := false
var stage := Stage.CHANNELS
## Gewählter bzw. markierter Kanal (Index).
var current := 0
## Markierung (Steuerkreuz) in der aktuellen Liste.
var cursor := 0
var pad := false
var target_name := ""
## Aktivität je Kanal-id: Statuszeile („Tankwart: tankt – 73 %“), leer = frei.
var activity := {}
var now := 0.0


func _init() -> void:
	name = "RadioPanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## M3.6: Funk-Klang (prozedural, Bus „UI“ = Regler „Lautstärke Menü/UI“, abschaltbar über
## „Funk-Klang“). Senden: Sprechtasten-Klick + kurzes Rauschen. Empfang: Rauschstoß (Squelch),
## zwei kurze Töne 1,2 kHz, Rauschschwanz. Zähler sounds je Art (auch headless, für Tests).
var sounds := {"senden": 0, "empfang": 0}
var _streams := {}


## Empfangs-Klang (Antwort eingegangen).
func beep() -> void:
	_radio_sound("empfang")


## Sende-Klang (Befehl abgesetzt).
func send_sound() -> void:
	_radio_sound("senden")


func _radio_sound(kind: String) -> void:
	if not beep_on:
		return
	sounds[kind] = int(sounds.get(kind, 0)) + 1
	if DisplayServer.get_name() == "headless":
		return
	if _beep == null:
		_beep = AudioStreamPlayer.new()
		_beep.bus = &"UI"
		_beep.volume_db = -8.0
		add_child(_beep)
	if not _streams.has(kind):
		_streams[kind] = make_radio_stream(kind)
	_beep.stream = _streams[kind]
	_beep.pitch_scale = randf_range(0.97, 1.03)
	_beep.play()


## Klang als 16-Bit-WAV (22,05 kHz). Rauschen tiefpassgefiltert und mit 3 kHz „Bandbreite“,
## damit es nach Funkgerät klingt und nicht nach weißem Rauschen.
static func make_radio_stream(kind: String) -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.2 if kind == "senden" else 0.34
	var n := int(rate * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1937 if kind == "senden" else 1938
	var lp := 0.0
	var hp := 0.0
	for i in n:
		var t := float(i) / rate
		lp += (rng.randf_range(-1.0, 1.0) - lp) * 0.45   # Tiefpass
		var noise := lp - hp
		hp += noise * 0.08                               # Hochpass (kein Brummen)
		var v := 0.0
		if kind == "senden":
			# Klick der Sprechtaste (5 ms), dann Rauschen, das nach 0,15 s abreißt
			if t < 0.005:
				v = (1.0 - t / 0.005) * 0.9 * (1.0 if i % 6 < 3 else -1.0)
			elif t < 0.15:
				v = noise * 0.55 * minf(1.0, (t - 0.005) / 0.01)
			elif t < 0.157:
				v = 0.6 * (1.0 if i % 8 < 4 else -1.0) * (1.0 - (t - 0.15) / 0.007)
		else:
			# Squelch-Öffnung, Doppelton, Rauschschwanz
			var tone := t > 0.05 and t < 0.11 or t > 0.14 and t < 0.2
			if t < 0.05:
				v = noise * 0.7
			elif tone:
				v = sin(TAU * 1200.0 * t) * 0.45 + noise * 0.12
			elif t < 0.29:
				v = noise * 0.4 * (1.0 if t < 0.2 else 1.0 - (t - 0.2) / 0.09)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 9000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	return w


func channel() -> RadioChannel:
	return channels[clampi(current, 0, channels.size() - 1)] if not channels.is_empty() else null


func entries() -> Array:
	if stage == Stage.CHANNELS:
		return channels
	var c := channel()
	return c.commands if c != null else []


static func load_last() -> int:
	var c := ConfigFile.new()
	c.load(GameSettings.PATH)
	return int(c.get_value(CFG_SECTION, CFG_KEY, 1)) - 1


static func save_last(index: int) -> void:
	var c := ConfigFile.new()
	c.load(GameSettings.PATH)
	c.set_value(CFG_SECTION, CFG_KEY, index + 1)
	c.save(GameSettings.PATH)


func open() -> void:
	is_open = true
	stage = Stage.CHANNELS
	current = clampi(load_last(), 0, maxi(channels.size() - 1, 0))
	cursor = current
	queue_redraw()


func close() -> void:
	is_open = false
	stage = Stage.CHANNELS
	queue_redraw()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


## Kanal i (0-basiert) wählen und dessen Befehle zeigen.
func select_channel(i: int) -> void:
	if i < 0 or i >= channels.size():
		return
	current = i
	stage = Stage.COMMANDS
	cursor = 0
	save_last(i)
	queue_redraw()


## Ziffer n (1-basiert): Kanal bzw. Befehl. Rückgabe: ausgeführter Befehl oder null.
func choose(n: int) -> RadioCommand:
	if not is_open:
		return null
	if stage == Stage.CHANNELS:
		select_channel(n - 1)
		return null
	var e := entries()
	if n < 1 or n > e.size():
		return null
	var c: RadioCommand = e[n - 1]
	var ch := channel()
	close()
	send_sound()
	command_chosen.emit(ch, c)
	return c


## Zurück: Befehle -> Kanalliste -> schließen.
func back() -> void:
	if stage == Stage.COMMANDS:
		stage = Stage.CHANNELS
		cursor = current
		queue_redraw()
	else:
		close()


## Kanal wechseln (Pfeil ←/→, LB/RB); bleibt in der aktuellen Stufe.
func cycle_channel(d: int) -> void:
	if channels.is_empty():
		return
	current = posmod(current + d, channels.size())
	if stage == Stage.COMMANDS:
		cursor = 0
		save_last(current)
	else:
		cursor = current
	queue_redraw()


func move(d: int) -> void:
	var n := entries().size()
	if n > 0:
		cursor = posmod(cursor + d, n)
		queue_redraw()


func confirm() -> RadioCommand:
	return choose(cursor + 1)


## Zuletzt eingegangene Antwort aller Kanäle (Panel zu: kurz einblenden), sonst {}.
func latest_answer() -> Dictionary:
	var best := {}
	for c in channels:
		if not c.log.is_empty() and (best.is_empty() or float(c.log[-1].t) > float(best.t)):
			best = c.log[-1]
	return best if not best.is_empty() and now - float(best.t) <= ANSWER_SHOW else {}


## Antwortzeilen unter der Liste: [text, live].
func body_lines() -> Array:
	if not is_open:
		var la := latest_answer()
		return [[String(la.text), false]] if not la.is_empty() else []
	if stage != Stage.COMMANDS:
		return []
	var c := channel()
	var out := []
	for e in c.log.slice(maxi(c.log.size() - ANSWERS, 0)):
		out.append([String(e.text), false])
	var live: String = activity.get(c.id, "")
	if live != "":
		out.append([live, true])
	return out.slice(maxi(out.size() - ANSWERS, 0))


func panel_height() -> float:
	var h := HEAD_H
	if is_open:
		h += 8.0 + entries().size() * ROW_H + 24.0
	var bl := body_lines().size()
	if bl > 0:
		h += 10.0 + bl * 20.0
	return h + 8.0


func _process(_dt: float) -> void:
	now = Time.get_ticks_msec() / 1000.0
	visible = is_open or not latest_answer().is_empty()
	if visible:
		queue_redraw()


static func _key(action: StringName) -> String:
	return KeyGlyphs.token(action, false)


func _draw() -> void:
	var c := channel()
	if c == null:
		return
	var h := panel_height()
	var sb := StyleBoxFlat.new()
	sb.bg_color = OLIVE
	sb.border_color = Color(BRASS, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(HudStyle.RADIUS + 2)
	draw_style_box(sb, Rect2(0, 0, W, h))
	for p in [Vector2(7, 7), Vector2(W - 7, 7), Vector2(7, h - 7), Vector2(W - 7, h - 7)]:
		draw_circle(p, 2.2, Color(BRASS, 0.9))
	# Kopfzeile: Betriebslampe, Kanal, Skalenfenster mit Kanal und Frequenz
	draw_rect(Rect2(4, 4, W - 8, HEAD_H - 8), OLIVE_DARK)
	draw_circle(Vector2(PAD + 4, 20), 4.5, HudStyle.OK if is_open else Color(HudStyle.OK, 0.35))
	draw_arc(Vector2(PAD + 4, 20), 5.5, 0, TAU, 16, Color(BRASS, 0.8), 1.0, true)
	var head := "Funk – Kanalwahl" if (is_open and stage == Stage.CHANNELS) else c.title()
	HudStyle.heading(self, Vector2(PAD + 16, 25), head, 12, BRASS)
	var dial := Rect2(W - PAD - 104, 10, 104, 22)
	draw_rect(dial, Color(0.05, 0.04, 0.02, 0.95))
	draw_rect(dial, Color(BRASS, 0.9), false, 1.0)
	HudStyle.text(self, Vector2(dial.position.x + 7, 27), "K%d" % c.number, 13, Color(DIAL, 0.75), true)
	HudStyle.text(self, Vector2(dial.end.x - 7, 27), c.freq + " MHz", 13, DIAL, true, 2)
	var sub := ("Ziel %s  ·  " % target_name) if target_name != "" else ""
	sub += "KI antwortet" if c.operator_peer == 0 else "Spieler am Gerät"
	HudStyle.text(self, Vector2(PAD + 16, 42), sub, 10, HudStyle.DIM)
	var y := HEAD_H
	if is_open:
		y += 6.0
		var e := entries()
		for i in e.size():
			var mark := i == cursor if (pad or stage == Stage.CHANNELS) else false
			if mark:
				draw_rect(Rect2(8, y, W - 16, ROW_H - 3), Color(BRASS, 0.26))
			var k := Rect2(PAD, y + 3, 20, 18)
			draw_rect(k, Color(HudStyle.KEY_FACE, 0.92))
			draw_rect(k, Color(BRASS, 0.9), false, 1.0)
			HudStyle.text(self, Vector2(k.position.x + 10, y + 17), str(i + 1), 13, HudStyle.KEY_TEXT, true, 1)
			if stage == Stage.CHANNELS:
				var ch: RadioChannel = e[i]
				HudStyle.text(self, Vector2(PAD + 30, y + 18), ch.name, 16, HudStyle.VALUE, true)
				HudStyle.text(self, Vector2(W - PAD - 18, y + 18), ch.freq, 11, HudStyle.DIM, false, 2)
				if String(activity.get(ch.id, "")) != "":
					draw_circle(Vector2(W - PAD - 5, y + 12), 4.0, Color(HudStyle.OK, 0.6 + 0.4 * sin(now * 5.0)))
			else:
				var rc: RadioCommand = e[i]
				HudStyle.text(self, Vector2(PAD + 30, y + 18), rc.label, 16, HudStyle.VALUE, true)
			y += ROW_H
		var foot := ""
		if stage == Stage.COMMANDS and pad and cursor < e.size():
			foot = (e[cursor] as RadioCommand).hint
		if foot == "":
			var what := "Kanal" if stage == Stage.CHANNELS else "Befehl"
			var bk := "schließen" if stage == Stage.CHANNELS else "Kanäle"
			foot = ("Kreuz ↑↓ + A %s · B %s · LB/RB Kanal" % [what, bk]) if pad else \
				("1–%d %s · %s %s · %s/%s Kanal" % [e.size(), what, _key(&"radio_back"), bk,
					_key(&"radio_prev"), _key(&"radio_next")])
		HudStyle.text(self, Vector2(PAD, y + 15), foot, 11, HudStyle.DIM)
		y += 24.0
	var bl := body_lines()
	if not bl.is_empty():
		HudStyle.rule(self, Vector2(PAD, y + 4), Vector2(W - PAD, y + 4))
		y += 10.0
		for i in bl.size():
			var live: bool = bl[i][1]
			var col := HudStyle.OK if live else (HudStyle.ACCENT if i == bl.size() - 1 else HudStyle.LABEL)
			var txt: String = bl[i][0]
			var full := txt
			while txt.length() > 8 and HudStyle.text_width(txt, 12) > W - PAD * 2 - 16:
				txt = txt.substr(0, txt.length() - 2)
			if txt != full:
				txt += "…"
			HudStyle.text(self, Vector2(PAD, y + 15), ("● " if live else "» ") + txt, 12, col)
			y += 20.0
