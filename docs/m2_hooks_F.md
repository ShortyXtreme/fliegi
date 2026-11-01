# Hooks für Paket 14 (Agent F – Welt, Pakete 12/13)

Gemeinsame Dateien sind eingefroren; diese Anbindungen fehlen noch und sind in Paket 14 einzubauen.

## Gelände (Paket 12)
1. **`world/game.gd`: TerrainWorld umschaltbar statt TestWorld.** Vorschlag:
   `world = load("res://world/terrain/terrain_world.tscn").instantiate() if use_terrain else TestWorld.new()`.
   Spawns über `world.runway_spawn(i)` und `RUNWAY_DIR` (gleiche Schnittstelle). Für Rot den zweiten Platz:
   `world.runway_spawn(i, 1)` (Platz Rot, 24,8 km entfernt). Hinweis: Auf TerrainWorld zeigt die Piste wie bei
   TestWorld nach −Z; Startpunkt Rot liegt bei (9000, ~124, −8080).
2. **`tests/test_suite.gd` `_spawn()`** nutzt `TestWorld.RUNWAY_DIR` und für die Luft `Vector3(0, alt, 0)`. Mit
   TerrainWorld liegt der Boden dort bei ~100–150 m; Suites mit Gelände sollten `alt` über `world.height_at()`
   setzen (meine Suites tun das selbst).
3. **KI-Bodenschutz / Geschosse**: lesen schon `WorldGround.height_at()`; TerrainWorld meldet sich automatisch an.
4. **Ziel-Marker** für spätere Missionen: Gruppe `terrain_targets` (Marker3D mit Meta `type`, `name`, `radius`,
   `nation`) bzw. `TerrainWorld.targets(type)`. Typen: `erzmine`, `raffinerie`, `fabrik`, `bruecke`.

## Floating Origin (Paket 13)
5. **`world/game.gd`: OriginShifter anlegen** (Schalter, Standard aus):
   `var sh := OriginShifter.new(); sh.focus = player_aircraft; add_child(sh)` – verschiebt alle Node3D-Kinder
   von `Game` (Welt, Flugzeuge, Kamera-Rig). Einschalten: `sh.enabled = true`, `OriginShifter.default_enabled`
   oder Umgebungsvariable `FLOATING_ORIGIN=1`.
6. **`weapons/projectile_system.gd` (Agent A)**: Methode `shift_origin(delta: Vector3)` ergänzen, die alle aktiven
   Geschoss-Positionen (SoA-Arrays) und gespeicherte Vorpositionen um `-delta` verschiebt. Der Shifter ruft sie
   automatisch auf, statt den Knoten zu bewegen. Gleiches für `weapons/transform_history.gd` (Verlauf in
   Szenen-Koordinaten) – oder dort gleich absolut speichern (`WorldOrigin.to_abs`).
7. **Netz/Ereignisse/HUD-Karte**: Positionen, die den Client verlassen (FireEvent, HitValidator, Kartenanzeige),
   über `WorldOrigin.to_abs()` absolut machen; eingehende mit `to_local()` zurückrechnen.
8. **Partikel/Spuren in Weltkoordinaten** (Agent E, `weapons/fx/`, Rauch/Öl Agent B): GPUParticles mit
   `local_coords = false` und Trails springen bei einer Verschiebung; entweder `shift_origin(delta)` anbieten
   oder in die Gruppe `origin_shift_skip` und selbst nachführen.
