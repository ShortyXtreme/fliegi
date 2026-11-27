# Prüfung Boden, Fahrzeuge, Figuren, Welt, allgemeine Code-Gesundheit

Stand: main 7a170bc (M3.9), Branch `audit-boden`. Prüfer: Agent Boden/Allgemein.
Grundlage: der Code unter game/vehicles/ground, ai/ground, ground_ops, characters, world und core,
dazu headless Messungen (Tests, Messskripte, `tools/soak.gd`).

## Befunde

| Befund | Ist (vorher) | Soll (mit Quelle) | Schwere | Vorschlag / Umsetzung |
|---|---|---|---|---|
| Baumkollision nur bis 700 m um die Kamera | Zylinder nur in Zellen bis `COLLIDE_R` um die Kamera, nur mit Optik und nur bei Vegetation > „Aus“. KI weiter weg und der ganze headless-Server fliegen durch Wälder. Wer mit „Aus“ spielt, kollidiert auch selbst nicht. | Die Kollision soll von Kamera und Grafikstufe unabhängig sein, damit sie im Mehrspieler auf dem Server fair entschieden wird. | **Fehler** | **Umgesetzt:** `TreeObstacles` (world/vegetation/tree_obstacles.gd) arbeitet ohne Physikkörper. Die Zellen kommen im Hintergrund aus `VegetationGen.build_cell`, also mit denselben Bäumen wie in der Optik. Ein 16-m-Raster dient der Abfrage. Geprüft wird ein Wischtest: Rumpf- und Flügelbox gegen den Stammzylinder, in Schritten von 0,6 m. Ein Treffer läuft wie ein Kontakt über `body_entered`. Zellen mit echten Körpern an der Kamera überspringt der Test. Kosten: im Mittel etwa 26 µs je Tick und Flugzeug, höchstens 0,15 ms. Das erste Anlegen der Daten dauert 25 ms (mit Optik) bzw. 0,4 s (kalt, headless). |
| Leck: ein PlayerController je Partie | `PlayerSession._init` legt einen FlightController an. `adopt_flight` gibt ihn nur frei, wenn er schon im Baum hängt, was nie der Fall ist. Folge: 47 „ObjectDB instances leaked“ und „3 resources still in use“ am Testende. Alle 47 Lecks stammen von hier (21 Hauptszenen). | 0 Lecks | **Fehler** | **Umgesetzt:** Knoten außerhalb des Baums werden mit `free()` freigegeben (control/player_session.gd). |
| Leck: Lambda-Kreis in PlayerService | `act["can"] = func(ch): _can(it, act, ch)`: Das Lambda fängt das Dictionary ein, in dem es selbst liegt. Dieser Referenzkreis wird nie freigegeben („345 orphaned lambdas“). | – | **Fehler** | **Umgesetzt:** gebundene Methode (`_can.bind(it)`, `_on_holding.bind(it)`). |
| Fahrzeug: Querbeschleunigung ohne Grenze | Bei 35 km/h und vollem Einschlag gilt R = 13 m, also a_quer ≈ 7 m/s². Ein hoher Tankwagen kippt rechnerisch ab ≈ 5 m/s² (g·Spur/2h), auf Gras ist die Haftung μ ≈ 0,4–0,5. | ≤ 3,5 m/s² | **Fehler** | **Umgesetzt:** Der Lenkwinkel wird auf atan(a_max·L/v²) begrenzt; `HIGH_SPEED_STEER` dient nur noch als Untergrenze. Bei 35 km/h ist jetzt R = 27 m. Die KI bremst vor Kurven auf √(a·R) (sonst würde sie um das Ziel kreisen). |
| Fahrzeug: kein Hangabtrieb | Gleiches Tempo bergauf und bergab, Steigfähigkeit unbegrenzt. | Hangabtrieb g·sin θ. Steigfähigkeit beladen auf Gras ≈ 20 % (Hinterachse ≈ 65 % der Last, μ 0,4) | **Fehler** | **Umgesetzt:** Vortrieb ist min(2,5 m/s², 9 W/kg / v), dazu −g·sin θ. Ergebnis: 10 % mit Vollgas 22 km/h, 30 % geht nicht, bergab rollt der Wagen. |
| Fahrzeug: Anfahren/Bremsen | 2,0 m/s² ohne Leistungsgrenze; Bremse 6,0 m/s² | Opel Blitz 3,6-36: 3,35 t leer, 68–75 PS, 80 km/h ([dday-overlord](https://www.dday-overlord.com/en/?p=134836)). Bremse heute StVZO ≥ 5,0 m/s² auf Asphalt ([§ 41 StVZO](https://www.gesetze-im-internet.de/stvzo_2012/__41.html)), mit Trommelbremsen beladen auf Gras eher weniger | Ungenau | **Umgesetzt:** Bremse 4,5 m/s². Bremsweg aus 35 km/h: vorher 7,4 m, jetzt 9,7 m. Die Anfahrt ist in etwa gleich (siehe Zeile davor). |
| Fahrzeug: Wasser | Fährt über den Grund eines 2,8 m tiefen Flusses. | Wattiefe Opel Blitz ≈ 0,5–0,6 m | Ungenau | **Umgesetzt:** Ab 0,3 m fährt der Wagen nur Schritttempo (1,5 m/s), ab 0,8 m säuft der Motor ab. |
| Fahrzeug: Masse, Stöße | Kinematisches Modell ohne Masse. Der Wagen schiebt Flugzeuge nicht und bleibt an ihnen stehen. Ein Flugzeug, das mit über 8 m/s auf einen Wagen rollt, löst die Bodenkontakt-Logik aus (Bauchlandung/Absturz). | – | Spielgefühl | Für Stil B in Ordnung. Wenn gewünscht, im Schadensbereich einen Stoß Flugzeug gegen Wagen mit eigener Schwelle prüfen. |
| Fallschirm ohne Physik | Feste 5,5 m/s ab dem Absprung, kein freier Fall, kein Öffnungsstoß. Die Absprungfahrt wird ×0,3 gerechnet und auf 8 m/s begrenzt. Landung auf dem Flussgrund. | Irvin 24 ft: 5,5–7,5 m/s, Öffnungsstoß ≈ 9 g ([RAF AP3456](https://scottbouch.com/rtfm/volume/ap/3456/e/ap3456e-p2-s3-c3.pdf)). Öffnung ≈ 2 s, höchstens 3 s ([FAA](https://www.faasafety.gov/files/events/WP/WP15/2016/WP1567978/Jun_2015_Bailout_Seminar_Handout_.pdf)). Freier Fall ≈ 54 m/s | **Fehler** | **Umgesetzt:** 90 kg, C_D·A 0,5 m² im freien Fall. Die Reißleine zieht nach 1 s, die Entfaltung dauert 2 s (Fläche ~t²), dann gilt C_D·A 40 m². Die Rechnung ist halbimplizit und damit stabil. Der Widerstand wirkt auf die Fahrt gegenüber der Luft (Drift wie der Wind). ρ kommt aus der Höhe. Ergebnisse: Sinkrate 5,97 m/s auf Meereshöhe und 7,04 m/s in 2900 m. Öffnungsstoß 1,8 / 4,4 / 7,1 / 9,7 g bei 0 / 60 / 100 / 140 m/s. Die Landung erfolgt auf dem Wasserspiegel. Aufprall über 10 m/s senkrecht ist tödlich. |
| Figuren: Wasser | Gehen auf dem Flussgrund (2,8 m unter Wasser) | Waten bremst; Schwimmen ≈ 0,7–1,0 m/s | Fehler | **Umgesetzt:** Ab 0,3 m Tiefe waten (bis ×0,35). Ab 1,35 m schwimmen: Kopf über Wasser, 0,9 m/s, kein Sprint. |
| Figuren: Gelände | Gleiches Tempo auf jeder Steigung, auch Wände hinauf | Tobler (1993): v ∝ exp(−3,5·\|s+0,05\|) | Ungenau | **Umgesetzt:** Tobler-Faktor (≥ 0,25), ab 45° ist Schluss. Der Test am Hang ergibt 34 m statt 45 m in 10 s Sprint bei 7,5 % Steigung. |
| Figuren: Tempo | Gehen 1,6 m/s, Sprint 4,5 m/s, ACCEL 12 m/s² | Bequemes Gehen 1,3–1,5 m/s, Laufen 3–5 m/s | OK/Spielgefühl | Bleibt so. |
| Figuren: Springen | Gibt es nicht | – | – | Offener Punkt; am Platz nicht nötig. |
| Figuren gegen Flugzeuge | Flugzeuge durchfahren Figuren (die Flugzeugmaske hat kein CHARACTER). Propeller tötet nicht, die KI meidet nur die Propellerzone. | – | Spielgefühl | Bleibt (Stil B). |
| Tankrate Tankwagen → Flugzeug | Einfach 30, Standard 6, Authentisch 4 l/s (240 l/min) | RAF-Tankwagen 1939: „20 gallons per minute“ = 91 l/min ([Commercial Motor 1939](https://archive.commercialmotor.com/article/21st-july-1939/52/mobile-refuelling-equipment-for-aircraft)); Messung 1945: 19 gal/min ([CM 1945](https://archive.commercialmotor.com/article/14th-september-1945/21/refuelling-vehicles-keep-pace-with-aircraft-develo)) | Ungenau | **Authentisch auf 2,5 l/s (150 l/min) gesetzt.** Standard bleibt bei 6 l/s, das ist bewusst etwa 4× schneller als die Wirklichkeit (Spielgefühl). |
| Handpumpe | Gibt es nicht (der Kanister als CarryItem hat keine Logik) | Fass-/Flügelpumpe 0,25–0,5 l je Hub, also ≈ 25–45 l/min ([Hallbauer](https://www.jh-profishop.de/marken/samoa-hallbauer/umwelt/gefahrstoffhandling/pumpen/fasspumpen/hand-fasspumpen)) | – | Für M4: Kanister/Handpumpe mit 0,5 l/s. |
| Tankwagen am Lager befüllen | 20 l/s (1200 l/min). Der Wert stand doppelt: `FuelTruck.FILL_RATE` und `GroundRules.truck_fill_lps`. | Gefälle oder Pumpe mit 3"-Leitung ≈ 300–600 l/min | Ungenau | Die doppelte Quelle ist behoben, maßgeblich ist jetzt `truck_fill_lps`. Für Authentisch werden 8–10 l/s vorgeschlagen (nicht umgesetzt). |
| Fassungsvermögen | Tankwagen 2000 l, Lager 8000 l Flugbenzin + 3000 l Ersatz, Bunker 20 000 Schuss, Wagen 6 × 500 | Thompson-Tankwagen 1939: 500 gal = 2273 l ([RAF Museum](https://collections.rafmuseum.org.uk/collection/object/object-65921)) | OK | Das Lager reicht für etwa 22 Füllungen à 360 l. Eine echte Staffel braucht über 10 000 l am Tag; das gehört zur Balance in M4. |
| Treibstoffdichte | `Aircraft.FUEL_DENSITY` = 0,72 kg/l (nur einmal definiert) | Flugbenzin 0,70–0,72 kg/l | OK | – |
| Munitionskiste | Standard 18 kg ×0,8, Authentisch 25 kg ×0,65. Die Werte standen doppelt im Code und in den Regeln; die Regeln hatten in Standard ×1,0, sodass die Sim-LOD-KI schneller trug als die Figur. | 500 Schuss 7,92×57 ≈ 13 kg, mit Gurt und Kasten ≈ 18–20 kg | Fehler (Widerspruch) | **Umgesetzt:** `CarryItem.apply_realism` liest die Regeln, Standard/Einfach haben jetzt ×0,8 und 18 kg. |
| Nachladen und Reparatur | Gurt 5 s je MG, Reparatur 3/6/25 HP/s. Abfertigung Standard 135 s, Authentisch 267 s. | Hurricane etwa 9 min, Spitfire etwa 26 min ([Forum mit Zitaten, sekundär](https://ww2aircraft.net/forum/threads/battle-of-britain-turn-around-time.19850/)); Malta 1942: Tanken 4–7 min | Spielgefühl | Bewusst gerafft (Faktor 4–10). Bleibt so; Stellschraube sind die .tres. |
| Doppelte Konstanten | Schlauch 12 m dreifach, Sprint 4,5 doppelt (KI/Figur), Gehen 1,6 (Figur/Regeln), Sim-LOD Wagen 7 m/s gegen KI-Fahrt bis 7,8 m/s. Vegetation 0,45 m und `Aircraft.inertia` haben im Code einen anderen Standardwert als in der .tres (8000/13000 gegen 7000/11000, Flugbereich). | – | Ungenau | Schlauch und Sprint sind auf eine Quelle gezogen. Rest siehe Korrekturliste. |
| `GroundEvents.depot_changed(depot: Node)` | Wird mit FuelSource/AmmoStore (RefCounted) gesendet | Signatur passt nicht | Ungenau | Typ auf `Object` ändern (Bus-Vertrag, Paket 14). |
| Physik in `_process` | Keine Spiel-Physik. Nur Optik/Kamera/Schlauch-Optik/Wind-Optik/UI | – | OK | – |
| Framerate | Physik mit festen 60 Hz. Zufall in der Spiellogik nur über Seeds; das globale `randf` dient nur Klang und Effekten. | – | OK | – |
| Determinismus (Mehrspieler) | Bodenfahrzeuge und Figuren sind kinematisch, in den Tests bitgleich. Jolt ist nicht plattformübergreifend deterministisch. Vegetations-Körper (Kamera, Threads) erscheinen zeitlich zufällig, `TreeObstacles` ebenfalls asynchron. Der Floating Origin verschiebt die Koordinaten je Client. | Server ist Autorität | Hinweis | Baumtreffer nur auf dem Server zählen (`TreeObstacles` prüft `Authority.is_server()`). |
| Warnung Jolt | „Jolt Physics job system exceeded the maximum number of jobs“ in test_crash_breakup | – | Hinweis (Schadensbereich) | An den Agenten Waffen/Schaden. |
| Speicher/Knoten in langen Partien | Siehe Messung unten | konstant | – | `tools/soak.gd` |
| Testabdeckung | Ungetestet waren: Fallschirm-Sinkrate/Öffnung, Querbeschleunigung, Hang beim Fahrzeug, Wasser für Figuren/Wagen, Baumkollision fern der Kamera. Weiterhin ungetestet: Stoß Wagen–Flugzeug, Funkenbrand-Wahrscheinlichkeit über viele Läufe, Massenkopplung des Treibstoffs im Flugmodell (Flugbereich), Sim-LOD gegen Echtlauf bei Fahrzeiten. | – | – | Neue Tests: test_tree_obstacles (3), test_parachute (4), test_lateral_limit, test_follows_slope (erweitert), test_cliff_and_swim. |

## Messung Langzeit (headless, `tools/soak.gd`)

Hauptszene 1 gegen 3. Alle 240 s steigt ein roter Pilot aus. Läuft etwa 2× schneller als Echtzeit.
Ergebnis 10 Spielminuten: siehe Abschnitt „Ergebnis Soak“ am Ende.

## Quellen

- Opel Blitz 36-6700A, Daten: https://www.dday-overlord.com/en/?p=134836
- Commercial Motor, 21.07.1939, Mobile Refuelling Equipment (20 gal/min): https://archive.commercialmotor.com/article/21st-july-1939/52/mobile-refuelling-equipment-for-aircraft
- Commercial Motor, 14.09.1945 (19 gal/min, Saughöhe): https://archive.commercialmotor.com/article/14th-september-1945/21/refuelling-vehicles-keep-pace-with-aircraft-develo
- RAF Museum, Thompson Refueller (500 gal): https://collections.rafmuseum.org.uk/collection/object/object-65921
- RAF AP3456 (Irvin 24 ft 5,5–7,5 m/s, Öffnungsstoß ≈ 9 g): https://scottbouch.com/rtfm/volume/ap/3456/e/ap3456e-p2-s3-c3.pdf
- FAA Bailout Seminar (Öffnung ≈ 2 s, ≤ 3 s): https://www.faasafety.gov/files/events/WP/WP15/2016/WP1567978/Jun_2015_Bailout_Seminar_Handout_.pdf
- § 41 StVZO (5,0 m/s²): https://www.gesetze-im-internet.de/stvzo_2012/__41.html
- Hand-Fasspumpen (l je Hub): https://www.jh-profishop.de/marken/samoa-hallbauer/umwelt/gefahrstoffhandling/pumpen/fasspumpen/hand-fasspumpen
- Abfertigungszeiten Battle of Britain (sekundär): https://ww2aircraft.net/forum/threads/battle-of-britain-turn-around-time.19850/
- Tobler, W. (1993): Three presentations on geographical analysis and modeling (Hiking Function).

## Priorisierte Korrekturliste

1. Bäume fern der Kamera und auf dem Server (**erledigt**, TreeObstacles)
2. Lecks PlayerSession/PlayerService (**erledigt**)
3. Fallschirm-Physik (**erledigt**)
4. Fahrzeug: Querbeschleunigung, Hang, Bremse, Wasser (**erledigt**)
5. Figuren in Wasser und Gelände (**erledigt**)
6. Doppelte Werte Kiste, Befüllrate, Schlauch, Sprint (**erledigt**)
7. Authentisch: Pumpe 2,5 l/s (**erledigt**), Lager-Befüllung 8–10 l/s (offen)
8. `depot_changed` als Object typisieren (offen, Bus-Vertrag)
9. Handpumpe/Kanister (M4)
10. Sim-LOD `truck_speed` an die echte KI-Fahrt koppeln (offen)

## Stellschrauben

- `GroundVehicle.MAX_LAT_ACCEL` (3,5), `DRIVE_ACCEL` (2,5), `POWER_PER_MASS` (9), `BRAKE_DECEL` (4,5), `WADE_DEPTH`/`DROWN_DEPTH`
- `Parachute.SINK_RATE` (6,0), `PULL_DELAY` (1 s), `INFLATE_TIME` (2 s), `LAND_KILL_SPEED` (10 m/s)
- `CrewCharacter.SLOPE_MIN_MUL`, `SLOPE_BLOCK`, `SWIM_DEPTH`, `SWIM_SPEED`
- `TreeObstacles.enabled`, `CHECK_AGL` (32 m), `PREFETCH_AGL` (300 m), `MAX_CELLS` (160)
- `ground_rules_*.tres`: pump_lps, truck_fill_lps, crate_speed_mul, crate_kg

## Ergebnis Soak (10 Spielminuten, nach den Korrekturen)

| t (s) | Objekte | Knoten | verwaist | Ressourcen | Speicher MB | Wracks | Jobs | Fallschirme |
|---|---|---|---|---|---|---|---|---|
| 0 | 5480 | 1654 | 1 | 552 | 215,1 | 0 | 4 | 0 |
| 180 | 5574 | 1654 | 1 | 552 | 215,9 | 0 | 3 | 0 |
| 300 | 5656 | 1726 | 1 | 552 | 216,4 | 1 | 6 | 1 |
| 480 | 5583 | 1655 | 1 | 552 | 216,2 | 0 | 5 | 1 |
| 600 | 5588 | 1655 | 1 | 552 | 216,2 | 0 | 8 | 1 |

Die Knoten bleiben nach Wrack und Fallschirm wieder bei 1655, und der Speicher steigt in 10 min um 1 MB (Aufwärmen).
Nach dem Freigeben der Szene bleiben 1 Knoten und 0 verwaiste übrig. Das Lecken am Ende ist von 47 Objekten auf 4 gesunken:
Übrig ist nur noch `assets/audio/ambient.ogg` (AudioStreamPlayback beim Beenden noch aktiv, Bereich Audio). Vorschlag: im
SoundDirector `_exit_tree` → `_ambient.stop()`. Die Hochrechnung auf 1–3 h ergibt kein messbares Wachstum.
Hinweis: Ein Durchlauf über 30 min wurde aus Zeitgründen abgebrochen (2 Minuten gleichbleibend). Aufruf:
`godot --headless --path game --fixed-fps 60 --script res://tools/soak.gd -- 60 out.csv`.
