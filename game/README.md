# Flugkern – Meilenstein 1.1 (+ M2 Paket 0 „Vertragsschnitt“)

Prototyp des Flugkerns für das Luftkampf-Spiel (Godot **4.7.2**, GDScript, Jolt-Physik, 60 Hz mit Physik-Interpolation).
Ein Tier-I-Jäger („Falke“, 2.500 kg, 700 kW) startet von einer Graspiste. Ein zweites, KI-gesteuertes Flugzeug kreist über dem Platz.

## Starten

**Windows (fertiger Build):** `builds/flugkern_m1_1_windows.zip` entpacken und `Flugkern.exe` starten. `Flugkern.pck` muss im selben Ordner liegen.
**Update von M1:** Es reicht, die neue `Flugkern.pck` über die alte zu kopieren. `Flugkern.exe` (Godot 4.7.2) ist unverändert. Der Fenstertitel zeigt danach „Flugkern M1.1“.
Der Build ist nicht signiert. Wenn Windows SmartScreen warnt: „Weitere Informationen“ → „Trotzdem ausführen“.

**Aus dem Editor:** Godot 4.7.x öffnen → `game/project.godot` importieren → F5.

**Kommandozeile:** `godot --path game`

**Tests (headless):** `game/tests/run_tests.sh` (Exit-Code 0 = alles grün, Suite „fast“). Optionen: `--suite=slow|all` (Duelle), `--only=landing` (Testname), `--file=weapons` (Dateipfad), `--list`; Verlauf mit `TRACE=1`. Testdateien liegen in `tests/suites/` (auch Unterordner), erben von `TestSuite` und werden automatisch gefunden – `test_runner.gd` muss dafür nicht geändert werden. Ohne `.godot`-Cache vorher einmal `godot --headless --path game --import`.

## Steuerung

Im Spiel blendet **F1** (Xbox: View-Taste) die Hilfe ein und aus. Beim Start ist sie eingeblendet.

### Tastatur
| Taste | Funktion |
|---|---|
| W / S (oder ↑ / ↓) | Nase runter / hoch |
| A / D (oder ← / →) | Rollen links / rechts |
| Q / E | Seitenruder links / rechts (am Boden: Heckradlenkung) |
| Shift / Strg | Gas mehr / weniger (halten) |
| Leertaste | Feuer (Primärwaffen) |
| V | Sekundärwaffe |
| J (1 s halten) | Notausstieg (nur bei schwerem Schaden, sonst „gesperrt“) |
| F | Klappen 0 → 50 → 100 % |
| B | Bremsen (halten); löst auch die Parkbremse |
| G | Fahrwerk ein-/ausfahren (ca. 6,5 s) |
| C | Kamera: Verfolger → Cockpit → Orbit |
| X | Modus Arcade ↔ Realistisch |
| M | Maus-Zielsteuerung an/aus |
| R / T | Neustart auf der Piste / in 500 m Höhe |
| F3 | Debug-Overlay (Kräfte als Text + 3D-Pfeile) |
| Esc | Maus freigeben |

### Maus
- **Linksklick** fängt die Maus. Der erste Klick fängt nur; ist die Maus gefangen, feuert die linke Maustaste. **Mittlere Taste:** Sekundärwaffe. Esc gibt die Maus frei.
- **Arcade-Modus mit Maus-Ziel (Standard):** Die Maus bewegt einen Zielkreis, das Flugzeug fliegt dorthin (wie bei War Thunder oder Nuclear Option). Das grüne Kreuz zeigt die Flugzeugnase. Tastatur- und Stickeingaben übersteuern die Maus sofort; nach dem Loslassen übernimmt die Maus wieder.
- Am Boden lenkt die Maus über das Heckrad. Zum Starten: Gas geben (Shift halten) und die Maus leicht über den Horizont halten.
- **Rechte Maustaste halten:** umsehen. **Mausrad:** Zoom der Orbit-Kamera.
- Im Realistisch-Modus (oder mit M aus) dient die Maus nur zum Umsehen.

### Xbox-Controller (XInput)
| Eingabe | Funktion |
|---|---|
| Linker Stick | Nicken / Rollen |
| RT / LT | Feuer / Sekundärwaffe |
| LB / RB | Seitenruder links / rechts (digital mit Rampe) |
| Steuerkreuz ↑ / ↓ | Gas mehr / weniger (halten) |
| Steuerkreuz → | Fahrwerk ein-/ausfahren |
| Steuerkreuz ← (1 s halten) | Notausstieg |
| A | Klappen |
| B | Bremsen |
| Y | Kamera wechseln |
| X | Arcade / Realistisch |
| Rechter Stick | Umsehen (Stick-Klick: zurück) |
| Start | Neustart auf der Piste |
| View | Hilfe |

Die Sticks haben eine Deadzone von 0,15 und eine weiche Expo-Kurve. Die Werte stehen in `core/input_bindings.gd`.
**Geändert in M2 (Entscheidung 1):** Die Trigger sind jetzt Abzüge. Das Seitenruder liegt auf LB/RB, das Gas nur noch auf dem Steuerkreuz ↑/↓. Das Fahrwerk wandert von Steuerkreuz ↓ nach →. So liegt jede Funktion auf einem eigenen Knopf, ohne Doppelbelegung und ohne Kurz/Lang-Unterscheidung. Der Test `test_binding_conflicts` prüft das. Bis Paket 2 fertig ist, feuern die Waffen noch nicht (Stub).

### Flugmodi
- **Arcade:** Der Knüppel gibt eine Drehrate vor statt eines Ruderausschlags. Die Hilfe dämpft automatisch, koordiniert Kurven über das Seitenruder und verhindert einen Strömungsabriss: Sie begrenzt den Anstellwinkel stetig auf ca. 1,25° unter dem Abriss (beim Hochziehen ca. 11–11,5° statt früher 7,5°). Unter ca. 190 km/h begrenzt sie zusätzlich die Nicklage, damit das Flugzeug nicht über das Heck abkippt. Beim Bremsen schützt sie vor einem Überschlag.
- **Realistisch:** Der Knüppel wirkt direkt aufs Ruder, nur mit leichter Gierdämpfung. Oberhalb von ca. 240 km/h wird das Höhenruder schwächer (wie steigende Knüppelkraft), die Nickrate liegt bei max. ca. 48°/s. Ein Strömungsabriss ist möglich.
- **Vorwarnung (beide Modi):** Ca. 3° vor dem Abriss beginnt die Kamera zu rütteln (stärker, je näher am Abriss). Gleichzeitig erscheint „STALL-WARNUNG“ mit Warnton und Rumpeln. Der Abriss selbst ist weich: Der Auftrieb sinkt auf etwa 75 %, vor allem steigt der Widerstand.

### Fahrwerk
- **G** bzw. **Steuerkreuz →** fährt das Fahrwerk ein oder aus (ca. 6,5 s, mit Animation). Das HUD zeigt den Zustand.
- Am Boden (Gewicht auf den Rädern) lässt es sich nicht einfahren.
- Ausgefahren kostet es Fahrt (ca. 30 km/h Höchstgeschwindigkeit). Über 300 km/h warnt das HUD „FAHRWERK: ZU SCHNELL“. Schaden gibt es noch nicht.
- Landung mit eingefahrenem Fahrwerk: **Bauchlandung**. Der Rumpf rutscht mit starker Reibung, das HUD zeigt „BAUCHLANDUNG“. Ein Schadensmodell folgt später. Danach R für den Neustart.
- Beim Start auf der Piste ist die **Parkbremse** gesetzt. Sie löst sich bei Gas über 10 % oder mit B.

## Erstflug-Tipp
1. Shift halten, bis das Gas auf 100 % steht (die Parkbremse löst sich dabei automatisch). Optional F für 50 % Klappen.
2. Ab ca. 100 km/h leicht ziehen (S), mit Maus-Ziel einfach etwas über den Horizont zielen. Das Flugzeug hebt bei ca. 130–140 km/h ab.
3. Nach dem Abheben G drücken: Das Fahrwerk fährt ein, das Flugzeug wird schneller.
4. Landen: G (Fahrwerk aus, unter 300 km/h!), Gas auf ca. 30 %, Klappen 100 %, mit etwa 160–180 km/h flach anfliegen und kurz vor dem Boden abfangen. Nach dem Aufsetzen Gas auf 0 und B halten.

## Architektur in Kürze
```
Controller (control/controller.gd)
 ├─ PlayerController   Tastatur/Gamepad/Maus  ─┐
 ├─ AIController       ai/ai_controller.gd    ─┼─► PilotIntent ─► Seat ─► Aircraft
 └─ ScriptedController tests/                 ─┘                          │
                                     FlightAssist (Arcade/Realistisch) ◄──┘
                                                 │ ControlCommands (Ruder)
                                     FlightModel (AeroSurface × 9, PropEngine, LandingGear)
```
- `core/`: `Authority` („bin ich Server?“, offline Peer 1), `InputBindings` (gesamte Eingabebelegung). Neu in M2: `Nations`, `CombatEvents`, `Layers`, `Spotting`, `RadarStation`, `MatchRules`, `WorldGround`, `WorldOrigin`. Die Schnittstellen und welche Dateien welchem Arbeitspaket gehören, stehen in `docs/m2_vertrag.md`.
- `control/`: Intent, Controller, Seat, Autopilot-Helfer (Mouse-Aim und KI nutzen dieselbe Lenklogik).
- `vehicles/aircraft/`: `Aircraft` (RigidBody3D, komplett im Code aufgebaut), `AircraftVisual`, `physics/` (Flugmodell hinter der Schnittstelle `FlightModel.integrate(state, commands)`), `data/` (`AircraftData`, `AeroSurfaceDef`, `WheelDef` und `fighter_t1.tres`).
- `world/`: Testwelt, Kamera-Rig, Hauptszene (`main.tscn` enthält nur einen Knoten mit `game.gd`).
- `ui/`: HUD. `tests/`: Headless-Tests. `tools/`: Datengenerator, Screenshot-Skript, Modell-Sync.
- M2-Stubs (Paket 0): `weapons/` (WeaponSystem, ProjectileSystem, `fx/`), `vehicles/aircraft/damage/` (DamageModel, HitboxSet), `physics/flight_modifiers.gd`, `ui/combat/`, `ai/brain/`, `world/terrain/`, `world/spawn_manager.gd`, `characters/`. Leer: `ground_ops/`, `vehicles/ground/`.

### Flugzeugwerte ändern
`vehicles/aircraft/data/fighter_t1.tres` lässt sich im Inspector bearbeiten. Alternativ die Werte in `tools/build_fighter_t1.gd` ändern und die Datei neu erzeugen:
`godot --headless --path game --script res://tools/build_fighter_t1.gd`. Danach `tests/run_tests.sh` laufen lassen.

### 3D-Modell
`AircraftData.model_path` zeigt auf `res://vehicles/aircraft/models/fighter_t1.glb`. `tools/sync_art.sh` kopiert neue Modelle aus `art/models/`. Fehlt die Datei, baut `AircraftVisual` automatisch einen Platzhalter aus den Aero-Flächen. Ausrichtung, Versatz und Maßstab werden über `model_rotation_deg`, `model_offset` und `model_scale`/`model_fit_span` eingestellt. Ein Knoten mit „prop“ im Namen dreht sich als Propeller.

## Messwerte (Headless-Tests, Stand M1.1)
| Größe | Wert |
|---|---|
| Abhebegeschwindigkeit (50 % Klappen) | ca. 132 km/h nach ca. 200 m Rollstrecke |
| Höchstgeschwindigkeit 500 m, Fahrwerk ein / aus | ca. 487 / 456 km/h |
| Höchstgeschwindigkeit 4.000 m (Volldruckhöhe) | ca. 547 km/h |
| Steigrate (Vollgas, 270 km/h, Fahrwerk ein) | ca. 14,2 m/s, in 3.000 m ca. 14,8 m/s, in 6.000 m ca. 10,4 m/s |
| Abrissgeschwindigkeit (ohne Klappen, 1 g) | ca. 152 km/h |
| Arcade, Maus 60° hoch bei 360 km/h | AoA ca. 11,4°, ca. 3,9 g, kein Abriss, kein Flattern |
| Realistisch, voll gezogen bei 360 km/h | Nickrate max. ca. 48°/s |
| Kurve 60° Querlage (Arcade) | ca. 239° in 12 s |
| Bremsweg aus 80 km/h | ca. 62 m |

Änderungen je Version: `docs/changelog.md`. Diagnose-Skripte: `tests/diag/` (`stall_diag.gd`, `perf_diag.gd`, `spawn_diag.gd`, Auswertung `summarize.py`).

## Bekannte Grenzen
- Kein Drehmoment- oder Propellerdrall-Effekt, kein Trudeln als eigenes Modell (der Abriss ist asymmetrisch möglich, aber nicht gezielt modelliert). Kein Schadensmodell: Ein Crash wird nur gemeldet, dann R drücken.
- Ruder- und Klappenanimation gibt es nur am Platzhalter. Beim GLB dreht sich der Propeller, und das Hauptfahrwerk klappt als Ganzes nach innen (die Beine, Räder und Klappen sind getrennte Meshes; keine echte Kinematik, die Fahrwerksklappen bewegen sich mit). Das Spornrad ist fest.
- Kein Schadensmodell: Fahrwerk über 300 km/h und Bauchlandung erzeugen nur HUD-Meldungen.
- Gelände flach mit einfachen Kegel-Hügeln. Bäume haben keine Kollision. Der Boden endet bei ±12 km.
- Rendering wurde nur per Software-OpenGL (Linux, xvfb) geprüft, nicht auf echter Windows-GPU. Performance und Schatten bitte auf dem Zielrechner prüfen.
- Gamepad-Belegung ist für das Xbox-Layout gedacht. Andere Pads funktionieren über SDL-Mapping, sind aber ungetestet. Eine Tastenbelegung im Spiel ist noch nicht änderbar.
- Kein Netzwerk (kommt in M3). `Authority` und `Seat.possess()` sind aber schon serverseitig abgesichert.
- Die Steuerhilfen-Parameter sind nur grob abgestimmt. Feintuning nach Spieltest-Feedback.

## Drittquellen
Kein fremder Code kopiert. Rechenweg der Flächen-Aerodynamik angelehnt an *gasgiant/Aircraft-Physics* (MIT). Idee der Maus-Zielsteuerung angelehnt an *MouseFlight* von Brian Hernandez (MIT). Beides eigene Implementierungen.
