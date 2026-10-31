class_name Layers
extends RefCounted
## Physik-Layer (Bitmasken). Namen zusätzlich in project.godot [layer_names].
## Vertrag aus Paket 0 – neue Layer nur in Paket 14.
## Geschosse sind KEINE Physikobjekte (ProjectileSystem, reine Daten); für bodennahe
## Raycasts nutzen sie MASK_PROJECTILE_RAY.

const WORLD := 1 << 0           # Boden, Gelände-Kacheln, Gebäude, Pisten
const AIRCRAFT := 1 << 1        # Flugzeug-Kollisionsboxen
const GROUND_VEHICLE := 1 << 2  # Fahrzeuge (später)
const CHARACTER := 1 << 3       # Piloten am Boden, Fallschirm (später)
const WRECK := 1 << 4           # Wracks (30 s)
const SENSOR := 1 << 5          # Areas/Trigger (Radar-, Platzzonen), keine Kollision

## Womit kollidiert ein Flugzeug.
const MASK_AIRCRAFT := WORLD | AIRCRAFT | GROUND_VEHICLE | WRECK
## Höhe über Grund (Telemetrie height_agl, nur fester Boden).
const MASK_GROUND_RAY := WORLD
## Fahrwerk und Bauchkufen (Boden, Fahrzeuge, Wracks – keine Flugzeuge).
const MASK_GEAR_RAY := WORLD | GROUND_VEHICLE | WRECK
## Bodennahe Geschoss-Raycasts.
const MASK_PROJECTILE_RAY := WORLD | GROUND_VEHICLE | WRECK
