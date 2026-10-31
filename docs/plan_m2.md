# Plan Meilenstein 2 – Waffen, Schaden, KI-Gegner

Stand: 31.10.2026 · Basis: GDD v3 (§6, §10 Punkte 15–19), Code M1 (+ M1.1) · Godot 4.7.2, Jolt, 60 Hz

## 1. Ziel und Abnahmekriterien

**Ziel:** Der Tester startet vom eigenen Platz und trifft auf 2–3 KI-Jäger der Feindnation. Er schießt sie mit begrenzter MG-Munition ab oder wird selbst abgeschossen, steigt aus oder notlandet und startet danach wieder am Platz.

**Abnahme (messbar):**
1. Szenario „Luftkampf 1 gegen 3“: mit Arcade-Hilfen schafft ein mittlerer Tester ≥ 1 Abschuss in 10 min.
2. TTK: 1–3 gute Feuerstöße (15–40 Treffer); alle Werte in `.tres`.
3. Ballistik: Flügel-MGs treffen sich im Konvergenzpunkt (Standard 250 m) auf ≤ 0,5 m; Absinken auf 500 m ≤ 5 % Abweichung von Referenztabelle.
4. Schaden: jede Zone zeigt Wirkung (je ein Headless-Test); Notausstieg ohne schweren Schaden gesperrt (Test).
5. Neustart ≤ 15 s nach Verlust (einstellbar).
6. KI-Regression headless: ≥ 8/10 Seeds Abschuss in 180 s; Veteran schlägt Rekrut in ≥ 7/10; < 5 % Bodenkollisionen ohne Schaden; gleicher Seed + Build → identischer Ereignis-Log-Hash.
7. Trefferprüfung: 100 % gefälschter Trefferberichte im Testkatalog abgelehnt.
8. Leistung: 8 Flugzeuge + 1.000 Geschosse ≤ 4 ms/Physik-Tick headless; ≥ 60 FPS beim Tester.
9. Alle M1/M1.1-Tests grün.

## 2. Waffensystem

**Daten:** `WeaponDef` (`weapons/data/*.tres`): caliber_mm, rpm, muzzle_velocity, projectile_mass, ballistic_k (½·ρ·Cd·A/m), dispersion_mrad, damage, tracer_every, max_range, ammo_type; optional heat_per_shot, cool_rate, jam_chance_hot. `GunMountDef` (Position, Gruppe primär/sekundär, Munition) als Liste in `AircraftData.guns`. Start T1: 2 × 7,92-mm-MG, 600 Schuss/min, 800 m/s, je 500 Schuss, Leuchtspur jeder 5.

**Marker ohne Modell:** Server/Headless laden kein GLB. `tools/extract_markers.gd` liest gun_*, hardpoint_*, Zonen, Ruder-Pivots einmal aus dem GLB in `AircraftData`; fehlende Marker → Ersatz aus Flächen/Rumpfbox.

**Ballistik** (`weapons/ballistics.gd`, reine Funktionen): a = g − k·|v|·v, halbimplizit, 2 Teilschritte; Startgeschwindigkeit = Mündung + Schütze; Konvergenz über vorberechnete Waffenrichtungen inkl. Fallkorrektur; Streuung aus deterministischem RNG (Seed = hash(shooter_id, gun_index, shot_index)); `time_of_flight(d)`, `drop(d)` als Tabelle für HUD/KI.

**Netzmodell (vorbereitet):** `FireEvent {shooter_id, gun_group, tick_on, tick_off}`; Schusszeiten aus Kadenz abgeleitet. Offline ruft Peer 1 dieselben Funktionen direkt.

**Projektile** (`weapons/projectile_system.gd`): Struct-of-Arrays (PackedVector3Array Position/Geschwindigkeit, Alter, Besitzer, Waffe), Ringpuffer 2.048, keine Nodes/RigidBodies. Treffer pro Tick Segment p0→p1: (1) Begrenzungskugel, (2) Segment ins Zielsystem inkl. Abzug der Zielbewegung im Tick, analytischer Test gegen Zonen-Hitboxen (OBB/Kapsel), (3) Boden über `Terrain.height_at()`, Physik-Raycast nur bodennah. Hitboxen als reine Daten (zurückspulbar).

**Trefferprüfung** (`weapons/hit_validator.gd`): `HitReport {shot_id, target_id, zone, tick, local_point}`; Server prüft Schuss existiert, Munition, Kadenz, Flugzeit, Ziel im Verlauf (`TransformHistory`, 1 s) mit Toleranz ≤ 3 m + Latenzanteil. KI nutzt denselben Weg.

**Effekte** (`weapons/fx/`, headless aus): Leuchtspuren als MultiMeshInstance3D, Mündungsfeuer-Pool (max. 8 OmniLights), Einschlag-Pool mit GPUParticles3D.

**Munition:** `AmmoMagazine` je Waffe; `AmmoStore`-Schnittstelle `request(type, n) -> int`, in M2 `InfiniteAmmoStore` am Platz; in M5 hängt sich `RearmJob` an.

**Eingabe:** `PilotIntent` + fire_primary, fire_secondary, eject. Belegungskonflikte: LMT fängt Maus → wenn gefangen, feuert LMT (erster Klick nur fangen). RT war Seitenruder rechts → RT = Feuer, LT = Sekundär; Seitenruder auf LB/RB (digital mit Rampe), Gas über Steuerkreuz ↑/↓. Tastatur: Leertaste = Feuer, J 1 s halten = Notausstieg; Pad: Steuerkreuz ← 1 s halten.

## 3. Schadensmodell

`DamageModel` am Flugzeug, Profil `damage_profile_t1.tres`, Änderungen nur wenn `Authority.is_server()`, Zustand als kompaktes Array.

| Zone | HP | Wirkung |
|---|---|---|
| engine | 120 | < 70 %: −15 % Leistung, Ölspur, Festfress-Timer 90 s; < 30 %: −50 %, Brandrisiko; 0: Motorstillstand |
| fuel_tank_L/R | 80 | Leck proportional (neues `FuelSystem`, Liter), Brandrisiko 8 %/Treffer |
| wing_L/R | 200 | Auftriebsfaktor sinkt, ab 50 % Querruder aus; 0 = Flügelbruch = Abschuss |
| tail | 120 | Höhen-/Seitenruder schwächer, Chance auf klemmendes Ruder |
| cockpit | 100 | < 60 verwundet (Eingabe gedämpft/verrauscht, Vignette); 0 = Pilot tot = Abschuss |

Kopplung über `FlightModifiers` (Hooks in flight_model.gd, aero_surface.gd, prop_engine.gd). Brand: 4 HP/s auf Zone, nach 10 s Übergriff Tank → Flügel, Sturzflug > 450 km/h löscht mit 15 %/s; Rauch (Öl grau, Brand schwarz + Flammen).

Abschuss: Flügelbruch, Pilot tot, Ausstieg, oder Bodenberührung ≤ 30 s nach Treffer; Kredit an letzten Schützen in 30 s, Beteiligung für Mitwirkende; `CombatEvents.aircraft_destroyed(victim, killer, cause)`.

Notausstieg nur bei Motorausfall, Brand, kritischem Leitwerk/Tragwerk oder verwundetem Pilot; sonst HUD „gesperrt“. M2: Fallschirm-Platzhalter, Ausfallzeit 15 s.

Aufprall: Bauchlandung (< 50 m/s, Sinkrate < 6 m/s, Querlage < 20°) → Pilot überlebt; sonst Absturz → Pilot verloren.

Neustart über `SpawnManager` (Server); Wracks nach 30 s weg; R/T bleiben Debugtasten.

Pilot/XP (nur Datenstruktur): `PilotRecord {id, level, xp_banked, xp_pending[], alive}`; XP nur bei Landung am eigenen Platz gutgeschrieben; Level-Hooks dispersion_mul, spot_range_mul.

## 4. KI-Gegner

`AIPilotBrain extends Controller` (`ai/brain/`), nur `PilotIntent`, Lenkung über `Autopilot.steer_to_direction`.

Wahrnehmung (`ai/perception.gd`): `Nations.is_hostile(a, b)`, Sichtweite 3 km (Frontkegel größer), Reaktionsverzögerung über verzögerten Positionspuffer.

Zustände: PATROUILLE, ANGRIFF/ANFLUG (Höhenvorteil), VERFOLGEN (Lead/Pure/Lag), FEUERN (< 400 m, Stöße 0,5–1,5 s), AUSWEICHEN (Feind am Heck < 600 m: Break, Schere, Spirale), ENERGIE (< 220 km/h), RÜCKZUG (Schaden, Munition < 10 %, Treibstoff knapp), BODENSCHUTZ mit Vorrang (Vorausschau 1/2/4 s gegen height_at).

Zielvorhalt (`weapons/lead_solver.gd`, auch HUD): Iteration Flugzeit/Zielgeschwindigkeit/-beschleunigung/Absinken, 3–4 Schritte.

Schwierigkeit (`AIDifficulty .tres` Rekrut/Erfahren/Veteran): Reaktion 0,9/0,5/0,25 s; Zielfehler 12/6/2,5 mrad; G-Nutzung 60/80/95 %; Manöver-Repertoire; Feuerdisziplin.

Nation: `Aircraft.nation_id` (0 Blau, 1 Rot) in `core/nations.gd` mit Diplomatie-Matrix. KI nutzt die in der Lobby erlaubten Hilfen.

Regression (`tests/suites/test_duels.gd`, Suite „slow“): 10 Seeds, frontal 2 km, 1.500 m, 180 s, `--fixed-fps`; Abschüsse, Treffer/Schuss, Bodenkollisionen, Log-Hash.

## 5. Spieler-Hilfen (HUD, `ui/combat/`)

Vorhaltepunkt (Arcade), Trefferanzeige (weiß/rot, Ton-Hook), Kill-Feed (oben rechts, 5 × 6 s), Kompassband, Radar-Light (3 km, Arcade), Feind-Markierung (Klammern + Entfernung, Randpfeile), Munition, Schadensskizze, Hinweis Notausstieg/gesperrt.

## 6. Testwelt-Erweiterung

`TerrainWorld` (TestWorld bleibt flach): Höhenkarte 40 × 40 km, 2.049² Punkte (~19,5 m), `tools/build_terrain.gd` (FastNoise, fester Seed, Talzug, geglättete Plätze) als `.res`; 16 × 16 Kacheln à 2,5 km mit HeightMapShape3D + Mesh in 3 LODs; `height_at(x, z)` bilinear; zwei Plätze ~25 km auseinander.

Floating Origin vorbereitet: Server rechnet absolut (±20 km ≈ 2 mm float32-Auflösung); `world/origin_shifter.gd` verschiebt nur Client-Darstellung ab 4 km Kameraabstand (inkl. reset_physics_interpolation, Geschosse); Netzwerk/Gameplay absolut (`WorldOrigin.to_abs/to_local`); in M2 per Schalter, Zitter-Messung entscheidet.

## 7. Arbeitspakete

| # | Paket | Dateien | Abh. | Tests | Umfang |
|---|---|---|---|---|---|
| 0 | Vertragsschnitt nach M1.1: Intent-Bits, nations.gd, combat_events.gd, layers.gd, Eingabe-Umbelegung, Stubs WeaponSystem/DamageModel/FlightModifiers mit Aufrufen, Test-Runner mit Suites | core/*, control/*, aircraft.gd, flight_model.gd, aero_surface.gd, prop_engine.gd, tests/test_runner.gd | M1.1 | M1 grün, Intent-Roundtrip | M |
| 1 | WeaponDef, Ballistik, LeadSolver | weapons/ballistics.gd, weapon_def.gd, lead_solver.gd, data/mg_t1.tres | 0 | Konvergenz, Absinken, Vorhalt | S |
| 2 | ProjectileSystem, Waffen, Munition, Debug-Linien | weapons/projectile_system.gd, weapon_system.gd, ammo_*.gd | 1 | Kadenz, Zähler, Testbox, 1.000 Geschosse | M |
| 3 | Marker-Extraktion, Hitboxen | tools/extract_markers.gd, vehicles/aircraft/damage/hitbox_set.gd | 0 | Ersatz-Hitboxen, Segment-OBB | S |
| 4 | DamageModel + Flugwirkungen, FuelSystem | vehicles/aircraft/damage/*.gd, physics/fuel_system.gd | 3 | ein Test je Zone | M |
| 5 | FireEvent, HitValidator, TransformHistory | weapons/fire_event.gd, hit_validator.gd, transform_history.gd | 2 | Katalog gefälschter Berichte | M |
| 6 | Abschuss, Ausstieg, Bauchlandung, SpawnManager, PilotRecord | world/spawn_manager.gd, characters/*.gd | 4 | Ausstieg gesperrt/erlaubt, Neustart ≤ 15 s | M |
| 7 | Wahrnehmung + AIPilotBrain + Schwierigkeit | ai/brain/*.gd, ai/perception.gd, ai/data/*.tres | 1 | Verfolgung, Bodenschutz | L |
| 8 | Duell-Suite | tests/suites/test_duels.gd, tests/duel_arena.gd | 2, 4, 7 | Abnahme 6 | M |
| 9 | Kampf-HUD | ui/combat/*.gd | 0, 1 | Smoke-Test, Screenshot | M |
| 10 | Waffen-Effekte | weapons/fx/*.gd | 0 | headless aus, Screenshot | M |
| 11 | Brand/Rauch/Öl, Ruder-Pivots animieren | vehicles/aircraft/damage/fx_*.gd, aircraft_visual.gd | 3 | Screenshot | S |
| 12 | Gelände (Höhenkarte, Kacheln) | tools/build_terrain.gd, world/terrain/*.gd | 0 | height_at = Raycast, Start/Landung | L |
| 13 | Floating Origin | world/origin_shifter.gd, core/world_origin.gd | 12 | Bahnabweichung ≤ 1 cm | M |
| 14 | Integration Szenario 1 gegen 3 | world/game.gd, world/combat_scenario.gd | alle | main_scene-Test, Abnahmespiel | M |
| 15 | (optional) Überhitzung/Ladehemmung | weapons/heat.gd | 2 | Hitzekurve | S |

**Parallel nach Paket 0 (keine gemeinsamen Dateien):** A Waffen 1→2→5→15 · B Schaden 3→4→6→11 · C KI 7→8 · D HUD 9 · E Effekte 10 · F Welt 12→13. Nur 0 und 14 berühren gemeinsame Dateien; Paket 11 braucht aircraft_visual.gd exklusiv.

## 8. Risiken und offene Fragen

Risiken: Konflikt mit M1.1 (Paket 0 erst nach Merge); GDScript-Leistung (SoA erlaubt später GDExtension); Gleitkomma plattformübergreifend nicht bitgleich (Toleranz in Trefferprüfung); abweichende Marker-Namen (Extraktion mit Warnung/Ersatz); KI-Bodenkollisionen (Bodenschutz mit Vorrang, gemessen).

Entscheidungen (31.10.2026):
1. Pad: RT = Feuer, LT = Sekundär, Seitenruder auf LB/RB, Gas über Steuerkreuz; Maus/Tastatur: LMT oder Leertaste = Feuer, J 1 s halten = Notausstieg → **vom Product Owner bestätigt**
2. Vorhaltepunkt/Radar-Light nur Arcade, Feindmarker in Realistisch erst ab Nähe, Lobby-Option → **bestätigt, ERWEITERT:** Erkennungsweite (spot range) hängt ab von Flugzeug (Sicht aus dem Cockpit, Anzahl Besatzung/Beobachter), Besatzungslevel und Radar (eigenes Bodenradar im Bereich und intakt → frühere Markierung; später Bordradar). Umsetzung: `spot_range = base(Modus) × aircraft_visibility × crew_level_mul + radar_bonus` als Funktion in `ai/perception.gd`/`core/spotting.gd`, von Spieler-HUD und KI gemeinsam genutzt. Radar in M2 als Stub (Objekt mit Reichweite + Zustand), echte Gebäude später.
3. M2: 15 s Ausfallzeit, Fallschirm ohne Third-Person → Projektmanager-Entscheidung: ja
4. Eigenbeschuss technisch immer an, Schaden per Lobby-Schalter, Standard aus → **bestätigt**
5. Eigenes Höhenkarten-System statt Terrain3D → Projektmanager-Entscheidung: eigenes System
