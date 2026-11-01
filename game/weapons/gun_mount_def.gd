class_name GunMountDef
extends Resource
## Einbauort einer Waffe im Flugzeug (Koordinaten wie AircraftData: Ursprung = Schwerpunkt,
## vorne = −Z). Später ersetzt ein Marker (gun_*) aus dem Modell die Position.

@export var marker_name := ""
## Mündungsposition (lokal, m).
@export var position := Vector3.ZERO
## WeaponSystem.Group (0 = primär, 1 = sekundär).
@export var group := 0
@export var weapon: WeaponDef
## Magazin (Schuss).
@export var ammo := 500
