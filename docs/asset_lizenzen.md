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

## M3.13 Texturen und Himmel (Poly Haven)

Aufbereitet mit `game/tools/prep_polyhaven.py` nach `game/assets/textures/polyhaven/` (Quelldateien 2K/4K nicht im Repo).
Alle: **CC0, keine Namensnennung nötig, Quelle Poly Haven** (polyhaven.com).

| Asset | Verwendung | Dateien im Spiel | Link | Lizenz |
|---|---|---|---|---|
| aerial_grass_rock (Textur, 2K-Quelle) | Gelände: Wiese, Feldrand, Weide, Pistengrund | gelaende_col_1k/2k, gelaende_nrm_1k (Ebene 0) | https://polyhaven.com/a/aerial_grass_rock | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| forest_ground_04 (Textur, 2K-Quelle) | Gelände: Waldboden (Nadelstreu, Moos) | gelaende_* (Ebene 1) | https://polyhaven.com/a/forest_ground_04 | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| leaves_forest_ground (Textur, 2K-Quelle) | Gelände: Waldboden (Laub), Hecken | gelaende_* (Ebene 2) | https://polyhaven.com/a/leaves_forest_ground | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| brown_mud_leaves_01 (Textur, 2K-Quelle) | Gelände: Ufer, Schlamm, Böschung, Flussbett | gelaende_* (Ebene 3) | https://polyhaven.com/a/brown_mud_leaves_01 | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| rocks_ground_02 (Textur, 2K-Quelle) | Gelände: Fels, Steilhang (triplanar) | gelaende_col_1k, gelaende_nrm_1k (Ebene 4) | https://polyhaven.com/a/rocks_ground_02 | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| coast_sand_rocks_02 (Textur, 2K-Quelle) | Gelände: Sand/Kies am Ufer | gelaende_col_1k, gelaende_nrm_1k (Ebene 5) | https://polyhaven.com/a/coast_sand_rocks_02 | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| dirt_floor (Textur, 2K-Quelle) | Gelände: offene Erde, Acker; Flugplatz: Rollwege, Abstellfläche, abgenutzte Grasbahnen | gelaende_* (Ebene 6) | https://polyhaven.com/a/dirt_floor | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| bark_platanus (Textur, 2K-Quelle) | Baumstämme (tree.gdshader) | rinde_col_1k, rinde_nrm_1k | https://polyhaven.com/a/bark_platanus | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| weathered_brown_planks (Textur, 2K-Quelle) | Hallen-Stirnwände und -Tore, Schuppen | bretter_col_1k, bretter_nrm_1k | https://polyhaven.com/a/weathered_brown_planks | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| wood_peeling_paint_weathered (Textur, 2K-Quelle) | Flugleitung (gestrichenes Holzhaus) | farbe_col_1k, farbe_nrm_1k | https://polyhaven.com/a/wood_peeling_paint_weathered | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| kloofendal_48d_partly_cloudy (HDRI, 4K-Quelle) | Standard-Himmel, Umgebungslicht, Sonnenrichtung | himmel_klar_2k.hdr | https://polyhaven.com/a/kloofendal_48d_partly_cloudy | CC0, keine Namensnennung nötig, Quelle Poly Haven |
| quarry_cloudy (HDRI, 4K-Quelle) | Himmel bei Bedeckung (Kaltfront) | himmel_bedeckt_2k.hdr | https://polyhaven.com/a/quarry_cloudy | CC0, keine Namensnennung nötig, Quelle Poly Haven |
