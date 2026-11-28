class_name FeedbackLog
extends Logger
## Feedback-Taste: eigener Logger (OS.add_logger, Godot 4.5+). Hält die letzten WINDOW_S Sekunden
## des Godot-Logs (print, printerr, push_error/push_warning, Engine-Fehler) als Ringpuffer.
## Logger-Methoden können aus beliebigen Threads kommen, daher Mutex und kein print() hier drin.

const WINDOW_S := 60.0
## Obergrenze gegen Log-Fluten (z. B. ein Fehler je Frame).
const MAX_LINES := 3000

static var instance: FeedbackLog = null

var _mutex := Mutex.new()
## [ticks_msec, Text]
var _lines: Array = []
var dropped := 0


## Einmal je Prozess anmelden (Feedback.ensure). Rückgabe: der Logger.
static func install() -> FeedbackLog:
	if instance == null:
		instance = FeedbackLog.new()
		OS.add_logger(instance)
	return instance


func _log_message(message: String, error: bool) -> void:
	var t := message.strip_edges(false, true)
	if t == "":
		return
	_add(("FEHLER-AUSGABE: " if error else "") + t)


func _log_error(function: String, file: String, line: int, code: String, rationale: String,
		_editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var kind: String = ["FEHLER", "WARNUNG", "SKRIPTFEHLER", "SHADERFEHLER"][clampi(error_type, 0, 3)]
	var what := rationale if rationale != "" else code
	_add("%s: %s  (%s:%d, %s)" % [kind, what, file.get_file(), line, function])


func _add(text: String) -> void:
	var now := Time.get_ticks_msec()
	_mutex.lock()
	_lines.append([now, text])
	_trim(now)
	_mutex.unlock()


func _trim(now: int) -> void:
	var cut := 0
	var limit := now - int(WINDOW_S * 1000.0)
	while cut < _lines.size() and int(_lines[cut][0]) < limit:
		cut += 1
	if _lines.size() - cut > MAX_LINES:
		dropped += _lines.size() - cut - MAX_LINES
		cut = _lines.size() - MAX_LINES
	if cut > 0:
		_lines = _lines.slice(cut)


## Kopie der Zeilen der letzten WINDOW_S Sekunden: [[ticks_msec, Text], …].
func snapshot() -> Array:
	_mutex.lock()
	_trim(Time.get_ticks_msec())
	var out := _lines.duplicate()
	_mutex.unlock()
	return out
