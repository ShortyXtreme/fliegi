# Game Design Document – Kurzfassung v1

Arbeitstitel: *Flugzeug Spiel* · Plattform: PC/Steam · Engine: Godot 4 · Stil: stilisiert-realistisch
Status: Entwurf des Game-Design-Agenten, Entscheidungen des Product Owners stehen aus (Abschnitt 8).

---

## 1. Elevator Pitch und Design-Säulen

**Pitch:** Du führst eine Fliegerstaffel durch ein Jahrhundert Luftfahrt – vom wackligen Doppeldecker auf der Graspiste bis zum Überschalljet auf dem Betonfeld. Du fliegst die Einsätze selbst, betankst und munitionierst deine Maschinen mit eigenen Händen und baust Forschung und Flugplatz Schritt für Schritt aus. Allein mit KI-Crew oder im Koop mit Freunden, die jederzeit in jeden Sitz einsteigen können.

**Design-Säulen:**
1. **Jede Maschine braucht einen Flugplatz.** Fortschritt ist nie nur ein neues Flugzeug, sondern das ganze System dahinter: Piste, Treibstoff, Personal, Waffen. Wer einen Jet will, muss ihn auch starten können.
2. **Hände an der Maschine.** Der Bodenbetrieb ist echtes Gameplay: körperlich, nachvollziehbar, unter Zeitdruck. Er ist nicht hinter Menüs versteckt.
3. **Jeder Sitz zählt, Mensch oder KI.** Jeder Platz (Pilot, Schütze, Bombenschütze, Tankwart) wird über dasselbe Sitz-System gesteuert. Spieler und KI sind austauschbar, eine Mission ist nie „unterbesetzt“.

---

## 2. Core Loop

**Minute-zu-Minute (Mikro):**
- *Am Boden:* Alarm, zur Maschine laufen, tanken, aufmunitionieren, Bomben laden, Motor anlassen, rollen, starten. Jede Handlung ist eine kurze, lesbare Interaktion (Schlauch ankoppeln, Gurt einlegen, Bombe am Hebewagen ausrichten).
- *In der Luft:* Ziel finden, Energie und Position managen, angreifen, Munition und Treibstoff im Blick behalten, Schäden melden. In Bombern zusätzlich Crew-Absprache.

**Mission (Meso, 15–30 min):**
Briefing → Vorbereitung am Boden (Beladung nach Auftrag wählen) → Start → Anflug → Kampf/Zielaktion → Rückflug → Landung → Nachbereitung (Schäden, Reparatur, Bergung). Das Ergebnis liefert Ressourcen, Forschungspunkte und Ruf. Verluste kosten Material und Personal.

**Langzeit (Makro, Kampagne):**
Missionsbelohnungen werden in Forschung und Bauprojekte investiert. Neue Infrastruktur schaltet neue Flugzeuge und Rüstungen frei. Damit werden anspruchsvollere Missionen möglich, und man rückt in die nächste Ära vor.

**Vorschlag zur offenen Frage „Basis-Simulation?“:** Ja, als **leichte Basis-/Staffel-Simulation**. Der Flugplatz ist ein begehbarer 3D-Ort, an dem man baut (Hallen, Tanklager, Pistenausbau). Es gibt aber kein komplexes Aufbau-Management mit Warenketten. Drei Ressourcen reichen:
- **Material** (Bauen, Flugzeuge, Reparatur), kommt aus Missionen und Nachschubkonvois,
- **Treibstoff/Munition** als physische Lagerbestände (sichtbar im Tanklager und Munitionsbunker),
- **Forschungspunkte** (aus Aufklärung, Abschüssen, Missionszielen).

Im Koop wird eine **gemeinsame Basis** pro Kampagnen-Spielstand empfohlen, die der Host speichert. Forschungsentscheidungen trifft der Host, die übrigen Spieler können Vorschläge abstimmen. Begründung: Das passt zum Listen-Server-Modell, und gemeinsames Wachsen ist das stärkste Koop-Motiv.

---

## 3. Fortschrittssystem

### 3.1 Ären/Tiers

| Tier | Ära (fiktiv) | Beispiel-Flugzeugtypen (generisch) | Infrastruktur-Voraussetzungen |
|---|---|---|---|
| **I** | Pioniere (≈1915–1925) | Doppeldecker-Jäger, Doppeldecker-Aufklärer (2 Sitze), leichter Doppeldecker-Bomber | Graspiste ≥ 400 m, Zelthangar, Benzin niedriger Oktanzahl in Fässern, Handpumpe, MG-Munition (Gurte), Grundausbildung Mechaniker |
| **II** | Zwischenkriegszeit (≈1925–1937) | Früher Eindecker-Jäger, zweimotoriger mittlerer Bomber, Torpedo-/Seeflugzeug (optional) | Schotterpiste ≥ 800 m, Holz-/Stahlhallen, Tanklager + erster Tankwagen, Benzin mittlere Oktanzahl, 20-mm-Kanonen-Munition, Bombenlager (leichte Bomben), Funk Stufe 1, Waffenwart-Ausbildung |
| **III** | Propeller-Hochzeit (≈1937–1946) | Schneller Kolben-Jäger, Jagdbomber, viermotoriger schwerer Bomber (bis 8 Crew) | Befestigte Piste ≥ 1.400 m, große Hallen, Hochoktan-Benzin, mehrere Tankwagen, schwere Bomben + Hebewagen, Werkstatt Stufe 2 (Motorwechsel), Radar Stufe 1 (Frühwarnung), Funkleitstelle |
| **IV** | Frühe Jets (≈1946–1960) | Erster Strahljäger, Strahlbomber, Allwetter-Abfangjäger | Betonpiste ≥ 2.000 m, Kerosin + separates Kerosinlager, Turbinenwerkstatt, ungelenkte Raketen, Jet-Ausbildung für Personal, Radar Stufe 2 (Bodenleitung), Starthilfe-Aggregat |
| **V** | Moderne Jets (≈1960–heute) | Mehrzweck-Überschalljäger, Kampfflugzeug mit 2 Sitzen (Pilot + Waffensystemoffizier), Tankflugzeug | Betonpiste ≥ 2.500 m + Fangseil, gehärtete Shelter, Druckbetankung, Lenkwaffenbunker, Elektronikwerkstatt, Radar/Datenlink Stufe 3, Spezialisten-Ausbildung (Avionik, Waffen) |

Fehlt eine Voraussetzung, ist das Flugzeug zwar sichtbar, aber **„nicht einsatzbereit“**. Die Benutzeroberfläche zeigt eine Checkliste, etwa: „Benötigt: Kerosin ✗, Piste 2.000 m ✗ (aktuell 1.400 m)“. Ein Übergangszustand ist erlaubt: Ein schwerer Bomber startet auch von zu kurzer Piste, dann aber nur mit reduzierter Beladung. So entsteht ein bewusster Zielkonflikt statt einer harten Sperre.

### 3.2 Forschungsbaum – Zweige

1. **Flugzeugbau:** Zellen, Motoren, Aerodynamik → neue Typen und Varianten.
2. **Bewaffnung:** MG → Kanonen → Bomben (Gewichtsklassen) → Raketen → Lenkwaffen.
3. **Flugfeld:** Pistenbelag und -länge, Beleuchtung (Nachtbetrieb), Rollwege, Shelter.
4. **Logistik & Treibstoff:** Oktanstufen, Tanklager, Tankwagen, Druckbetankung, Kerosin.
5. **Personal:** Ausbildungsstufen und Rollen, Gruppengröße, Arbeitstempo der KI-Crew.
6. **Werkstatt:** Reparaturtiefe, Ersatzteile, Wartungsintervalle.
7. **Aufklärung & Führung:** Funk, Radar, Datenlink, Missionsinfos im Briefing.

Knoten haben Querverweise, zum Beispiel „Strahltriebwerk“ (Flugzeugbau) + „Kerosin“ (Logistik) + „Jet-Ausbildung“ (Personal). Jedes Tier hat einen **Ärenwechsel-Meilenstein**, der Schlüsselknoten aus mindestens drei Zweigen verlangt.

---

## 4. Bodenbetrieb

### 4.1 Abläufe

- **Betanken:** Tier I: Fass rollen, Handpumpe bedienen (Rhythmus-Interaktion). Ab Tier II fährt man den Tankwagen heran, erdet ihn, koppelt den Schlauch, öffnet das Ventil und beobachtet die Füllanzeige. Ab Tier V Druckbetankung über einen Anschluss in wenigen Sekunden. Fehler (falscher Treibstoff, Erdung vergessen) verursachen Motorprobleme oder kleine Brände, die man löschen kann. Die Folgen sind ärgerlich, aber nie spielentscheidend.
- **Aufmunitionieren:** Munitionskiste holen, Klappe öffnen, Gurt einlegen, Waffe durchladen. Gurtungs-Mix (Leuchtspur/Panzerbrechend) ist wählbar.
- **Beladen (Bomben/Fracht):** Bombe am Bunker mit dem Hebewagen aufnehmen, zum Flugzeug fahren, unter der Aufhängung ausrichten, hochkurbeln, verriegeln, Zünder scharf schalten (Sicherungsstift ziehen). Schwere Bomben brauchen zwei Personen, Spieler oder KI. Fracht wird per Palette und Gabelstapler geladen.

Technisch läuft jeder Ablauf als **serverseitiger Job** (`RefuelJob`, `RearmJob`, `LoadOrdnanceJob`, `RepairJob`) mit Teilschritten. Spieler und KI arbeiten Teilschritte über dieselbe Schnittstelle ab, der Server prüft und schreibt den Fortschritt fort.

### 4.2 Rollen des Bodenpersonals

| Rolle | Aufgaben | ab Tier |
|---|---|---|
| Mechaniker | Motorstart, Vorflugkontrolle, Reparatur | I |
| Tankwart | Tanken, Treibstofflager | I |
| Waffenwart | Munition, Bomben, Zünder | I (Bomben ab II) |
| Fahrer | Tankwagen, Schlepper, Bombenwagen | II |
| Funker/Flugleiter | Startfreigabe, Lotsen, Radar | II/III |
| Spezialist (Turbine/Avionik) | Jet-Wartung, Lenkwaffen | IV/V |

Personal hat Ausbildungsstufen (Grund/Fortgeschritten/Experte). Die Stufe bestimmt, was die Person darf und wie schnell sie arbeitet.

### 4.3 KI-Bodenpersonal

Die KI übernimmt offene Jobs automatisch nach Priorität. Der Spieler kann per Befehlsrad Aufträge vergeben („Maschine 2 voll tanken“, „Bomben 250 kg an Maschine 3“) oder selbst anpacken. Ein Spieler arbeitet schneller als ein Grund-KI-Helfer, aber langsamer als ein Experte. Im Solo-Modus kann man den Bodenbetrieb komplett an die KI abgeben, er kostet dann Zeit statt Aufmerksamkeit.

### 4.4 Spaß-Hebel

- **Alarmstart (Scramble):** Feindliche Bomber in 4 Minuten über der Basis. Man entscheidet zwischen vollem Tank und schnellem Start mit halber Munition.
- **Turnaround-Wertung:** Eine Zeitwertung für die Bodencrew (wie Boxenstopp im Rennsport) und eine Bestenliste im Koop.
- **Basisangriffe:** Unter Beschuss tanken, Brände löschen, Krater in der Piste verfüllen.
- **Klare Haptik:** Große Interaktionspunkte, befriedigendes Einrasten, keine Pixelsuche.
- **Komfortregler:** Realismusstufe Bodenbetrieb (vereinfacht/standard/authentisch), z. B. ob die Erdung nötig ist.

---

## 5. Luftkampf und Crew-Rollen

**Flugzeugklassen und Sitze:**

| Klasse | Sitze | Spielgefühl |
|---|---|---|
| Jäger | Pilot (1) | Dogfight, Energiemanagement, Begleitschutz/Abfangen |
| Aufklärer/leichter Bomber (Tier I–II) | Pilot + Beobachter/Heckschütze | Fotos/Zielmarkierung, Verteidigung nach hinten |
| Jagdbomber | Pilot (1) | Bodenangriff, Sturzflug, Abwurf |
| Mittlerer Bomber | Pilot, Bombenschütze/Navigator, 1–2 Bordschützen | Formationsflug, Zielanflug, Abwehr |
| Schwerer Bomber | Pilot, Copilot/Bordingenieur, Navigator, Bombenschütze, Funker, 3–4 Bordschützen | Crew-Koordination, Schadensmanagement (Brände löschen, Treibstoff umpumpen), Sitzwechsel im Flug |
| Moderner Zweisitzer | Pilot + Waffensystemoffizier | Radar, Lenkwaffen, Störmaßnahmen |

**Kampfsystem:** Schaden zonenbasiert (Motor, Tanks, Steuerflächen, Crew-Positionen). Treffer an Crew-Plätzen setzen den Sitz außer Gefecht, und ein anderes Crewmitglied kann umsteigen. Munition begrenzt, Ballistik mit Konvergenz-Einstellung.

**Flugsteuerung – Vorschlag mit drei Modi:**
1. **Arcade/Instruktor:** Maussteuerung (Flugzeug folgt dem Zielpunkt), Stall- und Trudelschutz, Zielhilfe. Für Einsteiger.
2. **Realistisch:** Direkte Steuerung (Joystick/Tastatur), physikbasiertes Flugmodell mit Stall, Drehmoment und G-Effekten, optionale Hilfen.
3. **Simulator:** Wie Realistisch, dazu Motormanagement (Gemisch, Kühlerklappen, Drehzahl), Cockpitsicht und keine Zielhilfe.

Alle Modi nutzen **dasselbe Flugmodell**, die Hilfen sitzen als Eingabefilter davor. Das passt zur Seat-Architektur, weil auch die KI ihre Eingaben auf dieselbe Weise liefert. Server/Lobby legt fest, welche Modi erlaubt sind (z. B. PvP-Lobby nur ab „Realistisch“).

---

## 6. Multiplayer-Modi und KI-Rolle

- **Koop-Kampagne (Kernmodus, 1–8 Spieler):** Gemeinsame Basis, gemeinsame Missionen. Freie Sitze und Flügelmänner werden von KI besetzt.
- **Koop-Einzelmission/Szenario:** Vorgefertigte Einsätze ohne Basisfortschritt, z. B. „Bomberstrom verteidigen“ oder „Alarmstart“.
- **PvP (später):** Zwei Basen gegeneinander, Ziele sind Flugplätze, Konvois und Tanklager. Hier wird Bodenbetrieb zum strategischen Ziel.
- **Solo:** Identisch mit Koop, nur mit KI-Besatzung.

**KI-Rolle:** Die KI ist vollwertiger Sitzinhaber: Pilot, Bordschütze, Navigator, Bodenpersonal. Spieler können **jeden KI-Sitz übernehmen** (Sitzwechsel-Menü, im Bomber durch Herumlaufen im Rumpf). Die KI springt ein, wenn ein Spieler die Verbindung verliert oder den Platz verlässt. Kommandos laufen über ein Befehlsrad (Formation, Angriff, Rückzug, Ziel). KI-Fähigkeit skaliert mit der Personal-Ausbildung, was den Personal-Zweig spielerisch wertvoll macht.

---

## 7. Vertical Slice (Prototyp): Tier I

**Ziel:** Den kompletten Loop Boden → Luft → Boden in einer Ära beweisen, im Koop mit 2–4 Spielern über Steam-Lobby.

**Inhalt:**
- **1 Karte:** Feldflugplatz (Graspiste, Zelthangar, Fasslager, Munitionszelt) und etwa 15 × 15 km Gelände mit Front, feindlichem Feldflugplatz, Brücke, Nachschubstraße.
- **3 Flugzeuge:** Doppeldecker-Jäger (1 Sitz, 2 MG), zweisitziger Doppeldecker-Aufklärer/Bomber (Pilot + Heckschütze, leichte Bomben), feindlicher Jäger als KI-Gegner (gleiches Modell, andere Markierung).
- **Bodenbetrieb:** Betanken aus Fässern (Handpumpe), MG-Gurte laden, leichte Bomben von Hand einhängen, Motor anwerfen per Propeller (Mechaniker-Interaktion). Jobs: `RefuelJob`, `RearmJob`, `LoadOrdnanceJob`.
- **Bodenpersonal:** 2 Rollen (Mechaniker, Waffenwart), KI-Helfer mit Befehlsrad.
- **3 Missionen:** (1) Abfangen eines Aufklärers, (2) Bombenangriff auf die Brücke mit Begleitschutz, (3) Alarmstart bei einem Angriff auf die eigene Basis.
- **Fortschritt (Mini):** 6–8 Forschungsknoten, z. B. „Graspiste verlängern 400 → 600 m“, „Bessere Handpumpe“, „Leuchtspurgurte“, „Zweiter Zelthangar“. Damit wird der Wirkzusammenhang sichtbar.
- **Flugmodi:** Arcade und Realistisch (Simulator noch nicht).
- **Technik:** Seat-System inkl. Sitzwechsel und KI-Übernahme, Listen-Server per Steam-Lobby, Spielstand nur lokal beim Host.

**Nicht enthalten:** weitere Tiers, PvP, Wetter- und Nachtbetrieb, Tankwagen/Fahrzeuge, Reparatur über Schnellreparatur hinaus.

---

## 8. Offene Entscheidungen für den Product Owner

1. **Spielstruktur:** Leichte Basis-/Staffel-Simulation mit Missionen und drei Ressourcen (Material, Treibstoff/Munition als Lagerbestand, Forschungspunkte). *Empfehlung: ja, ohne tiefe Wirtschaftsketten.*
2. **Koop-Basis:** Gemeinsame Basis pro Spielstand beim Host, Forschungsentscheidung durch den Host mit Abstimmung. *Empfehlung: ja.*
3. **Nationen und Flugzeuge:** *Empfehlung: fiktive Nationen mit eigenen Hoheitszeichen, Flugzeuge „historisch inspiriert“ mit generischen Namen.* Begründung: Herstellernamen und Modellbezeichnungen sind oft Marken und würden Lizenzen erfordern. Echte Hoheitszeichen, insbesondere aus dem Zweiten Weltkrieg, sind rechtlich heikel (in Deutschland § 86a StGB, Steam-Regionalfreigaben) und ein Reputationsrisiko. Außerdem gibt es freies Balancing ohne historische Erwartungen an Leistungsdaten.
4. **Flugsteuerung:** Drei Modi (Arcade, Realistisch, Simulator) auf einem gemeinsamen Flugmodell, Lobby legt erlaubte Modi fest. *Empfehlung: ja, Slice mit Arcade + Realistisch.*
5. **Härte der Infrastruktur-Sperre:** Harte Sperre oder „Start mit Einschränkungen“ (z. B. reduzierte Beladung auf zu kurzer Piste)? *Empfehlung: weiche Sperre mit Einschränkungen, wo plausibel.*
6. **Verluste:** Permanenter Verlust von Flugzeugen und Personal oder nur Ressourcenkosten? *Empfehlung: Flugzeuge kosten Material, Personal wird verwundet (Ausfallzeit) statt permanent zu sterben. Ein Hardcore-Modus kann das optional ändern.*
7. **Realismus Bodenbetrieb:** Drei Stufen (vereinfacht/standard/authentisch) einstellbar? *Empfehlung: ja, Standard als Default.*
8. **Spielerzahl Koop:** *Empfehlung: Slice 2–4, Ziel 1.0: bis 8 Spieler (eine Bomber-Crew plus Begleitjäger).*
9. **PvP:** *Empfehlung: nicht vor Release 1.0, die Architektur aber nicht dagegen bauen.*
10. **Zeitspanne Tier V:** Bis „heute“ oder Ende bei ca. 1980 (weniger Elektronik-Komplexität)? *Empfehlung: Tier V auf frühe Mehrzweckjets begrenzen, moderne Lenkwaffen vereinfacht darstellen.*
