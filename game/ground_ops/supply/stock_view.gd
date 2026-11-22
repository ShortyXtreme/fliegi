class_name StockView
extends RefCounted
## M3.5: Lagerbestände (Tanklager, Munitionsbunker) sind kein HUD-Wissen. Sehen darf sie nur, wer
## dafür zuständig ist – später die Rollen Nachschub bzw. Werkstatt & Bodenpersonal an ihrer Tafel
## oder am Planungstisch. Das Debug-Overlay (F3) zeigt sie weiterhin.

## Rollen mit Einsicht in die Lagerbestände.
const ROLES: Array[StringName] = [&"supply", &"workshop"]


static func visible_for(role: StringName) -> bool:
	return ROLES.has(role)


## Bestände für eine Rolle ({} = keine Einsicht). Werte wie GroundHudData.stock().
static func query(role: StringName, depot: FuelSource, bunker: AmmoStore) -> Dictionary:
	if not visible_for(role):
		return {}
	return GroundHudData.stock(depot, bunker)
