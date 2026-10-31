# Änderungsprotokoll Flugkern

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
