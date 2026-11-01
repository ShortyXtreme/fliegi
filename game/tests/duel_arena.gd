class_name DuelArena
extends Node3D
## Minimale Testwelt für KI-Duelle (Paket 8): flacher Boden bei y = 0, optional einfaches
## Hügel-Gelände (Gauß-Hügel) mit Kollision (HeightMapShape3D) und height_at(x, z) über
## WorldGround – dieselbe Schnittstelle wie TerrainWorld (Vertrag).

const SPACING := 100.0
const CELLS := 160            # 16 km × 16 km Höhenfeld um den Ursprung
## Hügel: [x, z, Höhe, Radius(σ)] – ein Rücken zwischen den Duellanten plus zwei Kuppen.
const HILLS := [
	[0.0, 0.0, 1000.0, 1300.0],
	[2500.0, -1500.0, 800.0, 1000.0],
	[-2500.0, 1800.0, 700.0, 900.0],
]

var hills := false


func _init(with_hills := false) -> void:
	hills = with_hills


func _ready() -> void:
	var body := StaticBody3D.new()
	body.name = "Ground"
	var cs := CollisionShape3D.new()
	cs.shape = WorldBoundaryShape3D.new()
	body.add_child(cs)
	if hills:
		var hm := HeightMapShape3D.new()
		var n := CELLS + 1
		hm.map_width = n
		hm.map_depth = n
		var data := PackedFloat32Array()
		data.resize(n * n)
		var half := CELLS * SPACING * 0.5
		for iz in n:
			for ix in n:
				data[iz * n + ix] = height_at(ix * SPACING - half, iz * SPACING - half)
		hm.map_data = data
		var hs := CollisionShape3D.new()
		hs.shape = hm
		hs.scale = Vector3(SPACING, 1.0, SPACING)
		body.add_child(hs)
	add_child(body)
	WorldGround.set_provider(self)


func _exit_tree() -> void:
	WorldGround.clear_provider(self)


func height_at(x: float, z: float) -> float:
	if not hills:
		return 0.0
	var h := 0.0
	for p in HILLS:
		var dx: float = x - p[0]
		var dz: float = z - p[1]
		h += p[2] * exp(-(dx * dx + dz * dz) / (2.0 * p[3] * p[3]))
	return h
