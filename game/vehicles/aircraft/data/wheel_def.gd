class_name WheelDef
extends Resource
## Ein Rad mit Federbein (Raycast-Federung).

@export var name: String = "wheel"
## Oberer Federbein-Anlenkpunkt relativ zum Schwerpunkt, Meter.
@export var position: Vector3 = Vector3.ZERO
@export var rest_length: float = 0.6
@export var radius: float = 0.3
@export var spring: float = 90000.0     # N/m
@export var damper: float = 9000.0      # N/(m/s)
## Lenkeinschlag bei vollem Seitenruder (+ = Rad dreht nach links bei Ruder rechts, für Heckrad).
@export var steer_max_deg: float = 0.0
@export var has_brake: bool = false
@export var brake_friction: float = 0.55
@export var rolling_friction: float = 0.035
@export var lateral_friction: float = 0.9
## Einziehbar (Hauptfahrwerk). Das Spornrad ist fest.
@export var retractable: bool = true
