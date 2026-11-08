# Recherche M4 „Kriegswirtschaft und Ziele“

Stand: 08.11.2026 · Basis: GDD v3 (§1–5, §8, §10), Plan M3 (Bodenbetrieb mit physischen Lagern ist gebaut)
Zweck: Entscheidungsvorlage für den Product Owner. Teil 1 fasst zusammen, was andere Spiele bei Wirtschaft, Logistik, Zielen und Führung gut oder schlecht machen. Teil 2 beschreibt drei Konzept-Varianten für M4. Teil 3 sammelt einzelne Mechaniken, die mit jeder Variante funktionieren.

**Rahmen aus dem GDD, der für alle Varianten gilt:** Tier I, Karte 40 × 40 km, Fluss mit 2 Brücken, 1 Bahnlinie, 2 Haupt-Flugplätze. Kette Wald → Sägewerk → Flugzeugwerk und Ölfeld → Raffinerie → Depot, dazu eine Munitionsfabrik. Gebäude haben drei Zustände, es gibt 2 Bautrupps, Kriegskraft-Balken, Kapitulation nach 10 min unter 25 %, Lagebesprechung mit 3 Vorschlägen und Funkmeldungen mit Kurzbefehl. Spieler-Nation im Koop gegen eine KI-Nation, Partie 60–90 min.

---

## Teil 1: Was andere Spiele machen

### 1.1 Foxhole (Siege Camp)
- **Stark:** Logistik ist ein eigenes Spiel. Rohstoffe werden gesammelt, in Raffinerien zu Materialien verarbeitet, in Fabriken zu Ausrüstung und Fahrzeugen, und alles reist physisch in Kisten und Containern zur Front. Jeder Respawn kostet ein Versorgungsgut („Shirt“), also verliert eine Front ohne Nachschub sichtbar. Rollen sind frei gewählt, und Anerkennung entsteht über Belobigungen unter Spielern. Reviews loben das Gefühl, Teil einer großen Maschine zu sein.
- **Kritik:** 2021/22 streikten rund 1.800 Logistik-Spieler (Gruppe „LOGI“). Ihre Beschwerden betrafen fast nur Handgriffe: Kisten auspacken und Stapel zusammenführen, lange Wartezeiten an Lagern und Raffinerien, zu kurze Reservierung von Fabrikaufträgen, fehlende Warteschlangen, zu kleine Lagerlimits. Die Arbeit sei stressig und im frühen Kriegsverlauf „toxisch“ umkämpft. Update 48 behob vieles. Ein Krieg dauert Wochen, die Kette ist daher sehr tief.
- **Passt zu uns:** Physischer Transport und „leere Lager stoppen die Front“ haben wir schon (M3). **Nicht übernehmen:** Inventar-Kleinarbeit, tiefe Rezeptketten, Spieler als einzige Transporteure. Lehre: Logistik wird zum Frust, wenn man Handgriffe wiederholt, statt Entscheidungen zu treffen.

### 1.2 Nuclear Option (Shockfront)
- **Stark:** Im Hauptmodus „Escalation“ kämpfen zwei Seiten auf einer ca. 100 km großen Karte, und es gewinnt, wer die Infrastruktur des Gegners zerstört. Fabriken und Fahrzeugdepots erzeugen laufend KI-Bodeneinheiten (auch mobile Flak), die über Straßen, Brücken und Tunnel vorrücken. Spieler bremsen den Gegner, indem sie Fabriken bombardieren (Nachschub kommt langsamer) und vordere Depots treffen (der Anmarsch wird länger). Mit Punkten schaltet man stärkere Flugzeuge frei, ab einer Schwelle auch Atomwaffen. Diese Eskalation in Stufen gibt der Partie einen Bogen. Spieler betonen, dass hohe Belohnungen für Bodenziele eine sich selbst tragende Schleife erzeugen: Bomber ziehen Jäger an, Jäger ziehen Begleitschutz an.
- **Kritik:** Escalation sei „recht einfach“ und nach etwa 18 Minuten vorbei. Depots spawnen Flak zu schnell, und eigene Missionen gelten als abwechslungsreicher.
- **Passt zu uns:** Sehr nah an unserem Ziel. Eine kleine, gut lesbare Kette mit Fabrik → Einheiten → Straße/Brücke → Front, deren Störung man sofort an der Ankunftsrate sieht. Die Belohnung für Bodenziele erzeugt Luftkampf, ohne dass man ihn erzwingen muss. Lehre: Es braucht mehr Tiefe als nur „alles kaputt machen“, sonst endet die Partie zu schnell.

### 1.3 DCS Liberation (Community-Kampagne für DCS)
- **Stark:** Rundenbasierte dynamische Kampagne. Kontrollpunkte (Flugplätze, vorgeschobene Basen) sind über Fronten verbunden. Zielgebäude bringen ihrem Besitzer Einkommen, und mit dem Geld kauft man Flugzeuge und Bodeneinheiten. Die Frontlinie liegt zwischen zwei Punkten im Verhältnis ihrer „Stärke“ (0–1). Nach jeder Mission entscheiden Verluste und gewählte Haltung (defensiv bis Durchbruch), um wie viel sich die Stärke verschiebt (0,1/0,3/0,5). Rechtsklick auf ein Feindziel öffnet direkt die Angriffsplanung, auch das Abfangen abfliegender Konvois. SAM-Stellungen zeigen einen Zustandsbalken.
- **Kritik (Community):** Zwischen den Runden viel Menü- und Planungsarbeit. Die Ergebnisse werden abstrakt verrechnet, die Frontbewegung ist also eine Formel und kein gesehenes Gefecht. Die rote Nachschublinie auf der Karte ist laut Wiki nur Dekoration.
- **Passt zu uns:** Front als **Stärke-Verhältnis zwischen verbundenen Punkten** ist billig zu bauen und gut lesbar. Ebenso gut: Zielgebäude mit Einkommen und „Rechtsklick = Auftrag“. **Nicht übernehmen:** Rundenstruktur und Kaufmenüs.

### 1.4 Falcon 4.0 / BMS Dynamic Campaign
- **Stark:** Der Klassiker. Ziele (Städte, Fabriken, Flugplätze, Brücken) sind als Graph verbunden, jedes hat eine Priorität (1–100), und Bodeneinheiten ziehen entlang der Verbindungen. Eine KI erstellt die Lufteinsätze (ATO), und der Spieler fliegt einen davon. Über ein Prioritäten-Panel kann er Zieltypen, Einsatzarten und Regionen gewichten, und die KI plant entsprechend um.
- **Kritik:** Strategische Angriffe wirken langsam und kaum spürbar. Ein Test über 14 Spielstunden mit stark erhöhter Strategie-Priorität ergab mehr zerstörte Gebäude, aber keinen messbaren Unterschied im Kriegsverlauf. Prioritätenänderungen brauchten rund 2 Stunden, bis sie griffen. Für Einsteiger ist alles schwer zu durchschauen.
- **Passt zu uns:** Ziel-Graph mit Prioritäten als KI-Grundlage und „Spieler setzt Schwerpunkte, KI plant Einsätze“ passen gut zur Kommandantenrolle. **Wichtigste Warnung:** Wirkung muss in Minuten sichtbar sein, nicht in Stunden.

### 1.5 IL-2 Great Battles Career / PWCG
- **Stark:** Staffel-Erzählung, Piloten-Biografie, Verluste mit Folgen, glaubwürdige Missionen.
- **Kritik:** Die Ergebnisse ändern die Front nicht, weil die Geschichte feststeht. Spieler wünschen sich, dass Tiefflug- und Flugplatzangriffe Reaktionen auslösen (Patrouillen, Abfangjäger). Als positives Gegenbeispiel nennen sie *Battle of Britain II*, wo Verluste nachwirken und beschädigte Einheiten Zeit zur Erholung brauchen. Einen Kampagnengenerator kritisieren sie dafür, dass seine Wirkung „nur in Briefings und Statistiken“ sichtbar war.
- **Passt zu uns:** Lehre: **Wirkung muss in der Welt sichtbar sein** (Rauch, leere Lager, Umleitung), nicht nur in einer Statistik. Der Gegner sollte auf Angriffe sofort reagieren.

### 1.6 Hearts of Iron IV
- **Stark:** Luftzonen mit Missionen (Luftüberlegenheit, Abfangen, strategische Bombardierung). Bomben senken Fabriken und Infrastruktur nach und nach, und schlechte Infrastruktur schwächt den Nachschub der Front. Flak und Jäger senken den Schaden, Bomber ohne Begleitschutz erleiden hohe Verluste.
- **Kritik:** Die Wirkung kommt „langsam und kumulativ, nicht entscheidend“, über Monate Spielzeit. Spieler beschreiben den Luftkrieg als abstrakt („zwei Bomber ohne Gegenwehr“). Frühere Atomwaffen galten als billiger Auto-Sieg, die heutigen als zu selten.
- **Passt zu uns:** Ketten-Logik „Infrastruktur → Versorgung → Front“ und „Begleitschutz ist Pflicht“. **Nicht übernehmen:** reine Zahlenwirkung ohne Bild.

### 1.7 Highfleet
- **Stark:** Strategiekarte mit Städten, Treibstoff als ständigem Druck, gegnerischen Schlaggruppen, die einen jagen, und Funkaufklärung (Frequenzen abhören, Bewegungen plotten). Vor dem Kampf sieht man die Aufstellung des Gegners und kann die Reihenfolge wählen, ein Überraschungsangriff zeigt vorab seine Erfolgsaussicht. Die Kommandobrücke ist diegetisch (Hebel, Karten zeichnen) und fühlt sich handfest an.
- **Kritik:** Viele Systeme werden kaum erklärt. Die Funkaufklärung liefert oft nur Bruchstücke, und aktives Radar verrät die eigene Position. Manuelles Landen und Andocken wird schnell lästig. Viele Systeme auf einmal am Anfang.
- **Passt zu uns:** **Erwartete Wirkung vor der Entscheidung anzeigen** (wie bei unserer Lagebesprechung), diegetischer Kartentisch, Aufklärung mit Unschärfe. Lehre: Wiederholte Handgriffe brauchen eine Automatik.

### 1.8 Battlefield (Conquest) und PlanetSide 2 (Lattice)
- **Battlefield:** Wer mehr als die Hälfte der Punkte hält, lässt die Tickets des Gegners abfließen, und zwar umso schneller, je größer der Vorsprung ist. Gehaltene Punkte liefern Spawn, Fahrzeuge und Nachschubkisten. Das ist einfach, jederzeit lesbar und erzeugt Brennpunkte. Varianten schalten die Hauptbasis erst frei, wenn alle anderen Punkte fallen (Assault Lines), damit niemand sofort überrannt wird.
- **PlanetSide 2:** Die Lattice ersetzte freie Hex-Eroberung durch feste Verbindungslinien zwischen Basen. Angreifen darf man nur, was mit eigenem Gebiet verbunden ist. Das bündelt die Kämpfe, verhindert Eroberungen im leeren Hinterland und gibt Verteidigern Zeit. Das Bausystem mit Ressourcen wurde lange als unfertig kritisiert.
- **Passt zu uns:** **Verbindungen statt freier Fläche** machen eine 40-km-Karte lesbar. Abfluss nach Mehrheit ist ein gutes Modell für Kriegskraft und Zeitlimit. Die geschützte Hauptbasis passt zu unserer Schutzphase.

### 1.9 Factorio / Satisfactory
- **Stark:** Lesbarkeit. Ein Gebäude zeigt seinen Zustand am Modell: Beim Chemiewerk-Redesign (FFF #295) bekam es ein Fenster mit farbiger Flüssigkeit und Rauch in Rezeptfarbe, damit man aus jedem Winkel sieht, ob und was es produziert. Produktionsstatistiken zeigen Durchsatz, Symbole zeigen fehlende Eingänge.
- **Kritik:** In großen Fabriken wird die Statistik unübersichtlich. Spieler fordern Bedarfs- und Engpass-Ansichten, weil man nur sieht, was produziert wird, und nicht, was fehlt.
- **Passt zu uns:** Jedes Wirtschaftsgebäude sollte von oben aus dem Flugzeug lesbar sein (Rauch an/aus, Stapel im Hof, Lkw am Tor). Die Produktionstafel braucht eine **Engpass-Ansicht** („Flugzeugwerk wartet auf Holz“), keine Zahlenwand.

### 1.10 Mount & Blade II: Bannerlord
- **Stark:** Strategiekarte und Schlacht verbinden sich ohne Bruch, und der Spieler entscheidet, ob er selbst kämpft oder die Schlacht automatisch berechnen lässt.
- **Kritik:** Die Kampagne wiederholt sich (Heer aufbauen, Stadt halten, gegen ein riesiges Heer verlieren), und im Spätspiel wird sie zur Mühle. Große Reiche überrollen kleinere (Snowballing), Einkommen und Diplomatie sind flach, und die KI passt sich kaum an.
- **Passt zu uns:** „Selbst kämpfen oder auto-resolve“ entspricht unserem „jeder darf fliegen, keiner muss“. **Warnung:** Snowballing und die Mühle im Spätspiel. Wir brauchen Aufholhilfen und eine Partie mit klarem Ende.

### 1.11 Bomber Crew
- **Stark:** Jeder Einsatz ist eine kleine Krise mit Crew-Rollen und dauerhaften Verlusten. Nebenmissionen geben Abwechslung.
- **Kritik:** Missionen wiederholen sich, man levelt mit leichten Missionen, statt Fortschritt zu spüren, und es fehlen Speicherpunkte.
- **Passt zu uns:** Crew- und Verlustgefühl haben wir schon über das Pilotenlevel. Lehre: Zieltypen brauchen Varianz (Abwehr, Wetter, Tageszeit, Begleitschutz), sonst wird „Raffinerie bombardieren“ zur Routine.

### 1.12 Hell Let Loose (Kommandant)
- **Stark:** Der Kommandant führt die Makro-Wirtschaft, also Mannstärke, Munition und Treibstoff aus Knoten und Grundeinkommen. Er setzt Fähigkeiten mit Abklingzeit ein (Tiefangriff, Bombenteppich, Verstärkung) und schickt Nachschub-Lkw, die in einem Zyklus von etwa 4 Minuten Material für Stützpunkte bringen. Guides betonen, dass ein guter Kommandant Partien gewinnt, die die Trupps allein verlieren würden.
- **Kritik/Fehlerbilder (Guides):** Ressourcen auf Verdacht ausgeben, Angriffe ohne nachfolgenden Vorstoß, Lkw-Fahrer, die die Verbindung verlieren. Die Rolle hängt stark vom Können einer einzelnen Person ab.
- **Passt zu uns:** **Wenige, teure Kommandanten-Befehle mit Abklingzeit** und eine Nachschubrunde mit fester Dauer sind leicht zu verstehen. Die Rolle muss aber auch mit KI-Kommandant funktionieren.

### 1.13 Weitere kurz
- **Battle of Britain (TalonSoft 1999) / Battle of Britain II: Wings of Victory:** Auf deutscher Seite wählt man Ziele, plant Wellen, Finten und Ablenkungen, und eine Auto-Planung entwirft den Tag, den man dann bearbeitet. Gewonnen wird über Schaden an RAF, Industrie oder Moral innerhalb einer Frist. In BoB II kann man in jeden Verband springen, Verluste wirken nach, und Einheiten erholen sich nur langsam. **Kritik:** schwache Karte ohne Filter, und man sieht nicht, wie viele Feinde in welcher Höhe kommen. Vor einem Patch beendete das Bombardieren der Kraftwerke die Partie zu schnell, deshalb bekamen sie Flak. Die britische Seite gilt als weniger spannend. **Lehre:** Ein Schlüsselziel darf nicht allein entscheiden, und Verteidigen muss eigene Entscheidungen bieten.
- **Ace Combat (Kampagnen):** Missionen erzählen eine Front, und Nebenziele sowie verbündete Funksprüche machen den Fortschritt hörbar („Brücke ist gefallen, Panzer rücken vor“). **Lehre:** Funkmeldungen als Belohnung für Bodenziele.
- **Sky Rogue / Roguelite-Flugspiele:** Eine Kampagnenkarte mit wählbaren Einsätzen und steigender Bedrohung zeigt, dass schon wenige Zieltypen mit klarer Folge reichen.
- **Mechwarrior 5 Mercenaries / Battlezone 98 Redux:** Bei MW5 machen Vertragsauswahl mit Ruf und Bezahlung die Ziele zu einem Handel, kritisiert werden austauschbare prozedurale Missionen. Battlezone verbindet Basenbau, Ressourcen-Sammler und Ego-Kampf in einem Fahrzeug: Der Kommandant ist zugleich Kämpfer, und Befehle laufen über ein Schnellmenü. **Lehre:** Befehle müssen auch aus dem Cockpit in 1–2 Tasten gehen.

### 1.14 Querschnitt: wiederkehrende Probleme
| Problem | Beispiele | Gegenmittel für uns |
|---|---|---|
| Wirkung zu langsam oder unsichtbar | Falcon 4, HOI4, IL-2-Generator | Wirkung binnen 1–3 min sichtbar (Lager, Rauch, Ankunftsrate, Umleitung) |
| Mikromanagement und Handgriffe | Foxhole (LOGI-Streik), Highfleet (Andocken) | Automatik-Stufen, Logistik als Entscheidung (Route, Priorität), nicht als Kistenschleppen |
| Unübersichtlichkeit | Highfleet, Falcon, BoB-Karte | wenige Gebäudetypen, Verbindungs-Graph, Engpass-Anzeige, Kartenfilter |
| Snowballing / Mühle im Spätspiel | Bannerlord, Conquest-Überrollung | Schutz der Kernbasis, Wiederaufbau, Aufholhilfen, klares Partieende |
| Ein Ziel entscheidet alles | BoB (Kraftwerke), alte HOI4-Atomwaffen | Schlüsselziele stärker verteidigt, Wirkung zeitlich begrenzt, Redundanz |
| Routine-Missionen | Bomber Crew, MW5 | Varianz durch Abwehr, Konvoi-Timing, Gegenangriffe, Aufklärungsalter |

---

## Teil 2: Drei Konzept-Varianten für M4

### Variante A: „Klare Kette, Schlüsselziele“ (Kriegskraft-Duell)

**Kernidee:** Jede Nation hat eine kleine, vollständig sichtbare Wirtschaftskette mit etwa acht Gebäuden. Wer die Kette des Gegners an der richtigen Stelle trifft, sieht die Wirkung sofort im Kriegskraft-Balken und an leeren Lagern. Es gibt keine Bodenfront, der Krieg findet ganz in der Luft und an der Kette statt.

**Ablauf einer Partie (75 min, Normal):**
- 0–10 min Schutzphase: Aufklärungsflüge, die ersten Fotos decken feindliche Gebäude auf. Die Lagebesprechung bietet 3 Vorschläge.
- 10–35 min: Konvoi-Jagd, erste Raffinerie-Angriffe, und die KI antwortet mit angekündigten Gegenschlägen. Die Bautrupps werden knapp.
- 35–60 min: Rennen um den Forschungs-Meilenstein „Übergang Tier II“. Eine Nation, deren Kette stockt, forscht langsamer.
- 60–75 min: Entscheidung durch Kapitulation oder Zeitlimit.

**Wirtschaftskette (je Nation, 8 Gebäude + Transport):**
| Stufe | Gebäude | Anzahl |
|---|---|---|
| Rohstoff | Holzfällerlager (Wald), Ölfeld mit Pumpen | 1 + 1 |
| Verarbeitung | Sägewerk, Raffinerie | 1 + 1 |
| Produktion | Flugzeugwerk, Munitionsfabrik | 1 + 1 |
| Verteilung | Hauptdepot (an der Bahn) | 1 |
| Forschung | Institut | 1 |
| Transport | 1 Zug (Bahnlinie), 2–3 Lkw-Konvois, 2 Brücken als Engstellen | – |

Der Fluss liegt pro Gebäude bei 1–2 Gütern (Holz, Rohöl → Treibstoff, Munition, Flugzeuge), es gibt also keine Rezepte.

**Zieltypen und sichtbare Wirkung:**
| Ziel | Sofort sichtbar | Spürbar nach |
|---|---|---|
| Raffinerie | Großer Rauchpilz, die Treibstoff-Anzeige der Feind-Lagebesprechung wird gelb | 3–5 min: Feindjäger tanken Ersatzbenzin (langsamer) |
| Brücke | Brücke fällt, Konvois drehen um, die Umleitung erscheint auf der Karte | sofort: die Ankunftszeit verdoppelt sich |
| Konvoi / Zug | brennende Lkw, Kisten liegen herum | 2–4 min: Lücke im Feindlager |
| Munitionsfabrik | Explosionen nacheinander | 5 min: Feinde starten mit Teilbeladung |
| Flugplatz (Hangar, Lager) | Lagerbrand | sofort: weniger Starts, Alarmstart langsamer |
| Flugzeugwerk | Halle beschädigt | 8–10 min: weniger Nachschub-Flugzeuge |

**Warum sich ein Angriff lohnt:** Jedes Ziel hat einen sichtbaren **Kriegskraft-Effekt in Prozent** (Vorschau in der Lagebesprechung, Bestätigung im Funk „Raffinerie Nord brennt – Feind-Kriegskraft −6 %“). Die Einsatzbilanz zeigt bei der Landung die verursachte Ausfallzeit in Minuten.

**Rolle des Kommandanten:** Am Kartentisch sieht er die eigene und die aufgeklärte Feindkette als Graph mit Ampeln. Die Lagebesprechung (alle 8–10 min oder auf Abruf) bietet 3 Vorschläge mit Wirkung, Risiko und benötigten Maschinen. Er setzt Reparatur-Priorität und Budget. Im Flug bekommt er Meldungen mit Kurzbefehl.

**KI-Nation:** Ein Ziel-Graph mit Prioritäten nach Falcon-Vorbild, gewichtet nach Persönlichkeit (Industrieller: zuerst Raffinerie, dann Konvois). Gegenangriffe kündigen sich durch Sammeln an, beschädigte Ziele repariert sie sichtbar in fester Reihenfolge, und Schlüsselgebäude bekommen nach einem Treffer mehr Flak oder Jäger.

**Siegbedingung:** wie GDD §8 (Kapitulation 10 min unter 25 % oder Zeitlimit), dazu **Sofortsieg**, wenn eine Nation Tier II erreicht und die andere zu diesem Zeitpunkt unter 50 % Kriegskraft liegt (optional).

**Vorteile:** baut direkt auf GDD und M3 auf, jedes Element ist bereits geplant. Gut lesbar, die Wirkung kommt schnell. Die KI ist überschaubar.
**Risiken:** Ohne Bodenfront fehlt der Partie eventuell ein Bogen, und es droht „Raffinerie-Routine“ (Bomber-Crew-Problem). Wer zuerst die Raffinerie trifft, kann snowballen. Verteidigen könnte passiv wirken.
**Aufwand:** **M**
**Herkunft:** Nuclear Option (Fabrik → Nachschubrate), Factorio (Lesbarkeit), Falcon 4 (Ziel-Graph mit Prioritäten), HOI4 (Infrastruktur → Versorgung), BoB (Wellen planen, Schlüsselziele schützen), Battlefield (Balken als Stand).

---

### Variante B: „Frontlinie und Sektoren“ (Dynamic Campaign light)

**Kernidee:** Die Karte ist in 6–8 Sektoren geteilt, die über Straßen, Bahn und Brücken verbunden sind. Zwischen den Nationen verläuft eine Bodenfront, die von KI-Bodentruppen getragen wird. Ihr Verlauf hängt davon ab, wie viel Nachschub die Frontdepots erreicht und wie viel Luftunterstützung jede Seite liefert. Die Wirtschaft füttert die Front, und Luftangriffe verschieben sie sichtbar.

**Ablauf einer Partie (90 min, Normal):**
- 0–10 min: Die Front steht in der Mitte am Fluss, Aufklärung beginnt.
- 10–40 min: Beide Seiten versorgen 2–3 Frontabschnitte. Unterbrochener Nachschub (Brücke, Konvoi) lässt einen Abschnitt schwächeln, die Front kippt, und ein Sektor mit Feldflugplatz oder Ölfeld wechselt den Besitzer.
- 40–70 min: Durchbrüche, die KI kündigt Offensiven an („Panzer sammeln sich bei Sektor 4“). Spieler fliegen Abriegelung, Nahunterstützung und Jagdschutz.
- 70–90 min: Der Fall eines Kernsektors oder das Zeitlimit entscheidet.

**Wirtschaftskette:** wie Variante A (8 Gebäude), dazu **2–3 Frontdepots** je Nation. Die Gebäude stehen in Sektoren, ein eroberter Sektor bringt seine Gebäude beschädigt mit (Liberation-Vorbild). Bodentruppen sind abstrakt: pro Frontabschnitt ein Wert „Stärke 0–100“, dargestellt durch wenige sichtbare Stellungen, Panzer und Geschütze, die man angreifen kann.

**Frontmechanik:** Pro Abschnitt gilt Stärke = Versorgung (Munition und Treibstoff am Frontdepot) + Luftunterstützung (zerstörte Feindeinheiten, eigene Bodenangriffe) − Verluste. Die Front liegt im Verhältnis der Stärken auf der Verbindungslinie (DCS-Liberation-Formel) und bewegt sich langsam in Echtzeit (z. B. 200 m/min), aber spürbar. Ein Sektor fällt, wenn die Front seinen Mittelpunkt erreicht. Angreifen darf man nur benachbarte Sektoren (Lattice).

**Zieltypen:** die 5 aus dem GDD, dazu **Frontdepot**, **Artilleriestellung / Panzerbereitstellung** (Nahunterstützung) und **Kreuzung / Bahnhof** (Abriegelung).
**Warum sich ein Angriff lohnt:** Die Frontlinie auf der Karte und am Boden (Rauch, Granateinschläge) bewegt sich. Ein Treffer auf ein Frontdepot lässt den Abschnitt in 2–3 min einknicken. Mit einem Sektor gewinnt man Gebiet, Gebäude und eventuell einen Feldflugplatz.

**Rolle des Kommandanten:** Er setzt die **Haltung pro Abschnitt** (halten, angreifen, Durchbruch, wie bei Liberation) und verteilt den Nachschub auf die Abschnitte. Die Lagebesprechung schlägt Kombinationen vor („Abschnitt Süd: Durchbruch möglich, wenn Brücke B fällt“). Er kann mit Abklingzeit Bodenoffensiven auslösen, ähnlich wie Hell-Let-Loose-Befehle.

**KI-Nation:** Ihr Front-Planer wählt einen Schwerpunkt-Abschnitt, sammelt sichtbar und greift an. Ihre Luftwaffe teilt sich in Frontunterstützung und Hinterland-Angriffe, die Persönlichkeit bestimmt das Verhältnis.

**Siegbedingung:** Eroberung der **Kernsektors** (Haupt-Flugplatz) des Gegners oder Kapitulation (Kriegskraft) oder Zeitlimit. Den Kernsektor kann man erst angreifen, wenn ein Nachbarsektor gefallen ist (Assault-Lines-Prinzip).

**Vorteile:** Die Partie bekommt einen echten Bogen, und auf der Karte sieht man sofort, wer gewinnt. Viele verschiedene Lufteinsätze (Nahunterstützung, Abriegelung, Jagdschutz über der Front), und auch Verteidigen ist aktiv.
**Risiken:** Viel neue Technik: Bodentruppen-Simulation, Frontdarstellung, Sektorwechsel mit Gebäudebesitz und mehr KI. Die Front darf nicht nach Formel wirken, wie Kritiker es Liberation vorwerfen. Snowballing (Gebiet bringt Wirtschaft), deshalb sind Dämpfer nötig: Nachschubwege werden länger, je weiter man vorrückt. Auf 40 × 40 km eventuell zu eng.
**Aufwand:** **L**
**Herkunft:** DCS Liberation (Stärke-Verhältnis, Haltung, Gebäude mit Einkommen), Falcon 4 (Ziel-Graph, ATO), PlanetSide 2 (Lattice), Battlefield (Assault Lines), Hell Let Loose (Kommandanten-Befehle), HOI4 (Versorgung der Front), Ace Combat (Funk über Frontereignisse).

---

### Variante C: „Nachschub ist das Spiel“ (Foxhole light mit Konvois)

**Kernidee:** Es gibt wenige Fabriken, aber **jedes Gut reist sichtbar** per Zug, Lkw-Kolonne oder später Schiff über ein Netz mit Engstellen, und dieser Verkehr ist das Hauptziel. Spieler und KI planen Routen, eskortieren eigene Konvois, jagen fremde und reparieren Brücken. Der Luftkampf entsteht rund um die Transportwege.

**Ablauf einer Partie (75 min, Normal):**
- 0–10 min: Routen planen. Die Karte zeigt Bahn, 2 Brücken, 3 Straßenkorridore und den Fahrplan der eigenen Konvois.
- 10–50 min: Jeder Konvoi ist ein kleines Ereignis mit Abfahrt, Strecke und Ankunft. Abfangaufträge erscheinen, sobald Posten oder Aufklärer feindliche Kolonnen melden. Brücken fallen, Umleitungen und Behelfsbrücken entstehen. Konvois kann man begleiten.
- 50–75 min: Das ausgehungerte Lager einer Seite bringt ihre Luftwaffe zum Stehen, dann entscheiden Kapitulation oder Zeitlimit.

**Wirtschaftskette:** 5 Gebäude je Nation (Holzlager/Sägewerk zusammengefasst, Ölfeld/Raffinerie zusammengefasst, Flugzeugwerk, Munitionsfabrik, Hauptdepot), dazu das Transportnetz als eigentliche „Kette“: **1 Zug** (große Ladung, an die Bahn gebunden), **3–4 Lkw-Kolonnen** (flexibel, verwundbar), **2 Brücken + 1 Furt** (langsam, nur leichte Lkw), **Zwischenlager** an Kreuzungen. Ziel-Lager sind die physischen Lager aus M3 (Fasslager, Munitionszelt, Flak-Lager).

**Zieltypen:** Zug (Lok gezielt treffen = Zug steht), Lkw-Kolonne, Brücke, Bahnhof oder Stellwerk (der ganze Zugverkehr stockt), Zwischenlager, Behelfsbrücke im Bau. Fabriken sind vorhanden, aber stark geschützt und schnell repariert.
**Warum sich ein Angriff lohnt:** Was zerstört wird, kommt nicht an, und das sieht man am Ziel-Lager des Gegners (Aufklärungsfoto: Fassstapel kleiner). Die Fahrplan-Anzeige zeigt „Kolonne 3 verspätet / vernichtet“. Ein Zugtreffer wiegt drei Lkw-Kolonnen auf und ist entsprechend stärker begleitet.

**Rolle des Kommandanten / Logistikoffiziers:** Er legt Routen und Fahrpläne fest (wann fährt was wohin, mit oder ohne Begleitschutz) und wählt Umleitungen. Die Lagebesprechung schlägt Abfangfenster vor („Feindzug passiert Brücke Ost in 4 min“). Der Logistikoffizier wird hier spielbar, mit einer Logistikkarte aus Linien, Fahrplan und Füllständen. Optional fahren Spieler Lkw selbst. Wiederholte Handgriffe übernimmt die Automatik, Spieler treffen Entscheidungen statt Kisten zu stapeln (Lehre aus dem LOGI-Streik).

**KI-Nation:** fährt Fahrpläne, die sich durch Aufklärung lernen lassen, nach Verlusten aber variieren. Sie schickt Begleitschutz für wertvolle Transporte und jagt Spieler-Konvois. Brücken baut sie sichtbar wieder auf (Bautrupp mit Holz vom Sägewerk).

**Siegbedingung:** Kriegskraft wie im GDD, wobei Lagerbestände und Lieferquote stärker gewichtet werden. Optional ein „Versorgungs-Kollaps“: alle Frontlager 5 min leer.

**Vorteile:** Nutzt M3 (physische Lager, Fahrzeuge) maximal. Ständig gibt es sichtbare bewegliche Ziele, die Luftkampf erzeugen. Das passt zur Säule „Krieg ist Logistik“. Die Einsätze sind kurz und dicht, der Gegner reagiert ständig.
**Risiken:** Pfadfindung und Simulation vieler Fahrzeuge auf 40 km kosten Leistung und Netzwerk (Sichtbarkeit nur bei Aufklärung hilft). Foxhole-Gefahr, wenn Logistik zur Fleißarbeit wird. Fabriken wirken nebensächlich. Ohne Bodenfront fehlt eventuell der große Bogen. Konvoi-Jagd kann sich nach 60 min wiederholen.
**Aufwand:** **M–L**
**Herkunft:** Foxhole (physischer Transport, leeres Lager stoppt die Front, Rollen), Hell Let Loose (Nachschub-Lkw-Zyklus), DCS Liberation (abfliegende Konvois angreifen), HOI4 (Infrastruktur), Highfleet (Abfangen aus Funkaufklärung, Treibstoffdruck), Nuclear Option (Depots verlängern den Anmarsch).

---

### Variantenvergleich
| | A Schlüsselziele | B Front und Sektoren | C Nachschub-Netz |
|---|---|---|---|
| Lesbarkeit für Neulinge | hoch | mittel | mittel–hoch |
| Bogen der Partie | schwach–mittel | stark | mittel |
| Vielfalt der Lufteinsätze | mittel | hoch | mittel–hoch |
| Nutzt M3 (Lager, Fahrzeuge) | ja | teilweise | voll |
| Snowball-Gefahr | mittel | hoch (Gebiet) | mittel |
| Neue Technik | wenig | viel (Bodenfront) | mittel (Fahrzeugnetz) |
| Aufwand | M | L | M–L |

**Empfehlung zur Diskussion:** A als Fundament für M4 bauen und sie so auslegen, dass Bausteine aus C (Fahrplan, Abfangfenster, Zwischenlager) direkt andocken. B eignet sich als späterer Meilenstein für größere Karten (80+ km). Die Entscheidung liegt beim Product Owner.

---

## Teil 3: Ideen-Bausteine (variantenunabhängig)

1. **Aufklärungsfotos decken auf und veralten.** Ein Foto trägt Gebäude, Füllstand und Flak in die Karte ein. Mit dem Alter verblasst die Information und wird unscharf, und die Lagebesprechung schlägt Nachaufklärung vor. *Herkunft: GDD, Highfleet (Funkaufklärung mit Unschärfe), HOI4 (Aufklärungsstufen).*
2. **Brücke kaputt = Umweg auf der Karte.** Fällt eine Brücke, zeichnet die Karte die neue Route und die längere Ankunftszeit ein. Konvois sieht man umdrehen, eine Behelfsbrücke ist ein neues Ziel. *Herkunft: GDD, Falcon 4, Nuclear Option (Straßen, Brücken, Tunnel).*
3. **Wirkungsvorschau vor dem Angriff.** Jedes markierte Ziel zeigt „Feind-Kriegskraft −x %, Ausfall ca. y min, Abwehr: mittel“. Nach dem Angriff vergleicht die Einsatzbilanz Vorschau und Ergebnis. *Herkunft: Highfleet (Erfolgsaussicht beim Überraschungsangriff), DCS Liberation (Planung per Rechtsklick).*
4. **Sichtbare Gebäudezustände von oben.** Rauch an oder aus, Stapel im Hof, Lkw am Tor, Gerüste beim Wiederaufbau. Man liest aus 1.500 m Höhe ab, ob eine Fabrik läuft. *Herkunft: Factorio FFF #295.*
5. **Engpass-Anzeige statt Zahlenwand.** Die Produktionstafel zeigt pro Gebäude genau einen Grund für Stillstand („wartet auf Holz“, „Brücke West fehlt“, „kein Bautrupp frei“). *Herkunft: Factorio/Satisfactory (Forderungen nach Bedarfsstatistik).*
6. **Angekündigte Gegenangriffe.** Die KI sammelt sichtbar 2–5 min vorher („Verband sammelt sich bei Flugplatz Rot“). Wer aufklärt, sieht es früher, wer den Sammelplatz trifft, schwächt den Angriff. *Herkunft: GDD §4, BoB (Wellen und Finten), Hell Let Loose.*
7. **Konvoi-Abfangaufträge als dynamische Aufträge.** Melden Posten oder Aufklärer eine Kolonne, erscheint ein Auftrag mit Zeitfenster („Kolonne passiert Kreuzung K in 4 min“), den jeder Spieler annehmen kann. Sonst übernimmt die KI. *Herkunft: DCS Liberation (Konvois angreifen), Rettungsaufträge aus GDD §6.4.*
8. **Funkmeldungen als Belohnung und Kurzbefehl.** Treffer werden bestätigt („Raffinerie Nord brennt“, „Feindzug steht“), wichtige Fragen kommen mit Kurzbefehl (Annehmen, Ablehnen, KI entscheidet). *Herkunft: Ace Combat, GDD §5.2.*
9. **Lagebesprechung mit 3 Vorschlägen und Schwerpunkt-Reglern.** Drei Vorschläge mit Wirkung, Risiko und Bedarf, dazu ein Falcon-artiges Panel, das Zieltyp und Region gewichtet und den KI-Staffeln die Einsätze vorgibt. *Herkunft: Falcon 4 (Prioritäten-Panel, ATO), BoB (Auto-Planung zum Bearbeiten).*
10. **Wenige Kommandanten-Befehle mit Abklingzeit.** Zum Beispiel „Großangriff“ (alle KI-Staffeln für 5 min auf ein Ziel), „Notreparatur“ (Bautrupp doppelt schnell) und „Alle Lager auffüllen“ (Sonderkonvoi). Sie kosten Budget und haben eine Abklingzeit von 10 min. *Herkunft: Hell Let Loose.*
11. **Wiederaufbau sichtbar und angreifbar.** Bautrupps fahren sichtbar zum Ziel, Gerüste stehen, und der Fortschritt steht auf der Karte. Trifft man die Baustelle oder den Bautrupp, verlängert sich die Ausfallzeit. *Herkunft: GDD §3, BoB II (Erholung braucht Zeit), Nuclear Option (Depots).*
12. **Dämpfer gegen Snowballing.** Schlüsselziele bekommen nach dem ersten Treffer automatisch mehr Abwehr, Schaden an Gebäuden ist zeitlich begrenzt (es gibt keine permanente Zerstörung), und eine führende Nation hat längere Wege bzw. höhere Reparaturkosten. *Herkunft: BoB-Patch (Flak an Kraftwerken), Battlefield Assault Lines, GDD-Aufholhilfen.*

---

## Quellen
- Foxhole, Wikipedia: https://en.wikipedia.org/wiki/Foxhole_(video_game)
- PC Gamer, Foxhole-Logistikstreik: https://www.pcgamer.com/logistics-players-in-mmo-wargame-foxhole-go-on-strike
- Kotaku, Forderungen der LOGI-Gruppe: https://kotaku.com/foxhole-players-are-striking-over-increased-stress-and-1848370043
- Foxhole Wiki, Logistik: https://foxhole.wiki.gg/wiki/Community_Guides/Logistics
- Nuclear Option, Spielmodi: https://xgamingserver.com/docs/nuclear-option/game-modes
- Nuclear Option Wiki: https://nuclearoption.wiki.gg/wiki/General
- Nuclear Option, Steam-Diskussion (Escalation, Depots, Fabriken): https://steamcommunity.com/app/2168680/discussions/0/4035852798882232271
- Nuclear Option, Steam-Diskussion (Punkte und Freischaltung): https://steamcommunity.com/app/2168680/discussions/0/4203616172205421207
- War-Thunder-Forum, Vergleich mit Nuclear Option (Belohnungsschleife Bodenziele): https://forum.warthunder.com/t/nuclear-escalation-a-failed-war-thunder-interpretation-of-nuclear-option-and-how-to-improve-it/333824
- DCS Liberation Wiki, Frontbewegung: https://github-wiki-see.page/m/dcs-liberation/dcs_liberation/wiki/Frontline-Movement
- DCS Liberation Wiki, Oberfläche: https://github.com/dcs-liberation/dcs_liberation/wiki/Tutorial-UI
- Falcon 4 Kampagnenaufbau: https://www.pmctactical.org/f4/docs/campaign.php
- Combatsim, Falcon 4 Prioritäten: https://combatsim.com/htm/mar99/f4-strategy.htm
- Combatsim, Falcon 4 Prioritäten-Test: https://combatsim.com/htm/mar99/f4-strategy2.htm
- IL-2 Forum, Folgen von Karriere-Missionen: https://forum.il2sturmovik.com/topic/65456-any-side-effects-of-missions-results-in-career-mode/page/3
- IL-2 Dev Blog #102: https://il2sturmovik.com/news/185/dev-blog-102/
- HOI4, strategische Bombardierung: https://guildorder.com/games/hoi4/wiki/strategic-bombing-and-industry-attack
- HOI4 Steam-Diskussion: https://steamcommunity.com/app/394360/discussions/0/595138831417669909
- PC Gamer, Highfleet: https://www.pcgamer.com/uk/highfleet-is-an-action-strategy-game-thats-like-nothing-ive-ever-played-before/
- GosuNoob, Highfleet-Review: https://www.gosunoob.com/?p=185074
- Battlefield Wiki, Conquest: https://battlefield.fandom.com/wiki/Conquest
- PC Gamer, PlanetSide 2 Lattice: https://www.pcgamer.com/planetside-2-gu09-patch-released-adds-lattice-lanes-to-direct-map-flow
- Factorio Friday Facts #295: https://factorio.com/blog/post/fff-295
- Factorio Forum, Produktionsstatistik: https://forums.factorio.com/viewtopic.php?p=610731
- Tom's Guide, Bannerlord-Kritik: https://tomsguide.com/opinion/i-hate-to-say-it-but-bannerlord-hasnt-fulfilled-its-potential-not-even-close
- Use a Potion, Bomber-Crew-Review: https://www.useapotion.com/2018/07/bomber-crew-review/
- Guild Order, Hell Let Loose Kommandant: https://guildorder.com/games/hell_let_loose/guides/commander-role-manpower-and-logistics
- Combatsim, Battle of Britain (TalonSoft): https://www.combatsim.com/review.php?id=534

Hinweis: Zu Ace Combat, Sky Rogue, Mechwarrior 5 und Battlezone stützen sich die Aussagen auf allgemeines Spielwissen ohne eigene Quellenprüfung in dieser Runde. Die Details zu Nuclear Option „Escalation“ stammen aus Community-Diskussionen, nicht aus offizieller Dokumentation, und können sich mit Early-Access-Updates ändern.
