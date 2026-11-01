# M3 Strang C (KI-Flugbetrieb) – Hooks für Paket 14

Stand: 01.11.2026 · Branch `m3-c` · Pakete 8, 9a, 9b, 10

Strang C hat keine gemeinsame Datei geändert. Damit der Flugbetrieb im Spiel sichtbar wird, muss Paket 14 Folgendes verdrahten:

## 1. KI-Gegner am Boden (`world/combat_scenario.gd`)
- Statt `_place_enemy()` in der Luft: `spawn_manager.register_ground(a, br, layout, delay)` mit `layout = terrain.airfield_layout(red_field)`, danach einmal `spawn_manager.spawn_on_ground(a, layout, MatchRules.StartKind.FIRST)`.
- `spawn_on_ground()` legt `br.airfield = AirfieldPhases` an und setzt Phase `PARKED`. Damit rollt, startet und landet die KI selbst. Den Neustart (`AFTER_LOSS`) erledigt der SpawnManager über den registrierten Callback.
- Die erste Maschine hat in Standard 50 % Treibstoff, die KI will aber ≥ 60 %. Ohne Bodenpersonal startet sie nach `scramble_timeout` (90 s) per Notstart. Für sofortige Starts kann man `br.airfield.scramble_timeout` senken oder der Bodenmannschaft (Strang G) die Maschine zuerst geben.
- Ein Notstart erfolgt nur mit > 30 % Treibstoff und ≥ 20 % Munition. Nach einem Abschuss (15 %/0) wartet die KI auf Versorgung.

## 2. Spieler am Boden (`world/game.gd`)
- `_place_player_on_ground()` → `spawn_manager.spawn_on_ground(player_aircraft, layout_blau, MatchRules.StartKind.FIRST)`.
- `spawn_manager.register(...)` → `spawn_manager.register_ground(player_aircraft, player, layout_blau)`. Neustarts nach einem Verlust kommen dann als `AFTER_LOSS` auf einen freien Abstellplatz.
- „Neue Maschine nach Landung“: `spawn_manager.respawn_after_landing(aircraft)` (Restzustand bleibt).
- Die Debugtasten R/T in `game.gd` setzen noch auf die Piste bzw. in die Luft. Diese Debughilfe sollte bleiben, im Spielablauf kommt sie aber nicht mehr vor.

## 3. Pistenvergabe
- `RunwayControl.find_or_create(node, index)` legt je Platz eine Instanz an (Gruppe `runway_controls`). Der SpawnManager legt sie bei Bedarf unter sich an. Wer einen festen Ort will, legt sie in `game.gd` unter Game an. Der Spieler fragt die Piste bisher nicht an, die KI achtet also nicht auf ihn. Als möglicher Hook für M3.1 kann der Spieler beim Rollen auf die Piste `request()` aufrufen.

## 4. Selbsttest Phase E (Paket 15)
- Gleiches Muster wie `tests/suites/airfield/airfield_util.gd: ai_at_parking()`: eine rote KI am Abstellplatz mit 100 % Munition und ≥ 60 % Treibstoff. Messung: Phase `TAXI_OUT` bis `height_agl ≥ 300` in ≤ 90 s (Test: 10/10, höchstens 86 s).

## 5. Daten
- `ground_ops/airfield/data/airfield_{0,1}.tres` wird mit `godot --headless --path game --script res://ground_ops/airfield/build_layouts.gd` aus `AirfieldLayout.make_default()` erzeugt. Neu sind die Felder `parking_in_nodes`, `exit_nodes`, `pattern_altitude` und `pattern_side`.
- Die Abstellplätze liegen bei x = −52 und z = 290…430, Abstand 28 m, Nase nach Süden. Rollweg x = −27, Haltepunkt (−27, 455), Einroll-Halbkreis südlich der Schwelle. Grafik/Integration: Bodenmarken an `parking_transform(i)`.

## 6. Bekannte Grenzen
- Die Landung nach Rückflug, Platzrunde und Einrollen dauert 4–8 min (lange Platzrunde, Rollen mit 20 km/h bis zur Ausfahrt).
- Am Boden weichen sich Flugzeuge nur aus, indem sie anhalten. Bei gegenseitiger Blockade fährt die kleinere `entity_id`. Begegnen sich zwei Maschinen auf demselben Rollwegstück frontal, gibt es keine Ausweichlogik.
- Nach der Landung steht die Maschine mit der Nase nach SSW (etwa 30° gegen die Spawnrichtung). Für den nächsten Start ist das kein Problem.
- `test_duels_flat` (slow) war schon auf der Basis 3bd2292 rot (6 Abschüsse, 1 Zusammenstoß). Mit Strang C sind die Werte identisch.
