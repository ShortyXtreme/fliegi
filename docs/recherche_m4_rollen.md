# Recherche M4 „Rollen, die man gern spielt“

Stand: 22.11.2026 · Basis: GDD v3 (§1, §3–5, §10), Recherche M4 Wirtschaft (Varianten A/B/C, Ideen-Bausteine 1–12), Plan M3 (Bodenbetrieb, Befehlsrad, Alarmstart mit Bestzeit)
Frage des Product Owners: Wie gestalten wir M4 so, dass ein echter Spieler in einer Nicht-Flug-Rolle (Kommandant, Logistik/Wirtschaft, Bau, Luftverteidigung, Bodenpersonal) sich nicht langweilt und für das Team wirklich wichtig ist?

Aufbau: Teil 1 analysiert andere Spiele mit Kommando-, Support- und Logistikrollen. Teil 2 leitet 12 Design-Prinzipien ab. Teil 3 macht konkrete Vorschläge für unsere Rollen. Teil 4 empfiehlt eine Wirtschafts-Variante, Teil 5 schlägt den M4-Umfang vor. Was schon in der Wirtschafts-Recherche steht (z. B. Foxhole-Streik im Detail, HLL-Nachschubzyklus, Bausteine 1–12), wird hier nur referenziert („Baustein 7“).

---

## Teil 1: Was andere Spiele mit Support-Rollen machen

### 1.1 Natural Selection 2 (Commander)
- **Spannend:** Der Commander baut, forscht und versorgt von oben, und ein rechtzeitiges Medpack oder eine Struktur kann einen verlorenen Kampf drehen. Spieler wünschen sich Aufgaben, die Aufmerksamkeit und Timing verlangen, statt bloß Gebäude abzustellen.
- **Langweilig:** Wer nur Gebäude setzt und Gegenstände abwirft, fühlt sich nach Forenaussage wie ein „NPC, der Ressourcen hütet“. Dass der Commander die ganze Strategie vorgeben musste, führte schon in NS1 zu Frust oder Langeweile.
- **Typische Probleme:** Partien starten nicht, weil niemand kommandieren will. Ein schwacher Commander entscheidet die Partie fast allein. Marines folgen nicht, der Commander „bettelt“ um Gefolgschaft. Zwei Griefer können auf kleinen Servern jeden Commander per Abwahl hinauswerfen, und niemand sieht, wer die Abstimmung gestartet hat.
- **Vorgeschlagene Gegenmittel (Community):** Routine automatisieren, Training gegen Bots, KI-Commander als Ersatz, verschiebbarer „Fokus“-Marker mit Abklingzeit, der das Team anstößt, Abwahl mit Sichtbarkeit und Mindestquote.
- **Lehre:** Eine Rolle, die alles entscheidet, schreckt ab. Eine Rolle, die nur verwaltet, langweilt. Sie braucht eigene, direkt wirkende Hebel, und ohne Mensch muss eine KI einspringen.

### 1.2 Battlefield 2 / 2142 (Commander)
- **Spannend:** Wenige starke Werkzeuge mit Nachladezeit: Versorgungsabwurf, Scan (nur für den Commander sichtbar), UAV (fürs ganze Team sichtbar), Orbitalschlag bzw. Artillerie, EMP. Befehle an Squad-Leader per Rechtsklick. Wer Befehle befolgt, bekommt Bonuspunkte und in 2142 auch kürzere Gadget-Abklingzeiten. Der Commander erhält Punkte, wenn sein Team punktet, und beim Sieg doppelt.
- **Langweilig/Kritik:** Kritiker nennen den Commander-Loop „völlig anders“ als den aller anderen. Wer von einem Marschflugkörper getroffen wird, empfindet das als Gratis-Kill. Werden die Commander-Anlagen zerstört, ist er „buchstäblich nutzlos“.
- **Typische Probleme:** Vergabe nach Rang, Meuterei per Abstimmung, Commander, die Befehle ignoriert sehen.
- **Lehre:** **Anreize statt Zwang** (Bonus fürs Befolgen) und **Informationen, die das Team sieht** (UAV) sind die Teile, die Spieler vermissen. Gefährlich wird es, wenn die Macht des Commanders sich für andere unfair anfühlt oder bei Verlust einer Anlage komplett wegfällt.

### 1.3 Hell Let Loose (Commander, Support, Engineer, Nachschub-Lkw)
- **Spannend:** Ein guter Kommandant gewinnt Partien, die die Trupps verlieren würden. Seine Fähigkeiten (Luftschlag, Aufklärer, Versorgungsabwurf, Panzer) kosten drei Ressourcen (Munition, Mannstärke, Treibstoff), und Squad-Leader sind seine Augen am Boden. Rollenspiel per Sprachchat („Eisenhower-Imitatoren“) gibt der Rolle Charakter.
- **Langweilig:** Spieler beschreiben Support und Kommando als „Laufsimulator“ und „Paketbote“. Knoten (Ressourcengebäude) zu bauen, gilt als lästig und unverbunden mit dem Kampf, und doch ist ein Team ohne sie klar im Nachteil. Kommandanten warten laut Forum meistens auf Abklingzeiten, sodass zusätzliche Ressourcen kaum etwas ändern.
- **Typische Probleme:** Die Rolle ist unbeliebt, der Kommandant wird für jede Niederlage verantwortlich gemacht, Spieler ignorieren Befehle und jagen lieber Kills. XP für Führung gelten als zu gering.
- **Lehre:** **Pflicht-Fleißarbeit, die das Spiel entscheidet**, ist das schlimmste Muster. Wenn Abklingzeiten der eigentliche Engpass sind, entsteht Leerlauf. Wer führt, braucht spürbare Belohnung.

### 1.4 Squad (Logistik, FOB-Bau)
- **Spannend:** Ohne Nachschubfahrten keine vorgeschobenen Basen, ohne Basen kein Respawn nahe der Front. Die Platzierung entscheidet die nächste Phase. Versteckte Basen schlagen stark befestigte, die der Gegner findet.
- **Langweilig:** Wer die Fahrerrolle widerwillig rotiert, liefert spät und mit halber Ladung.
- **Typische Probleme:** Überbauen (alles an einem Ort), unkoordinierte Platzierung zwischen Trupps, unverteidigte Basen, Festhalten an Basen hinter der Front.
- **Lehre:** Bauen wird spannend durch **Ort und Zeitpunkt** (Risiko, Tarnung, Vorausdenken), nicht durch den Bauvorgang. Der Logistiker ist der, der die Pläne anderer erst möglich macht, und das muss das Spiel ihm zeigen.

### 1.5 Foxhole (Logistik, Fabriken, Streik)
- **Spannend:** Das Gefühl, Teil einer großen Maschine zu sein. Autoren bewundern Spieler, die stundenlang Munition herstellen, die sie nie selbst abfeuern. Kameradschaft in Logistik-Clans.
- **Langweilig:** Lagerverwaltung („extrem mühsam“), lange Wartezeiten, weite Wege nach Kartenvergrößerung, schwerfällige Oberfläche (Details in der Wirtschafts-Recherche, 1.1).
- **Typische Probleme:** Stress, „toxischer“ Wettbewerb um Fabrikplätze im frühen Krieg. Der Streik zeigte, was fehlt, wenn Logistiker fehlen: Soldaten nur mit Pistolen, unversorgte Gebiete, die über Nacht kippen, und Nicht-Logistiker, die notgedrungen einsprangen und ausbrannten. Die Streikenden beklagten zudem fehlende Anerkennung durch die Entwickler.
- **Lehre:** Wenn eine Spielergruppe das Rückgrat ist, braucht sie **Werkzeuge gegen Kleinarbeit und sichtbare Wertschätzung**. Unser Vorteil: Bei uns füllt die KI die Lücke, ein „Streik“ ist also nie fatal.

### 1.6 PlanetSide 2 (Zug-/Truppführer, Konstruktion)
- **Spannend:** Laut einem erfahrenen Zugführer bleiben neue Spieler oft erst dann, wenn sie einen guten Zug mit gutem Anführer finden.
- **Langweilig/Kritik:** Das Bausystem (seit 2016) galt lange als schwierig, und Verteidiger fanden das Kämpfen an Spielerbasen „fast schon mühsam“. Die Überarbeitung 2023 hatte das Ziel, dass Bauer Basen errichten, an denen auch Nicht-Bauer gern kämpfen.
- **Typische Probleme:** Führen ist viel Arbeit, die Belohnungen dafür sinken, Missionen und Hinweise gehen im Chat unter.
- **Lehre:** **Was der Bauer baut, muss für die anderen Spaß machen**, nicht nur für ihn. Führung braucht greifbare Belohnung und Werkzeuge, die die Botschaft wirklich zu den Spielern bringen (HUD statt Chat).

### 1.7 Savage 2 / Silica (RTS-Commander plus Shooter)
- **Spannend (Silica):** Der Commander sieht die ganze Karte, entscheidet, wann und wo gedrückt wird, und seine Produktion wird direkt zu Fahrzeugen, die Shooter-Spieler nutzen. Die Ernter (Harvester) sind das ganze Einkommen und brauchen Begleitschutz. Den Commander-Stuhl kann man jederzeit an die KI abgeben und als Infanterie weiterspielen.
- **Langweilig/Kritik:** Bei Savage 2 nennt die Review die Commander-Ansicht unintuitiv. Laut NS2-Forum waren gute Bodenkämpfer wertvoller, deshalb hatten manche Partien gar keinen Commander. Bei Silica gibt es auf großen Karten lange Laufwege ohne Handlung, und ein verlorenes Forschungsgebäude kann den Ausbau dauerhaft stoppen.
- **Lehre:** Die **KI-Übergabe in beide Richtungen** ist richtig (bei uns schon GDD-Säule 3). Die Commander-Produktion muss bei den Kämpfern ankommen und dort sichtbar sein. Bei uns heißt das: Der Konvoi, den der Flieger beschützt, ist das Einkommen, das er gleich selbst tankt.

### 1.8 Nuclear Option (Escalation, Transport)
- **Spannend:** Transportflieger wie die Tarantula setzen Munitionscontainer an vorgeschobenen Tank- und Munitionspunkten ab und bringen Fahrzeuge, die Spieler dann RTS-artig steuern. Logistik passiert also **selbst fliegend**. Hohe Belohnungen für Bodenziele erzeugen die Schleife „Bomber ziehen Jäger an, Jäger ziehen Begleitschutz an“ (Wirtschafts-Recherche 1.2).
- **Kritik:** In großen Schlachten ist der Transporter verwundbar und schwer zu schützen.
- **Lehre:** Bei uns kann eine Support-Aufgabe ein Flugauftrag sein (Rettung, später Lufttransport). Gefährdete Transporte sind **Anlässe für Luftkampf** und damit gut für beide Spielergruppen.

### 1.9 Barotrauma, Sea of Thieves, Space Station 13 (Crew-Rollen mit Abhängigkeit)
- **Barotrauma:** Kapitän, Sicherheit, Arzt, Mechaniker, Ingenieur. Stirbt ein Spezialist, fehlen den anderen die Fähigkeiten. Ruhephasen füllen Mechaniker und Ärzte mit Herstellen von Reparatursets und Medizin. Die KI erledigt Routine-Reparaturen gut. **Kritik:** In ruhigen Phasen gibt es außer „U-Boot am Laufen halten“ wenig zu tun, und gelangweilte Spieler fluten zum Spaß Abteile. Verräter und toxische Spieler führen zu Schuldzuweisungen. Ein schwacher Kapitän gefährdet die ganze Runde.
- **Sea of Thieves:** Die Rollen (Steuer, Kanone, Flex, „Bilge“ mit Reparieren und Wasserschöpfen) sind nicht festgelegt, sondern entstehen über Zurufe: Die Bilge ruft nach Hilfe, wenn das Wasser steigt, und der Steuermann nach dem Flex für die Segel. In offenen Crews spielen die meisten ohne feste Rollen. *(Teilweise allgemeines Spielwissen.)*
- **Space Station 13:** Abteilungen hängen voneinander ab (Energie, Atmosphäre, Fracht, Medizin), und ein Ausfall läuft durch die ganze Station. Fracht wird zum Waffenlager, wenn die Waffenkammer unzugänglich ist. Wer eine Schlüsselfunktion hat, kann die Station sogar erpressen.
- **Lehre:** **Gegenseitige Abhängigkeit erzeugt Geschichten**, aber nur mit Puffern (KI-Ersatz, Teilfunktion), sonst wird ein Ausfall oder Griefer fatal. **Zurufe und Anfragen** organisieren Rollen besser als feste Zuweisung. Leerlauf führt zu Unfug, also braucht jede Rolle eine ruhige Nebenbeschäftigung, die etwas bringt.

### 1.10 Battlestations Midway / Pacific
- **Spannend:** Etwa drei Viertel der Zeit befehligt man über eine kleine taktische Karte, kann aber jederzeit in jede Einheit springen (Jäger, U-Boot, Flak eines Schiffs). Die Review lobt, wie leicht der Wechsel fällt. Im Mehrspieler entscheiden Taktik und Absprache.
- **Lehre:** Das ist unser Modell „Rolle behalten, kurz selbst fliegen oder an die Flak springen“. Der Wechsel muss **eine Taste** sein und die Befehlsebene im Hintergrund weiterlaufen.

### 1.11 EVE Online (Industrie, Transport)
- **Spannend:** Transportspieler fliegen riesige Frachter, teilen in Gruppen Informationen über Piraten, setzen faire Preise und versichern sich gegenseitig. Ein Entwickler sagt, viele Spieler mögen gerade die „langweiligen“ Tätigkeiten mit geringem Risiko und sicherer Belohnung.
- **Kritik:** Hinterhalte, Pfand-Verluste und Betrug, und die Rolle wird als „oft vergessen“ beschrieben.
- **Lehre:** **Es gibt Spieler, die ruhige Planungsarbeit suchen.** Für sie muss die Rolle entspannt spielbar sein, aber mit gelegentlicher Gefahr. Risiko kommt vom Gegner, nicht von der Oberfläche.

### 1.12 Arma 3 Zeus / Arma Reforger (Kommando, Spielleitung, Nachschub)
- **Zeus:** Spielleiter mit freier Kamera, der Einheiten, Artillerie und Marker setzt, begrenzt durch ein Ressourcen-Budget. Spieler rufen ihn per Ping, er springt in deren Sicht. Feuerunterstützung kommt mit Verzögerung und Vorwarnung.
- **Reforger Conflict:** Nachschub wird per Lkw von Depot zu Basis gefahren und dort für Bauten (Werkstatt, Munitionspunkt, Lazarett, Funkrelais) ausgegeben. Beförderung gibt es für Eroberung und **Versorgung** von Basen. Spieler mögen das Adrenalin auf gefährlichen Routen, die Ortskenntnis, das gute Gefühl, die Front zu versorgen, und manche die Ruhe. Sie hassen Hinterhalte an den immer gleichen Straßen, Eigenbeschuss, zähes Entladen, Kollegen, die fremde Ladungen entladen und die XP abgreifen, Begleiter, die nach einer Fahrt verschwinden, und ein Team, das die Lieferungen verschwendet.
- **Lehre:** **Budget statt Allmacht** (Zeus). **Lieferungen fair zuordnen**, Entladen automatisieren, und Verschwendung durch andere sichtbar machen oder bremsen.

### 1.13 Enlisted (Ingenieur, Sammelpunkte)
- **Spannend:** Ingenieure bauen Sammelpunkte, Munitionskisten und Flak. Punkte gibt es, wenn andere sie nutzen.
- **Kritik:** Spieler halten das für unterbelohnt und schlagen Punkte pro gespawntem Soldaten bzw. pro aufgefülltem Prozent vor. Gegenstimme: Höhere Belohnungen verleiten zum Abreißen fremder Sammelpunkte, um selbst neu zu bauen.
- **Lehre:** **Belohnung nach Nutzen durch andere** (Kettenkredit) ist der richtige Ansatz, sie muss aber gegen Missbrauch gesichert sein.

### 1.14 Highfleet (Kommandobrücke)
- **Spannend:** Funkaufklärung mit Bruchstücken, Bewegungen auf der Karte selbst plotten, diegetische Kommandobrücke (Details in der Wirtschafts-Recherche, 1.7).
- **Lehre für die Luftverteidigung:** **Unsichere Information, die man selbst deutet**, ist ein Spiel für sich. Der Plot-Tisch der Luftverteidigung kann genau so funktionieren.

### 1.15 Querschnitt: Probleme und wer sie hat
| Problem | Beispiele | Ursache | Gegenmittel (→ Prinzip in Teil 2) |
|---|---|---|---|
| Keiner will die Rolle | NS2, Savage, HLL | Rolle ist Pflicht, schwer, undankbar | KI füllt immer, Rolle nie Voraussetzung (P10), Anerkennung (P7) |
| Commander wird ignoriert | NS2, HLL, BF | nur Bitten, keine Hebel | eigene Ressource (P3), Anreize fürs Folgen (P4), KI-Einheiten gehorchen immer |
| Fleißarbeit | Foxhole, HLL-Knoten, Reforger-Entladen | Handgriffe statt Entscheidungen | Automatik für Routine, Entscheidung bleibt beim Menschen (P2) |
| Leerlauf | HLL (Abklingzeiten), Barotrauma, Silica-Laufwege | keine Ereignisse zwischen Spitzen | Takt von Ereignissen, Vorbereitungsaufgaben (P6) |
| Kein sichtbarer Einfluss | Foxhole, HLL-Knoten, Falcon/HOI4 | Wirkung abstrakt oder spät | Wirkung binnen Sekunden zeigen (P1), Kettenkredit (P7) |
| Frust, wenn Team nicht folgt | HLL, NS2, Reforger-Begleiter | Abhängigkeit vom Willen anderer | KI-Fallback, Anfragen mit Frist (P8) |
| Schuld und Druck | HLL, NS2, Barotrauma-Kapitän | ein Mensch entscheidet alles | Rolle beeinflusst, entscheidet nicht allein (P12) |
| Griefing | NS2-Abwahl, Enlisted-Abriss, Barotrauma-Verräter, SS13 | Macht ohne Leitplanken | Drossel, Rückgängig, Protokoll, Abwahl-Regeln (P11) |

---

## Teil 2: Design-Prinzipien für spannende Support-Rollen

**P1 Wirkung in Sekunden sichtbar, Folgen in Minuten.** Jede Entscheidung erzeugt sofort ein Zeichen in der Welt oder im Funk (Kolonne fährt los, Bautrupp rollt, Alarm-Sirene, Marker erscheint im HUD der Flieger). Die Folgen kommen in 1–5 min und werden der Rolle **ausdrücklich zugeschrieben** („Konvoi 2 ist angekommen, Fasslager Blau 80 %“). *Herkunft: Falcon/HOI4 als Negativbeispiel, Squad (Basis = Respawn).*

**P2 Entscheiden statt schleppen.** Der Mensch wählt Was, Wann, Wohin und Wie riskant. Wiederholte Handgriffe übernimmt die KI. Wenn die Rolle eine Handlung im 3D-Raum hat (Bodenpersonal, Bautrupp anführen, Lkw fahren), ist sie freiwillig und gibt einen Bonus, sie ist keine Pflicht. *Herkunft: Foxhole-Streik, HLL-Knoten, Reforger-Entladen.*

**P3 Eigene Macht, eigene Ressource.** Jede Rolle verfügt über etwas, das nur sie einsetzt: Befehlspunkte (Kommandant), Fahrplan-Plätze und Ladung (Logistik), Bautrupps und Holz (Bau), Alarmstarts und Posten (Luftverteidigung), Werkstattplätze (Bodenpersonal). Wer nur bitten kann, wird ignoriert. *Herkunft: NS2 („betteln“), Zeus-Budget, HLL-Ressourcen.*

**P4 KI gehorcht, Menschen werden gelockt.** KI-Staffeln, KI-Konvois und KI-Bautrupps führen Befehle immer aus, so hat der Kommandant garantiert Wirkung. Menschliche Flieger werden über Anreize gelenkt (XP-Bonus, kürzere Wartezeit, bessere Beladung), nie gezwungen. *Herkunft: BF2142 (Bonus für befolgte Befehle), NS2 (Fokus-Marker).*

**P5 Informationsvorteil, den Flieger brauchen.** Support-Rollen sehen, was der Pilot nicht sieht (Plot-Tisch, Fahrpläne, Feindfotos, Lagerstände), und geben es als HUD-Hinweis weiter. So wird der Support zum Auge der Flieger. *Herkunft: BF2142 UAV, Silica-Kartenübersicht, HLL (Squad-Leader als Augen).*

**P6 Takt und Zeitfenster gegen Leerlauf.** Alle 2–4 min erreicht jede Rolle ein Ereignis mit Frist (Konvoi-Abfahrt, Postenmeldung, Landung, Schaden). Ruhige Phasen füllen **Vorbereitungsaufgaben**, die später zählen (Ausbau, Ausbildung, Tarnung). Abklingzeiten dürfen nie der Hauptengpass sein. *Herkunft: HLL (Warten auf Abklingzeit), Barotrauma (Herstellen in Ruhephasen).*

**P7 Anerkennung und Kettenkredit.** Wer etwas ermöglicht, bekommt einen Anteil an dem, was andere damit erreichen (Treibstoff → Start → Abschuss). Es gibt eine eigene Bilanz für Nicht-Flieger, Auszeichnungen am Partieende und lobende Funkmeldungen. *Herkunft: Enlisted (Punkte pro Nutzung), BF2 (Commander-Punkte aus Teamerfolg), PS2-Mentoren, Foxhole (fehlende Anerkennung).*

**P8 Synergien mit Puffer.** Rollen stellen einander Anfragen mit Frist (Begleitschutz, Flak-Munition, Reparatur zuerst), und die Annahme gibt beiden Punkte. Bleibt eine Anfrage unbeantwortet, springt die KI ein, damit niemand blockiert wird. *Herkunft: Sea of Thieves (Zurufe), SS13/Barotrauma (Abhängigkeit), GDD §5.3 (Anfragen mit Frist).*

**P9 Ein-Tasten-Wechsel und Körper in der Welt.** Vom Kartentisch ins Cockpit, an die Flak oder zum Bautrupp ist es ein Schritt. Der Arbeitsplatz ist ein Ort im 3D-Flugplatz, und die Rolle läuft in der Abwesenheit nach einer selbst gesetzten Leitlinie weiter. *Herkunft: Battlestations, Silica-Stuhl, GDD §5.2.*

**P10 Rolle als Angebot, nie als Voraussetzung.** Jede Rolle funktioniert vollständig mit KI, ein Mensch macht sie besser, schneller und überraschender. Die KI-Stufe „voll automatisch“ ist solide, aber berechenbar und langsamer (z. B. 60–120 s Reaktionszeit), sodass ein aufmerksamer Mensch messbar besser ist. *Herkunft: NS2/Savage (Partien ohne Commander), Silica.*

**P11 Leitplanken gegen Griefing und Fehlgriffe.** Drossel bei destruktiven Aktionen (Lager leeren, Gebäude abreißen, Budget verschieben), 30 s Rückgängig, Protokoll „wer hat was getan“ für alle sichtbar, Abwahl nur mit Mindestquote und Sichtbarkeit des Initiators. Belohnungen so bauen, dass Sabotage am eigenen Team sich nicht lohnt. *Herkunft: NS2-Abwahl-Griefing, Enlisted-Abriss, Barotrauma-Verräter.*

**P12 Einfluss ja, Alleinschuld nein.** Eine Rolle verschiebt Partien um spürbare Prozent, entscheidet sie aber nicht allein. Schlechte Entscheidungen werden durch KI-Untergrenzen abgefedert (z. B. Reparatur läuft weiter, auch wenn niemand priorisiert). Gegner-Druck auf Support-Wege (Konvois, Baustellen) macht die Rolle spannend, ohne dass Fehler sofort tödlich sind. *Herkunft: NS2 („hängt zu sehr am Commander“), HLL-Schuldzuweisung, Eve/Reforger (Gefahr als Würze).*

---

## Teil 3: Konkrete Vorschläge für unsere Rollen in M4

### 3.0 Gemeinsame Bausteine für alle Nicht-Flug-Rollen

**A. Dienstbilanz (die Einsatzbilanz der Nicht-Flieger).** Analog zur Einsatzbilanz bei der Landung (GDD §6.1) bekommt jede Nicht-Flug-Rolle alle 10 min, beim Rollenwechsel und am Partieende eine kurze Bilanz: 2–3 Kennzahlen und **eine Highlight-Zeile mit Folgekette**, z. B. „Konvoi 3 lieferte 900 l Hochoktan → 7 Starts → 2 Abschüsse durch Blau 2 und Blau 4“. Daraus entstehen **Dienst-XP** und ein Dienstgrad pro Rolle (3 Stufen in M4), deren Boni Komfort bringen und keine Macht (z. B. +1 Fahrplan-Platz, +1 gespeicherte Vorlage, Bautrupp-Anführen +5 %). Der Dienstgrad bleibt nur in der Partie, wie das Pilotenlevel.

**B. Kettenkredit.** Jede Wirkung trägt eine Herkunftskette (Lagerbestand ← Konvoi ← Logistik; Start ← Abfertigung ← Bodenpersonal; Abfang ← Vektor ← Luftverteidigung; Treffer im Schwerpunkt ← Kommandant). Flug-XP werden dadurch **nicht kleiner**, der Support bekommt zusätzlich einen Anteil (Richtwert 20–30 % der Flug-XP als Dienst-XP). Gegen Missbrauch (P11): Kredit gibt es nur für Ressourcen, die tatsächlich verbraucht wurden, und nur einmal pro Einheit.

**C. Anfragen-Bus.** Rollen (Mensch oder KI) senden einander Anfragen mit Frist und erwarteter Wirkung, etwa: „Logistik → Flieger: Begleitschutz Kolonne 2, Abfahrt in 2:00, +40 XP“. Annahme per Kurzbefehl, im Flug per Funk (GDD §5.2). Läuft die Frist ab, entscheidet die KI (fährt ohne Schutz, wartet oder nimmt einen KI-Jäger). Wer annimmt und erfüllt, bekommt XP, der Anfragende Dienst-XP.

**D. Übergabezettel beim Wechsel ins Cockpit.** Beim Einsteigen in ein Flugzeug fragt ein einzeiliges Menü nach der Leitlinie für die Abwesenheit: „wie bisher“, „sparsam/defensiv“, „aggressiv“, dazu die Automatik-Stufe. Nach der Landung zeigt eine Zeile, was die KI in der Zwischenzeit getan hat („3 Konvois gefahren, 1 verloren, Brücke Ost repariert“).

**E. Arbeitsplätze im 3D-Raum.** Kommandantur-Baracke mit Kartentisch, Fahrdienstleitung am Depot bzw. im Lkw-Hof, Bauhof, Plot-Raum mit Funk, Bodenpersonal am Vorfeld. Alle Tafeln gibt es zusätzlich als Overlay (Taste M), damit niemand laufen muss, aber am Ort sieht man mehr (z. B. Fahrplan-Details nur an der Fahrdienstleitung). *Optional; Säule 2 „Hände an der Maschine“.*

---

### 3.1 Kommandant

**Was er jede Minute tut:** Er schaut auf Kartentisch und Feed, beantwortet 1–2 Anfragen, verschiebt bei Bedarf Schwerpunkte und plant den nächsten Befehl. Alle 8–10 min kommt die Lagebesprechung (Baustein 9).

| # | Mechanik | Entscheidung | Wie das Team es spürt |
|---|---|---|---|
| K1 | **Schwerpunkt-Marker** (max. 2 aktiv, Verlegen kostet 90 s Sperre). Ziele und Abschüsse in der Zone geben +25 % Flug-XP. KI-Staffeln fliegen bevorzugt dorthin. | Wo liegt das Gewicht: Feindraffinerie oder eigene Brücke schützen? | Der Ring erscheint im Flieger-HUD und in der Lagebesprechung, und Funk meldet „Schwerpunkt Brücke West“. Der Bonus zeigt sich in der Einsatzbilanz. |
| K2 | **Befehlspunkte (eigene Ressource).** 1 Punkt alle 3 min, dazu +1 für jedes erfüllte Schwerpunktziel, höchstens 5 Punkte gespeichert. Befehle (Baustein 10): Großangriff (alle KI-Staffeln 5 min auf ein Ziel, 3 P.), Notreparatur (ein Bautrupp doppelt schnell, 2 P.), Sonderkonvoi (sofort, mit KI-Begleitschutz, 2 P.), Alarmbereitschaft (2 Maschinen 6 min startklar mit laufendem Motor, 1 P.), Funktäuschung (Feind-KI meldet einen Scheinangriff, 2 P.). | Wann spare ich, wann setze ich ein? Was bringt am meisten? | Jeder Befehl hat eine sofortige Wirkung in der Welt (Staffeln heben ab, Bautrupp-Sirene, Lkw rollt). |
| K3 | **Auftragstafel mit Kopfgeld.** Aus Lagebesprechung und Anfragen entstehen Aufträge. Der Kommandant setzt Priorität und Belohnung (+0/+25/+50 % XP aus einem begrenzten Topf pro 10 min). Spieler nehmen an, sonst übernimmt eine KI-Staffel. | Welche 2–3 Aufträge sind jetzt wichtig, und wie viel ist mir das wert? | Flieger sehen am Hangar und im Funk „offene Aufträge“ mit Belohnung. Wer einen Auftrag erfüllt, bekommt Lob über Funk. |
| K4 | **Foto-Tisch (Informationsvorteil).** Aufklärungsfotos kommen nach der Landung herein. Der Kommandant bestätigt oder verwirft erkannte Objekte (Flak, Lager, Attrappe?) mit einem Klick pro Objekt, ca. 10–20 s pro Foto. Die KI tut das sonst erst nach 2 min und erkennt Attrappen schlechter (Trefferquote 50 % statt 80 %). | Ist das ein echtes Lager oder eine Attrappe? Ist die Nachaufklärung nötig? | Feindziele erscheinen schneller und zuverlässiger auf der Karte aller Spieler. |
| K5 | **Absicht des Gegners deuten.** Kündigt die KI einen Angriff an (Baustein 6), zeigt die Lage 2–3 mögliche Ziele mit Wahrscheinlichkeit. Der Kommandant legt die Verteidigung fest (wo Jäger, wo Flak-Munition, was wird geräumt). | Finte oder echter Angriff? | Eine richtige Wahl bringt spürbar weniger Schaden. Die Bilanz zeigt dann „vorhergesagt: Raffinerie ✓“. |

**Wertung:** Dienst-XP für erfüllte Schwerpunktziele, Anteil an Aufträgen, richtig gedeutete Angriffe, Kriegskraft-Differenz pro 10 min. Auszeichnung am Ende: „Stratege“ (höchster Kriegskraft-Gewinn pro Befehlspunkt).
**KI-Automatik:** Bei „Routine automatisch“ beantwortet die KI Budgetanträge unter 10 % und setzt Fotos selbst um, Schwerpunkte und Befehle bleiben beim Menschen. Bei „voll automatisch“ übernimmt sie mit 90 s Verzögerung den ersten Vorschlag der Lagebesprechung.
**Gegen Langeweile:** Der Befehlspunkte-Kreislauf (K2) und das Kopfgeld (K3) geben immer etwas zu planen. Der Foto-Tisch füllt ruhige Minuten mit nützlicher Arbeit.

---

### 3.2 Logistik und Wirtschaft (Logistikoffizier + Wirtschaftsplaner light)

**Was er jede Minute tut:** Er schaut auf die Fahrplantafel (wer fährt, wer kommt an, wo ist Gefahr), entscheidet die nächste Abfahrt, reagiert auf Postenmeldungen („Feindjäger über Straße Süd“) und hält die Engpass-Ansicht im Blick.

| # | Mechanik | Entscheidung | Wie das Team es spürt |
|---|---|---|---|
| L1 | **Fahrplantafel mit Konvoi-Fenstern.** 3–4 Lkw-Kolonnen und 1 Zug. Pro Abfahrt wählt er Ladung (Treibstoff/Munition/Holz in drei Schiebern), Route (Brücke West, Brücke Ost, Furt) und Zeitpunkt. Die KI schlägt einen Standardfahrplan vor, und der Mensch verschiebt nur. | Große Kolonne (effizient, auffällig) oder zwei kleine (verteilt das Risiko)? Jetzt fahren oder auf Begleitschutz warten? | Die Kolonne fährt sichtbar los, die Ankunftszeit steht an jedem Lager. Fasslager und Munitionszelt füllen sich physisch (M3). |
| L2 | **Begleitschutz anfordern.** Eine Anfrage mit Abfahrtszeit geht an Flieger (Anfragen-Bus, Kopfgeld vom Kommandanten). Ein Konvoi mit Schutz verliert bei Angriffen deutlich weniger. | Verzögern für Schutz oder sofort fahren? | Flieger bekommen einen klaren Auftrag mit Luftkampf-Chance (Nuclear-Option-Schleife). |
| L3 | **Verteilung und Priorität.** Die Lager (Flugplatz 1, Flugplatz 2, Flak-Lager, Bauhof-Holz) stehen in Konkurrenz. Er setzt Mindestbestände und Rangfolge. Leere Lager blockieren Starts (GDD §3). | Wohin geht knapper Treibstoff? Flak-Munition vor Bomben? | Gleich am nächsten Abstellplatz: „Fasslager leer, Ersatzbenzin“ oder eben nicht. |
| L4 | **Engpass-Ansicht und Schichten (Wirtschaft light).** Jedes Werk zeigt genau einen Grund für Stillstand (Baustein 5). Er stellt die Produktion um (Munitionsfabrik: MG-Gurte ↔ Bomben) und kann für 5 min eine **Sonderschicht** anordnen (+30 % Ausstoß, danach 3 min −30 %, Abklingzeit). | Wann lohnt die Sonderschicht, z. B. vor einem geplanten Großangriff? | Mehr Bomben sind genau dann im Lager, wenn der Kommandant den Großangriff auslöst (Synergie K2). |
| L5 | **Täuschen und Umleiten.** Ein Leerkonvoi dient als Köder (zieht Feind-KI an, kostet nur Treibstoff). Melden Posten einen Feindjäger, kann er Kolonnen per Klick in einen Wald-Halt schicken (Tarnung, 2 min Pause). Optional fährt er eine Kolonne selbst (Lkw aus M3) und bekommt +10 % Fahrtempo durch die Führung. | Halten oder durchfahren? Ködern lohnt sich wann? | Funk: „Kolonne 2 verdeckt im Wald, Feindjäger dreht ab“. Gelingt der Köder, ist ein echter Konvoi sicher durch. |

**Wertung:** gelieferte Tonnen, Lieferquote (angekommen/abgefahren), „ermöglichte Starts“ (Kettenkredit), verlorene Kolonnen. Auszeichnung: „Rückgrat“ (die meisten ermöglichten Starts).
**KI-Automatik:** Den Standardfahrplan fährt die KI selbstständig. Der Mensch greift nur ein, wenn die Lage es verlangt (Ausnahmesteuerung). Be- und Entladen ist immer automatisch (Foxhole/Reforger-Lehre).
**Gegen Langeweile:** Kein Kistenschleppen, nur Entscheidungen. Der Gegner (Konvoi-Jagd der KI) sorgt für regelmäßige Krisen. Für Spieler, die Ruhe mögen (EVE-Lehre), funktioniert die Rolle auch im entspannten „Fahrdienstleiter“-Tempo.

---

### 3.3 Bauleiter

**Was er jede Minute tut:** Er schaut auf die Bauliste und den Zustand der Bautrupps, sortiert nach Treffern um, entscheidet zwischen Behelf und gründlicher Reparatur, und in ruhigen Phasen plant er den Ausbau.

| # | Mechanik | Entscheidung | Wie das Team es spürt |
|---|---|---|---|
| B1 | **Reparatur-Reihenfolge unter Angriff.** Eine Warteschlange per Ziehen und Ablegen für die 2 Bautrupps. Die Trupps fahren sichtbar über die Straßen (Baustein 11). Ein Bautrupp, der in eine Zone mit aktivem Angriff fährt, kann verloren gehen (5 min Ersatz). | Erst Fasslager (Starts) oder Raffinerie (Nachschub)? Jetzt hineinfahren oder abwarten? | Gerüste stehen, und der Fortschritt erscheint auf der Karte und am Gebäude. Funk: „Fasslager wieder in Betrieb“. |
| B2 | **Behelf oder gründlich.** Die Behelfsreparatur bringt ein Gebäude in 50 % der Zeit auf 60 % Leistung, ist aber bei einem neuen Treffer sofort wieder zerstört. Die gründliche Reparatur kostet die volle Zeit und bringt 100 %. | Schnell wieder starten oder robust werden? | Die Flieger merken es an Startbereitschaft und Lagerfüllung. |
| B3 | **Attrappen und Tarnung.** Aus Holz baut er Schein-Flugzeuge, Schein-Fasslager oder eine Schein-Flakstellung (60–120 s, wenig Holz), dazu Tarnnetze über echten Lagern (Feind-KI-Aufklärung erkennt das Ziel schwerer). | Wo binde ich Feindbomben, wo verstecke ich das Echte? | Funk: „Feind bombardiert Attrappe Nord“. Die Bilanz zählt „Bomben auf Attrappen“. Der gegnerische Kommandant (PvP) muss Fotos genauer prüfen (Synergie K4). |
| B4 | **Vorausschauender Ausbau.** Splitterschutzwälle um Abstellplätze, zweites Fasslager als Reserve, Behelfsbrücke an der Furt (wird sichtbar zum Feindziel). Kosten: Holz und Bautrupp-Zeit, die dann bei Reparaturen fehlt. | Investieren in Redundanz oder Bautrupps frei halten? | Nach dem nächsten Angriff sieht man den Unterschied (Wall fängt Splitter ab, Reservelager springt ein). |
| B5 | **Baustelle selbst anführen (optional, 3D).** Steht der Bauleiter als Figur an der Baustelle, ist der Trupp 25 % schneller. Unter Beschuss bleibt er allerdings gefährdet (Ausfall 2 min). Krater auf der Piste füllt er mit Bodenpersonal zusammen. | Am Kartentisch alles im Blick oder vor Ort Tempo? | Andere Spieler sehen ihn arbeiten. Das passt zu Säule 2. |

**Wertung:** wiederhergestellte Kapazität in Gebäude-Minuten, Bomben auf Attrappen, Ausfallzeit gegenüber KI-Standard (wie viel schneller als die KI). Auszeichnung: „Wiederaufbau“.
**KI-Automatik:** Die KI repariert immer in fester Reihenfolge nach Kriegskraft-Gewicht (Untergrenze, P12). Der Mensch gewinnt durch Situationsgespür (welches Gebäude jetzt gebraucht wird, z. B. vor einem Alarmstart).
**Gegen Langeweile:** Zwischen Angriffen füllen Ausbau (B4) und Attrappen (B3) die Zeit, und das bringt beim nächsten Angriff sichtbare Wirkung.

---

### 3.4 Luftverteidigungs-Koordinator

**Was er jede Minute tut:** Er liest neue Postenmeldungen und schiebt Plots auf dem Tisch, beurteilt Kurs und Größe, entscheidet über Alarm und weist Jägern Vektoren zu.

| # | Mechanik | Entscheidung | Wie das Team es spürt |
|---|---|---|---|
| V1 | **Plot-Tisch mit unsicheren Meldungen.** Beobachtungsposten melden Richtung, geschätzte Höhe und „ca. 3–6 Maschinen“. Der Koordinator schiebt Plot-Marker und legt per Ziehen einen geschätzten Kurs fest. Das System zeigt mögliche Ziele mit Ankunftszeit. *Highfleet-Prinzip.* | Wohin fliegt das? Wie viele sind es wirklich? | Je besser die Schätzung, desto genauer und früher die Warnung an alle („Roter Verband, Kurs Raffinerie, 3:20“). |
| V2 | **Alarmstart auslösen.** Er entscheidet über Alarmstart (startet den Countdown aus M3 für das Bodenpersonal) und über die Anzahl Maschinen. Ein Fehlalarm kostet Treibstoff und bindet Maschinen, ein verspäteter kostet Schaden. | Jetzt alarmieren oder auf zweite Meldung warten (Finte)? | Sirene, das Bodenpersonal rennt, Flieger bekommen einen Startbefehl. Das verbindet drei Rollen in einem Moment. |
| V3 | **Jäger-Vektoren.** Er wählt einen Plot und einen Jäger (Spieler oder KI) aus, und der Pilot bekommt im HUD einen Pfeil mit Kurs und Höhe sowie per Funk „Vektor 090, Engel 2“. Abschüsse innerhalb von 3 min nach Vektor zählen als Assist für den Koordinator. | Welcher Jäger auf welchen Verband? Bomber oder Begleitschutz zuerst? | Spieler-Jäger finden den Gegner schneller (P5). Ohne Koordinator zeigt die KI nur einen groben Sektor. |
| V4 | **Posten und Flak einteilen.** 4–6 Beobachtungsposten werden auf festen Plätzen gesetzt und umgesetzt (Abdeckung gegen tote Winkel). Später kommen 3–4 mobile Flak-Batterien (Verlegung 3 min) und **Feuerzonen**: „Korridor frei“ schützt eigene heimkehrende Flieger. | Wo sind die Lücken? Heimkehrer schützen oder alles beschießen? | Weniger Überraschungsangriffe, und eigene Flieger werden nicht von der Flak getroffen. |
| V5 | **Selbst an die Flak.** Mit einer Taste springt er bei einem Angriff an ein Geschütz (Flak-Sitz). Der Plot läuft automatisch weiter. *Battlestations-Prinzip.* | Leiten oder selbst schießen? | Ein sichtbarer Mitspieler am Geschütz. |

**Wertung:** gewonnene Vorwarnzeit gegenüber KI-Standard, Abfangquote (Verbände vor dem Ziel angegriffen), Vektor-Assists, Fehlalarme. Auszeichnung: „Adlerauge“.
**KI-Automatik:** Die KI alarmiert erst nach der zweiten bestätigten Meldung und vektorisiert grob nach Sektor. Der Mensch gewinnt 60–90 s Vorwarnung und präzisere Vektoren.
**Gegen Langeweile:** Bei einer KI-Nation kommen Angriffe alle 5–8 min, dazwischen Aufklärer und Einzeljäger als kleine Plots. Ruhige Phasen füllt die Posten-Planung, die Feuerzonen und das Zuhören, was die Posten über Konvoi-Gefahren melden (Hinweis an Logistik, Synergie L5).

---

### 3.5 Bodenpersonal (bereits spielbar, erweitern)

**Was er jede Minute tut:** Maschinen abfertigen (M3), Befehle über das Befehlsrad an KI-Helfer, Wagen fahren. Neu sind Entscheidungen und Fortschritt, die über das Abarbeiten hinausgehen.

| # | Mechanik | Entscheidung | Wie das Team es spürt |
|---|---|---|---|
| G1 | **Schadensbefund.** Eine beschädigte Maschine zeigt beim Rundgang Zonenschäden. Der Mechaniker entscheidet: Flicken (90 s, Start mit Restrisiko, z. B. 15 % mehr Schaden bei Treffer in der Zone) oder Werkstatt (4–6 min, wieder 100 %). | Pilot schnell zurück in die Luft oder sicher? | Der Pilot sieht den Zustand im Cockpit und kann den Mechaniker per Funk bitten („bitte flicken, Alarm läuft“). |
| G2 | **Vorbestellung per Funk.** Vor der Landung bestellt der Pilot per Kurzbefehl „Voll“, „Schnell“ oder „Bomben“. Der Mensch am Boden stellt Wagen und Kisten am Abstellplatz bereit, und die Abfertigung startet ohne Wartezeit. | Welcher Abstellplatz, welche Maschine zuerst, wenn drei gleichzeitig landen? | Spürbar kürzere Standzeit. Die Bilanz des Piloten nennt den Mechaniker. |
| G3 | **KI-Helfer ausbilden.** Jede Abfertigung, die ein Spieler gemeinsam mit einem KI-Helfer abschließt, bringt dem Helfer Erfahrung. Es gibt 3 Stufen mit je +8 % Tempo. Das bleibt auch, wenn der Spieler danach fliegt. | Wen bilde ich aus (Tankwart oder Waffenwart)? | Dauerhafter, sichtbarer Einfluss auf den Flugplatz, auch nach Rollenwechsel (Abzeichen über dem KI-Helfer). |
| G4 | **Bestzeiten-Tafel und Teamwertung.** Die Abfertigungszeiten aus M3 werden zu einer Tafel im Hangar („Boxencrew der Partie“) mit Bestzeit pro Maschinentyp und Alarmstart-Rekord, dazu ein Ehrenvermerk in der Bilanz des Piloten. | Risiko gegen Tempo (Schnellabfertigung: 50 % Tank). | Ein sichtbarer Wettbewerb, ein Grund, die Rolle gern zu spielen. |
| G5 | **Flugplatz-Notfälle.** Nach Angriffen brennen Fässer oder liegt ein Wrack auf der Piste, Krater müssen gefüllt werden. Das sind kurze Ereignisse mit Timer, alle KI-Helfer können helfen, der Mensch beschleunigt. Optional fährt er den Rettungs-Lkw für ausgestiegene Piloten über eigenem Gebiet (GDD §6.4). | Was zuerst: Brand löschen oder Piste räumen? | Die Startfähigkeit kommt schneller zurück, der gerettete Pilot ist schneller wieder da. |

**Wertung:** Abfertigungen, Durchschnittszeit gegenüber KI, ermöglichte Starts, Ausbildungsstufen, Notfälle. Auszeichnung: „Boxencrew“.
**KI-Automatik:** Die KI fertigt nach Prioritätenliste ab (M3). Der Mensch bringt Tempo, Vorbestellung und Befund-Entscheidungen.
**Gegen Langeweile:** In der Wartezeit zwischen Landungen fallen Ausbildung (G3), Wagen nachfüllen und Notfälle (G5) an. Seltene, aber planbare Spitzen sind die Landewellen und der Alarmstart.

---

### 3.6 Rollen-Synergien auf einen Blick

| Auslöser | → wer reagiert | Was passiert |
|---|---|---|
| Kommandant setzt Großangriff (K2) | Logistik (Sonderschicht Bomben, L4), Bodenpersonal (Bomben laden) | Die Welle startet voll beladen |
| Logistik fordert Begleitschutz (L2) | Flieger, Kommandant (Kopfgeld K3) | Luftkampf über der Straße |
| Posten meldet Verband (V1) | Kommandant (Absicht deuten K5), Bau (Bautrupps zurückziehen B1), Logistik (Kolonne in Wald-Halt L5) | Schaden wird kleiner |
| Alarmstart (V2) | Bodenpersonal (Countdown, G1/G2), Flieger | Sirene, alle drei Rollen in einem Moment |
| Feind trifft Fasslager | Bau (B1/B2), Logistik (Umleitung auf Platz 2, L3), Kommandant (Notreparatur K2) | Wiederanlauf in Minuten statt Viertelstunden |
| Attrappe getroffen (B3) | Kommandant (Foto-Tisch beim Gegner, K4) | Gegner verschwendet Bomben |

---

## Teil 4: Welche Wirtschafts-Variante trägt Support-Rollen am besten?

**Bewertung nach Rolle** (++ trägt stark, + trägt, o neutral):

| Rolle | A Klare Kette | B Front-Sektoren | C Nachschub-Netz |
|---|---|---|---|
| Kommandant | ++ klare Ziele mit Wirkungsvorschau | ++ Haltung pro Abschnitt | + Abfangfenster |
| Logistik/Wirtschaft | o wenig laufende Entscheidungen | + Frontdepots verteilen | ++ Fahrplan, Routen, Begleitschutz, Köder |
| Bau | + Reparatur der Kette | + eroberte Gebäude | ++ Brücken, Behelfsbrücken, Zwischenlager |
| Luftverteidigung | + Schlüsselziele schützen | + Front und Hinterland | ++ Konvoi-Schutz, häufige kleine Plots |
| Bodenpersonal | + | + | + (direkter Lagerbezug) |
| Takt gegen Leerlauf | mittel (Angriffswellen) | hoch | hoch (jeder Konvoi ist ein Ereignis) |

**Empfehlung: A als Gerüst mit dem Kern von C („A+C“).** Das bestätigt die Richtung der Wirtschafts-Recherche, jetzt mit Begründung aus Sicht der Rollen:
1. **C liefert den Takt.** Konvoi-Abfahrten, Postenmeldungen über Straßen und Brückenschäden erzeugen alle 2–4 min eine Entscheidung für Logistik, Bau und Luftverteidigung (P6). Bei reinem A haben diese Rollen zwischen Angriffswellen zu wenig zu tun.
2. **A liefert die Lesbarkeit für den Kommandanten.** Acht Gebäude mit Ampeln und Kriegskraft-Vorschau machen seine Entscheidungen verständlich und die Wirkung sofort sichtbar (P1).
3. **C nutzt M3 voll.** Die physischen Lager und Wagen machen die Arbeit der Logistik am Abstellplatz spürbar, eine direkte Verbindung zum Bodenpersonal.
4. **B trägt den Kommandanten am stärksten, die anderen Support-Rollen aber kaum mehr als A+C**, und er kostet viel Technik (Bodenfront). Er bleibt der richtige Kandidat für einen späteren Meilenstein mit größeren Karten.

**Was aus C für M4 genügt:** Fahrplan mit 3–4 Kolonnen + 1 Zug, 2 Brücken + 1 Furt, 1 Zwischenlager an einer Kreuzung, Konvoi-Abfangaufträge (Baustein 7). Fabriken bleiben als Schlüsselziele aus A (stark geschützt, Wirkungsvorschau). Keine Schiffe, keine tiefen Rezepte.

---

## Teil 5: Vorschlag für den M4-Umfang

**Grundidee: wenige, dichte Sitze.** Bei 1–4 Spielern wird ein Sitz mit zu wenig Arbeit sofort langweilig. M4 bündelt deshalb die Katalogrollen (GDD §5.1 bleibt gültig) in **drei spielbare Nicht-Flug-Sitze** plus Bodenpersonal. Bei mehr Spielern lässt sich ein Bündel später teilen.

1. **Sitz „Kommandant“ (ausbauen):** Schwerpunkt-Marker mit XP-Bonus (K1), Befehlspunkte mit 3 Befehlen (Großangriff, Notreparatur, Sonderkonvoi; K2), Auftragstafel mit Kopfgeld (K3). Foto-Tisch (K4) als Kann-Ziel.
2. **Sitz „Nachschub“ (neu, Logistik + Wirtschaft light):** Fahrplantafel mit Konvoi-Fenstern (L1), Begleitschutz-Anfrage (L2), Lager-Priorität (L3), Engpass-Ansicht mit Sonderschicht (L4). Be- und Entladen immer automatisch.
3. **Sitz „Platzleitung“ (neu, Bau + Luftverteidigung light):** Reparatur-Warteschlange mit Behelf/gründlich und sichtbaren Bautrupps (B1, B2), ein Attrappen-Typ (Schein-Flugzeug, B3). Plot-Tisch aus Postenmeldungen, Alarmstart-Entscheidung und Jäger-Vektoren (V1–V3). Flak-Verlegung und Feuerzonen folgen mit der bemannbaren Flak im nächsten Meilenstein.
4. **Bodenpersonal erweitern:** Schadensbefund (G1), Vorbestellung per Funk (G2), Bestzeiten-Tafel (G4). Die KI-Ausbildung (G3) ist günstig und hat starke Wirkung, gern mitnehmen.
5. **Wirtschaft A+C:** acht Gebäude aus Variante A, Fahrplan-Netz aus C (Kolonnen, Zug, 2 Brücken, Furt, 1 Zwischenlager), Konvoi-Abfangaufträge.
6. **Dienstbilanz und Kettenkredit** für alle Nicht-Flieger (3.0 A/B), mit Highlight-Zeile und drei Auszeichnungen am Partieende.
7. **Anfragen-Bus** zwischen Mensch- und KI-Rollen mit Frist und Kurzbefehl im Flug (3.0 C). **Übergabezettel** beim Einsteigen ins Cockpit (3.0 D).
8. **KI-Untergrenze pro Sitz:** jede Rolle voll spielbar durch die KI, aber mit Reaktionszeit von 60–120 s, damit ein Mensch messbar hilft (P10).
9. **Leitplanken:** 30 s Rückgängig, Drossel für destruktive Aktionen, öffentliches Aktionsprotokoll, Abwahl mit sichtbarem Initiator und Mindestquote (P11).
10. **Messbares Testziel:** In einem Test mit 3 Spielern bleibt einer 30 min in „Nachschub“ oder „Platzleitung“. Gemessen werden Entscheidungen pro Minute (Ziel ≥ 1), die längste Pause ohne Ereignis (Ziel < 90 s), Kettenkredit-Anteil an Starts und Abschüssen sowie eine Kurzumfrage („Warst du wichtig?“, „Hast du dich gelangweilt?“). Erst danach werden weitere Rollen geteilt oder neue gebaut.

**Nicht in M4:** eigener Forschungsleiter-Sitz (bleibt KI mit Vorschlagsleiste), bemannbare Flak und Flak-Verlegung, Bodenfront (Variante B), Lufttransport, PvP-spezifische Täuschung (Funktäuschung wirkt in M4 nur gegen die KI).

---

## Quellen
- NS2-Forum, mehr Aufgaben für Commander: https://forums.unknownworlds.com/discussion/comment/1737645
- NS2-Forum, Erfahrung mit Commandern: https://forums.unknownworlds.com/discussion/comment/2108579
- NS2-Forum, Spiel hängt zu sehr am Commander: https://forums.unknownworlds.com/discussion/comment/1833944
- NS2-Forum, Abwahl-Griefing: https://forums.unknownworlds.com/discussion/125697/ideas-to-thwart-commander-eject-griefing
- Battlefield Wiki, Commander: https://battlefield.fandom.com/wiki/Commander_(Feature)
- Gamepressure, BF2142 Commander: https://www.gamepressure.com/battlefield2142/commander/z3694
- EA-Forum, Commander zurückbringen: https://forums.ea.com/discussions/battlefield-6-general-discussion-en/the-commander-must-be-reintroduced/13153495/replies/13193185
- PC Gamer, Hell Let Loose und Rollenspieler: https://www.pcgamer.com/ww2-shooter-hell-let-loose-is-only-made-better-by-diehard-roleplayers
- PC Gamer, HLL Nachschub-Lkw: https://www.pcgamer.com/au/hell-let-loose-adds-supply-trucks-and-bullet-penetration-to-its-very-pretty-ww2/
- Steam, HLL Commander-Diskussion: https://steamcommunity.com/app/686810/discussions/0/3196988875699215162
- Steam, HLL Knoten und Support: https://steamcommunity.com/app/686810/discussions/0/4517758633229547662
- All Things How, HLL Vietnam Kommandant: https://allthings.how/hell-let-loose-vietnam-how-to-play-the-commander-role/
- Guild Order, Squad FOB und Logistik: https://guildorder.com/games/squad/wiki/fob-placement-and-logistics-doctrine
- PCGamesN, Foxhole Logistik: https://www.pcgamesn.com/foxhole/logistics-hero
- NME, Foxhole-Streik und Folgen: https://www.nme.com/features/how-a-logistics-strike-in-foxhole-created-a-war-like-no-other-3163884
- GamesRadar, Foxhole-Streik: https://www.gamesradar.com/a-group-of-mmo-players-are-threatening-an-in-game-strike-to-fix-issues-with-their-role
- MMOBomb, PlanetSide 2 Bausystem-Überarbeitung: https://www.mmobomb.com/news/planetside-2-construction-system-will-get-an-overhaul-so-builders-can-make-bases-that-players-enjoy-fighting-at
- Devtrackers, PlanetSide 2 Zugführer-Feedback: https://devtrackers.gg/planetside/p/56773028-the-shattered-warpgate-actual-feedback-from-a-platoon-leader-in-the-first-session
- SI.com, Silica-Vorschau: https://videogames.si.com/features/silica-early-access-preview
- Shockbyte, Silica Commander oder Infanterie: https://shockbyte.com/blog/silica-beginners-guide-commander-or-infantry
- GamesRadar, Savage 2 Review: https://www.gamesradar.com/savage-2-a-tortured-soul-review
- Skyward FM, Nuclear Option Tarantula: https://www.skywardfm.com/posts/nuclear-option:-tactical-tarantula
- Noobfeed, Barotrauma Review: https://www.noobfeed.com/reviews/2037/barotrauma-pc-review
- Steam, Barotrauma-Geschichten: https://steamcommunity.com/app/602960/discussions/0/1644304412670026117
- Steam, Sea of Thieves Rollen: https://steamcommunity.com/app/1172620/discussions/5/4348869643730918170
- Game Developer, Space Station 13 Fallstudie: https://www.gamedeveloper.com/design/space-station-13-a-case-study-in-emergent-gameplay-and-system-heavy-design
- GameSpot, Battlestations Midway Review: https://www.gamespot.com/reviews/battlestations-midway-review/1900-6165086/
- Kotaku, EVE Space-Trucker: https://kotaku.com/one-of-eve-onlines-most-challenging-jobs-is-being-a-spa-1835703889
- VideoGamer, EVE „langweilige“ Features: https://www.videogamer.com/news/eve-players-like-the-boring-features-says-lead-producer/
- Bohemia Wiki, Arma 3 Zeus: https://community.bistudio.com/wiki/Arma_3_Field_Manual_-_Zeus
- Bohemia Wiki, Arma Reforger Conflict: https://community.bistudio.com/wiki/Arma_Reforger:Conflict
- Reddit (Spiegel), Reforger Nachschubfahrten: https://reddit.birdcat.cafe/r/ArmaReforger/comments/1ju1wni/how_do_ppl_fr_like_doing_supply_runs
- Enlisted-Forum, Punkte für Sammelpunkte und Munitionskisten: https://forum.enlisted.net/t/increase-points-given-for-rally-points-and-ammo-boxes/90593
- Highfleet: siehe Quellen in `recherche_m4_wirtschaft.md`

Hinweise: Einzelheiten zu BF2-Commander-Werkzeugen (Artillerie, Fahrzeugabwurf) und zu Sea of Thieves stützen sich teils auf allgemeines Spielwissen. Forenaussagen sind Einzelmeinungen und geben die Stimmung wieder, keine repräsentative Erhebung. Alle Zahlen in Teil 3 und 5 (Prozente, Zeiten, Punkte) sind Startwerte für den Playtest.
