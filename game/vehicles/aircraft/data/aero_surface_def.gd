class_name AeroSurfaceDef
extends Resource
## Eine aerodynamische Fläche (Flügelsegment, Leitwerkshälfte, Seitenflosse).
## Lokales Flächen-Koordinatensystem: -Z = Profilsehne nach vorn, +Y = Flächennormale
## ("oben"), +X = Spannweitenrichtung. Über rotation_deg wird sie am Rumpf ausgerichtet:
## x = Einstellwinkel (Grad), z = V-Form (Grad), z = 90 -> Seitenflosse.

enum ControlAxis { NONE, PITCH, ROLL, YAW, FLAPS }

@export var name: String = "surface"
## Lage des Druckpunkts (t/4-Linie, Segmentmitte) relativ zum Schwerpunkt, Meter.
@export var position: Vector3 = Vector3.ZERO
@export var rotation_deg: Vector3 = Vector3.ZERO
@export var span: float = 1.0
@export var chord: float = 1.0
## Streckung des ganzen Flügels (für Auftriebsanstieg und induzierten Widerstand).
@export var aspect_ratio: float = 6.0
## Profil-Auftriebsanstieg (pro Radiant), 2*PI für dünnes Profil.
@export var lift_slope: float = 6.0
@export var zero_lift_aoa_deg: float = -2.0
@export var stall_angle_high_deg: float = 15.0
@export var stall_angle_low_deg: float = -13.0
## Nullwiderstandsbeiwert der Fläche.
@export var skin_friction: float = 0.008
## Anteil der Ruder-/Klappentiefe an der Profiltiefe (0..1).
@export var flap_fraction: float = 0.25
@export var control_axis: ControlAxis = ControlAxis.NONE
## Vorzeichen des Ruderausschlags bezogen auf das Steuerkommando.
@export var control_sign: float = 1.0
@export var max_deflection_deg: float = 20.0
## Anteil des Flügel-Abwinds, den diese Fläche sieht (1 = Höhenleitwerk, 0 = keiner).
@export var downwash_factor: float = 0.0
## Gehört zum Haupt-Flügel (für Strömungsabriss-Anzeige).
@export var is_main_wing: bool = false


func area() -> float:
	return span * chord
