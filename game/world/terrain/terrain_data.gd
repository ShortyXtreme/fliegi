class_name TerrainData
extends Resource
## Gespeicherte Höhenkarte (erzeugt von tools/build_terrain.gd, Paket 12).
## Koordinaten "Gelände-lokal": x, z in Metern, Kartenmitte = (0, 0), Rand bei ±size_m/2.
## Höhen liegen als float32 (auf 1/64 m gerundet) zstd-komprimiert vor, die Bodenmaske
## (R Wald, G Platz/gemäht, B Wasser/Aue, A Felder erlaubt) als PNG.

@export var seed: int = 0
@export var size_m: float = 40000.0
@export var samples: int = 2049
@export var tiles: int = 16
@export var heights_zstd := PackedByteArray()
@export var heights_raw_size: int = 0
@export var mask_png := PackedByteArray()
## Je Kachel [min, max] Höhe (für AABBs), Reihenfolge tz * tiles + tx.
@export var tile_minmax := PackedFloat32Array()
## Flugplätze: {name, center: Vector3 (y = Pistenhöhe), length, width, nation}
@export var airfields: Array[Dictionary] = []
## Ziel-Marker: {type ("erzmine", "raffinerie", "fabrik", "bruecke"), name, pos: Vector3, radius, nation}
@export var targets: Array[Dictionary] = []
## Talzug/Flusslauf als Mittellinie (x, z), von Nordwest nach Südost.
@export var river := PackedVector2Array()


func spacing() -> float:
	return size_m / float(samples - 1)


func decode_heights() -> PackedFloat32Array:
	return heights_zstd.decompress(heights_raw_size, FileAccess.COMPRESSION_ZSTD).to_float32_array()


func decode_mask() -> Image:
	var img := Image.new()
	img.load_png_from_buffer(mask_png)
	return img
