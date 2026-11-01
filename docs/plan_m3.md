# Plan Meilenstein 3 „Bodenbetrieb“

Stand: 01.11.2026 · Basis: GDD v3 (§5, Slice-Punkte 25–28), v1 §4, Code M2.2 (main 28d406f) · Godot 4.7.2, Jolt, 60 Hz

## 1. Ziel und Abnahmekriterien

**Ziel:** Nach dem Flug rollt der Tester zum Abstellplatz und steigt aus. Zu Fuß oder mit dem Tankwagen betankt er die Maschine aus dem Tanklager, holt Munition aus dem Bunker, flickt leichten Schaden und startet neu. Die KI-Bodenmannschaft hilft dabei. Rote KI-Jäger rollen, starten, landen und werden von ihrer eigenen KI-Mannschaft versorgt.

**Abnahme (messbar):**
1. Der ganze Ablauf funktioniert ohne Menü: Landung → Abstellplatz → Aussteigen → Tanken, Munition, Reparatur → Einsteigen → Start. In Stufe Standard dauert die Abfertigung allein ≤ 3:30 min, mit 2 KI-Helfern ≤ 1:45 min (Anzeige „Abfertigung“).
2. Nach einem Abschuss steht eine neue Maschine am Abstellplatz, in Standard mit 15 % Treibstoff und 0 Munition. Ohne Treibstoff springt der Motor nicht an. Nach einer Landung bleibt der Restzustand erhalten.
3. Mengen bleiben erhalten: Jeder Liter und jeder Schuss im Flugzeug kommt aus einem Lager (Test, Summe ±0,1 %). Bei leerem Lager ist der Job mit Hinweis blockiert. Ersatzbenzin senkt die Leistung um 12 % je Anteil Ersatz im Tank (Test über `engine_power_mul`).
4. Drei Realismus-Stufen über `[m3] bodenbetrieb=` bzw. `--boden=`, Standard voreingestellt. Die Zeiten aus §2 stimmen auf ±10 % (Headless-Test je Stufe).
5. Befehlsrad mit ≥ 6 Befehlen. Die Automatik versorgt gelandete Maschinen auch ohne Befehl.
6. KI-Flugbetrieb, 10 Seeds: ≥ 9/10 Starts ohne Schaden, ≤ 90 s von „Rollen“ bis 300 m über Grund. ≥ 8/10 Landungen ohne Schaden bis zum Abstellplatz. Kein Flugzeug erscheint mehr in der Luft (Test).
7. 3 KI-Maschinen gleichzeitig verursachen keine Kollision. Die Piste wird exklusiv vergeben (Test).
8. Modelle in Stil B: Hangar, Tankwagen, Munitionswagen, Kiste, Fass, Tanklager, Bunker und eine Figur mit ≥ 6 Animationen. Jede Lizenz steht in `art/licenses/`.
9. Leistung: 6 Figuren, 3 Fahrzeuge und 8 Flugzeuge ≤ 5 ms je Physik-Tick headless, ≥ 60 FPS beim Tester.
10. Jede Zustandsänderung läuft über `JobBoard` oder `SeatService` mit Prüfung über `Authority`. Ein simulierter Client wird abgelehnt (Test).
11. Selbsttest mit der **exportierten .pck** um die Boden-Phasen C–E erweitert und grün. Alle Tests aus M1 und M2 bleiben grün.

## 2. Spielablauf (Minute für Minute, Standard)

| Zeit | Spieler | KI-Bodenpersonal |
|---|---|---|
| 0:00 | Landung, Ausrollen. Gelbe Bodenmarke „Abstellplatz 1“ und HUD-Pfeil | Automatik meldet „Blau 1 gelandet“ und reserviert Tankwagen und Munitionswagen |
| 0:40 | Auf dem Abstellplatz: Gas weg, Parkbremse. XP-Gutschrift wie in M2 | Tankwagen rollt vom Tanklager los (~150 m) |
| 0:50 | **J bzw. Steuerkreuz ← 1 s halten = Aussteigen**. In der Luft bleibt dieselbe Taste der Notausstieg, es kommt keine neue Belegung dazu. Wechsel in Third-Person | – |
| 1:00 | Statuspanel: Tank 22 %, MG 0/1.000, Leitwerk 70 %. Entscheidung: selbst tanken oder Munition holen | Mechaniker A koppelt den Schlauch an (oder der Spieler tut es) |
| 1:00–2:00 | Kiste vom Munitionswagen nehmen (langsamer laufen), MG-Klappe links öffnen, Gurt einlegen (halten), Klappe schließen. Danach rechts dasselbe | Tanken mit 6 l/s, ~50 s für 300 l |
| 2:00–2:30 | Reparatur light am Leitwerk (halten) | Mechaniker koppelt ab, Wagen fährt zurück |
| 2:30 | Am Cockpit „F Einsteigen“ (das ist ein Sitzwechsel), Gas geben, rollen | Personal geht aus der Propellerzone (Pflicht) |
| 3:00 | Start | – |

**Alarmstart:** Der Beobachtungsposten meldet „Roter Verband, 3:00 min“. Ein Countdown erscheint, die KI arbeitet um 25 % schneller und priorisiert erst Munition für ein Minimum und dann Treibstoff (Befehl „Schnellabfertigung“: 50 % Tank, volle Munition). Am Ende stehen eine Zeitwertung und eine Bestzeit (`user://`).

**Zeiten je Stufe** (solo / mit 2 KI-Helfern):

| Schritt | Vereinfacht | Standard | Authentisch |
|---|---|---|---|
| Tankwagen | steht schon am Abstellplatz | vom Lager holen oder rufen | muss vorher am Lager selbst befüllt werden (20 l/s) |
| Erden | – | – | 3 s. Vergessen = 5 % Funkenbrand, mit dem Löscher löschbar |
| Schlauch | 1 s Taste | Ende tragen (12 m Schlauch), 2 s ankoppeln | dazu Tankdeckel öffnen, Ventil auf. Überlaufen kostet Treibstoff und erhöht die Brandgefahr |
| Pumpen | 30 l/s | 6 l/s | 4 l/s, den Füllstand selbst beobachten |
| Munition je MG | 3 s am Wagen | Kiste tragen, Klappe 1,5 s, Gurt 5 s, Klappe 1,5 s | dazu Durchladen im Cockpit, Kiste 25 kg (Gehtempo −35 %) |
| Reparatur light | 25 HP/s | 6 HP/s | 3 HP/s, nur mit Werkzeugkiste |
| **Gesamt** | ~0:50 / ~0:30 | ~3:15 / ~1:40 | ~5:30 / ~2:45 |

KI-Grundpersonal arbeitet mit Faktor 0,8 im Vergleich zum Spieler, Experten (später) mit 1,25.

## 3. Systeme

**3.1 Sitze und Steuerung (Paket 0).** Die Figur ist ein Fahrzeug mit einem Sitz `Seat.Role.CREW`. Neu sind außerdem `DRIVER` und `PASSENGER`. `Controller.compute_crew_intent(dt) -> CrewIntent` liefert: Bewegung (Vector2), Blick (Gieren/Nicken), Sprint, interact (gehalten), drop, enter, wheel_open, wheel_choice, view_toggle und `to_array()` wie bei `PilotIntent`. Fahrzeuge nutzen den `PilotIntent` weiter (throttle, yaw = Lenkung, brakes). Ein- und Aussteigen läuft als Sitzwechsel über den neuen `SeatService` (Server): `request_enter(peer, character, seat)` und `request_exit(peer, seat)`. Er prüft Abstand ≤ 3 m zum `entry_point`, Fahrt < 1 m/s, Bodenkontakt und ob der Sitz frei oder mit KI besetzt ist (die KI macht Platz). `PlayerSession` (control/) besitzt einen Flug- und einen Crew-Controller und schaltet Kamera und HUD je nach besetztem Sitz um. `InputBindings` bekommt Kontexte (FLIGHT, CREW, DRIVE). Der Konflikttest prüft dann pro Kontext.

**3.2 Figur** (`characters/crew/`): `CrewCharacter` (CharacterBody3D, Layer `CHARACTER`) läuft mit 1,6 m/s, sprintet mit 4,5 m/s und folgt `height_at`. Er hat einen Trageplatz für Kiste, Schlauchende, Kanister oder Werkzeug. `CrewCamera` bietet Third-Person über die Schulter und Ego auf Taste C. `InteractionQuery` wählt den nächsten Interaktionspunkt im Blickkegel von 2,5 m.

**3.3 Interaktion und Jobs** (`ground_ops/`): `Interactable` ist ein Punkt mit Aktionen `{id, label, hold_s, needs_item}` und kommt aus Markern: am Flugzeug `svc_fuel_cap`, `svc_gun_hatch_L/R`, `svc_entry`, `svc_engine`, am Fahrzeug `hose_reel`, `crate_slot_*`, `seat_driver`. Fehlt ein Marker, gelten Ersatzpositionen aus AircraftData. Der `JobBoard` (Node unter Game, nur Server) erzeugt Jobs, vergibt sie, schreibt den Fortschritt fort und meldet über den neuen Bus `GroundEvents`: job_added, job_progress, job_done, job_blocked(reason), depot_changed, turnaround. Spieler und KI rufen dieselbe Funktion `request_step(peer, job_id, step, dt)` auf. Offline ist das ein direkter Aufruf, später ein RPC wie beim HitValidator.
- `RefuelJob`: Schritte bringen, erden, ankoppeln, pumpen, abkoppeln. Er nimmt aus `FuelSource.draw(grade, l)` (Tankwagen oder Lager) und gibt an `FuelSystem.add(l, grade)`.
- `RearmJob` pro Waffe: Kiste, Klappe, Gurt, Klappe. Schnittstelle `WeaponSystem.load_gun(i, store, n)` mit `AmmoBunker`/Wagen als `AmmoStore`.
- `RepairJob` light: `DamageModel.repair(zone, hp)` nur für Zonen > 0 HP. Flügelbruch und Brand sind ausgeschlossen, Strukturbruch-Schaden wird anteilig abgebaut.
- Die Zeiten liegen in `ground_ops/data/ground_rules_{einfach,standard,authentisch}.tres` (kein Code).

**3.4 Lager:** `FuelDepot` führt Liter je Sorte (`aviation` 8.000 l, `ersatz` 3.000 l) und hat `draw()`/`deposit()`. `AmmoBunker extends AmmoStore` hat einen endlichen Bestand (`7.92` 20.000 Schuss) und `available(type)`. Beide haben HP und das Signal `destroyed` als Haken für spätere Angriffe (M4), in M3 ohne Wirkung. Der Lagerzustand ist ein kompaktes Array (Netz). `FuelSystem` merkt sich den Anteil `grade_mix`. `DamageModel` multipliziert `engine_power_mul` mit `fuel.power_mul()`.

**3.5 Fahrzeuge** (`vehicles/ground/`): `GroundVehicle` als kinematisches Fahrmodell (Einspurmodell auf `height_at`, ≤ 35 km/h, Kollisionskapsel), deterministisch und netzfreundlich, ohne VehicleBody3D. `FuelTruck` hat 2.000 l, einen Schlauch von 12 m (Kurve aus Segmenten) und die Sitze Fahrer und Beifahrer. `AmmoCart` (Lkw) trägt 6 Kisten. Der Bombenwagen kommt später (Frage 5).

**3.6 KI-Bodenpersonal** (`ai/ground/`): `GroundCrewBrain extends Controller` liefert einen `CrewIntent` und läuft auf dem Rollweg-Graph des Platzes. Er nimmt Jobs nach Priorität: Alarm > Spieler-Maschine > KI-Maschine > Wagen nachfüllen. Er hält Abstand zur Propellerzone (5 m bei laufendem Motor). Befehlsrad: „Voll abfertigen“, „Nur tanken“, „Nur Munition“, „Schnellabfertigung“, „Tankwagen zu mir“, „Folgen“, „Reparieren“, „Zurück/Pause“. **Sim-LOD:** Ist kein Spieler im Umkreis von 2 km (z. B. auf Platz Rot), läuft die Mannschaft abstrakt mit getakteten Wegezeiten über dieselben Job-Schritte. Das spart Physik und bleibt deterministisch.

**3.7 KI-Flugbetrieb** (`ai/brain/airfield_phases.gd`, aufgerufen von `AIPilotBrain`): Phasen PARKED (wartet auf Versorgung, Mindestmenge 60 % Treibstoff und 80 % Munition, sonst „Notstart“ nach Timeout), TAXI_OUT (Graph, 20 km/h, `hold_heading`), HOLD (wartet auf die Pistenfreigabe von `RunwayControl`), TAKEOFF (Klappen 50 %, Gas voll, Heck heben, Abheben bei 135 km/h, Fahrwerk ein), danach Kampf wie in M2. RTB ersetzt RETREAT bei Munition < 10 %, Treibstoff < 25 % oder Schaden. Platzrunde: Gegenanflug, Queranflug, Endanflug mit 160 km/h und Klappen 100 %, Abfangen über `hold_pitch_attitude`, Bremsen, TAXI_IN, PARKED. Durchstarten bei belegter Piste oder Sinkrate > 4 m/s. Ist die Landung unmöglich (Motor aus, schwerer Schaden), gibt es eine Notlandung wie bisher.

**3.8 Spawn am Boden:** Der `SpawnManager`-Callback setzt die Maschine auf einen freien Abstellplatz (`place(..., refill=false)` mit `ServiceState` je nach Stufe). Das gilt für Spieler und KI. Die Abstellplätze, der Rollweg-Graph, Pistenanfang und -ende, Tanklager, Bunker, Hangar und Crew-Spawn liegen im `AirfieldLayout`, einer Ressource je Platz, die `TerrainWorld.airfield_layout(i)` liefert.

## 4. HUD und UI (`ui/ground/`)

- Interaktionshinweis am Punkt („[E] halten: Gurt einlegen“, Pad „[A]“), mit Hinweis bei fehlendem Gegenstand („Kiste fehlt“).
- Ringförmiger Fortschrittsbalken, beim Pumpen zusätzlich eine Literanzeige.
- Befehlsrad (Tab bzw. LB halten, Maus oder rechter Stick wählt): Zielmaschine plus Befehl.
- Statuspanel Flugzeug (am Boden und beim Annähern): Treibstoff in l und %, Sorte, MG-Munition links/rechts, Zonenskizze (Wiederverwendung aus `ui/combat`), laufende Jobs mit Bearbeiter.
- Lagerleiste oben: Benzin, Ersatz, Munition.
- Abfertigungszeit, Alarm-Countdown, Bodenmarken und Pfeil zum Abstellplatz.
- F1-Hilfe je Kontext.

## 5. Grafik und Assets (Grafik-Agent, Blender-Python, Stil B)

| Prio | Asset | Quelle | Marker |
|---|---|---|---|
| 1 | Figur „Mechaniker“ (low-poly, Overall, Mütze, Abnutzung) mit humanoidem Skelett nach Godot `SkeletonProfileHumanoid` | `art/scripts/build_crew.py` (eigen) | hand_R/L, carry |
| 1 | Animationen Idle, Gehen, Laufen, Tragen-Gehen | **Quaternius „Universal Animation Library“ (CC0)**, Retargeting in Godot über BoneMap. Ersatz: Kenney „Animated Characters“ (CC0) | – |
| 1 | Posen: Schlauch halten, Kiste anheben, Kurbeln/Arbeiten am Flugzeug, Einsteigen | im Blender-Skript als Keyframes (eigen). Hände in Godot per IK (SkeletonModifier3D/TwoBoneIK) | – |
| 1 | Tankwagen (Tier I, Lkw mit Tank, Schlauchtrommel) | `build_airfield_props.py` | hose_reel, seat_driver, ground_clip |
| 1 | Munitionswagen, Munitionskiste, Fass | dito | crate_slot_1..6 |
| 2 | Hangar (Holz/Stahl), Tanklager (Fassstapel + Tank), Munitionsbunker (Erdwall) | dito | door, fuel_tap, ammo_door |
| 2 | Service-Marker im Jäger-GLB (`svc_*`) | `build_game_aircraft.py` erweitern | svc_fuel_cap, svc_gun_hatch_L/R, svc_entry |
| 3 | Feuerlöscher, Werkzeugkiste, Bremsklötze, Bodenmarken | dito | – |

**Lizenz:** Mixamo nicht verwenden. Die Adobe-Bedingungen verlangen ein Konto und verbieten das Weitergeben der Rohdateien, das passt nicht zum Repo. Jede fremde Datei kommt mit Quelle, Lizenztext und Datum nach `art/licenses/`. Die Lizenz wird beim Download erneut geprüft. Lässt sich nicht laden oder retargeten, gibt es einen vollständig prozeduralen Gehzyklus als Ersatz (Sinus-Keyframes im Blender-Skript). Das ist eigen und ohne Lizenzrisiko. Budget: Figur ≤ 6k Dreiecke, Fahrzeuge ≤ 15k, Texturen 1024 (S3TC).

## 6. Arbeitspakete

Höchstens 3 Agenten gleichzeitig. Jedes Paket ist nach ≤ 45 min committbar, große Pakete sind in a/b geteilt. Paket 0 schreibt `docs/m3_vertrag.md`.

| # | Paket | Dateien/Ordner (exklusiv) | Abh. | Tests | Umfang |
|---|---|---|---|---|---|
| 0a | Vertrag Steuerung: CrewIntent, Seat-Rollen, `compute_crew_intent`, SeatService, PlayerSession-Stub, Eingabe-Kontexte | control/*, core/input_bindings.gd, core/ground_events.gd, core/match_rules.gd (`ground_realism`, Startzustand) | M2.2 | Intent-Roundtrip, Konflikte je Kontext, Sitzwechsel-Rechte | M |
| 0b | Vertrag Spielsysteme: `place(refill)`, ServiceState, `FuelSystem.add/grade_mix/power_mul`, `DamageModel.repair`, `WeaponSystem.load_gun`, `AmmoStore.available`, Stubs aller neuen Klassen, `AirfieldLayout`-Klasse, `TerrainWorld.airfield_layout()`, Marker-Namen, `test_contract_m3.gd` | aircraft.gd, fuel_system.gd, damage_model.gd, weapon_system.gd, ammo_store.gd, terrain_world.gd, game.gd | 0a | M1/M2 grün, Mengen-Erhalt-Stub | M |
| **Strang G (Bodenlogik)** |||||
| 1 | Lager: FuelDepot, AmmoBunker, Sorten, Ersatzbenzin | ground_ops/supply/ | 0 | Erhalt ±0,1 %, leer blockiert, Leistung ×0,88 | S |
| 2 | JobBoard + RefuelJob + RearmJob, Regeln-.tres | ground_ops/jobs/, ground_ops/job_board.gd, ground_ops/data/ | 1 | Zeiten je Stufe ±10 %, Client abgelehnt | M |
| 3 | RepairJob light, Alarmstart-Logik, Abfertigungs-Wertung | ground_ops/jobs/, ground_ops/turnaround.gd | 2 | Reparaturgrenzen, Zeitwertung | S |
| 7a | KI-Personal Automatik (Prioritäten, Propellerzone, Sim-LOD) | ai/ground/ | 2, 4 | versorgt Maschine ohne Befehl, LOD gleiches Ergebnis | M |
| 7b | Befehle (Befehlsrad-API), KI fährt Tankwagen | ai/ground/ | 7a, 6 | jeder Befehl ein Test | M |
| **Strang H (Figur und Fahrzeuge)** |||||
| 4 | CrewCharacter, CrewPlayerController, CrewCamera (Ego/Third), InteractionQuery | characters/crew/, ground_ops/interaction/ | 0 | Laufen auf Gelände, Punktwahl | M |
| 5 | Tragen, Ein-/Aussteigen über SeatService, Schlauch | characters/crew/, ground_ops/interaction/ | 4 | Aussteigen nur im Stand, Schlauchlänge | S |
| 6 | GroundVehicle, FuelTruck, AmmoCart | vehicles/ground/ | 0, 1 | Fahrmodell, Befüllen am Lager | M |
| **Strang C (KI-Flug)** |||||
| 8 | AirfieldLayout-Daten, Rollweg-Graph, RunwayControl | ground_ops/airfield/ (inkl. .tres) | 0 | Graph verbunden, exklusive Piste | S |
| 9a | Rollen und Start | ai/brain/airfield_phases.gd | 8 | 10 Seeds Start ≥ 9/10 | M |
| 9b | RTB, Platzrunde, Landung, Abstellen, Durchstarten | ai/brain/ | 9a | 10 Seeds Landung ≥ 8/10 (slow) | L |
| 10 | Spawn am Boden für Spieler und KI, ServiceState | world/spawn_manager.gd, characters/pilot_record.gd | 8, 0b | kein Spawn in der Luft, 3 Maschinen ohne Kollision | S |
| **Phase 2** |||||
| 11 | Platz-Modelle | art/scripts/build_airfield_props.py, art/models/, game/assets/ground/ | 0 (Markernamen) | Import-Smoke, Screenshot | M |
| 12a/b | Figur + Rig / Animationen + AnimationTree | art/scripts/build_crew.py, art/licenses/, characters/crew/anim/ | 4 | Animationsanzahl ≥ 6, auch im Export | L |
| 13 | Boden-HUD, Befehlsrad, Statuspanel | ui/ground/ | 2, 4 | Smoke, Screenshot | M |
| 14 | Integration: Szenario, PlayerSession, Alarmstart, F1, cfg | game.gd, hud.gd, combat_scenario.gd, project.godot | alle | Hauptszenen-Test | M |
| 15 | Selbsttest Boden (Phasen C–E), Export, Doku, Build | world/selbsttest.gd, tests/suites/export/, docs/ | 14 | **mit exportierter .pck** | M |

**Reihenfolge:** 0a → 0b (ein Agent) → Phase 1 mit G (1→2→3→7a), H (4→5→6) und C (8→9a→9b→10) → Phase 2 mit Grafik (11→12), HUD (13) und G (7b), danach 14 → 15. Die Tests liegen jeweils unter `tests/suites/<ordner>/` des Strangs.

**Selbsttest neu:**
- **C:** Die KI-Mannschaft fertigt die leere Spieler-Maschine ab. Geprüft werden Lagerdifferenz = Tankdifferenz und die Zeitgrenze.
- **D:** Die Figur interagiert über die echten Aktionen `crew_interact`/`crew_enter` (Input.action_press wie in M2.2).
- **E:** Eine rote KI rollt und startet bis 300 m über Grund in ≤ 90 s.
- **Diagnose:** Modelle geladen (Mesh-Anzahl > 0), Animationen ≥ 6, Layout gefunden, Lagerbestände.

## 7. Risiken

1. **KI-Landung mit Spornrad:** Ausbrechen und Kopfstand sind möglich. Gegenmittel: konservativer Anflug, Seed-Regression, Durchstarten. Notfalls in M3 nur der Start, die Landung kommt als M3.1.
2. **Sitzwechsel bricht Annahmen:** HUD, Kamera und Szenario setzen `hud.aircraft` voraus. Darum PlayerSession schon in Paket 0 und ein Hauptszenen-Test für jeden Wechsel.
3. **Eingabe-Kontexte:** Doppelbelegungen kommen zurück. Der Konflikttest prüft je Kontext, und die Belegung wird in der F1-Hilfe dokumentiert.
4. **Export:** GLB-Animationen oder Ressourcen fehlen in der .pck (Lehre aus M2.2). Die Diagnosezeilen gehören zur Pflicht-Suite „export“.
5. **Animation:** Das Retargeting fremder Animationen auf das eigene Skelett schlägt fehl. Dann gilt der prozedurale Ersatz.
6. **Spielspaß:** Die Abfertigung kann zäh werden. Darum liegen alle Zeiten in .tres, die Vorgabe ist Vereinfacht ≤ 1 min, und ein Tester-Durchgang erfolgt vor dem Feinschliff.
7. **Leistung und Nutzungslimit:** Sim-LOD für fremde Plätze, höchstens 3 Agenten, Pakete ≤ 45 min.
8. **Umfang:** Bomben, Motorstart per Propeller und Feuerlöschen bleiben draußen, außer der Product Owner entscheidet anders.

## 8. Offene Fragen an den Product Owner

1. **Ansicht:** Third-Person, Ego oder beides? *Empfehlung:* Third-Person als Standard, Ego auf C umschaltbar. Third-Person ist beim Tragen und Ausrichten lesbarer.
2. **Tanken:** Schlauch selbst tragen und ankoppeln? *Empfehlung:* ja in Standard (tragen plus 2 s halten). Erden und Überlauf nur in Authentisch, in Vereinfacht ein Tastendruck.
3. **Reparatur in M3?** *Empfehlung:* ja, als „light“: Zonen-HP auffüllen, kein Teilewechsel, Flügelbruch bleibt Totalverlust.
4. **Fahrzeuge selbst fahren?** *Empfehlung:* ja, Tankwagen und Munitionswagen mit einfachem Fahrmodell. Die KI fährt sie auf Befehl ebenfalls.
5. **Bomben schon in M3?** *Empfehlung:* nein, erst mit Bomber oder Jagdbomber in M4. Die Schnittstelle `LoadOrdnanceJob` legt Paket 0 trotzdem an.
6. **Zeitdruck:** Alarmstart mit Countdown und Bestzeit in M3, und wie voll startet die erste Maschine einer Partie? *Empfehlung:* Alarmstart ja, alle 12–15 min oder auf Debugtaste. Erste Maschine in Standard mit 50 % Treibstoff und voller Munition, danach gelten die Regeln aus §1 Punkt 2.

### Critical Files for Implementation
- /home/claude/fliegi/game/control/seat.gd
- /home/claude/fliegi/game/vehicles/aircraft/aircraft.gd
- /home/claude/fliegi/game/world/spawn_manager.gd
- /home/claude/fliegi/game/ai/brain/ai_pilot_brain.gd
- /home/claude/fliegi/game/world/terrain/terrain_world.gd