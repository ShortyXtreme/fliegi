# Prüfung Flugphysik (Audit 11/2026)

Stand: 27.11.2026, Branch `audit-flug`, Basis main 7a170bc (M3.9). Geprüft wurden `flight_model.gd`, `aero_surface.gd`, `prop_engine.gd`, `flight_assist.gd`, `landing_gear.gd`, `fuel_system.gd`, `aircraft.gd` (Masse), `fighter_t1.tres` und die Kopplung an `core/weather.gd`.
Gemessen wurde mit der neuen Messsuite `tests/suites/physics/test_flight_perf.gd` (Suite `perf`, Aufruf `tests/run_tests.sh --suite=perf --file=flight_perf`). Die Regressionstests stehen in `tests/suites/physics/test_flight_audit.gd` (Suite fast).

## Kennwerte des Modells
Tier-I-Jäger „Falke“: 2.500 kg voll, Flügel 17,2 m², Spannweite 10,6 m, echte Streckung 6,5, Flächenbelastung 145 kg/m², 700 kW (≈ 950 PS) bis 4.000 m Volldruckhöhe, 360 l Kraftstoff, 2 MG.
Damit liegt er zwischen MS.406 (2.540 kg, 16 m², 830 PS) und Bf 109 E (2.610 kg, 16,4 m², 990–1.100 PS).

## Befunde

| Befund | Ist (vorher) | Soll (mit Quelle) | Schwere | Vorschlag / Umsetzung |
|---|---|---|---|---|
| Atmosphäre: Dichte als Exponentialfunktion (H = 8.500 m), keine Temperatur, keine Schallgeschwindigkeit | ρ(4 km) 0,765, ρ(6 km) 0,604 (−7 … −9 %) | ISA: 0,819 / 0,660 kg/m³ (ICAO-Normatmosphäre) | Fehler | **umgesetzt:** ISA mit T, ρ, a; Test `test_isa_atmosphere` |
| Keine Kompressibilität, kein Mach | Sturz unbegrenzt, M 0,67 ohne jede Wirkung, im senkrechten Sturz deutlich mehr | dicke Profile der 30er: M_krit ≈ 0,62–0,68, Sturzgrenzen 610–850 km/h IAS (Hurricane 380 mph, Spitfire I 450 mph, Bf 109 E 750–850 km/h) | Fehler | **umgesetzt:** Wellenwiderstand ab M 0,64 (`mach_critical`), steiler Anstieg bis M ≈ 0,74. Senkrechter Sturz Vollgas aus 6.000 m: max M 0,67, 775 km/h |
| Stall-Schutz (Arcade/KI) zieht stationär nicht bis zur eigenen Grenze | Dauerkurve AoA 11,0° statt 12,75° (Grenze = Abriss − 1,25°), ≈ 8 % Auftrieb verschenkt. Ursache: Dämpfungsterm −0,35·q wirkt im stationären Ziehen als Dauer-Abzug, und die Nickrate braucht zusätzlich Höhenruder | Begrenzer soll ≥ 90 % CL_max nutzen (eigene Recherche M1.1) | Fehler | **umgesetzt:** Vorsteuerung `elevator_per_qv`·q/V statt −D·q, α̇-Dämpfung 0,5 → 1,0. Jetzt AoA 12,7–13,2°, kein Abriss (Test `test_stall`: Arcade 0,00) |
| Keine g-Grenze | Arcade 16 g bei 230 m/s, Realistisch 10–11 g (Meldung Waffen-Agent) | Struktur +8 g (Bruch ~11–12 g: IL-2 Bf 109 E 11 g, I-16 12 g), Pilot 5–6 g dauerhaft | Fehler | **umgesetzt:** Arcade/KI: Lastgrenze 7,5 g (`arcade_g_limit`) über Grenz-AoA und Nickraten-Wunsch, gemessen max 7,9 g bei 830 km/h. Realistisch: Knüppelkraft-Exponent 1,5 → 1,7, max 9,6 g bei 830 km/h (Stil B: intakter Flügel bricht nicht) |
| Rollrate zu hoch | Realistisch voll: 96 / 122 / 151 / 183 °/s bei 200/300/400/500 km/h, pb/2V ≈ 0,13–0,16 | pb/2V 0,08–0,09 bei vollem Ausschlag, Forderung 0,07; bei 300 mph nur halber Ausschlag (NACA ACR L-334, Spitfire V) | Ungenau | **umgesetzt:** Querruder 18° → 13°, Realistisch ab 340 km/h Knüppelkraft (v_ref/v)^1,5. Jetzt 55 / 96 / 93 / 82 °/s (200/300/400/500). Arcade-Obergrenze 126 °/s unverändert |
| Kein Propellerstrahl am Leitwerk | Seitenruder im Stand/Startlauf nur mit Fahrtwind; Ausbrechen bei 8 m/s Seitenwind mit Heck oben (offen aus M3.9) | Strahltheorie v_w = √(v² + 2T/(ρA)), im Stand ≈ 50 m/s | Fehler | **umgesetzt:** `prop_wash` je Fläche (Seitenleitwerk 0,6, Höhenleitwerk 0,3), `prop_diameter` 3,1 m. Test `test_crosswind_takeoff_tail_up` |
| Streckung im Datensatz 7,0 | geometrisch 10,6² / 17,2 = 6,5 | – | Ungenau | **umgesetzt:** 6,5 (induzierter Widerstand +7 %) |
| Dauerkurve | 19,4 s (1.000 m), vorher mit verschenktem Auftrieb | Bf 109 E 20,5 s (SL, 270 km/h IAS), I-16 19,0 s (IL-2-Museum) | OK | nachher 19,7–20,4 s bei 255–260 km/h, 2,55 g |
| Höchstgeschwindigkeit | 483 km/h (100 m), 553 km/h (4.000 m) | Bf 109 E 477 / 520 (2 km) / 564 (5 km); MS.406 452 (2 km) / 490 (4,5 km); Hurricane I ≈ 410–440 SL / 520 | OK | nachher (ISA) 481 / 510 / 541 / 537 / 532 km/h bei 0,1/2/4/5/6 km |
| Steigrate | 14,9 (SL) / 15,1 (3 km) / 10,5 (6 km) / 6,9 m/s (8 km) | Bf 109 E 14 / 13,3 / 7; I-16 16,7 / 13,8 / 8,8; MS.406 Ø 11 m/s bis 6 km | OK (6 km etwas hoch) | nachher 14,7 / 14,9 / 10,6 / 6,9. Leistungsabfall über der Volldruckhöhe ∝ ρ ist eher mild |
| Abrissgeschwindigkeit | 145 km/h IAS sauber, 129 mit Landeklappen | Bf 109 E 152–159 / 147; MS.406 160 / 135; Hurricane II 138 / 109 | OK | nachher 145 / 133 (50 %) / 132 (100 %). Landeklappen bringen über 50 % kaum mehr ΔCL (Wirkungsabfall ab 10° Ausschlag) – Spielgefühl, offen |
| Start | 202 m Rollstrecke, Abheben 132 km/h, 15 m nach 365 m | Hurricane I 210–256 m (Klappen 30° / ein), Abheben 113–121 km/h IAS; MS.406 270 m bis 8 m | OK | nachher 242 m, 140 km/h, 15 m nach 393 m |
| Landung | 256 m mit Bremse (ab 100 km/h), 919 m ohne | MS.406 340 m ab 8 m Höhe | OK | unverändert ≈ 250 m |
| Rollreibung Gras | 0,035 überall | feste, kurze Wiese 0,04–0,06, Bremsen 0,3–0,4 (eaglepubs, Takeoff & Landing) | Ungenau | offen (wirkt auf alle Boden-/KI-Tests; Vorschlag 0,045). Es gibt nur Graspisten, eine Beton-Kennlinie ist nicht nötig |
| Verbrauch | 324 l/h Vollgas (0,245 kg/PSh), 209 l/h bei 60 % | DB 601: 0,24–0,27 kg/PSh Startleistung, sparsam ~0,21; Bf 109 E 400 l, 312–396 l/h | OK | Verbrauch hängt nur vom Gashebel ab, nicht von der Leistung über der Volldruckhöhe (Ungenau; Aufruf sitzt in `damage_model.gd`, fremder Bereich) |
| Reichweite | 360 l, 60 % Gas 444 km/h in 4 km → ≈ 760 km | Bf 109 E 660 km, MS.406 720 km (Kampf) | OK | – |
| Energieverlust im Ziehen | aus 400 km/h: 10,7 km/h/s bei 4,7 g | grob 15–25 km/h/s bei 4–5 g | Spielgefühl | nachher 14,8 km/h/s bei 5,2 g (durch volle Begrenzer-Marge) |
| Trägheitsmomente 8.000 / 13.000 / 6.000 kg m² (Nick/Gier/Roll) | Roskam-Radien (Rx 0,25, Ry 0,38, Rz 0,39): ≈ 7.000 / 9.000 / 4.400 | – | Ungenau | offen; Gier und Roll ≈ 40 % hoch, ändern Rollbeschleunigung. Trägheit sinkt nicht mit dem Kraftstoff |
| Masse: Munition nicht gekoppelt, Schwerpunkt fest | 1.000 Schuss ≈ 26 kg | – | Ungenau | offen (klein) |
| Motor: kein Drehmoment, kein P-Faktor, kein Drall, kein Kreiseleffekt | – | real deutliches Linksdrehen beim Start | Spielgefühl | offen; Vorschlag: abschaltbar mit Faktor 0,3–0,5, erst nach KI-Starttest |
| Motor: keine Kühlung/Überhitzung, Gemisch nur Ein/Abstellen, Kaltstart ohne Warmlauf | – | – | Spielgefühl | offen (Feature) |
| Propellerwirkungsgrad konstant 0,8 | – | Verstellpropeller 0,80–0,85 | OK | – |
| Leistung über Höhe: bis 4.000 m konstant, darüber ∝ ρ | – | DB 601 A 990 PS SL / 1.020 PS 4,5 km | OK | – |
| Fahrtmesser zeigt wahre Fahrt (TAS) | Abriss in 3 km scheinbar 15 % „schneller“ | Fahrtmesser zeigt IAS | Ungenau | **Telemetrie** `ias` und `mach` neu; HUD-Anzeige liegt bei einem anderen Bereich |
| Wind-Kopplung | Luft-relativ (v − w) für Flächen, Rumpf, Schub; Fahrwerk über Grund; Rollböe v_punkt −= UP·roll_grad·(r·rechts) | – | OK | richtig angewandt, keine Änderung |
| AoA mit v + ω×r, Abwind, Cmq, Vorzeichen, Einheiten | – | – | OK | – |
| Integration | 60 Hz fest, Federn ζ ≈ 0,4, Reibsteifigkeiten dt·k < 1 | – | OK | stabil |
| Seitenkraft Rumpf am Schwerpunkt (kein destabilisierendes Giermoment) | – | – | Ungenau | offen, gering |

## Duell-Patt (`test_duels_flat`)
Vorher 6/10 Abschüsse (Seeds 1000, 1002, 1004, 1009 ohne). Der Verlauf von Seed 1000 zeigt 180 s lang wiederholte Begegnungen mit Aspekt 120–160° und anschließendem Zwei-Kreis-Kampf bei 3–5 g mit 280–430 km/h, ohne einen Schuss. Seeds 1002 und 1009 enden mit 8 bzw. 23 Treffern ohne Abschuss.
Physikalischer Anteil: Der Stall-Schutz hat ~8 % Auftrieb verschenkt und die KI flog mit bis zu 16 g ohne Lastgrenze. Beides ist behoben, wirkt aber auf beide Seiten gleich. Der Patt kommt aus der vollständigen Symmetrie (gleiches Flugzeug, gleiche KI) und aus der Schadensschwelle (20–33 Treffer). Messwerte nach der Korrektur: siehe Abschnitt „Ergebnisse“.

## Priorisierte Korrekturliste
1. Stall-Schutz-Bias und g-Grenze (KI und Arcade) – erledigt
2. ISA und Kompressibilität – erledigt
3. Propellerstrahl am Leitwerk (Seitenwind beim Start) – erledigt
4. Rollrate und Querruder-Knüppelkraft – erledigt
5. Rollreibung Gras 0,045 – offen
6. Trägheitsmomente nach Roskam prüfen, Trägheit mit Kraftstoff – offen
7. Drehmoment, P-Faktor, Drall (abschaltbar, Stil B) – offen
8. Verbrauch an die abgegebene Leistung koppeln (Aufruf in `damage_model.gd`) – offen, fremder Bereich
9. Fahrtmesser auf IAS umstellen (`telemetry.ias`) – HUD-Bereich

## Stellschrauben
`AircraftData.arcade_g_limit` (7,5), `elevator_per_qv` (25), `mach_critical` (0,64), `prop_diameter` (3,1), `realistic_aileron_ref_speed`/`_exponent` (340 km/h, 1,5), `realistic_elevator_exponent` (1,7), `AeroSurfaceDef.prop_wash` (Seitenleitwerk 0,6, Höhenleitwerk 0,3), `FlightAssist.LIMIT_AOA_RATE_D` (1,0), `FlightModel.WAVE_K`/`WAVE_SPAN`.

## Angepasste Tests
- `test_arcade_mouse_pull`: Grenze für die Standardabweichung der G-Last 0,3 → 0,5. Der Begrenzer nutzt jetzt die volle Marge (G-Mittel 4,1 statt 3,7). Die Standardabweichung enthält den Fahrtverlust, der dadurch schneller wird. Das Flattern (0,031) bleibt unter 0,1.

## Quellen
- IL-2 Sturmovik Museum, Bf 109 E-7: https://il2sturmovik.com/museum/fighters/bf-109-e-7/
- IL-2 Sturmovik Museum, I-16 Typ 24: https://il2sturmovik.com/museum/fighters/i-16-type-24/
- NACA ACR L-334, Phillips & Vensel 1942, Spitfire VA (pb/2V, CL_max 1,21, Querruderkräfte): https://ntrs.nasa.gov/api/citations/19930092582/downloads/19930092582.pdf
- NACA, Phillips 1942, Querruder P-36, P-40, Spitfire, Hurricane: https://ntrs.nasa.gov/citations/20150015694
- Hurricane-Erprobung (Start 280/230 yd, Sturzgrenze 380 mph): https://erenow.org/ww/flying-limit-testing-world-war-ii-single-engined-fighter-aircraft/1.php
- Hurricane I: https://www.historyofwar.org/articles/weapons_hawker_hurricaneI.html
- Spitfire I: https://www.historyofwar.org/articles/weapons_spitfire_mkI.html
- Bf 109 E: https://warbirdsresourcegroup.org/LRG/luftwaffe_messerschmitt_bf109e_specifications.html
- MS.406: https://en.wikipedia.org/wiki/Morane-Saulnier_M.S.406
- Roll- und Bremsreibung: https://eaglepubs.erau.edu/introductiontoaerospaceflightvehicles/chapter/takeoff-landing-performance/
- ICAO-Normatmosphäre (Doc 7488), Lock-Gesetz für den Wellenwiderstand, Roskam „Airplane Design“ Teil V (Trägheitsradien) – Lehrbuch
