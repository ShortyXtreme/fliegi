class_name Nations
extends RefCounted
## Nationen und Diplomatie (M2: Blau gegen Rot). Vertrag aus Paket 0 – nur Paket 14 ändert.
## Aircraft.nation_id hält einen dieser Werte. Wer wen bekämpft, steht in der Matrix;
## KI-Wahrnehmung, HUD-Marker und Trefferprüfung fragen ausschließlich is_hostile().
## Eigenbeschuss ist technisch immer möglich; ob er Schaden macht, entscheidet
## MatchRules.friendly_fire_damage (Lobby, Standard aus).

enum Relation { ALLIED, NEUTRAL, WAR }

const NONE := -1
const BLUE := 0
const RED := 1
const COUNT := 2

const NAMES := ["Blau", "Rot"]
const COLORS := [Color(0.35, 0.6, 1.0), Color(1.0, 0.35, 0.3)]

## Diplomatie-Matrix [a][b] (symmetrisch gepflegt über set_relation).
static var _matrix: Array = _default_matrix()


static func _default_matrix() -> Array:
	return [
		[Relation.ALLIED, Relation.WAR],
		[Relation.WAR, Relation.ALLIED],
	]


static func is_valid(n: int) -> bool:
	return n >= 0 and n < COUNT


static func relation(a: int, b: int) -> int:
	if not is_valid(a) or not is_valid(b):
		return Relation.NEUTRAL
	return _matrix[a][b]


static func is_hostile(a: int, b: int) -> bool:
	return relation(a, b) == Relation.WAR


static func is_friendly(a: int, b: int) -> bool:
	return is_valid(a) and relation(a, b) == Relation.ALLIED


static func set_relation(a: int, b: int, r: int) -> void:
	if not Authority.is_server() or not is_valid(a) or not is_valid(b):
		return
	_matrix[a][b] = r
	_matrix[b][a] = r


static func reset() -> void:
	_matrix = _default_matrix()


static func display_name(n: int) -> String:
	return NAMES[n] if is_valid(n) else "–"


static func color(n: int) -> Color:
	return COLORS[n] if is_valid(n) else Color(0.8, 0.8, 0.8)
