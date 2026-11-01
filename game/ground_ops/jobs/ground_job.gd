class_name GroundJob
extends RefCounted
## M3 (Strang G / Pakete 2–3): Basis aller Bodenjobs. Ein Job hat feste Schritte;
## JobBoard.request_step() schreibt den Fortschritt fort (nur Server).
## Feste Signaturen: id, kind, target, steps, step_index, progress, worker, blocked_reason,
## current_step(), is_done(), step(step_name, dt, rules) -> bool (true = Schritt fertig), advance().
##
## Unterklassen legen je Schritt fest: duration() (s Arbeit, 0 = sofort), point() (Servicepunkt,
## an dem die Figur stehen muss), autonomous() (läuft ohne Arbeiter, z. B. Pumpen),
## can_skip() (Schritt darf übersprungen werden) und die Wirkung in _finish_step().

var id := 0
var kind: StringName = &""
var target: Node = null
var steps: Array[StringName] = []
var step_index := 0
## Fortschritt des aktuellen Schritts 0..1.
var progress := 0.0
var worker: Node = null
## Leer = nicht blockiert, sonst z. B. &"depot_empty", &"item_missing".
var blocked_reason: StringName = &""
## Höhere Zahl = wichtiger (GroundCrewBrain.Priority: Alarm > Spieler > KI > Wagen nachfüllen).
var priority := 0
## Gearbeitete Sekunden (Spielzeit, für Wertung und Tests).
var elapsed := 0.0
var cancelled := false

const BLOCK_TEXT := {
	&"depot_empty": "Lager leer",
	&"store_empty": "Keine Munition im Vorrat",
	&"item_missing": "Gegenstand fehlt",
	&"toolbox_missing": "Werkzeugkiste fehlt",
	&"not_repairable": "Nicht reparierbar",
	&"not_available": "Noch nicht verfügbar",
	&"source_far": "Schlauch reicht nicht",
	&"no_target": "Keine Maschine",
	&"spark_fire": "Funkenbrand!",
}


func current_step() -> StringName:
	return steps[step_index] if step_index < steps.size() else &""


func is_done() -> bool:
	return step_index >= steps.size()


func is_open() -> bool:
	return not is_done() and not cancelled


static func block_text(reason: StringName) -> String:
	return BLOCK_TEXT.get(reason, String(reason))


## Arbeitet dt Sekunden (bereits mit Arbeitsfaktor) am Schritt step_name.
func step(step_name: StringName, dt: float, rules: GroundRules) -> bool:
	if step_name != current_step() or blocked_reason != &"":
		return false
	if progress <= 0.0 and not _begin_step(step_name, rules):
		return false
	var d := duration(step_name, rules)
	if d <= 0.0:
		progress = 1.0
	else:
		progress = minf(progress + maxf(dt, 0.0) / d, 1.0)
		if progress <= 0.0:
			progress = 0.000001
	if progress >= 1.0:
		return _finish_step(step_name, rules)
	return false


func advance() -> void:
	step_index += 1
	progress = 0.0


## Dauer des Schritts in s Arbeit (0 = sofort fertig).
func duration(_step_name: StringName, _rules: GroundRules) -> float:
	return 0.0


## Servicepunkt (ServiceMarkers-Name), an dem gearbeitet wird, "" = keiner.
func point(_step_name: StringName, _rules: GroundRules) -> String:
	return ""


func autonomous(_step_name: StringName, _rules: GroundRules) -> bool:
	return false


func can_skip(_step_name: StringName, _rules: GroundRules) -> bool:
	return false


## Wird beim ersten Arbeiten am Schritt aufgerufen. false = (noch) nicht möglich.
func _begin_step(_step_name: StringName, _rules: GroundRules) -> bool:
	return true


## Wirkung am Ende des Schritts. false = Schritt bleibt offen (z. B. Pumpen nicht fertig).
func _finish_step(_step_name: StringName, _rules: GroundRules) -> bool:
	return true


## Beim Überspringen des aktuellen Schritts (JobBoard prüft can_skip()).
func on_skip(_step_name: StringName, _rules: GroundRules) -> void:
	pass


## Wird regelmäßig vom JobBoard gerufen: Blockade aufheben, wenn der Grund weg ist.
func recheck(_rules: GroundRules) -> void:
	pass


## Ende (fertig oder abgebrochen): Reste zurückgeben (Mengen-Erhalt).
func cleanup() -> void:
	pass


## Gesamte Arbeitszeit nach Regeln (ohne Wege, ohne autonome Schritte).
func work_seconds(rules: GroundRules) -> float:
	var t := 0.0
	for s in steps:
		if not autonomous(s, rules):
			t += duration(s, rules)
	return t


func aircraft() -> Aircraft:
	return target as Aircraft


func block(reason: StringName) -> void:
	blocked_reason = reason
