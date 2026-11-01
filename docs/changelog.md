# Änderungsprotokoll Flugkern

## M2.2 „Trefferfix“ (01.11.2026)

### Behoben
- **Keine Treffer im exportierten Spiel (M2.1, Tester: 11 min, Treffer-Log leer).** Der Export wandelt Text-Ressourcen (.tres) in Binär-Ressourcen um. Dabei verlor `fighter_t1_markers.tres` in Godot 4.7.2 alle Packed-Arrays (Zonen, Waffen- und Außenlastpunkte; nur `points`/`source` blieben). Folge: 0 Hitbox-Zonen je Flugzeug, kein Segmenttest traf, kein Trefferbericht. Aus dem Projektordner (alle Tests) war die Datei intakt.
  - Fix: `editor/export/convert_text_resources_to_binary=false` (project.godot); .tres gehen unverändert in die .pck. Geprüft: alle anderen exportierten Ressourcen waren nicht betroffen.
  - Absicherung: `AircraftMarkers.load_for` nimmt leere Marker nicht mehr an (Fehlermeldung, Ersatz-Marker aus den Flugzeugdaten).

### Neu
- **Selbsttest im Spiel:** `Flugkern.exe --selbsttest` (auch `-- --selbsttest`). Gegner 250 m vor dem Spieler, Spieler feuert 3 s über die echte Aktion `fire_primary`; danach feuert ein Gegner 3 s von hinten. Zählt Geschosse, Segmenttests, Trefferberichte (akzeptiert/abgelehnt) und Schaden, schreibt ins Godot-Log und nach `user://logs/selbsttest_*.txt`, Exit-Code 0 = Treffer in beide Richtungen (`world/selbsttest.gd`).
- **Diagnosezeilen beim Start** im Godot-Log je Flugzeug: Hitbox-Zonen, Radius, Waffen, Marker-Quelle, Ziel angemeldet.
- `ProjectileSystem.segment_tests` (Zähler der genauen Hitbox-Prüfungen).
- **Test-Suite „export“** (`tests/suites/export/`): exportiert die .pck und startet sie im Selbsttest-Modus (xvfb/OpenGL, sonst headless). Pflicht im Build-Skript `game/tools/build_windows.sh <ziel>`.

## M2.1 „Treffer-Debug“ (01.11.2026)

Reaktion auf das Tester-Feedback zu M2.

### Behoben
- **„Kein Schaden erhalten“:** Die Treffer kamen technisch beim Spieler an (Zielregistrierung, Hitboxen, HitValidator, DamageModel geprüft, auch nach Neustart). Es gab aber zwei echte Ursachen:
  1. **Die KI schoss in der Heckverfolgung nie.** Gegen einen gleich schnellen Spieler blieb sie ca. 560 m dahinter „kleben“, weil ihre Feuerdistanz nur 400 m beträgt. Bei kaum Annäherung (< 25 m/s, Ziel fliegt weg, Winkel < 30°) feuert sie jetzt bis zum 1,6-Fachen der Feuerdistanz (`AIPilotBrain.fire_range_now`).
  2. **Die Schadensskizze zeigte einzelne Treffer nicht.** Sie färbte erst unter 66 % HP der Zone um (ein Treffer = 10 von 120–200 HP). Jetzt ist der Verlauf stufenlos (grün → gelb → rot, schon kleiner Schaden sichtbar), das Aufblitzen dauert 0,9 s, und neben „SCHADEN“ steht der Gesamtschaden in %.
- **„PARKBREMSE“ in der Luft:** Der Hinweis erscheint nur noch am Boden im Stand (Radkontakt, < 5 km/h). In der Luft löst sich die Parkbremse selbst.

### Neu
- **Treffer-Debug-Modus (F3, Xbox: L3 oder Share-Taste):** Am getroffenen Flugzeug erscheint kurz eine Markierung mit Zone und Schaden (z. B. „Leitwerk −10“). Dazu kommen die Listen „Meine Treffer“ (Ziel, Zone, Schaden, Entfernung, Zeit) und „Getroffen von“, Pfeile aus der Richtung erhaltener Treffer sowie die Zonen-HP als Zahlen für das eigene Flugzeug und das anvisierte Ziel. Im Modus: **F4** Hitboxen als Drahtgitter, **F5** Geschossbahnen aller Schüsse, **F6** Treffer zwischen anderen. Vom HitValidator abgelehnte Treffer werden rot mit Grund markiert. Das Kräfte-Overlay aus M1 liegt jetzt auf **Shift+F3**.
- **Treffer-Log:** Jeder Treffer wird als CSV-Zeile gespeichert, unter Windows in `%APPDATA%\Godot\app_userdata\Flugkern M2\logs\kampf_JJJJMMTT_HHMMSS.csv`.
- **Treffer-Ton:** ein helles „Tick“ beim eigenen Treffer, ein dumpfer Schlag beim Getroffenwerden (prozedural).
- **Ziel-Zoom (Tester: „Visieren ist sehr schwer“):** Rechte Maustaste, Z oder Xbox R3 halten. Das Sichtfeld wird weich enger (ca. 70° → 30°). Maus-Ziel, Umsehen und Kamerafolge werden dabei proportional ruhiger. Funktioniert in der Verfolger- und der Cockpitkamera.
  - Arcade: immer verfügbar. Realistisch: nur mit Visier-Upgrade (`AircraftData.has_zoom_sight`, `sight_zoom_factor`; bei Tier I aus, später über Forschung). Lobby-Option `MatchRules.realistic_zoom` bzw. `[m2] zoom_realistisch = "flugzeug" | "immer" | "nie"`.
  - **Belegung geändert:** Umsehen mit der Maus liegt jetzt auf **Alt** oder **Maustaste 4** (vorher rechte Maustaste). R3 ist nicht mehr „Blick zurück“ (der rechte Stick kehrt beim Loslassen ohnehin zurück, und der Zoom setzt den Blick nach vorn).
- **Vorhaltepunkt (Arcade):** größer, mit Entfernungsangabe und „Konv.“, wenn das Ziel im Konvergenzbereich liegt (±30 %). Er wird grün und zeigt „TREFFER WAHRSCHEINLICH“, wenn die vorhergesagte Ablage unter 4 m liegt. Kein Auto-Aim.
- Version „M2.1“ in Fenstertitel, HUD und F1-Hilfe. Der Projektname bleibt „Flugkern M2“, damit Einstellungen und Logs im selben Ordner liegen.

### Technik
- `ProjectileSystem.hit_resolved(shooter, target, zone, damage, world_point, local_point, result)` meldet jeden Zieltreffer, auch abgelehnte. `HitDebug` (`ui/debug/hit_debug.gd`) sammelt die Daten ohne Rendering, `HitDebugOverlay` zeichnet sie.
- Neue Tests: Hauptszene (passiver Spieler wird getroffen und die Skizze zeigt es, auch nach Neustart; Spieler-Treffer schaden der KI), Debug-Daten, CSV, Zoom-Regeln, Sichtfeld und Empfindlichkeit, Vorhalt-Qualität, Parkbremsen-Hinweis. Diagnose: `tests/diag/damage_diag.gd`.
- Nicht umgesetzt: Die KI startet nach einem Abschuss weiter in der Luft über Platz Rot. `AIPilotBrain` hat noch keinen Startlauf; ein Bodenstart braucht eine eigene Start-Logik (Rollen, Abheben, Fahrwerk). Vorgemerkt für M3.

## M2 „Luftkampf 1 gegen 3“ – Paket 14 Integration (01.11.2026)

Spielbare Testversion M2. Enthält die Pakete 1–13 und 15 (Waffen, Schaden, KI, Kampf-HUD, Effekte, Gelände, Floating Origin, Überhitzung) und deren Integration.

### Spiel
- **Hauptszene:** Gelände (40 × 40 km) statt Testwelt. Der Spieler startet auf Platz Blau mit Parkbremse. 3 rote KI-Jäger (Stufe „Erfahren“) patrouillieren 6–10 km entfernt und greifen an. Ist der Spieler in der Luft und mehr als 2,5 km vom eigenen Platz weg, lenkt die Bodenleitung die Gegner zu ihm. Abgeschossene Gegner starten nach 30–60 s über Platz Rot neu. Der Spieler startet 15 s nach einem Verlust neu.
- **Einstellbar:** KI-Stufe und Anzahl der Gegner über `user://flugkern.cfg` (`[m2] ki_stufe`, `gegner`) oder die Startoptionen `--ki=`/`--gegner=`. `--testwelt` lädt die alte Welt.
- **Kill-Feed mit Namen** („Rot 1“ …, neu gestartete Gegner zählen weiter). **XP:** Abschuss +100, Mithilfe +40. Gutgeschrieben wird bei Stillstand auf Platz Blau.
- **Steuerung:** Feuer mit Linksklick oder Leertaste, am Pad mit RT. Notausstieg: J bzw. Steuerkreuz ← 1 s halten (nur bei schwerem Schaden). Der Hinweis erscheint nur kurz beim Halten.
- **Abriss-Warnung (Tester-Feedback):** beginnt jetzt 1,5° statt 3° vor dem Abriss und wird progressiv stärker (Rütteln 0,1 → 0,75, Warnton lauter werdend, HUD).
- **HUD:** Das alte Text-HUD ist aus, das neue Flug-Panel unten links zeigt alles. Fenstertitel und Hilfe zeigen „M2“.

### Technik
- Das Spielmodell `fighter_t1_game.glb` liegt jetzt in `res://` (importiert). Den Gegner unterscheiden nur getauschte Albedo-Texturen, das spart ca. 10 MB. Normal- und ORM-Texturen sind auf 1024/512 px begrenzt und VRAM-komprimiert (S3TC). Die Kollisions-Hilfsnetze `col_*` des Modells werden nicht mehr als Körper importiert; vorher stürzten KI-Flugzeuge dadurch sofort ab. Das alte `fighter_t1.glb` ist entfernt.
- `ProjectileSystem`: Die Ziel-ID wird jeden Tick aus `entity_id` neu gelesen. Neu ist `shift_origin()` (ebenso in `TransformHistory` und `WeaponFx`). Der `OriginShifter` hängt in der Hauptszene, ist aber standardmäßig aus.
- `SpawnManager.register(…, delay)` erlaubt eine eigene Ausfallzeit je Flugzeug.
- **Flugzeug:** Die Treibstoffmasse ist gekoppelt (0,72 kg/l). `telemetry.fuel_fraction` und `DamageModel.health_fraction()/is_critical()` sind für die KI da (Rückzug bei Schaden, Brand, Motorausfall oder unter 12 % Treibstoff). Wracks frieren nach einem Absturz ein. Kontakte in den ersten 3 Ticks nach `place()` werden ignoriert.
- **Schaden:** Ein zerschossenes Leitwerk (0 HP) zählt als Abschuss. Neu ist der Strukturbruch ab 320 HP Gesamtschaden (`DamageProfile.structure_hp`), damit auch verteilte Treffer in 15–40 Treffern zum Abschuss führen. Streift die Nase beim Bremsen mit Rädern am Boden unter 20 m/s, ist das kein Absturz mehr.
- **KI (BFM):** Das Zielen nutzt eine eigene, kürzere Nachführ-Verzögerung (`tracking_delay` 0,3/0,18/0,12 s), Entscheidungen weiter die Reaktionszeit. Gefeuert wird nur bei vorhergesagter Ablage ≤ 6/4/3 m, frontal ≤ 3,5/2,5/2 m; ein Feuerstoß bricht ab, wenn die Ablage zu groß wird. Lag-, Pure- und Lead-Verfolgung wechseln mit Hysterese. Vor frontalen Begegnungen baut die KI 450 m seitlichen Versatz auf. Je nach Energie fliegt sie High- oder Low-Yo-Yo. Ein Patt-Brecher greift nach 8 s Kreiskampf (vertikal, Umkehrkurve oder Extend). Am Heck des Gegners bleibt sie trotz geringer Fahrt dran, und sie sinkt nicht mehr in einer Spirale ab. Der Arcade-Abriss-Schutz (1,25° Abstand) wurde geprüft und ist nicht der Engpass.

### Messwerte (Duell-Suite slow, echte Hitboxen und echter Schaden)
| | vorher | nachher |
|---|---|---|
| Abschüsse flach (10 Seeds, 180 s) | 0/10 | 6/10 (je nach Stand 5–7) |
| Abschüsse Hügel | – | 8/10 |
| Veteran gegen Rekrut | – | 8 : 0 |
| Treffer/Schuss | 5,8 % | 19,8 % (Hügel 25 %) |
| Ablage beim Feuern | 10,7 m | 4,0 m |
| Anteil frontaler Schüsse | 28 % | 0 % |
| Bodenkollisionen | 0 % | 0 % |

Die Abnahme 6 ist im flachen Gelände noch nicht erreicht (6 statt 8 von 10). Der Rest-Engpass ist der symmetrische Kurvenkampf zweier gleich starker KIs.

### Tests
- fast 100/100; slow 4/5 (`test_duels_flat` rot, siehe oben). Neu ist `test_tracking_turning_target`. Die KI-Tests nutzen echte Hitboxen, die Ersatz-Hitboxen sind entfernt.

## M2 Paket 0 „Vertragsschnitt“ (31.10.2026)

Grundlage: `docs/plan_m2.md` §7. Die Schnittstellen und die Dateien je Agent stehen in `docs/m2_vertrag.md`. Die Flugphysik ist unverändert, alle M1.1-Messwerte sind identisch.

### Neu
- **Kern:** `Nations` (Blau/Rot, Diplomatie-Matrix, `is_hostile`), `CombatEvents` (Bus mit 6 Signalen, Ereignis-Log und Log-Hash), `Layers` (Physik-Layer und Masken, Namen in `project.godot`), `Spotting` (Erkennungsweite nach Entscheidung 2) mit `RadarStation`-Stub, `MatchRules` (Lobby-Werte), `WorldGround.height_at`, `WorldOrigin` (Stub).
- **PilotIntent:** `fire_primary`, `fire_secondary`, `eject`, als Bits in `to_array()[8]` (alte Arrays bleiben lesbar).
- **Flugzeug:** `nation_id`, `entity_id`, `crew_level`, `pilot`, `weapons` (WeaponSystem), `damage` (DamageModel), Signal `eject_requested(aircraft, allowed)`. Kollisions-Layer `AIRCRAFT`. Die Raycasts für Fahrwerk und Höhe über Grund ignorieren andere Flugzeuge.
- **Schadens-Hooks:** `FlightModifiers` mit Auftriebs-, Widerstands- und Ruderfaktor je Fläche, klemmendem Ruder, Motorleistung, Motorausfall und Zusatzwiderstand. Angebunden in `FlightModel`, `AeroSurface.compute` und `PropEngine.update`.
- **Stubs:** `WeaponSystem`, `ProjectileSystem`, `WeaponFx`, `DamageModel`, `HitboxSet`, `CombatHud` (in `hud.gd` registriert), `AIPilotBrain`, `TerrainWorld`, `SpawnManager`, `PilotRecord`. Die Hauptszene legt ProjectileSystem, WeaponFx und SpawnManager an. Spieler = Blau, KI = Rot.
- **Tests:** Der Läufer findet Testdateien in `tests/suites/` automatisch (Basisklasse `TestSuite`) und unterstützt die Suiten `fast` (Standard), `slow` und `all` sowie `--file=` und `--list`. Die 19 M1-Tests liegen jetzt in `tests/suites/test_flight_m1.gd`. Neu sind 8 Vertragstests in `test_contract_m2.gd`: Nationen, Bus, Spotting, Modifier-Hooks, Kampf-Hooks, Belegungskonflikte, Feuer/Notausstieg-Halten, Hauptszene. Der Intent-Roundtrip prüft jetzt auch die Tasten-Bits.

### Eingabe (Entscheidung 1)
- **Xbox:** RT = Feuer, LT = Sekundär, LB/RB = Seitenruder (digital mit Rampe), Steuerkreuz ↑/↓ = Gas, **Steuerkreuz → = Fahrwerk** (vorher ↓), Steuerkreuz ← 1 s halten = Notausstieg. So gibt es keine Doppelbelegung und keine Unterscheidung zwischen kurzem und langem Drücken.
- **Tastatur/Maus:** Leertaste oder LMT = Feuer (LMT nur bei gefangener Maus, der erste Klick fängt nur), V oder mittlere Maustaste = Sekundär, J 1 s halten = Notausstieg.
- F1-Hilfe und README sind aktualisiert. Die Waffen feuern erst ab Paket 2. Der Notausstieg meldet bis Paket 4/6 immer „gesperrt“.

## M1.1 (31.10.2026)

Anlass: Tester-Feedback „Strömungsabriss beim Hochziehen kommt zu früh“ (Maus+Tastatur, Arcade, Mouse-Aim) und „Flugzeug rollt beim Start rückwärts“. Grundlage: `docs/diagnose_stall.md`, `docs/recherche_flugphysik_spielgefuehl.md`.

### Flugphysik
- **Arcade-Stall-Schutz** (`flight_assist.gd`): Die Schaltschwelle ist weg. Neu ist eine stetige Begrenzung relativ zur Trimmung: `max_elev = trim(α_lim) + K·(α_lim − α) − D·q − D_α·α̇`. Dazu kommt der neue Parameter `AircraftData.elevator_per_aoa` (0,038/°). `STALL_MARGIN` sinkt von 2,5° auf 1,25°. Bei geringer Fahrt greift der Begrenzer stärker vor.
- **Nicklage-Begrenzung in Arcade** unter ca. 190 km/h (Grenze 80° → 10° bei Fahrt 0). Sie verhindert das Abkippen über das Heck.
- **Auftriebskurve weich** (`aero_surface.gd`): ab 4° vor dem Abriss eine tanh-Abrundung, danach über 7° ein Abfall auf ein Plateau von 75 % CL_max. Ab 30° geht die Kurve in die ebene Platte über. Im Abriss steigt vor allem der Widerstand (+0,2·t). Der Flügel reißt jetzt bei 16° Profil-AoA ab (CL_max ≈ 1,37), Klappen verschieben den Abrisswinkel realistischer.
- **Abwind am Höhenleitwerk** (dε/dα = 0,4, mit Laufzeitverzögerung als α̇-Effekt) und **Nickdämpfung** (Cmq = −6).
- **Realistisch:** Höhenleitwerk mit 24° Ausschlag statt 30°, Rudertiefe 38 % statt 45 %. Oberhalb von 240 km/h nimmt die Wirkung mit (240/v)^1,5 ab, wie eine steigende Knüppelkraft.
- **Energie:** Rumpf-Widerstandsfläche 0,10 → 0,17 m². Der Motor hat einen Lader mit voller Leistung bis 4.000 m (Volldruckhöhe), darüber ∝ Luftdichte. Der Übergang zwischen Propellerschub und Standschub ist weicher (Exponent 4 → 2,5). Leerlauf: 4 % Gas, leichter Vorwärtsschub.

### Neu
- **Einziehfahrwerk:** Taste G bzw. Xbox Steuerkreuz ↓ (vorher Gas weniger, dafür LB). Ein- und Ausfahren dauert 6,5 s, die Animation klappt die GLB-Fahrwerksteile nach innen. Ausgefahren kommen 0,08 m² Widerstandsfläche dazu. Am Boden ist Einfahren gesperrt (Gewicht auf den Rädern). Über 300 km/h mit ausgefahrenem Fahrwerk erscheint eine HUD-Warnung. Das HUD zeigt den Fahrwerkszustand. Die KI fährt das Fahrwerk nach dem Start ein.
- **Bauchlandung:** Kufenpunkte unter dem Rumpf, der Rumpf rutscht mit starker Reibung, HUD-Meldung „BAUCHLANDUNG“. Kein Schaden.
- **Vorwarnung vor dem Abriss:** Das Kamera-Rütteln (Buffet, 9–17 Hz) beginnt 3° vor dem Abriss und wird proportional stärker. Die HUD-Warnung kommt zur gleichen Zeit, also früher. Dazu kommen ein prozeduraler Warnton (pulsierend) und Rumpeln (AudioStreamGenerator, keine Audiodateien).
- **Parkbremse** beim Start, löst sich bei Gas über 10 % oder mit B.
- HUD und Fenstertitel zeigen „M1.1“. Das Debug-Overlay (F3) zeigt zusätzlich Buffet, Abwind und den Begrenzer-Eingriff.

### Fehlerbehebungen
- **Flugzeug rollte beim Start rückwärts** (bis 14 m/s nach 8 s). Ursache: Die Radfederkraft wirkte entlang der Rumpf-Hochachse. In der 12°-Dreipunktlage zeigt diese Achse schräg nach hinten, so entstand ein Rückwärtsschub von ≈ 0,2·Gewicht. Die Rollreibung (0,035) war zu klein, um ihn aufzuhalten. Jetzt wirkt die Radlast entlang der Bodennormalen. Dazu kommen Parkbremse, Leerlaufschub und eine Spawn-Höhe in der Ruhelage (1,655 m, 12,4°), sodass nichts mehr nachfedert. Gemessen: 0,015 m Bewegung in 5 s, minimal −0,012 m/s.
- Bremse mit eigener Haftreibungskennlinie: Der Bremsweg aus 80 km/h sinkt von 122 m auf 62 m.

### Vorher/Nachher (Diagnose `tests/diag/`)
| Wert | M1 | M1.1 |
|---|---|---|
| Arcade Mouse-Aim 60° bei 360 km/h: AoA max / Mittel | 9,1° / 7,7° | 11,4° / 11,0° |
| … G-Last Mittel / Std.-Abw. (0,5–3 s) | 2,97 / 0,50 | 3,68 / 0,43¹ |
| … Ruder-Sprünge (> 0,15 pro Tick) | 24 (4,8 Hz) | 0 |
| Realistisch, volle Taste 360 km/h: Nickrate / AoA max | 87°/s / 24,6° | 49°/s / 14,4° |
| … Abriss | 1,00 | 0,01 |
| Realistisch, halber Stick: AoA max | 13,9° | 7,5° |
| Arcade langsames Ziehen: min. Fahrt / Abriss | 93 km/h / 0 | 108 km/h / 0,02 |
| 1-g-Abriss (Leerlauf, ohne Klappen) | 154 km/h | 152 km/h |
| Steigrate 270 km/h (Fahrwerk ein) | 15,6 m/s² | 14,2 m/s |
| Höchstgeschwindigkeit 500 m, Fahrwerk ein / aus | 483 km/h³ | 487 / 456 km/h |
| Abheben (50 % Klappen) | 151 km/h | 132 km/h |

¹ Die Standardabweichung enthält den gleichmäßigen Fahrtverlust während des Ziehens. Das Flattern (Abweichung vom gleitenden 0,5-s-Mittel) liegt bei 0,003 g. Der Regressionstest misst 0,24.
² M1 ohne Fahrwerkswiderstand.
³ M1 hatte kein Einziehfahrwerk und keinen Fahrwerkswiderstand.

### Tests
19 Headless-Tests (12 alte + 7 neue): `test_arcade_mouse_pull`, `test_realistic_pitch_rate`, `test_climb_rate`, `test_gear_top_speed`, `test_gear_ground_lock`, `test_belly_landing`, `test_spawn_at_rest`. Verschärft: Höchstgeschwindigkeit 470–530 km/h (Fahrwerk ein), 1-g-Abriss 140–162 km/h.

### Build
`builds/flugkern_m1_1_windows.zip` (Flugkern.exe + Flugkern.pck + README). Die einzelnen Dateien liegen zusätzlich in `builds/m1_1/` (Flugkern.pck, README.md). Godot 4.7.2 und Export-Templates sind unverändert, `Flugkern.exe` ist identisch mit M1. Keine GDExtensions, keine neuen DLLs.

## M1 (31.10.2026)
Erster Flugkern-Prototyp: Tier-I-Jäger, Arcade/Realistisch, Mouse-Aim, KI, Headless-Tests, Windows-Build.
