# Asset-Lizenzen

Herkunft und Lizenz aller Grafik-Assets, die nicht im Projekt selbst entstanden sind.
Klänge: siehe art/licenses/ und docs/sound_quellen_recherche.md.

## M3.7 Welt (Boden, Vegetation, Spuren)

Keine fremden Assets. Alles ist eigene Arbeit des Projekts:

| Asset | Entstehung | Lizenz |
|---|---|---|
| Gelände-Detailtexturen (fBm, Zellen, Normal-Detail) | zur Laufzeit erzeugt mit FastNoiseLite (`TerrainWorld._detail_textures`), keine Bilddateien | eigenes Werk |
| Untergrund-Mischung, Felder, Fels, Sand | Shader `game/world/terrain/terrain.gdshader` | eigenes Werk |
| Bäume und Busch (laub_a, laub_b, nadel_a, nadel_b, busch; je 3 Detailstufen) | Blender-Skript `art/scripts/build_vegetation.py` (bmesh, Vertexfarben, keine Texturen) → `game/assets/ground/vegetation.glb` | eigenes Werk |
| Gras-Büschel | zur Laufzeit erzeugt (`Vegetation._clump_mesh`), Shader `game/world/vegetation/grass.gdshader` | eigenes Werk |
| Abnutzung auf der Graspiste | weiche Flecken (Laufzeit-Verlaufstextur) in `airfield_dressing.gd` | eigenes Werk |
