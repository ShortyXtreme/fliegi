# Flugkern – M2.1 „Luftkampf 1 gegen 3“ mit Treffer-Debug

Prototyp des Luftkampf-Spiels (Godot **4.7.2**, GDScript, Jolt-Physik, 60 Hz mit Physik-Interpolation).
Ein Tier-I-Jäger („Falke“, 2.500 kg, 700 kW) startet vom **Platz Blau** im neuen 40-km-Gelände. Drei rote KI-Jäger (Stufe „Erfahren“) patrouillieren 6–10 km entfernt Richtung Platz Rot und greifen an. Bewaffnung: 2 × MG 7,92 mm, zusammen 1.000 Schuss, Leuchtspur jeder 5. Schuss.

## Szenario M2
- **Ziel:** rote Jäger abschießen. Ist der Spieler in der Luft und mehr als 2,5 km vom eigenen Platz entfernt, leitet die „Bodenleitung“ freie Gegner zu ihm.
- **Abgeschossene Gegner** starten nach 30–60 s über dem Platz Rot (ca. 25 km entfernt) neu – der Kampf geht weiter.
- **Eigener Verlust:** Neustart auf Platz Blau nach 15 s (Parkbremse gesetzt). Notausstieg nur bei schwerem Schaden (J bzw. Steuerkreuz ← 1 s halten).
- **Erfahrung (XP):** Abschuss +100, Mithilfe +40. Gutgeschrieben wird erst nach der Landung und dem Stillstand auf Platz Blau (Meldung im Kill-Feed).
- **Kill-Feed** oben rechts mit Namen („Rot 1“, „Rot 2“ … neu gestartete Gegner zählen weiter).
- **Treffer-Debug (M2.1):** F3 (Xbox: L3 oder Share-Taste) zeigt, was wen wo getroffen hat. Details unten unter „Treffer-Debug und Treffer-Log“.
- **Einstellungen:** Datei `%APPDATA%/Godot/app_userdata/Flugkern M2/flugkern.cfg` anlegen:
  ```
  [m2]
  ki_stufe="erfahren"   ; "rekrut" | "erfahren" | "veteran"
  gegner=3              ; 1..6
  zoom_realistisch="flugzeug" ; Zoom im Realistisch-Modus: "flugzeug" (nur mit Visier-Upgrade) | "immer" | "nie"
  ```
  oder Startoption `Flugkern.exe -- --ki=veteran --gegner=2`. Die alte Testwelt aus M1: `-- --testwelt`.

## Starten

**Windows:** Die neue `Flugkern.pck` (aus `builds/m2_1/`) über die alte kopieren. `Flugkern.exe` (Godot 4.7.2) bleibt unverändert. Der Fenstertitel zeigt danach „Flugkern M2.1“.
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
| Leertaste oder linke Maustaste | Feuer (Primärwaffen; Maus nur, wenn gefangen) |
| Z oder rechte Maustaste (halten) | Ziel-Zoom (M2.1) |
| Alt (halten) oder Maustaste 4 | Umsehen mit der Maus (M2.1, vorher rechte Maustaste) |
| V | Sekundärwaffe |
| J (1 s halten) | Notausstieg (nur bei schwerem Schaden, sonst „gesperrt“) |
| F | Klappen 0 → 50 → 100 % |
| B | Bremsen (halten); löst auch die Parkbremse |
| G | Fahrwerk ein-/ausfahren (ca. 6,5 s) |
| C | Kamera: Verfolger → Cockpit → Orbit |
| X | Modus Arcade ↔ Realistisch |
| M | Maus-Zielsteuerung an/aus |
| R / T | Neustart auf der Piste / in 500 m Höhe |
| F3 | Treffer-Debug an/aus (darin F4 Hitboxen, F5 Geschossbahnen, F6 Treffer anderer) |
| Shift+F3 | Kräfte-Debug (Text + 3D-Pfeile, M1) |
| Esc | Maus freigeben |

### Maus
- **Linksklick** fängt die Maus. Der erste Klick fängt nur; ist die Maus gefangen, feuert die linke Maustaste. **Mittlere Taste:** Sekundärwaffe. Esc gibt die Maus frei.
- **Arcade-Modus mit Maus-Ziel (Standard):** Die Maus bewegt einen Zielkreis, das Flugzeug fliegt dorthin (wie bei War Thunder oder Nuclear Option). Das grüne Kreuz zeigt die Flugzeugnase. Tastatur- und Stickeingaben übersteuern die Maus sofort; nach dem Loslassen übernimmt die Maus wieder.
- Am Boden lenkt die Maus über das Heckrad. Zum Starten: Gas geben (Shift halten) und die Maus leicht über den Horizont halten.
- **Rechte Maustaste halten:** Ziel-Zoom (M2.1). **Alt oder Maustaste 4 halten:** umsehen. **Mausrad:** Abstand der Orbit-Kamera.
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
| Rechter Stick | Umsehen (kehrt beim Loslassen zurück) |
| R3 (rechten Stick drücken, halten) | Ziel-Zoom (M2.1, vorher „Blick zurück“) |
| L3 (linken Stick drücken) oder Share | Treffer-Debug an/aus (M2.1) |
| Start | Neustart auf der Piste |
| View | Hilfe |

Die Sticks haben eine Deadzone von 0,15 und eine weiche Expo-Kurve. Die Werte stehen in `core/input_bindings.gd`.
**Geändert in M2 (Entscheidung 1):** Die Trigger sind jetzt Abzüge. Das Seitenruder liegt auf LB/RB, das Gas nur noch auf dem Steuerkreuz ↑/↓. Das Fahrwerk wandert von Steuerkreuz ↓ nach →. So liegt jede Funktion auf einem eigenen Knopf, ohne Doppelbelegung und ohne Kurz/Lang-Unterscheidung. Der Test `test_binding_conflicts` prüft das. 

### Ziel-Zoom (M2.1)
Zoom-Taste halten: Das Sichtfeld wird in ca. 0,1 s von ca. 70° auf 30° enger (Faktor 2,33). Maus-Ziel, Umsehen und Kamerafolge werden im selben Verhältnis langsamer, so lässt sich ruhiger zielen. In der Verfolgerkamera hebt sich die Kamera dabei, damit das eigene Flugzeug nicht die Sicht verdeckt.
- **Arcade:** immer verfügbar.
- **Realistisch:** nur mit Visier-Upgrade (`AircraftData.has_zoom_sight`, Vergrößerung `sight_zoom_factor`). Tier I hat es nicht; später über Forschung. Lobby-Option `zoom_realistisch` (siehe Einstellungen) kann den Zoom auch immer erlauben oder ganz verbieten.
- **Vorhaltepunkt (Arcade):** Kreis mit Entfernung; „Konv.“ heißt: Das Ziel liegt im Konvergenzbereich der Flügel-MGs (±30 % um 250 m). Grün mit „TREFFER WAHRSCHEINLICH“: Die Nase zeigt so genau, dass die vorhergesagte Ablage unter 4 m liegt. Kein Auto-Aim.

### Treffer-Debug und Treffer-Log (M2.1)
**F3** (Xbox: L3 oder Share-Taste) schaltet den Treffer-Debug-Modus ein:
- **Eigene Treffer:** Markierung an der Trefferstelle mit Zone und Schaden (z. B. „Motor −10“). Die Liste „Meine Treffer“ rechts zeigt Ziel, Zone, Schaden, Entfernung und Alter.
- **Erhaltene Treffer:** Die Liste „Getroffen von“ links zeigt Schütze, Zone und Schaden. Rote Pfeile zeigen, aus welcher Richtung geschossen wurde („hinten“, wenn hinter der Kamera). Die getroffene Zone blinkt in der Schadensskizze auf.
- **Zonen-HP als Zahlen** für das eigene Flugzeug (links) und das anvisierte Ziel (rechts).
- **F4** Hitboxen als Drahtgitter (eingefärbt nach Zustand), **F5** Geschossbahnen aller Schüsse, **F6** Treffer zwischen anderen (KI gegen KI) in der Liste. Vom HitValidator abgelehnte Treffer erscheinen rot mit Grund.
- **Shift+F3:** das alte Kräfte-Overlay.

**Treffer-Log:** Jeder Treffer (auch abgelehnte) wird als CSV gespeichert, unabhängig vom Debug-Modus:
`%APPDATA%\Godot\app_userdata\Flugkern M2\logs\kampf_JJJJMMTT_HHMMSS.csv` (eine Datei je Spielstart; Spalten: Zeit, Schütze, Ziel, Zone, Schaden, Nennschaden, Entfernung, Ergebnis, eigen = aus/ein/-, Position). Bei Problemen bitte diese Datei mitschicken. Der Ordnername bleibt „Flugkern M2“ (Projektname), damit die Einstellungen aus M2 weiter gelten.

### Flugmodi
- **Arcade:** Der Knüppel gibt eine Drehrate vor statt eines Ruderausschlags. Die Hilfe dämpft automatisch, koordiniert Kurven über das Seitenruder und verhindert einen Strömungsabriss: Sie begrenzt den Anstellwinkel stetig auf ca. 1,25° unter dem Abriss (beim Hochziehen ca. 11–11,5° statt früher 7,5°). Unter ca. 190 km/h begrenzt sie zusätzlich die Nicklage, damit das Flugzeug nicht über das Heck abkippt. Beim Bremsen schützt sie vor einem Überschlag.
- **Realistisch:** Der Knüppel wirkt direkt aufs Ruder, nur mit leichter Gierdämpfung. Oberhalb von ca. 240 km/h wird das Höhenruder schwächer (wie steigende Knüppelkraft), die Nickrate liegt bei max. ca. 48°/s. Ein Strömungsabriss ist möglich.
- **Vorwarnung (beide Modi):** Ca. 1,5° vor dem Abriss (M2, vorher 3°) beginnt die Kamera leicht zu rütteln und wird bis zum Abriss deutlich stärker. Gleichzeitig erscheint „STALL-WARNUNG“ mit Warnton (lauter werdend) und Rumpeln. Der Abriss selbst ist weich: Der Auftrieb sinkt auf etwa 75 %, vor allem steigt der Widerstand.

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
- M2: `weapons/` (Waffen, Geschosse, Trefferprüfung, `fx/`), `vehicles/aircraft/damage/` (Schadenszonen, Hitboxen, Wrack), `ui/combat/` (Kampf-HUD), `ai/` (AIPilotBrain, Wahrnehmung, Stufen), `world/terrain/` (Gelände), `world/combat_scenario.gd` (Szenario 1 gegen 3), `world/spawn_manager.gd`, `characters/`. Leer: `ground_ops/`, `vehicles/ground/`.

### Flugzeugwerte ändern
`vehicles/aircraft/data/fighter_t1.tres` lässt sich im Inspector bearbeiten. Alternativ die Werte in `tools/build_fighter_t1.gd` ändern und die Datei neu erzeugen:
`godot --headless --path game --script res://tools/build_fighter_t1.gd`. Danach `tests/run_tests.sh` laufen lassen.

### 3D-Modell
`AircraftData.model_path` zeigt auf `res://vehicles/aircraft/models/fighter_t1.glb`. `tools/sync_art.sh` kopiert neue Modelle aus `art/models/`. Fehlt die Datei, baut `AircraftVisual` automatisch einen Platzhalter aus den Aero-Flächen. Ausrichtung, Versatz und Maßstab werden über `model_rotation_deg`, `model_offset` und `model_scale`/`model_fit_span` eingestellt. Ein Knoten mit „prop“ im Namen dreht sich als Propeller.

## Messwerte M2 (Duell-Suite slow, KI gegen KI, echter Schaden, 180 s)
| Serie | Abschüsse | Treffer/Schuss | Ablage beim Feuern | Bodenkollisionen |
|---|---|---|---|---|
| Flach, Erfahren gegen Erfahren | 6/10 (Ziel 8/10) | 19,8 % | 4,0 m | 0 % |
| Hügel, Erfahren gegen Erfahren | 8/10 | 25,2 % | 3,7 m | 0 % |
| Veteran gegen Rekrut | 8 : 0 | – | – | 0 % |

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
- Abgeschossene KI-Gegner starten in der Luft über Platz Rot neu, nicht vom Boden. Die KI kann noch nicht selbst starten; das ist für M3 vorgemerkt.
- Kein Drehmoment- oder Propellerdrall-Effekt, kein Trudeln als eigenes Modell (der Abriss ist asymmetrisch möglich, aber nicht gezielt modelliert). Kein Schadensmodell: Ein Crash wird nur gemeldet, dann R drücken.
- Ruder- und Klappenanimation gibt es nur am Platzhalter. Beim GLB dreht sich der Propeller, und das Hauptfahrwerk klappt als Ganzes nach innen (die Beine, Räder und Klappen sind getrennte Meshes; keine echte Kinematik, die Fahrwerksklappen bewegen sich mit). Das Spornrad ist fest.
- Kein Schadensmodell: Fahrwerk über 300 km/h und Bauchlandung erzeugen nur HUD-Meldungen.
- Abgeschossene KI-Gegner starten in der Luft über Platz Rot neu, nicht vom Boden (die KI kann noch nicht starten; vorgemerkt für M3).
- Gelände flach mit einfachen Kegel-Hügeln. Bäume haben keine Kollision. Der Boden endet bei ±12 km.
- Rendering wurde nur per Software-OpenGL (Linux, xvfb) geprüft, nicht auf echter Windows-GPU. Performance und Schatten bitte auf dem Zielrechner prüfen.
- Gamepad-Belegung ist für das Xbox-Layout gedacht. Andere Pads funktionieren über SDL-Mapping, sind aber ungetestet. Eine Tastenbelegung im Spiel ist noch nicht änderbar.
- Kein Netzwerk (kommt in M3). `Authority` und `Seat.possess()` sind aber schon serverseitig abgesichert.
- Die Steuerhilfen-Parameter sind nur grob abgestimmt. Feintuning nach Spieltest-Feedback.

## Drittquellen
Kein fremder Code kopiert. Rechenweg der Flächen-Aerodynamik angelehnt an *gasgiant/Aircraft-Physics* (MIT). Idee der Maus-Zielsteuerung angelehnt an *MouseFlight* von Brian Hernandez (MIT). Beides eigene Implementierungen.
