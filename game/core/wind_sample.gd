class_name WindSample
extends RefCounted
## M3.9: Ergebnis einer Wind-Abfrage (Weather.sample) mit Anteilen – für Flugmodell und
## Kräfte-Debug. Alle Vektoren m/s, Welt; total = mean + turb + orographic + thermal.

var total := Vector3.ZERO
## Mittlerer Wind (Profil, Drehung mit der Höhe, Kanalisierung, Lee-Abschwächung)
var mean := Vector3.ZERO
## Turbulenz (Böen, eingefrorenes Feld nach Dryden-Skalen)
var turb := Vector3.ZERO
## Hangauf-/abwind (senkrecht)
var orographic := 0.0
## Thermik / Absinken (senkrecht)
var thermal := 0.0
## Rollböe: Unterschied des Vertikalwindes zwischen den Flügelspitzen je Meter Spannweite (1/s);
## Wind an einem Punkt r (Welt, relativ zum Schwerpunkt) = total + UP · roll_grad · (r · rechts)
var roll_grad := 0.0
## Turbulenz-Stärke (σu, σv, σw in m/s) und Hilfswerte
var sigma := Vector3.ZERO
var z0 := 0.03
var lee := 0.0
var channel := 0.0
var agl := 0.0


func clear() -> void:
	total = Vector3.ZERO
	mean = Vector3.ZERO
	turb = Vector3.ZERO
	orographic = 0.0
	thermal = 0.0
	roll_grad = 0.0
	sigma = Vector3.ZERO
	z0 = 0.03
	lee = 0.0
	channel = 0.0
	agl = 0.0
