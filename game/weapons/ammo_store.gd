class_name AmmoStore
extends RefCounted
## Munitionsquelle (Lager am Platz, später Versorgung/RearmJob in M5).
## Basis: liefert nichts. Unterklassen überschreiben request().


## Bis zu n Schuss vom Typ `type` anfordern. Rückgabe: tatsächlich gelieferte Menge.
func request(_type: StringName, _n: int) -> int:
	return 0
