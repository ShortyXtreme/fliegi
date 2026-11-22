# M3 Hooks Grafik (für Paket 14)

Stand: 02.11.2026 · Branch `m3-grafik`

## Modelle (Paket 11)
- GLBs unter `game/assets/ground/` (Quelle `art/models/ground/`, Daten in `art/models/ground/ground_props.json`).
  Konvention: Y oben, **vorn −Z**, rechts +X, Ursprung am Boden (y = 0). Fahrzeuge: Mitte zwischen den Achsen
  (Radstand 3,70 m, Spur 1,60 m, Radius 0,46 m). Gebäude: Öffnung/Tür nach −Z.
- Bewegliche Knoten: `wheel_FL/FR/RL/RR` (Drehpunkt Nabe, rollen um lokale X), `hose_reel_drum` (um X),
  `tailgate` (Munitionswagen, Scharnier unten, um X), `door_leaf_1..4` (Hangar, Schiebetor entlang X),
  `ammo_door_L/R` (Bunker, Scharnier außen, um Y).
- Marker (leere Knoten): Tankwagen `hose_reel`, `hose_nozzle`, `ground_clip`, `fuel_fill`, `seat_driver`,
  `seat_passenger`, `entry_driver`, `entry_passenger`; Munitionswagen `crate_slot_1..6` (Unterkante Kiste auf
  der Ladefläche), `cargo_access`, Sitze wie oben; Kiste/Fass/Kleinteile `carry` (+ Kiste `hand_L/R`);
  Hangar `door`, `aircraft_spot`; Tanklager `fuel_tap`, `fuel_tap_truck`; Bunker `ammo_door`, `ammo_door_truck`;
  Bodenmarke `stand_point`, `main_wheel_stop` (Flugzeug-Nase zeigt nach −Z).
- Test: `tests/suites/art/test_art_assets.gd` (Import, Meshes, Marker, Animationen).

## Jäger-Marker (svc_*)
- `art/models/fighter_t1_game.glb` und `_enemy.glb` enthalten jetzt `svc_fuel_cap`, `svc_gun_hatch_L/R`,
  `svc_entry`, `svc_engine` (verlustfrei in den GLB-JSON-Block eingefügt, Geometrie/Texturen unverändert).
  Extraktion geprüft: 7 Trefferzonen, 2 Waffen, 3 Außenlasten wie vorher, Punkte 29 → 34.
  Vergleich (02.11.): `tools/extract_markers.gd` mit dem neuen GLB in eine Scratch-.tres; die Felder
  `zone_names`, `zone_centers`, `zone_half_extents` sind byte-gleich mit der bestehenden
  `vehicles/aircraft/data/markers/fighter_t1_markers.tres` (md5 identisch). Die Diagnosezeile „Hitbox-Zonen 9“
  bleibt: `HitboxSet.from_markers` ergänzt zu den 7 Marker-Zonen 2 Rumpf-Füllboxen (`_add_fuselage_fillers`).
- **Paket 14:** `tools/sync_art.sh` ausführen (kopiert nach `vehicles/aircraft/models/`) und
  `tools/extract_markers.gd` neu laufen lassen → `vehicles/aircraft/data/markers/fighter_t1_markers.tres`
  (gemeinsame Dateien, darum nicht von Grafik geändert). Bis dahin greifen die Ersatzpositionen in `ServiceMarkers`.

## M3.5: Munitionsklappen und Tankstutzen (Agent B)
- Modell: `ammo_hatch_L/R` (Klappe über dem Flügel-MG, Scharnier vorn, öffnet 105°) über `ammo_box_L/R`
  (fester Munitionsschacht mit Gurt); Tankstutzen `fuel_filler` (fest, roter Ring) mit Deckel `fuel_cap_lid`
  (hinten angeschlagen, schwenkt 110° nach außen) an der **linken Rumpfseite vor der Windschutzscheibe** (Rumpftank-Bereich,
  ~2 m über Grund, vom Boden/Flügelwurzel aus erreichbar), nicht mehr oben auf dem Rumpf.
  (Flügelwurzel-Oberseite verworfen: KI-Tankwagen parkt dann seitlich, Schlauchrolle > 12 m vom Deckel.) Achsen/Winkel in `fighter_t1_rig.json` (`parts.*.axis_local_vec`, `open_deg`).
  Erzeugt von `build_game_aircraft.py -- --add-service-parts` (verlustfrei, nach `--build` automatisch).
- Marker neu gesetzt (Namen gleich): `svc_gun_hatch_L/R` über der Klappenmitte, `svc_fuel_cap` (= `fuel_port`)
  über dem Deckel. Trefferzonen unverändert (7 Marker-Zonen + 2 Füllboxen = 9).
- **Schnittstelle für Bodenjobs:** `aircraft.set_service_part_open(name, open) -> bool` bzw.
  `aircraft.visual.set_service_part_open(name, open, instant = false)`; `name` = `"gun_hatch_L"`,
  `"gun_hatch_R"`, `"fuel_cap"` (Präfix `svc_` wird akzeptiert). Abfrage `is_service_part_open(name)`,
  `service_part_amount(name)` (0..1); Signal `AircraftVisual.service_part_changed(name, open)` am Ende der
  Bewegung (0,8 s). Reine Darstellung, kein Netzwerkzustand.

## Figur „Mechaniker“ (Paket 12)
- `game/assets/ground/crew_mechanic.glb` (2.300 Dreiecke, 1024er Atlas). Blick **−Z**, Ursprung am Boden
  zwischen den Füßen, T-Pose, Knochennamen nach `SkeletonProfileHumanoid` (ohne Finger/Augen/Kiefer, mit `Root`).
- Animationen (30 fps, eigene prozedurale Keyframes): `idle`, `walk` (1,0 s ≙ 1,6 m/s), `run` (0,7 s ≙ 4,5 m/s),
  `carry`, `hose`, `work` (Schleifen, gesetzt in `crew_mechanic.glb.import`), `lift` und `enter` (einmalig).
  Namen = `CrewCharacter.ANIM_NAMES` plus `lift`.
- Marker: `hand_R`/`hand_L` an den Handknochen (werden BoneAttachment3D), `carry` vor dem Körper (0, 1,0, −0,42).
- `characters/crew/anim/crew_model.tscn`: GLB + `AnimationTree` mit `crew_anim_tree.tres` (StateMachine,
  Zustände wie oben, Überblendung 0,2 s, `lift`/`enter` laufen automatisch nach `idle` zurück).
  **Paket 14/Strang H:** `crew_model.tscn` unter `CrewCharacter.visual` instanziieren und
  `anim_tree` auf dessen `AnimationTree` setzen (`parameters/playback` passt). Neu erzeugen mit
  `characters/crew/anim/build_crew_anim.gd`.
