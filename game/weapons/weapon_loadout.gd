class_name WeaponLoadout
extends Resource
## Bewaffnung eines Flugzeugtyps (Datei aus AircraftData.loadout_path).

@export var mounts: Array[GunMountDef] = []
## Konvergenzentfernung (m) der Waffen, gemessen ab dem Visier entlang −Z.
@export var convergence := 250.0
## Visierpunkt (lokal). Die Waffen werden auf visier + (0, 0, −convergence) justiert.
@export var sight_position := Vector3.ZERO
## Eigengeschwindigkeit (m/s) entlang −Z für die Justierung (0 = Bodenjustierung).
@export var harmonize_speed := 0.0


## Justierte Abschussrichtungen (lokal) je Waffe: Flugbahn schneidet die Visierlinie in
## `dist` (Standard: convergence) – inkl. Fallkorrektur.
func aim_directions(dist := -1.0) -> PackedVector3Array:
	if dist <= 0.0:
		dist = convergence
	var target := sight_position + Vector3(0, 0, -dist)
	var res := PackedVector3Array()
	for m in mounts:
		var w := m.weapon
		if w == null:
			res.append(Vector3.FORWARD)
			continue
		res.append(Ballistics.solve_direction(m.position, target, w.muzzle_velocity,
				w.ballistic_k, Vector3(0, 0, -harmonize_speed)))
	return res
