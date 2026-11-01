class_name AmmoStore
extends RefCounted
## Munitionsquelle (Lager am Platz, später Versorgung/RearmJob in M5).
## Basis: liefert nichts. Unterklassen überschreiben request().


## Bis zu n Schuss vom Typ `type` anfordern. Rückgabe: tatsächlich gelieferte Menge.
func request(_type: StringName, _n: int) -> int:
	return 0


## M3 (Paket 0b): Bestand vom Typ `type` (Schuss). Basis: nichts.
func available(_type: StringName) -> int:
	return 0


## M3: Schuss zurückgeben (Gurt wieder ausgebaut, Kiste zurück). Rückgabe: angenommen.
func give_back(_type: StringName, _n: int) -> int:
	return 0
