# Recherche Windphysik (M3.9)

Ziel: ein Windmodell für Flugkern, das sich realistisch anfühlt (Stil B), in GDScript pro Flugzeug
und Physik-Tick billig ist (< 0,05 ms) und deterministisch aus Seed, Ort und Zeit folgt (später
Multiplayer: Server und Clients rechnen dasselbe). Ausgangspunkt ist M3.8 (`core/weather.gd`):
fester Grundwind je Partie, Potenzgesetz mit Höhe, Böen als Summe weniger Sinuswellen (±25 %).

Zahlen ohne eigene Quelle in der Liste sind Lehrbuchwerte (Stull, *An Introduction to Boundary
Layer Meteorology*; Panofsky & Dutton; Wieringa). Sie sind als solche markiert (LB).

---

## 1. Atmosphärische Grenzschicht

### 1.1 Logarithmisches Windprofil, Rauigkeit
In der Bodenschicht (unterste ~50–100 m, neutral geschichtet) gilt

    U(z) = (u* / κ) · ln((z − d) / z0),   κ ≈ 0,4

mit Schubspannungsgeschwindigkeit u*, Rauigkeitslänge z0 und Verdrängungshöhe d (bei Wald
≈ 0,7 × Baumhöhe, LB). Umrechnung zwischen zwei Höhen:
U(z2) = U(z1) · ln((z2−d)/z0) / ln((z1−d)/z0) [Q3, Q4].

Rauigkeitslängen (Davenport/Wieringa-Klassen) [Q3, Q4]:

| Untergrund | z0 (m) | Spiel |
|---|---|---|
| offenes Wasser (≥ 5 km Anlauf) | 0,0002 | Fluss (schmal → in der Praxis Ufer dominiert, ~0,001–0,005) |
| Watt, Schnee, kahl | 0,005 | Fels oberhalb ~800 m |
| kurzes Gras, wenige Hindernisse | 0,03 | Wiese, Flugplatz (Referenz) |
| niedrige Feldfrüchte | 0,10 | Felder |
| hohe Feldfrüchte, verstreute Hindernisse | 0,25 | – |
| Parklandschaft, Büsche | 0,5 | Waldrand, Hecken |
| Wald, Vorstadt | 1,0 | Wald (dazu d ≈ 10 m) |

Folgerung: Über Wald ist der Wind in Baumwipfelhöhe deutlich schwächer, aber **u\* und damit
die Turbulenz sind größer**. Über Wasser ist der Wind bodennah stärker und ruhiger.

**Mischungshöhe ("blending height")**: Bei wechselnder Oberfläche passt sich der Wind unterhalb
von ~50–100 m dem lokalen Untergrund an, darüber sieht er eine flächengemittelte Rauigkeit (LB,
Wieringa/Mason). Praktisch: Wind in z_b ≈ 60 m ist überall gleich (nur großräumig variabel),
darunter gilt das Log-Profil mit lokalem z0. Das ist billig und physikalisch sauber.

### 1.2 Oberhalb der Bodenschicht, Gradientwind
Bis zur Grenzschichtobergrenze (tags 1–2 km, nachts 100–500 m [Q11]) nimmt der Wind weiter
zu und erreicht dann ungefähr den geostrophischen bzw. Gradientwind. Faustregel aus der
Pilotenausbildung: **Bodenwind über Land ≈ 50 % der Stärke des Windes in 2.000 ft und ~30°
zurückgedreht; über Wasser ≈ 70 % und ~10°** [Q8]. Das Log-Profil über z0 = 0,03 m ergibt von
10 m bis 1.000 m den Faktor ~1,8, also gut verträglich.

Tagsüber (durchmischte Grenzschicht) ist das Profil oberhalb der Bodenschicht fast konstant
(Potenzgesetz-Exponent ~0,1), nachts (stabil) stark gescherter Anstieg (Exponent 0,3–0,5),
der Bodenwind schläft ein, und darüber kann sich ein **Low-Level-Jet** mit übergeostrophischem
Wind in 100–500 m bilden [Q11]. Abends bricht die Turbulenz "innerhalb einer Stunde"
zusammen [Q11].

### 1.3 Drehung mit der Höhe (Ekman-Spirale)
Reibung bremst den Wind, die Corioliskraft wird schwächer, der Bodenwind dreht nach links
(Nordhalbkugel). Mit der Höhe **dreht der Wind nach rechts (veering)**: über Land 20–40°
zwischen Boden und Grenzschichtoberkante, über Wasser ~10° [Q7, Q8]. Die meiste Drehung
passiert in den untersten paar hundert Metern. Beim Sinkflug sieht der Pilot daher eine
Linksdrehung und Abnahme des Windes ("backing on approach") [Q7].

### 1.4 Tagesgang
- Morgens: Bodeninversion wird aufgezehrt, Wind frischt am Boden auf.
- Mittag/Nachmittag: konvektive Grenzschicht, böig, Thermik, Böenfaktor am höchsten, Wind am
  Boden am stärksten.
- Abend/Nacht: Turbulenz bricht zusammen, Bodenwind flaut ab, Scherung über der Inversion,
  ggf. Low-Level-Jet [Q11].

Flugkern hat (Stand M3.8) **keine Tageszeit**: die Sonne steht fest bei ~30° Höhe
(Nachmittag). Das Modell bekommt deshalb einen Stabilitätsparameter (0 = stabile Nacht …
1 = kräftige Konvektion), der heute fest "Nachmittag, mäßig konvektiv" ist und später an die
Sonne gekoppelt werden kann.

---

## 2. Turbulenz und Böen

### 2.1 Dryden-Modell (MIL-F-8785C, MIL-HDBK-1797)
Spektren (Ω räumliche Kreisfrequenz, V Fluggeschwindigkeit) [Q1, Q2]:

- längs: Φu(ω) = (2σu²Lu/πV) · 1/(1 + (Lu ω/V)²)
- quer/vertikal: Φv,w(ω) = (σ²L/πV) · (1 + 3(Lω/V)²)/(1 + (Lω/V)²)²
- Rollen: Φp = (σw²/(V Lw)) · 0,8 (πLw/4b)^(1/3) / (1 + (4bω/πV)²)
- Nicken/Gieren: Φq,r = (ω/V)²/(1 + (4b bzw. 3b · ω/πV)²) · Φw,v

Erzeugt wird die Turbulenz klassisch durch weißes Rauschen durch Formfilter (rationale
Übertragungsfunktionen, daher bei Simulationen beliebt; von Kármán ist "genauer", aber
irrational und nur näherungsweise filterbar) [Q1, Q5].

**Niedrige Höhe (< 1.000 ft, h in ft)** [Q1]:
- Lw = h, Lu = Lv = h / (0,177 + 0,000823 h)^1,2
- σw = 0,1 · W20, σu/σw = σv/σw = 1/(0,177 + 0,000823 h)^0,4
- Achsen: längs = mittlerer Wind, vertikal = senkrecht (erdfest)
- W20 = Wind in 20 ft (6 m): leicht 15 kn, mäßig 30 kn, schwer 45 kn.

**Mittlere/große Höhe (> 2.000 ft)**: L = 1.750 ft (533 m), isotrop, σ nach
Überschreitungswahrscheinlichkeit (Tabelle MIL-F-8785C Fig. 7; JSBSim: Index 1–7,
z. B. Index 1 → 3,2 ft/s in 500 ft, 0 ab 15.000 ft) [Q1, Q6]. Dazwischen linear
interpoliert.

Beispielwerte (umgerechnet, m):

| Höhe über Grund | Lw | Lu | σu/σw |
|---|---|---|---|
| 3 m | 3 m | 24 m | 2,0 |
| 10 m | 10 m | 63 m | 1,9 |
| 30 m | 30 m | 140 m | 1,7 |
| 100 m | 100 m | 230 m | 1,4 |
| 300 m | 300 m | 305 m | 1,0 |
| ≥ 600 m | 533 m | 533 m | 1,0 |

**Physikalische Lesart (Bodenschicht)**: σu ≈ 2,4–2,5 u\*, σv ≈ 1,9 u\*, σw ≈ 1,25 u\*
(Panofsky & Dutton, LB; Wieringa c = 2,5 [Q5]). Mit dem Log-Profil folgt die
**Turbulenzintensität σu/U ≈ 1/ln(z/z0)** [Q5] – über Gras in 10 m ≈ 17 %, über Wasser ≈ 9 %,
über Wald (in 10 m über d) ≈ 43 %. Das passt zu Dryden (σu/W20 ≈ 0,19 in 10 m) und liefert
gleich die Abhängigkeit vom Untergrund.

### 2.2 Böenfaktor
G = Umax/U (3-s-Böe gegen 10-min-Mittel). Wieringa: ⟨G⟩ ≈ 1 + (1,42 + 0,301 ln(990/(U t) − 4))
/ ln(z/z0) [Q5]. Über kurzem Gras gemessen G ≈ 1,43–1,55 [Q5]. Typische Spanne 1,2 (Wasser) bis
1,8 (raues Gelände) [Q5]. Für Spiel-Kalibrierung: Böen bis etwa +50 % über Gras, +25 % über
Wasser, +80 % über/hinter Wald.

### 2.3 Diskrete Böen (1−cos)
MIL-Spec und JSBSim kennen zusätzlich eine deterministische "1−cos"-Böe (Anstieg, Halten,
Abfall) [Q6]. Sie ist für Zulassungsrechnungen gedacht; in einem kontinuierlichen,
intermittierenden Turbulenzfeld entstehen solche Einzelböen ohnehin. **Weglassen.**

### 2.4 Räumliche Kohärenz, Taylor-Hypothese
Die Dryden-Spektren beschreiben eine *räumliche* Struktur, die das Flugzeug mit V durchfliegt
("frozen turbulence", Taylor). Ein eingefrorenes Feld, das mit dem mittleren Wind treibt, ist
genau diese Annahme: Ein Flugzeug mit 100 m/s erlebt die Frequenz Ω·V, ein Windsack am Boden
dieselben Wirbel, nur langsamer (mit U). Zwei Flugzeuge nahe beieinander spüren dieselbe Böe,
Windsack und landendes Flugzeug passen zusammen. Deterministisch ist es auch.

### 2.5 Rotationsanteile
Für Spannweiten ~10 m und Längen-Skalen ≥ 30 m sind p_g (Rollen durch unterschiedlichen
Aufwind an den Flügelspitzen) die spürbarste Komponente (Flügelwackeln in Bodennähe);
q_g und r_g sind klein [Q1]. Umsetzbar als Differenz des Vertikalwindes zwischen den
Flügelspitzen (statt eigenem Filter).

---

## 3. Windscherung und Gelände

### 3.1 Scherung, Windsprünge
- Scherung in der Bodenschicht: Log-Profil (siehe oben); beim Landeanflug nimmt der
  Gegenwind ab → Fahrt sinkt in den letzten 50 m um ein paar m/s. Reales, bekanntes Phänomen
  (Gradient, Segelflieger lernen "Fahrtzuschlag bei Wind").
- Nächtliche Inversion: abrupter Windsprung an der Inversionsoberkante. Wegen fester
  Tageszeit nicht relevant.

### 3.2 Hangaufwind und Lee
FAA Glider Flying Handbook [Q9]:
- Hangaufwind brauchbar ab 10–15 kn (5–8 m/s) fast senkrecht zum Kamm (30–40° Abweichung
  geht noch), ideal Hangneigung ~1:4, Aufwind reicht bis zur 2–3-fachen Kammhöhe, darüber
  verlagert sich das Steiggebiet luvwärts.
- Lee: Abwinde bis 2.000 ft/min (10 m/s) an steilen Kämmen bei starkem Wind.
- Leewellen/Rotoren: Kammwind ≥ 15–20 kn, ±30° zur Senkrechten, stabile Schicht in
  Kammhöhe; Rotorturbulenz "mäßig bis schwer". Kleinere Hügel verlieren die Wellen
  nachmittags durch Konvektion [Q9].

Die Spielwelt hat Hügel/Bergzüge bis ~900 m mit 200–600 m Relief und einen Talzug
(Nordwest–Südost). Leewellen mit 3–30 km Wellenlänge sind bei Nachmittagskonvektion
unwahrscheinlich [Q9] → **keine Wellen, aber Lee-Turbulenz und Abwind hinter Kämmen**.

### 3.3 Kanalisierung
Täler lenken den bodennahen Wind in Talrichtung, unterhalb der Talränder (LB). Im Spiel:
Hauptflusstal ~4–5 km breit, 100–300 m tief.

### 3.4 Thermik und Untergrund
- Thermiksäulen typ. 150–300 m Durchmesser, kegelförmig nach oben breiter, Steigen
  0,5–2,5 m/s (Prognosebeispiel max. 4,6 m/s), Abstand ≈ 1,5× Grenzschichthöhe,
  sterben abends ab [Q9].
- Gute Auslöser: trockene Felder, Fels, Siedlungen; schwach: Wald, Wiese; Absinken über
  Wasser und feuchten Auen (LB, Segelflug-Praxis).
- Bei starkem Wind wird die Thermik zerrissen und versetzt (LB); MSFS braucht ~3 kn Wind
  für "richtige" Thermik [Q13].

### 3.5 Rauigkeitsübergang
Nach einem Übergang Wald → Wiese wächst eine "interne Grenzschicht" mit ~1/10 der
Lauflänge; direkt hinter dem Waldrand ist es in Bodennähe ruhig im Mittel, aber turbulent
(Nachlauf der Bäume, ca. 5–10 Baumhöhen) (LB). Für das Spiel: der Waldrand-Effekt am
Platzrand (Hecken/Wald im Luv der Schwelle) ist ein bekanntes Phänomen beim Landen.

---

## 4. Wetterdynamik über 1–3 h

- Großwetterlage ändert sich in Stunden: langsames Drehen um 10–30°, Auffrischen/Abflauen
  um 20–50 % sind über 2 h normal (LB).
- **Kaltfront**: Wind dreht beim Durchgang kräftig nach rechts (Süd/Südwest → West/Nordwest,
  45–90°), frischt auf und wird böig, danach klart es auf [Q12]. Böenlinien/Schauerbänder
  laufen in ~40 km Abstand, ~30 min auseinander, je < 30 min an einem Ort [Q12]. Front
  zieht mit 25–50 km/h (LB); der Übergang am Ort dauert 10–30 min.
- Warmfront: allmähliche Drehung, weniger böig (LB).

---

## 5. Wie Spiele/Sims es machen

- **JSBSim/FlightGear**: Dryden nach MIL-F-8785C (Varianten "Milspec" und "Tustin",
  verschieden diskretisiert), Stärke über `windspeed_at_20ft` bzw. Index 0–7 für große Höhe,
  zusätzlich eine globale 1−cos-Böe, Rotationsraten pqr separat [Q6]. Turbulenz ist
  zeitlich (Filter am Flugzeug), nicht räumlich – zwei Flugzeuge spüren verschiedene Böen.
- **IL-2 Great Battles**: Windschichten je Höhe, Turbulenz-Parameter je Schicht im Editor,
  nicht dynamisch, nicht an Konvektion/Gelände gekoppelt [Q14]. Spieler loben das
  Flugmodell, vermissen aber Bodenturbulenz an windigen Sommertagen; Kampagnen-Tools senken
  Bodenturbulenz, weil "Menschen und KI Probleme beim Landen hatten" [Q14]. Seitenwind ist
  spielerisch wichtiger als Turbulenz (Start/Landung, Abdrift beim Bodenangriff) [Q14].
- **DCS**: ein Turbulenz-Wert (max. Böengeschwindigkeit), Windschichten 10 m/2.000 m/8.000 m;
  Spieler finden keine Referenz, wie viel realistisch ist [Q15].
- **MSFS (SU11/2024)**: Luftströmungssimulation ("CFD") im 20-km-Umkreis in Schichten:
  Aufwind-Partikel aus Sonne/Albedo/Wasser, Gelände-Hangwind, Nahbereich mit Bäumen/
  Gebäuden. Kritik: Turbulenz-Updates anfangs "überzogen", Hangaufwind noch fehlerhaft
  [Q13, Q16].
- **X-Plane**: Thermik und Turbulenz je Wetterschicht, Hang-/Leeeffekte über Geländeraster
  (LB, Doku).

Was Spielern gefällt: sichtbarer Zusammenhang (Windsack, Rauch, Bäume = was das Flugzeug
spürt), Seitenwind bei Start und Landung, ruhige Luft über Wasser/morgens, Böen in
Bodennähe an Hindernissen. Was nervt: gleichförmiges Zufallsrütteln in jeder Höhe,
Turbulenz ohne Ursache (windstiller Morgen), zu starke Turbulenz bei der Landung,
Abstürze durch einzelne Extrem-Böen.

Performance-Tricks: vorberechnete Gitter (Gelände-Windfaktoren), eingefrorene Felder statt
Filterzuständen (kein Zustand je Flugzeug, deterministisch), wenige Rauschfunktionen in
nativem Code (Godot: `FastNoiseLite` ist C++).

---

## 6. Wirkung auf Jäger der späten 1930er

- Flächenbelastung Bf 109 E ~160 kg/m² (Recherche Flugphysik), Spitfire ~120 kg/m²,
  Hurricane ~130 kg/m², Bodenanflug 150–180 km/h. Eine Vertikalböe w ändert den
  Anstellwinkel um w/V: 2 m/s bei 45 m/s → 2,5°, d. h. ΔCL ≈ 0,25 → ±25 % Last. In
  Bodennähe spürbar, in 400 km/h-Luftkampf nur leichtes Schütteln (0,3–0,5 g).
- **Spornrad**: Schwerpunkt hinter dem Hauptfahrwerk → Wetterhahn-Effekt und
  Ausbrechen (Ringelpiez) werden mit dem Schiebewinkel stärker [Q10]. Gegenmittel:
  Seitenruder früh, Querruder in den Wind, Bremsen; bei Böen Fahrtzuschlag, länger am
  Boden halten; Radlandung bei böigem Seitenwind [Q10].
- Seitenwindgrenzen: leichte Spornradflugzeuge zeigen typ. 10–15 kn (5–8 m/s) 90°-Komponente;
  die Jäger der Zeit starteten auf Graspisten möglichst gegen den Wind (Platz ohne feste
  Bahnrichtung). Flugkern-Pisten liegen in Hauptwindrichtung (±80°): Seitenwind bis
  ~8 m/s ist das obere Ende des Beherrschbaren.

---

## 7. Was wichtig ist und was weggelassen wird

Wichtig für das Spielgefühl (Stil B):
1. **Bodennaher Wind mit Böen und Scherung**: Start/Landung, Windsack, Rauch passen zu dem,
   was der Spieler spürt. Hier entscheidet sich, ob Wind "echt" wirkt.
2. **Turbulenz mit Ursache**: stark in Bodennähe, über/hinter Wald und Kämmen, bei Tag über
   Feldern; ruhig über Wasser und in der Höhe. Kein gleichförmiges Rütteln.
3. **Seitenwind am Boden** (Wetterhahn), beherrschbar.
4. **Wetter ändert sich** sichtbar und gemeldet (Drehen, Auffrischen, Front).
5. Höhenwind stärker und gedreht (Abdrift, Navigation, Bombenwurf später).

Weglassen: Leewellen, Rotor-Strukturen im Detail, Nacht-Jet (keine Tageszeit), 1−cos-Böen,
echte Strömungssimulation, Wirbelschleppen, Mikroburst.

---

## 8. Empfehlung (priorisiert)

1. **Neues Grundprofil** (P1): Log-Profil mit lokalem z0 unterhalb der Mischungshöhe
   (60 m), darüber Log-Profil mit regionalem z0 bis zur Grenzschicht (1.000 m), dann
   konstanter Gradientwind (~1,7× Bodenwind). Rechtsdrehung mit der Höhe 25° (Land) bzw.
   12° (Wasser). Stärkestufe bezieht sich weiter auf 10 m über kurzem Gras (Flugplatz).
   Begründung: billig, physikalisch, macht Scherung beim Landen und Untergrund-Unterschiede.
2. **Turbulenz als eingefrorenes, mit dem Wind treibendes Feld** (P1): drei Bänder
   (L ≈ 400 m / 100 m / 25 m) aus `FastNoiseLite` (nativ, deterministisch per Seed), je
   Komponente; Höhenabhängige Gewichte, sodass Varianz und Längenskala Dryden
   (Niedrighöhenformeln) folgen; σ aus u\* (σu = 2,4 u\*, σv = 1,9 u\*, σw = 1,25 u\*),
   Abnahme mit der Höhe bis zur Grenzschicht, darüber schwache Restturbulenz.
   Intermittenz (Böen in Schüben) über eine langsame Hüllkurve. Rollböe aus der
   Vertikalwind-Differenz an den Flügelspitzen.
   Begründung: räumlich kohärent (Windsack = Flugzeug, Rotte spürt dieselbe Böe),
   deterministisch, kein Zustand je Flugzeug, spektral nahe Dryden.
3. **Gelände-Windgitter** (P2): beim Laden aus Höhen und Bodenmaske ein grobes Gitter
   (200 m): z0, geglättete Höhe und Gradient, Tal-Achse/-tiefe, Thermik-Eignung. Zur
   Laufzeit: Hangauf-/abwind = U·∇H mit Abklingen über Grund, Lee-Turbulenz
   (Luv-Höhe größer als hier) mit Abschwächung des Mittelwindes, Kanalisierung im Tal,
   Thermikzellen über Feldern/Fels, Absinken über Wasser.
4. **Wetterentwicklung** (P2): langsames Drehen/Auffrischen nach Seed; in einem Teil der
   Partien eine Kaltfront (Rechtsdrehung 30–60° in ~15 min, Auffrischen 1,3–1,5×, böiger
   für ~20 min). Richtung bleibt im Pistensektor. Funk meldet Änderungen.
5. **Stärkestufen** (P2): Schwach 1–3, Normal 3–6, Stark 6–9 m/s (10 m, Gras), Böigkeit aus
   dem Modell (G ≈ 1,3–1,6). Thermik bei schwachem Wind relativ stärker (Sommernachmittag),
   bei starkem Wind zerrissen.
6. **Bodenverhalten** (P3): Wetterhahn entsteht aus dem Flugmodell (Seitenleitwerk im
   Luftstrom); prüfen und ggf. Spornrad-Seitenführung so lassen, dass Wind wirkt, aber
   mit Seitenruder beherrschbar ist.
7. **Spielbarkeits-Stellschraube** (P1): Faktor für die bodennahe Vertikalturbulenz und
   die Rollböen (Standard < 1), damit KI und Spieler bei Normal nicht durchstarten müssen.

---

## Quellen

- [Q1] MathWorks, *Dryden Wind Turbulence Model (Continuous)* – Formeln nach MIL-F-8785C:
  https://www.mathworks.com/help/aeroblks/drydenwindturbulencemodelcontinuous.html
- [Q2] Wikipedia, *Dryden Wind Turbulence Model*:
  https://en.wikipedia.org/wiki/Dryden_Wind_Turbulence_Model (nur über Suche gefunden)
- [Q3] Wikipedia, *Roughness length*: https://en.wikipedia.org/wiki/Roughness_length
- [Q4] wind-stats, *Roughness length*:
  https://wind-stats.readthedocs.io/en/latest/user_guide/roughness_length.html
- [Q5] KNMI (Verkaik), *Gustiness / roughness from gust factors*:
  https://cdn.knmi.nl/system/data_center_publications/files/000/067/178/original/gustiness.pdf
- [Q6] JSBSim, *FGWinds* (Turbulenzmodelle, 1−cos-Böe):
  https://jsbsim-team.github.io/jsbsim/classJSBSim_1_1FGWinds.html
- [Q7] Flying Magazine, *Those Shifty Winds*: https://www.flyingmag.com/those-shifty-winds/
- [Q8] PPRuNe, *Surface wind backing*:
  https://www.pprune.org/private-flying/printthread-583376-surface-wind-backing.html
- [Q9] FAA, *Glider Flying Handbook*, Kap. 9 (Thermik, Hangaufwind, Wellen):
  https://www.faa.gov/regulations_policies/handbooks_manuals/aviation/glider_handbook/gfh_chapter_9.pdf
- [Q10] FAA, *Airplane Flying Handbook*, Kap. 14 (Spornradflugzeuge):
  https://www.faa.gov/sites/faa.gov/files/regulations_policies/handbooks_manuals/aviation/airplane_handbook/15_afh_ch14.pdf
- [Q11] Univ. Washington ATMS 547, *Lecture 12* (Tagesgang, Nachtjet):
  https://atmos.uw.edu/academics/classes/2013Q2/547/lect12.pdf
- [Q12] SKYbrary, *Cold Front*: https://skybrary.aero/articles/cold-front
- [Q13] AVSIM, *SU11 CFD* (MSFS-Luftströmung):
  https://www.avsim.com/forums/topic/626199-is-anybody-else-excited-about-the-new-20-km-cfd-in-su11/
- [Q14] IL-2 Forum, *Low level turbulence*: https://forum.il2sturmovik.com/topic/74897-low-level-turbulence/
- [Q15] DCS Forum, *Realistic amount of turbulence*:
  https://forum.dcs.world/topic/231535-realistic-amount-of-turbulence
- [Q16] MSFS Forum, *Orographic ridge lift still not fixed in 2024 SU2*:
  https://forums.flightsimulator.com/t/orographic-ridge-lift-still-not-fixed-in-2024-su2/721942
- Lehrbuch (LB): R. B. Stull, *An Introduction to Boundary Layer Meteorology* (1988);
  H. A. Panofsky, J. A. Dutton, *Atmospheric Turbulence* (1984); J. Wieringa, *Representative
  roughness parameters for homogeneous terrain* (1993).
