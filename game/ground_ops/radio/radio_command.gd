class_name RadioCommand
extends RefCounted
## M3.5: Eintrag im Funkgerät (Funkkanal). Entweder ein Befehl (command = GroundCrewBrain.Command
## bzw. später Befehle anderer Rollen) oder eine Unterebene (children, höchstens eine Ebene tief).
## Siehe docs/funk_konzept.md.

var id: StringName = &""
var label := ""
## Befehl (-1 = Unterebene).
var command := -1
## Kurze Erklärung (Fußzeile im Panel).
var hint := ""
var children: Array = []


static func make(p_id: StringName, p_label: String, p_command := -1, p_hint := "", p_children: Array = []) -> RadioCommand:
	var c := RadioCommand.new()
	c.id = p_id
	c.label = p_label
	c.command = p_command
	c.hint = p_hint
	c.children = p_children
	return c


func is_menu() -> bool:
	return not children.is_empty()
