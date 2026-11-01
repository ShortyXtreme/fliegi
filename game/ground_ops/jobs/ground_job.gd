class_name GroundJob
extends RefCounted
## M3 Vertrag (Paket 0b, gehört Strang G / Pakete 2–3): Basis aller Bodenjobs. Ein Job
## hat feste Schritte; JobBoard.request_step() schreibt den Fortschritt fort.
## Feste Signaturen: id, kind, target, steps, step_index, progress, worker, blocked_reason,
## current_step(), is_done(), step(step_name, dt, rules) -> bool (true = Schritt fertig).

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
## Höhere Zahl = wichtiger (Alarm > Spieler-Maschine > KI-Maschine > Wagen nachfüllen).
var priority := 0


func current_step() -> StringName:
	return steps[step_index] if step_index < steps.size() else &""


func is_done() -> bool:
	return step_index >= steps.size()


## Arbeitet dt Sekunden am Schritt step_name. Unterklassen überschreiben das.
func step(_step_name: StringName, _dt: float, _rules: GroundRules) -> bool:
	return false


func advance() -> void:
	step_index += 1
	progress = 0.0
