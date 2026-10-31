# Diagnose: „Strömungsabriss kommt beim Hochziehen zu früh“

Messung: `game/tests/diag/stall_diag.gd` (+ `diag_assist.gd`), 41 CSVs in `game/tests/diag/out/`. Aufruf: `godot --headless --path . --fixed-fps 60 --script res://tests/diag/stall_diag.gd [-- --no-protect | --alt-limiter]`. Am Produktionscode wurde nichts geändert.

## Ursachen, nach Wahrscheinlichkeit sortiert

**1. Arcade-Stall-Schutz greift zu früh und zu hart (Hauptursache, Arcade + Mouse-Aim).**
`FlightAssist.apply()`: Der Begrenzer schaltet sich schon bei `aoa > limit − 3°` ein, also ab 7,5° Rumpf-AoA (Abriss bei 13°, Grenze 10,5°). Dort lässt er nur `max_elev = −over·6 − q·0,6 ≈ 0,31` zu. Das ist genau das Ruder, mit dem 7,7° gehalten werden. Gemessen:
- Mouse-Aim 30°/60° und schneller Maus-Ruck bei 362 km/h: AoA max. 9,1°, Mittelwert 7,7°. Wurzel-CL im Mittel 0,94, möglich wären ≈1,36 (ca. 70 %). Kein Abriss.
- Langsames Hochziehen (c): 1 g lässt sich nur bis **194 km/h** halten. Der echte 1-g-Abriss liegt bei ≈150 km/h. Das Flugzeug „hängt“ also ~45 km/h zu früh, und es fühlt sich an wie ein Abriss.
- Das Ein- und Ausschalten an der 7,5°-Schwelle lässt das Höhenruder mit **4,8 Hz** zwischen 1,0 und ≈0 hin- und herspringen. Die G-Last pendelt dabei zwischen 2,5 und 3,8 g (Standardabweichung 0,50). Das ist das „komische“ Gefühl.
- Gegenprobe ohne Schutz: Mouse-Aim 60° führt zum vollen Abriss (AoA 20,5°). Der Schutz ist also nötig, nur falsch eingestellt.
- Mein Prototyp eines stetigen Begrenzers (nur im Diagnose-Skript): AoA max. 10,3°, mittlere G-Last 3,43 statt 2,96, G-Standardabweichung 0,26, 1 g bis 177 km/h.

**2. Realistisch: zu viel Höhenruder-Wirkung, der AoA schießt über.**
Bei voller Taste (Rampe 0,25 s) und 360 km/h: Abriss nach 0,35 s bei 15,7° AoA und 4,4 g, Nickrate 87°/s, AoA schießt bis 24,6°. Schon der halbe Stick erreicht 13,9° und streift den Abriss (7 %). Das Höhenleitwerk hat ±30° Ausschlag und 45 % Rudertiefe, das entspricht ≈17,7° wirksamem Anstellwinkel. Damit reicht schon ein halber Ausschlag bis an den Abriss.

**3. Kein Rechenfehler gefunden.** Geprüft und in Ordnung:
- AoA mit v + ω×r, Vorzeichen, Bezugsachsen, Grad/Rad (`body_stall_aoa` = 15° − 2° = 13°)
- Auftriebs- und Widerstandsrichtung, Vorzeichen des Höhenruders
- Flächen: Flügel 17,2 m², Höhenleitwerk 3,6 m²
- Schwerpunkt bei 0, Trägheit (8000/13000/6000)
- Reihenfolge des Abrisses: Wurzel und Mitte zuerst, Flügelspitzen 0,02 s später (Schränkung wirkt). Das Höhenleitwerk reißt nie ab.

**4. Energie und Fahrwerk: unauffällig.** Realistisch, Vollgas, Fahrt gehalten: **15,6 m/s bei 243 km/h**, 15,5 m/s bei 268 km/h. Das entspricht dem Zielwert. Bei 20° Nicklage stellen sich ≈215 km/h und 11 m/s ein, in Arcade und Realistisch gleich. Das Fahrwerk (`landing_gear.gd`) hat **null Luftwiderstand**, es wirkt nur bei Bodenkontakt. Es kostet beim Steigen also nichts.

**5. Nebenbefund.** Wer in Arcade lange voll zieht, steigt bis über 80° Nicklage, bis die Fahrt fast null ist. Dann kippt das Flugzeug über das Heck ab (Prototyp: v → 15 km/h). Der AoA-Schutz kann das nicht abfangen.

## Fix-Vorschläge
1. `game/vehicles/aircraft/physics/flight_assist.gd`, `apply()`, Stall-Schutz: Die Schwelle `if over > -3°` entfernen und das Ruder stetig begrenzen:
   `max_elev = elev_trim(limit) + (limit − aoa)·4 − q·0,6`, mit `elev_trim ≈ 0,04/° · (limit°+0,5)` (gemessen). Besser wäre ein neuer Parameter `AircraftData.elevator_per_aoa`.
   `STALL_MARGIN` von 2,5° auf ≈1,0–1,5° senken.
2. Optional in Arcade: unter ≈150 km/h die Grenze für die Nicklage senken oder die Nase herunternehmen (Schutz gegen das Abkippen aus Punkt 5).
3. Realistisch (Zielwerte von der Recherche abwarten): in `fighter_t1.tres` bei `htail_*` `max_deflection_deg` von 30 auf ≈20 senken oder `flap_fraction` von 0,45 auf 0,30. Alternativ in `FlightAssist` (REALISTIC) den Höhenruder-Ausschlag oberhalb ≈300 km/h mit ~(v_ref/v)² abschwächen, wie eine Knüppelkraft. Ziel: Nickrate ≤ 40–50°/s, voller Ausschlag nahe Eckgeschwindigkeit.
4. Einziehfahrwerk (geplant): Fahrwerkswiderstand ergänzen, nur bei ausgefahrenem Fahrwerk (CdA ≈ 0,05–0,1 m²), sonst wird der Start zu leicht.
5. Regressionstest: Arcade mit Mouse-Aim 60° bei 360 km/h soll AoA ≥ 10° erreichen, der Abriss soll unter 0,3 bleiben und die G-Standardabweichung unter 0,3.
