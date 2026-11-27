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

## M3.8 Fluss und Wind

Keine fremden Assets. Alles ist eigene Arbeit des Projekts:

| Asset | Entstehung | Lizenz |
|---|---|---|
| Fluss- und Bachläufe, Flussbett, Ufer | prozedural im Geländegenerator `game/world/terrain/terrain_generator.gd` (Talachse, Priority-Flood-Abfluss), gespeichert in `terrain_main.res` | eigenes Werk |
| Wasserfläche (Strömung, Wellen, Spiegelung, Schaum) | Shader `game/world/terrain/water.gdshader`, Band-Meshes zur Laufzeit (`river_water.gd`), Wellen-Normalen zur Laufzeit aus FastNoiseLite (keine Bilddatei) | eigenes Werk |
| Ufer (Schlamm, Kies, Sand, Flussbett) | Shader `game/world/terrain/terrain.gdshader` mit Ufer-Textur aus dem Generator | eigenes Werk |
| Brücken (Fachwerk, Steinbogen, Erddämme) | prozedural zur Laufzeit (`game/world/terrain/bridges.gd`, SurfaceTool), einfache Materialien | eigenes Werk |
| Wasserfontäne, Gischt, Ringwellen, Einschlag-Spritzer | GPUParticles/Meshes zur Laufzeit (`crash_fx.gd`, `weapon_fx.gd`) | eigenes Werk |
| Windsack, Wind in Gras/Bäumen/Rauch | vorhandene eigene Modelle/Shader, an `core/weather.gd` gekoppelt | eigenes Werk |
