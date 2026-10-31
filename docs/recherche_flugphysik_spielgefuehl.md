# Recherche: Flugphysik und Spielgefühl beim Hochziehen und Strömungsabriss

Stand: 31.10.2026. Anlass: Der Tester meldet, dass der Abriss beim Hochziehen zu früh kommt. Bezug: Tier-I-Jäger, 2.500 kg, 700 kW. Abgeglichen mit `aero_surface.gd`, `flight_assist.gd`, `prop_engine.gd` und `build_fighter_t1.gd`.

## Kurzfazit

Der Code enthält zwei konkrete Ursachen:

1. **Arcade:** Der Stall-Schutz in `flight_assist.gd` begrenzt den **absoluten** Höhenruderausschlag, nicht den Ausschlag über der Trimmung. Er setzt schon bei etwa 7,5° Rumpf-AoA ein (13° − 2,5° − 3°). Um 10° AoA zu halten, braucht man etwa 0,4 Höhenruder. Der Limiter erlaubt bei 10° nur `0,05 − 0,6·q`. Nachgerechnet bleibt das Flugzeug am Rand des Eingriffsfensters bei etwa **7–7,5° AoA** hängen (CL ≈ 0,95), obwohl der Flügel erst bei 13° abreißt (CL ≈ 1,36). Das Flugzeug „sackt durch“, bevor es wirklich abreißt. Das wirkt wie ein zu früher Abriss.
2. **Realistisch:** Die Auftriebskurve hat einen **Abriss mit Abbruchkante**. Sie bleibt bis zum Abrisswinkel linear. Danach fällt CL innerhalb von 4° (`STALL_BLEND`) von 1,36 auf etwa 0,45 (Platte: 0,72·sin 2x), also um rund 65 %. Echte Jäger dieser Zeit runden die Kurve vor CL_max ab und behalten danach noch etwa 70–85 % ihres Auftriebs.

Die Energiebilanz ist nicht das Problem. Nach dem Modell steigt das Flugzeug mit etwa 17 m/s bei 270 km/h. Der Nullwiderstand ist eher zu niedrig (siehe 4).

## 1. Typische Auftriebskurven (Jäger, späte 1930er)

- **CL_max ohne Klappen bei niedriger Machzahl:** Spitfire ≈ 1,36, Bf 109 ≈ 1,4, Fw 190 ≈ 1,35–1,45, P-51 ≈ 1,4. Bei M 0,4–0,5 sinkt der Wert auf 1,05–1,2. In NACA-Messungen der Spitfire V kam CL_max im Kurvenflug nur auf **1,23**.
- **Abrisswinkel:** Der Flügel (NACA 230xx/22xx, Streckung 6–7) reißt bei etwa 15–17° Profil-AoA ab. Der Rumpf-AoA bei Abriss liegt wegen der Einstellwinkel 1–2° niedriger, also bei etwa **13–16°**. Für die P-51 nennen Quellen etwa 16° bei CL ≈ 1,6.
- **Auftriebsanstieg:** 3D etwa 4,4–4,8 /rad (≈0,08/°). Der Nullauftriebswinkel liegt bei −1,5° bis −2,5°.
- **Abrissgeschwindigkeit:** Bf 109 E: 152–159 km/h IAS ohne Klappen, etwa 147 km/h in Landekonfiguration (IL-2-Daten, Flächenbelastung ≈ 160 kg/m²). Für 2.500 kg auf 17,2 m² und CL 1,36 ergibt sich **≈ 148 km/h**. Das passt.
- **Nach dem Abriss:** Gute Muster melden den Abriss mit Buffet etwa **8–16 km/h (5–10 mph) vorher** an (NACA-Bericht zur Spitfire V). Danach folgen leichtes Nicken und Gieren, ab und zu kippt ein Flügel weg. Ein harter Abbruch ist das nicht. In schnellen Kurven mit zu viel gezogenem Höhenruder rollt die Spitfire dagegen plötzlich weg.
- **Klappen:** ΔCL_max ≈ +0,4 bis +0,6 (Spaltklappe). Der Abriss-AoA sinkt dabei um 1–3°.
- **Glättung in Spielen:** Spiele definieren die Kurve meist als Kurve oder Tabelle (vazgriz: `AnimationCurve`; JSBSim: Tabelle CL(α)). Ab etwa 70–80 % von CL_max wird der Verlauf abgerundet. Nach dem Maximum folgt ein flacher Abfall auf ein Plateau, erst bei 25–45° geht er in die ebene Platte über. Khan & Nahon verwenden für dicke Profile einen tanh-Übergang `f = 0,5·(1 − tanh(a·(α − α_s)))` statt eines harten Umschaltens. JSBSim betont, dass der Abriss vor allem den **Widerstand** stark erhöht. Der Auftrieb bricht dagegen nicht völlig weg.

## 2. Häufige Fehler, die einen frühen oder harten Abriss verursachen

| Fehler | Status bei uns |
|---|---|
| AoA ohne Rotationsanteil `v + ω × r` | korrekt (`flight_model.gd:56`) |
| Kein Abwind am Leitwerk (ε ≈ 0,35–0,45·α) | **fehlt**. Das Leitwerk ist dadurch zu stabil, man braucht mehr Höhenruder, und der Limiter (siehe oben) schlägt stärker durch |
| Limiter regelt den absoluten Ausschlag statt das Delta zur Trimmung | **Hauptursache Arcade** |
| Lineare Kurve bis CL_max, dann Kliff | **Hauptursache Realistisch** |
| Ruderwirkung bzw. Nickrate zu hoch, AoA schießt über | möglich: volles Höhenruder ergibt Δα ≈ 17,7°, die Trimmung landet bei ≈ 18° > 13° Abriss |
| Fehlende Nickdämpfung | vorhanden über das Leitwerk; kein Cmq des Flügels, kein Cm_α̇ |
| Induzierter Widerstand zu hoch | unkritisch (e = 0,8, Streckung 7) |
| Schub fällt zu stark mit v | unkritisch (≈ 9 kN bei 200 km/h, ≈ 6,5 kN bei 300 km/h). Aber: Leistung ∝ σ ohne Lader, deshalb in 3–4 km Höhe 30–40 % zu wenig |
| Querruder am Außenflügel: Ausschlag nach unten verschiebt den Abriss | Klappen heben `s_hi` nur um 0,5·Δα. Ein Querruderausschlag nach unten bei hohem AoA lässt die Spitze früher abreißen (realistisch, aber hart) |
| Schwerpunkt zu weit hinten | nein (Flügel-t/4 liegt 5 cm hinter dem SP, Leitwerksvolumen ≈ 0,6) |

## 3. Wie Spiele das Hochziehen angenehm machen

- **War Thunder (Instruktor):** Bei Mouse-Aim hat der Instruktor die volle Kontrolle. Er verhindert kritischen AoA, Abriss und Trudeln und baut die g-Last nahe am Strukturlimit langsamer auf. In Arcade schützt er auch bei manueller Steuerung, in Realistic nur bei „vereinfachter“ Steuerung, in Simulator gar nicht. Spieler beschreiben, dass Mouse-Aim bis an den maximal erlaubten AoA zieht und dabei Energie verliert. Der Limiter sitzt also knapp unter CL_max, nicht weit davor.
- **Tiny Combat Arena (why485):** Die Maussteuerung arbeitet über ein AoA-Modell, das nicht abreißen kann. Kondensfahnen über dem Flügel erscheinen kurz vor dem kritischen AoA als Vorwarnung. Leitlinie: „Es soll sich realistisch anfühlen, nicht realistisch sein.“
- **Ace Combat:** Abriss erst bei sehr niedriger Fahrt (≈ 120 km/h). Er ist im Kern ein Fahrtverlust und keine Aerodynamik.
- **Limiter als Nickmoment (Modding-Praxis Strike Fighters):** Ein AoA- oder g-Limiter wirkt als weich einsetzendes Nickmoment nach unten, gestaffelt in mehreren Stufen. Zielwert für das Restpendeln: 2–3° AoA bzw. 0,2–0,3 g.
- **vazgriz:** Ein g-Limiter skaliert das Steuersignal so, dass die vorhergesagte Last unter dem Limit bleibt. Dazu kommen Drehraten- und Beschleunigungsgrenzen je Achse. (Aus dem Gedächtnis zusammengefasst; der Blog war für diese Recherche nicht abrufbar.)
- **Vorwarnung:** Buffet (Kamera- und Knüppelzittern), Windgeräusch, Kondensfahnen und ein HUD-Ton, alle ab etwa 80–85 % von CL_max bzw. 2–3° vor dem Abriss.

## 4. Energie-Referenz

- **Bf 109 E-7** (2.614 kg, ≈ 1.000 PS): Steigrate 14 m/s am Boden, 13,3 m/s in 3.000 m, 7 m/s in 6.000 m. Vollkreis in 20,5 s bei 270 km/h.
- **Unser Modell:** 270 km/h bei ≈ 7,2 kN Schub, CD ≈ 0,026, Widerstand ≈ 1,5 kN, das ergibt **≈ 17 m/s**. Zielwert: 13–15 m/s. Der Nullwiderstand ist zu niedrig (f ≈ 0,28 m² statt 0,38–0,42 m², also CD0 0,016 statt ≈ 0,023).
- **Hochziehen aus 450 km/h in einen senkrechten Steigflug:** Ohne Widerstand bringt das etwa 800 m Höhe (v²/2g). Real sind es mit Widerstand eher 500–650 m. Bei Dauerlast 4–5 g verliert ein solcher Jäger etwa 15–25 km/h pro Sekunde.

## 5. Empfehlungen

1. **Limiter auf Delta umstellen:** Erst den Trimmausschlag für den Ziel-AoA schätzen, `elev_trim(α) ≈ k_t·α` mit k_t ≈ 0,042/° (online lernen oder aus der Feed-Forward-Rechnung), dann `max_elev = elev_trim(α_lim) + K·(α_lim − α) − D·q`, mit K ≈ 3/rad und D ≈ 0,3 s.
2. **Limit-AoA hochsetzen:** Statt `STALL_MARGIN` 2,5° besser 1,0–1,5° verwenden. Das Eingriffsfenster auf 1,5° statt 3° verkleinern. Ziel: Arcade nutzt ≥ 90 % von CL_max.
3. **Kurvenform weich machen:** Statt linear plus Smoothstep `CL = CL_max·tanh(CL_α·x / CL_max)` bis s_hi. Danach in 6–8° (`STALL_BLEND`) auf ein Plateau von 0,75·CL_max abfallen und erst ab 30–40° in die Platte übergehen. Abbruch abmildern: `POST_STALL_LIFT` 0,72 → 1,0–1,1.
4. **Widerstand im Abriss betonen:** `cd += 0,1–0,2·t`. Das kostet spürbar Energie, ohne den Auftrieb wegbrechen zu lassen.
5. **Abwind am Leitwerk:** `α_tail = α_body − ε`, mit `ε = ε0 + dε/dα·α_wing`, dε/dα ≈ 0,4 (≈ 2·CL/(π·AR)). Anschließend die Trimmung und k_t neu messen.
6. **Kurzzeit-Nickdämpfung:** zusätzlich `M = −Cmq·q·c̄/(2V)·q̄·S·c̄`, Cmq ≈ −8 bis −12, sowie ein α̇-Term, damit der AoA beim schnellen Ziehen nicht überschießt.
7. **Realistic-Modus:** Volles Höhenruder auf Δα ≈ 13–14° begrenzen (`max_deflection` 30° → 22–24°). Alternativ die Knüppelkurve mit Exponent 1,5–2 formen.
8. **Querruder bei hohem AoA:** `s_hi` an der Flügelspitze nicht mit dem Ruder verschieben, oder im Arcade-Modus über 0,8·α_stall das Querruder auf 50 % begrenzen.
9. **Buffet:** Ab `α > α_stall − 3°` bzw. CL > 0,85·CL_max Kamera- und Rumpfzittern einsetzen, Amplitude ∝ (α − α_on)/3°, 8–14 Hz, plus Geräusch. In Arcade etwas früher.
10. **Energie kalibrieren:** `fuselage_drag_area` 0,10 → ≈ 0,20 (oder Profil-CD0 0,008 → 0,011). Leistung bis zur Volldruckhöhe (≈ 4–4,5 km) konstant halten, darüber ∝ σ. Testfälle: Steigen 13–15 m/s bei 270–280 km/h, Abriss bei 148 ± 5 km/h, Vollkreis 19–21 s.
11. **Regressionstest:** In `test_runner.gd` die AoA bei Arcade-Vollausschlag protokollieren und als Ziel `α ≥ α_stall − 1,5°` setzen.

## Quellen

- https://wiki.warthunder.com/Instructor/How_the_instructor_works
- https://forum.warthunder.com/t/suggestion-a-g-or-aoa-limiter-key/84221
- https://il2sturmovik.com/museum/fighters/bf-109-e-7/
- https://forum.il2sturmovik.com/topic/25336-another-look-at-turn-times/page/8/
- https://forum.dcs.world/topic/101588-turn-performance-and-lift-coefficient
- https://digital.library.unt.edu/ark:/67531/metadc61033/m2/1/high_res_d/19930092581.pdf (NACA ACR L-353, Spitfire VA)
- https://escholarship.mcgill.ca/downloads/dj52w7317 (Khan, Dissertation zum Modell von Khan & Nahon 2015)
- https://github.com/kurtdekker/Aircraft-Physics (Fork von gasgiant/Aircraft-Physics)
- https://wiki.flightgear.org/images/cache/1/1b/JSBSim_Aerodynamics.html
- https://why485.itch.io/tiny-combat-legacy-flight-model-test
- https://www.skywardfm.com/post/interview-why485-developer-of-tiny-combat-arena-part-2
- https://acecombat.wiki.gg/wiki/Stalling
- https://combatace.com/forums/topic/98849-g-and-aoa-limiters/
- https://vazgriz.itch.io/flight-sim-part-1
- https://godotengine.org/asset-library/asset/edit/23008 (addmix Godot Aerodynamic Physics)
- https://www.physicsforums.com/threads/propellor-thrust-calculations-for-p-51-mustang-simulation.302688/
