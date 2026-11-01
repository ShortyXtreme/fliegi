class_name Interactable
extends Node3D
## M3 (Paket 4, Strang H): Interaktionspunkt. Kommt aus Markern
## (ServiceMarkers: svc_*, hose_reel, crate_slot_*, seat_driver). Aktionen:
##   {id: StringName, label: String, hold_s: float, needs_item: StringName (leer = keins)}
## Optional je Aktion: "can": Callable(character) -> bool (sonst immer möglich),
## "continuous": true = Dauer-Aktion (nur holding solange gehalten, nie performed).
## Feste Signaturen: marker, target, actions, add_action(), actions_for(character) -> Array.
##
## Ablauf (CrewCharacter): Die Figur wählt per InteractionQuery den Punkt im Blickkegel,
## hält „Interagieren“ und meldet jeden Tick holding(id, character, dt, progress). Ist
## hold_s erreicht (bzw. sofort bei hold_s = 0), kommt einmal performed(id, character).
## Langläufer wie Pumpen oder Gurt einlegen hängen sich an holding (JobBoard.request_step).
## Alle Punkte im Baum stehen in Interactable.all() (Kandidaten für die Abfrage).

signal holding(action_id: StringName, character: Node, dt: float, progress: float)
signal performed(action_id: StringName, character: Node)

var marker := ""
## Flugzeug/Fahrzeug/Gebäude, zu dem der Punkt gehört.
var target: Node = null
var actions: Array[Dictionary] = []
## Optional: Sitz hinter dem Punkt (Einsteigen mit F, CrewCharacter.try_enter).
var seat: Seat = null
## Ausgeschaltete Punkte findet die Abfrage nicht.
var enabled := true

static var _all: Array[Interactable] = []


func _enter_tree() -> void:
	if not _all.has(self):
		_all.append(self)


func _exit_tree() -> void:
	_all.erase(self)


static func all() -> Array[Interactable]:
	return _all


func add_action(id: StringName, label: String, hold_s: float = 0.0, needs_item: StringName = &"",
		can: Callable = Callable()) -> Dictionary:
	var a := {"id": id, "label": label, "hold_s": hold_s, "needs_item": needs_item}
	if can.is_valid():
		a["can"] = can
	actions.append(a)
	return a


func get_action(id: StringName) -> Dictionary:
	for a in actions:
		if a.id == id:
			return a
	return {}


## Aktionen, die die Figur gerade ausführen kann (Bedingung erfüllt, Gegenstand da).
func actions_for(character: Node) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a in actions:
		if _possible(a, character) and missing_item(a, character) == &"":
			out.append(a)
	return out


## Erste sichtbare Aktion (Bedingung erfüllt), auch wenn der Gegenstand fehlt – für den
## Hinweis „[E] halten: Gurt einlegen“ bzw. „Kiste fehlt“ im HUD. Leer = nichts zu tun.
func hint_for(character: Node) -> Dictionary:
	for a in actions:
		if _possible(a, character):
			var h := a.duplicate()
			h["missing"] = missing_item(a, character)
			return h
	return {}


## Fehlender Gegenstand für die Aktion (leer = vorhanden bzw. nicht nötig).
static func missing_item(a: Dictionary, character: Node) -> StringName:
	var need: StringName = a.get("needs_item", &"")
	if need == &"":
		return &""
	var item = character.get("carried") if character != null else null
	if item != null and is_instance_valid(item) and StringName(item.get("kind")) == need:
		return &""
	return need


static func _possible(a: Dictionary, character: Node) -> bool:
	var c: Callable = a.get("can", Callable())
	return not c.is_valid() or bool(c.call(character))
