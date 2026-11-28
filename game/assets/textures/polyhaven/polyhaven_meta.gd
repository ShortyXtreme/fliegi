# Erzeugt von tools/prep_polyhaven.py (M3.13) – nicht von Hand ändern.
# Poly Haven, CC0 (docs/asset_lizenzen.md).
extends RefCounted

## Gelände-Ebenen (Index im Texture2DArray)
const LAYERS := ["aerial_grass_rock", "forest_ground_04", "leaves_forest_ground", "brown_mud_leaves_01", "rocks_ground_02", "coast_sand_rocks_02", "dirt_floor"]
## Stufe Hoch: Index im 2K-Array je Ebene (-1 = nur 1K)
const HI_INDEX := [0, 1, 2, 3, -1, -1, 4]
## Mittlere Farbe je Ebene (linear, nach AO) – der Shader nimmt Textur / Mittel als Detail
const MEAN := [Color(0.12750, 0.09204, 0.02181), Color(0.14359, 0.10263, 0.06127), Color(0.17037, 0.10178, 0.03981), Color(0.12571, 0.09119, 0.03435), Color(0.15062, 0.11504, 0.07247), Color(0.07023, 0.05760, 0.02829), Color(0.45008, 0.25110, 0.12348)]
## Mittlere Farbe Rinde/Bretter/Farbe (linear)
const OBJ_MEAN := {"rinde": Color(0.09672, 0.06688, 0.04779), "bretter": Color(0.11853, 0.07329, 0.04411), "farbe": Color(0.07645, 0.06054, 0.04440)}
## himmel_klar: Richtung zur Sonne (Godot-Panorama), Höhe/Azimut in Grad, Mittel oberer Halbraum, Horizont
const HIMMEL_KLAR := {"sun": Vector3(-0.39348, 0.74147, 0.54351), "elev": 47.86, "az": 215.90, "mean_up": Color(0.42002, 0.48081, 0.67680), "horizon": Color(0.42506, 0.46235, 0.56728)}
## himmel_bedeckt: Richtung zur Sonne (Godot-Panorama), Höhe/Azimut in Grad, Mittel oberer Halbraum, Horizont
const HIMMEL_BEDECKT := {"sun": Vector3(-0.46579, 0.88372, 0.04552), "elev": 62.09, "az": 264.42, "mean_up": Color(1.11485, 1.26602, 1.42967), "horizon": Color(0.23733, 0.27241, 0.27959)}
