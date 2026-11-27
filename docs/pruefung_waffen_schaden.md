# Prüfung Waffen, Ballistik, Schaden, Absturz

Stand: 27.11.2026 · Basis: main 7a170bc (M3.9) · Branch `audit-waffen`
Geprüft: `game/weapons/` (Ballistik, ProjectileSystem, LeadSolver, HitValidator, WeaponSystem, Daten), `game/vehicles/aircraft/damage/` (DamageModel, DamageProfile, HitboxSet, Breakup, Debris, Wreck, CrashFx) und die Schnittstelle Schaden → Flugphysik (`FlightModifiers`).
Messskripte (nur Diagnose, ändern nichts): `game/tests/diag/weapons_diag.gd` (Ballistik-Tabelle, Tickraten, Dichte, Treffer bis Abschuss je Anflugrichtung), `game/tests/diag/selbsttest_ab_diag.gd` (Selbsttest A/B nachgestellt), `game/tests/diag/gload_diag.gd` (erreichbare g-Last).

## 1. Kurzfassung

Die Ballistik ist physikalisch sauber: Der Luftwiderstand passt mit Cd ≈ 0,30 zu einem Spitzgeschoss im Überschall, der Integrator weicht bei 60 Hz um weniger als 2 % ab, und die Trefferprüfung über bewegte Segmente kennt kein Tunneling. Das Schadensmodell hat dagegen einen echten Fehler und eine grobe Geometrie, die zusammen das Spielgefühl bestimmen:

1. **Fehler:** Der Schadensfaktor der Rumpf-Füllboxen (`damage_mul` 0,4) wird nie angewendet. Treffer in den hinteren Rumpf zählen deshalb voll als Leitwerk, Treffer in die Rumpfmitte voll als Cockpit.
2. **Leitwerk als massiver Block** (3,7 × 1,8 × 1,5 m, also 6,7 m² Stirnfläche statt ≈ 1,5 m² echter Fläche). Bei 6 Uhr gehen 99 % aller Treffer ins Leitwerk, und nach **genau 12 Treffern** ist das Flugzeug abgeschossen, immer am Leitwerk. Motor und Pilot sind von hinten praktisch nicht zu treffen. Ein Abschuss am Leitwerk durch Gewehrkaliber war historisch selten.
3. **Kadenz 600/min** liegt bei der Hälfte jeder echten Flugzeug-MG der Epoche (1.100–1.800/min). Die Feuerdauer beträgt 50 s statt 25 s (MG 17 mit 500 Schuss) bzw. 15 s (Spitfire).
4. **Keine Bruchlast unter g:** Der Jäger erreicht in Arcade beim vollen Ziehen 16 g (bei 230 m/s), in Realistisch 10 g. Auch ein zerschossener Flügel hält das aus. Das fehlende g-Limit gehört zur Flugphysik, die Kopplung „beschädigter Flügel bricht unter Last“ zum Schaden.
5. **Selbsttest A/B:** Die Zahlen sind erklärbar und kein Waffenfehler. A ergibt 6 Treffer × 10 = 60. In B ist das Leitwerk nach 12 Treffern bei 0 HP (12 × 10 = 120), und die weiteren 32 Treffer treffen die zerstörte Zone mit 0 Schaden. Die Trefferzahl hängt nur davon ab, wie stark die Flugzeuge nach `place()` aufnicken (+1,8° in 2,7 s, Ziel wandert 7–8 m aus der Visierlinie). Niemand zielt dabei.

## 2. Befunde

| Befund | Ist | Soll (mit Quelle) | Schwere | Vorschlag |
|---|---|---|---|---|
| Schadensfaktor der Füllboxen | `HitboxSet` liefert `damage_mul` 0,4 für Rumpfmitte/Heckrumpf, `ProjectileSystem._hit_target` nutzt nur `w.damage` | Laut Kommentar in `hitbox_set.gd` sollen Füllboxen „verringerten Schaden“ machen | **Fehler** | `dmg = w.damage × hit.damage_mul` |
| Leitwerk-Hitbox | ein Block 3,7 × 1,8 × 1,5 m (Marker-AABB über Flosse + Höhenleitwerk) | Höhenleitwerk ≈ 3,7 × 0,15 m, Flosse ≈ 0,15 × 1,4 m, Profildicke ≈ 10–12 % der Tiefe ([AircraftData-Flächen htail/vtail]) | **Fehler** (Geometrie) | Leitwerk als zwei Platten aus den Flächen `htail_*`/`vtail`, Heckkonus als Füllbox |
| Treffer bis Abschuss von 6 Uhr | 12 (immer Leitwerk, Streuung 12–13) | 20–40 Gewehrkaliber-Treffer für einen Jäger (abgeleitet: 3–4 Treffer 20 mm genügen [W1], 20 mm hat ein Vielfaches der Wirkung; Bomber überstanden > 100 Treffer .303 [A1]); Plan M2 §1: 15–40 | Spielgefühl | nach den Korrekturen neu messen (Ziel 20–35, Ursache gemischt) |
| Durchschlag hinter der Außenhaut | innere Zone zählt nur bis 1,0 m hinter dem Eintritt | Gewehrgeschosse durchschlagen den dünnen Heckrumpf (Monocoque/Stoff) bis zur Panzerplatte; die Hurricane-Bespannung zeigte meist nur zwei kleine Löcher [W1] | Ungenau | `PENETRATION` 1,0 → 3,5 m, dafür Rückenpanzer |
| Rückenpanzer Pilot | keine Panzerung, Cockpit von allen Seiten gleich | Bf 109 E: 8-mm-Platte hinter dem Tank + 10-mm-Kopfpanzer; Spitfire ab Mitte 1940: 4,5 mm Rücken, 6,5 mm Kopf, 33 kg [W1]; nur 1 % der 7,92-mm-SmK durchschlugen 4 mm auf 200 yd [A1] | Ungenau | Cockpit-Treffer aus dem hinteren Kegel (±53°) × 0,3 |
| Kadenz | 600/min | MG 17: 1.200 [W2][R1]; Browning .303 Mk II: 1.150 [H1]; ShKAS: 1.800 (synchronisiert 1.650) [W3]; M2 .50: 750–850 [N1] | Ungenau / Spielgefühl | 1.150/min (Flügel-MG, nicht synchronisiert) |
| Feuerdauer | 500 Schuss / 600 min⁻¹ = 50 s | MG 17 im Flügel 500 Schuss = 25 s [D1]; Rumpf-MG 17 1.000 Schuss ≈ 55 s (synchronisiert) [D2]; Spitfire 300 Schuss ≈ 15 s [P1] | Spielgefühl | mit 1.150/min: 26 s |
| Mündungsgeschwindigkeit | 800 m/s | .303 Mk VII 744 m/s / Mk VIII 811 m/s [H1]; ShKAS 775–825 [W3]; MG 17 885–905 [W2]; M2 .50 866 [N1] | OK | – |
| Geschossmasse | 12,8 g | 7,92 s.S. 12,8 g; MG 17 laut [W2] 11,5 g; .303 11,3 g (0,4 oz) [H1]; ShKAS 9,6 g [W3] | OK | – |
| Luftwiderstand k | 7,0·10⁻⁴ 1/m → Cd = 0,297 bei ρ = 1,225 | Spitzgeschoss im Überschall Cd ≈ 0,3, transsonisch höher (McCoy, MC DRAG [M1]) | OK | – |
| Luftdichte | k fest (Meereshöhe) | Widerstand ∝ ρ; das Flugmodell nutzt ρ(h) = 1,225·e^(−h/8500). In 3.000 m: v(500 m) 625 statt 563 m/s, Fall 2,31 statt 2,50 m | Ungenau | k beim Abschuss mit ρ(h)/ρ₀ skalieren (ProjectileSystem, HitValidator, LeadSolver gleich) |
| Integrator | halbimplizit, 2 Teilschritte/Tick | Referenz 6.000 Hz: Fall 500 m 2,454 m; 60 Hz: 2,499 m (+1,8 %), 30 Hz +3,7 %, 120 Hz +0,9 %; Plan ≤ 5 % | OK | – |
| Tunneling | Segment p0→p1 im Zielsystem (p0 mit Vortick-Transform, p1 mit aktuellem), Grobtest mit bewegter Kugel | analytisch, kein Tunneling bei 1.000 m/s Annäherung (Test `test_hit_moving_box_high_speed`) | OK | – |
| Framerate-Unabhängigkeit | Waffen, Geschosse und Schaden laufen im Physik-Tick; Brand-Löschchance `1−(1−p)^dt` | – | OK | – |
| Verwundeten-Zittern | Tiefpass `x·0,95 + r·0,05` je Tick | sollte zeitbasiert sein | Ungenau (gering) | α = 1 − e^(−dt/τ) |
| Kadenz-Nachlauf `late` | Startpunkt `+ (v0·dir + v_Schütze)·late` | richtig wäre `+ v0·dir·late` (der Schütze war `late` s früher weiter hinten); Fehler ≤ v·dt = 1,8 m längs der Bahn | Ungenau (gering) | `pos += dir·v0·late` |
| Konvergenz | 250 m, Bahnen kreuzen die Visierlinie auf 0,00 m | RAF 1940: 400 → 250 yd, Erfolgsquote 39 → 53 % [A1] | OK | – |
| Waffenposition | Loadout (±1,9; −0,3; −0,9), Modell-Marker (±2,35; −0,07; −0,89) | Mündungsfeuer und Bahnen sollen am Modell-MG beginnen | Ungenau | Loadout auf Marker setzen |
| Streuung | 1,5 mrad (σ je Achse) | Sims arbeiten mit 1–3 mrad; bei 250 m σ = 0,37 m | OK | – |
| Leuchtspur | jeder 5. Schuss | üblich 1:3 bis 1:5 | OK | – |
| Rückstoß | nicht modelliert | 2 × 7,92 mm bei 1.150/min ≈ 2 × 250 N ≈ 4 % des Standschubs | Ungenau (gering) | offen, erst bei Kanonen sinnvoll |
| Munitionsmasse | nicht in der Flugzeugmasse | 7,92 × 57 mit Gurtglied ≈ 40 g/Schuss [W2] → 1.000 Schuss ≈ 40 kg (1,6 % von 2.500 kg) | Ungenau (gering) | Hook `WeaponSystem.ammo_mass_kg()`, Kopplung in `aircraft.gd` (Flugphysik) |
| Synchronisation | keine (nur Flügelwaffen) | synchronisierte Rumpf-MG ≈ 10 % langsamer (Bf 109 E: 1.000 Schuss in ≈ 55 s ≈ 1.090/min [D2]) | OK (n. a.) | bei Rumpfwaffen `rpm` × 0,9 |
| Schaden je Kaliber | nur 7,92 mm (10) | Empfehlung für spätere Waffen (Wirkung grob ∝ Energie, HE gesondert): 12,7 mm ≈ 30–35, 20 mm MG FF/M ≈ 90–110 (3–4 Treffer für einen Jäger [W1]) | – | in `WeaponDef.damage` |
| Motor | 120 HP, < 70 % Ölspur + Festfressen nach 90 s, < 30 % ×0,5 und Brandrisiko 10 % | flüssigkeitsgekühlte V12: ein Treffer in Kühler/Leitung → Festfressen in Minuten | OK (Stil B) | Kühler als eigene kleine Zone (später) |
| Tankbrand | 8 % je Treffer | .303 Mk IV und 7,92-mm-Brandmunition entzündeten Blenheim-Tanks etwa bei jedem 10. Schuss [A1] | OK | – |
| Brand | 4 HP/s, Ausbreitung Tank → Flügel nach 10 s, Löschen > 450 km/h mit 15 %/s | – | OK (Stil B) | – |
| Pilot | verwundet < 60 %, tot bei 0 (10 Volltreffer) | – | OK | mit Panzer s. o. |
| Steuerseile/Leitwerk | Ruderwirkung bis ×0,3, klemmendes Ruder 25 % × Schadensquote | – | OK | wirkt nach dem Fix auch über die Heckrumpf-Füllbox (×0,4) |
| Strukturversagen unter g | fehlt; Flugmodell erreicht 16 g (Arcade, 230 m/s) bzw. 10 g (Realistisch) | Spitfire F.7/30: Lastvielfaches 9,0 [P2]; übliche Bruchlast Jäger ≈ 12–13 g | Ungenau | beschädigter Flügel (< 75 % HP) bricht über 5–12 g (linear), intakt kein Bruch (Stil B) |
| Flügel-Hitbox | Dicke 0,5 m (AABB inkl. V-Form) | Profildicke ≈ 0,15–0,3 m | Ungenau | später in 2 Teilboxen je Flügel |
| Schaden → Flugphysik | Auftrieb −35 %, Cd +0,02, Querruder aus < 50 %, Flügel 0 HP → Fläche fehlt; Lochwiderstand 0,015 m² je Zone (Rumpf 0,17 m²) | Schnittstelle vollständig neutral bei intakt (`is_neutral`) | OK | – |
| `broken_root_lift` | Profilwert 0,4, nicht benutzt (abgerissener Flügel: alle Flächen 0) | – | Ungenau (toter Wert) | Wert entfernen oder Wurzel 0,4 behalten |
| Wrack-Übergabe | Wrack 1.800 kg, k = 4 → Endgeschwindigkeit 66 m/s; aus 150 m/s bremst es sofort mit 5 g | Flugzeug 2.500 kg; ein trudelndes Flugzeug fällt mit ≈ 50–80 m/s | Spielgefühl | Masse vom Flugzeug, k so, dass v_end ≈ 70 m/s, aber Abbremsen ≤ 2 g |
| Trümmer | Flügel 160 kg, k = 0,5·1,2·1,0·A → v_end ≈ 17 m/s, Leitwerk ≈ 12 m/s, Wind | flatternde Platte | OK | – |
| Krater/Wasser | CrashFx: Explosion, Krater, Rauch; im Wasser Fontäne, Wrack versinkt in 9 s | – | OK | – |
| Zusammenstoß | Relativfahrt > 15 m/s: zufälliger Flügel 0 HP | – | OK | – |
| Selbsttest A/B | A: 62 Schuss, 6 Treffer, 60 Schaden; B: 62 Schuss, 44 Treffer, 120 Schaden | A: 6 × 10 = 60 ✓. B: 12 × 10 = 120 = Leitwerk-HP ✓, der Rest trifft die zerstörte Zone (0 Schaden). Trefferzahl hängt am Aufnicken nach `place()` | OK (Test misst nur die Kette) | als Messgröße für Genauigkeit ungeeignet (Hinweis an Selbsttest-Verantwortliche) |

## 3. Messwerte vorher (main 7a170bc)

**Ballistik MG 7,92 mm** (v0 800 m/s, k 7·10⁻⁴, 12,8 g, Meereshöhe):

| Entfernung | Flugzeit | Fall | v_rest | E_kin |
|---|---|---|---|---|
| 100 m | 0,130 s | 0,09 m | 746 m/s | 3,6 kJ |
| 250 m | 0,342 s | 0,56 m | 671 m/s | 2,9 kJ |
| 500 m | 0,751 s | 2,50 m | 563 m/s | 2,0 kJ |
| 1.000 m | 1,817 s | 13,1 m | 396 m/s | 1,0 kJ |
| 1.500 m | 3,332 s | 40,1 m | 279 m/s | 0,5 kJ |

**Treffer bis Abschuss** (Streukreis 1 m am Ziel, 40 Versuche, `weapons_diag.gd`):

| Anflug | Median (10–90 %) | Trefferzonen | Ursache |
|---|---|---|---|
| 6 Uhr | 12 (12–13) | Leitwerk 99 % | immer Leitwerk |
| hinten-oben 15° | 15 (13–18) | Leitwerk 80 %, Cockpit 8 %, Motor 6 % | Leitwerk |
| seitlich 90° | 22 (16–28) | Cockpit 45 %, Flügel 40 %, Motor 13 % | Pilot (38/40) |
| frontal | 25 (21–31) | Leitwerk 47 % (!), Motor 21 %, Cockpit 11 % | Leitwerk |
| von oben | 24 (18–31) | Cockpit 41 %, Flügel 25 %, Tanks 22 % | Pilot |

Dass frontal 47 % der Treffer im Leitwerk landen, zeigt die Blockgeometrie: Geschosse, die am Motor vorbeigehen, treffen 5 m dahinter den 1,8 m hohen Block.

**g-Last beim vollen Ziehen** (3 s, `gload_diag.gd`): Arcade 4,3/7,4/11,3/16,0 g bei 110/150/190/230 m/s; Realistisch 4,7/6,5/8,3/10,3 g.

**Spielgefühl (Ist):** Bei 600/min und 2 MG sind es 20 Schuss/s. Bei 20 % Trefferquote (KI-Duelle, Changelog M2) ergibt das 4 Treffer/s, also ≈ 3 s Feuer von hinten. Gezielt auf Motor oder Pilot zu schießen lohnt nicht: Von hinten erreicht man beides nicht, und das Leitwerk fällt immer zuerst.

## 4. Priorisierte Korrekturliste

1. **`damage_mul` anwenden** (Fehler, `projectile_system.gd`). Test: Treffer in den Heckrumpf macht 4 statt 10 Schaden.
2. **Leitwerk-Hitbox als Platten** aus den Leitwerksflächen, Heckkonus als Füllbox (Fehler, `hitbox_set.gd`). Test: Schuss knapp über dem Höhenleitwerk geht vorbei, Flosse/Höhenleitwerk getroffen.
3. **Durchschlag 3,5 m + Rückenpanzer** (×0,3 aus dem hinteren Kegel) (`hitbox_set.gd`). Test: Schuss von hinten durch den Heckrumpf trifft das Cockpit mit Faktor 0,3, von der Seite mit 1,0.
4. **Kadenz 1.150/min, Waffenposition am Modell** (`mg_t1.tres`, `loadout_fighter_t1.tres`). Test: Kadenztest (vorhandener `test_cadence_and_ammo`).
5. **Bruchlast beschädigter Flügel** (`damage_model.gd`, `damage_profile.gd`). Test: Flügel bei 40 % bricht über 7,8 g nach 0,1 s, intakt bei 16 g nicht.
6. **Luftdichte in der Ballistik** (`ballistics.gd`, `projectile_system.gd`, `hit_validator.gd`, `lead_solver.gd`). Test: Geschoss in 3.000 m langsamer gebremst, HitValidator akzeptiert weiterhin.
7. Kleinkram: `late`-Startpunkt, Zittern zeitbasiert, Wrack-Masse/Abbremsen, Hook `ammo_mass_kg()`.

Für andere Bereiche (nur gemeldet):
- **Flugphysik:** kein g-Limit / keine Strukturgrenze. Arcade erlaubt 16 g bei 230 m/s, ein Schutz wie der War-Thunder-Instruktor („g-Last nahe am Strukturlimit langsamer aufbauen“, `recherche_flugphysik_spielgefuehl.md`) fehlt. Die Munitionsmasse (≈ 40 kg) wäre in `aircraft.gd` wie der Treibstoff zu koppeln.
- **Selbsttest:** Phase A/B misst keine Genauigkeit, weil die Maschinen nach `place()` aufnicken. Für eine echte Genauigkeitsmessung müsste die Fluglage festgehalten werden (z. B. Autopilot Höhe halten oder Ziel kinematisch).

## 5. Quellen

- [W1] Wikipedia: Aircraft of the Battle of Britain – Panzerung Spitfire/Hurricane/Bf 109 E, selbstdichtende Tanks, „three or four hits [20 mm] were usually enough to down a fighter“, Hurricane-Bespannung. https://en.wikipedia.org/wiki/Aircraft_of_the_Battle_of_Britain
- [W2] Wikipedia: MG 17 machine gun – 1.200/min, 885–905 m/s, Patrone 35,5 g, Geschoss 11,5 g. https://en.wikipedia.org/wiki/MG_17_machine_gun
- [W3] Wikipedia: ShKAS machine gun – 1.800/min (synchronisiert ≈ 1.650), 775–825 m/s, 9,6 g, I-16: 650 Schuss je Waffe. https://en.wikipedia.org/wiki/ShKAS_machine_gun
- [W4] Wikipedia: MG FF cannon – 520–540/min, 600 m/s (HE 134 g), MG FF/M 700 m/s (Mine 90 g), 60-Schuss-Trommel. https://en.wikipedia.org/wiki/MG_FF_cannon
- [R1] R. Horta, deutsche Flugzeugwaffen (Tabelle): MG 17 1.200/min, 905 m/s; MG FF 540/min, 575/700 m/s; MG 131 930/min. https://rhorta.home.xs4all.nl/jgguns.htm
- [H1] History of War: Browning 0.303in Mark II – 1.150/min, 2.660 ft/s, 0,4 oz. https://www.historyofwar.org/articles/weapons_browning_mkII_raf.html
- [N1] NavWeaps: .50 cal M2 – Flugzeugversion 750–850/min, 866 m/s, Geschoss 48,5 g. https://navweaps.com/Weapons/WNUS_50cal-M2_MG.htm
- [D1] Dinger's Aviation Pages: Bf 109 armament – Rumpf-MG 17 1.000 Schuss, Flügel-MG 17 500 Schuss, MG FF 60 Schuss. https://www.dingeraviation.net/bf109/bf109armament.htm
- [D2] Dinger's Aviation Pages: Aircraft machine guns – Browning .303 1.140/min, M2 750–800/min, ShKAS ≈ 1.800/min, Bf 109 E 1.000 Schuss ≈ 55 s Feuer. https://dingeraviation.net/machineguns/aircraftmguns.htm
- [A1] The Armory Life: Guns of the Battle of Britain – Browning 1.150/min, Konvergenz 400 → 250 yd (Erfolg 39 → 53 %), Blenheim-Versuche 1939 (Durchschlag 4 mm, Brandwirkung ≈ 1:10), Bomber mit > 100 Treffern. https://thearmorylife.com/guns-of-the-battle-of-britain
- [P1] PPRuNe: WW2 British .303 guns – ≈ 300 Schuss je Waffe, ≈ 15 s Feuer, Konvergenz 250–300 yd. https://www.pprune.org/military-aviation/194046-ww2-british-303-guns-just-boring-trivia.html
- [P2] PPRuNe: Limit Load Factors WW2 Fighters – Spezifikation F.7/30: Lastvielfaches 9,0. https://www.pprune.org/archive/index.php/t-443530.html?pda=1
- [M1] R. L. McCoy: MC DRAG – A Computer Program for Estimating the Drag Coefficients of Projectiles, BRL-TR-02293 (1981). https://apps.dtic.mil/sti/pdfs/ADA098110.pdf
- [G1] E. Gustin, Usenet rec.aviation.military 1998 (zitiert bei yarchive): B-17 ≈ 20 Treffer 20 mm, 3 Treffer 30 mm. https://www.yarchive.net/mil/german_aircraft_cannon.html

## 6. Korrekturen (umgesetzt)

| Nr. | Änderung | Dateien | Test |
|---|---|---|---|
| 1 | `damage_mul` der Trefferbox wird im Schaden angewendet | `weapons/projectile_system.gd` | `test_damage_mul_and_density` (Heckrumpf 4,0 statt 10) |
| 2 | Leitwerk als Höhenleitwerks- und Flossenplatte (aus `htail_*`/`vtail`) plus Heckkonus-Füllbox; Durchschlag aus Rumpf-Füllboxen bis 4,5 m (sonst 1,0 m); Rückenpanzer Cockpit ×0,3 aus dem hinteren Kegel (cos > 0,6) | `vehicles/aircraft/damage/hitbox_set.gd` | `test_tail_plates_and_rear_armor` |
| 3 | Kadenz 600 → 1.150/min; Waffenposition = Modell-Marker (±2,35; −0,068; −0,89); `structure_hp` 320 → 280 | `weapons/data/mg_t1.tres`, `loadout_fighter_t1.tres`, `weapon_def.gd`, `damage_profile.gd` | `test_cadence_and_ammo` (38 Schuss/s) |
| 4 | Bruchlast beschädigter Flügel: unter 75 % HP bricht er über 5–12 g (linear), wenn die Last 0,1 s anliegt; negative g zählen doppelt, intakt kein Bruch | `damage_model.gd`, `damage_profile.gd` | `test_wing_overload_break` (40 % → 8,7 g) |
| 5 | Luftdichte: k ∝ ρ(h) beim Abschuss (`Ballistics.k_at`), gleich in ProjectileSystem, HitValidator (`Shot.k`) und LeadSolver | `ballistics.gd`, `projectile_system.gd`, `hit_validator.gd`, `lead_solver.gd` | `test_damage_mul_and_density` (3.000 m: 668 statt 625 m/s nach 0,5 s) |
| 6 | Erster Schuss nach dem Abzug ohne Vorlauf (`late` = 0). Vorher galt er als einen Tick zu früh abgegeben, bei 1.150/min lehnte der HitValidator Folgeschüsse als CADENCE ab. Der `late`-Versatz ist jetzt nur `v0·dir·late` | `weapon_system.gd` | `test_aircraft_fires_on_box` 20/20 |
| 7 | Wrack: Masse vom Flugzeug, k = 5 (v_end ≈ 70 m/s), Luftbremsung ≤ 2 g; Zittern des Verwundeten zeitbasiert; Hook `WeaponSystem.ammo_mass_kg()` (`WeaponDef.round_mass` 40 g) | `wreck.gd`, `damage_model.gd`, `weapon_system.gd`, `weapon_def.gd` | – |

**Angepasste Tests** (brechen nur durch die korrigierte Geometrie bzw. Physik):
- `test_fallback_hitboxes` zählt jetzt Zonen statt Boxen.
- `test_service_markers_positions` (art) und die Selbsttest-Diagnose erwarten 11 statt 9 Boxen.
- `test_cadence_and_ammo` leitet den Sollwert aus der Kadenz ab.
- `test_lead_crossing_target` und `test_hit_moving_box_high_speed` rechnen mit k in Schützenhöhe.
- `test_tolerance` nimmt den echten Trefferpunkt statt des Segmentanfangs, der vorher zufällig im Rahmen lag.

**Vorher/Nachher** (Treffer bis Abschuss, Median, Streukreis 1 m, `weapons_diag.gd`):

| Anflug | vorher | nachher | Ursache nachher |
|---|---|---|---|
| 6 Uhr | 12 | 37 | Leitwerk 30, Zelle 10 (Cockpit 27 % der Treffer, gepanzert) |
| seitlich | 22 | 30 | Pilot 27, Zelle 13 |
| frontal | 25 | 29 | Zelle, Motor aus |
| von oben | 24 | 33 | Zelle, Pilot |
| gezielt Cockpit seitlich | – | 12 | Pilot |
| gezielt Motor seitlich / frontal | – | 12 / 16 | Motor aus |

Spielgefühl: Die Feuerdauer sinkt von 50 auf 26 s, die Feuerrate je Flugzeug steigt von 20 auf 38 Schuss/s. Ein Abschuss dauert in Sekunden Feuer ungefähr so lange wie vorher (≈ 3–5 s bei 20 % Trefferquote). Der Munitionsverbrauch je Abschuss steigt aber etwa auf das 2,5-Fache (Wirtschaft/Bunker beachten). Gezieltes Schießen auf Motor oder Pilot lohnt jetzt: Es braucht etwa ein Drittel der Treffer.

**Stellschrauben:** `HitboxSet.REAR_ARMOR_MUL`/`PENETRATION_FUSELAGE`/`FILLER_MUL`, `DamageProfile.structure_hp`, `wing_weak_below`/`wing_break_g_min|max`, `WeaponDef.rpm`/`damage`.

**Teststand:**
- Weapons 17/17 und Damage 34/34 grün (einzeln).
- Fast-Suite 284/287. Rot waren der angepasste Boxenzähler (inzwischen grün) und zwei Leistungstests unter Last der geteilten Maschine: `test_perf_1000_shots_8_targets` ist einzeln grün mit 3,3 ms, `test_query_cost` gehört zum Wetter-Bereich.
- airfield (all) 17/17, ai_ground (all) 29/29.
- KI-Tests (all) 11/13, die beiden Duell-Tests sind rot. Zum Vergleich gleicher Rechner, Code von main 7a170bc:

| Duelle (10 Seeds, 180 s, Ziel ≥ 8) | main | audit-waffen |
|---|---|---|
| flach | 6 (rot) | 7 (rot) |
| Hügel | 8 | 7 (rot) |
| Treffer/Schuss flach | 19,2 % | 19,6 % |
| Veteran : Rekrut | – | 9 : 0 (grün) |

Insgesamt gibt es 14 Abschüsse wie vorher. Der Flach-Test war schon auf main rot, im Hügel-Test fehlt jetzt ein Abschuss. Ursache ist die höhere TTK von 6 Uhr (12 → 37 Treffer); die doppelte Kadenz gleicht das nur zum Teil aus. Stellschraube ohne Bruch der Belege: `structure_hp` 280 → 250 (6 Uhr Median 34, dann bricht öfter die Zelle). Der Rückenpanzer 0,3 → 0,5 brachte fast nichts (35). Der Selbsttest wurde nach den Änderungen nicht mehr ausgeführt.

**Offen:** KI-Duelle (slow) mit neuer TTK und Kadenz nachmessen; g-Limit/Strukturschutz in der Flugphysik (16 g in Arcade); Munitionsmasse in `aircraft.gd` koppeln; Flügel-Hitbox dünner; Kühler als eigene Zone; Rückstoß erst bei Kanonen.
