# Game Design Document – Kurzfassung v2 (dynamischer Krieg)

Arbeitstitel: *Flugzeug Spiel* · PC/Steam · Godot 4 · stilisiert-realistisch
Status: Entwurf. Er enthält folgende Entscheidungen des Product Owners: dynamischer Krieg statt Missionen, Koop UND PvP auf einer Karte, übernehmbare Nicht-Flug-Rollen inklusive Verteidigung. Wo hier nichts Neues steht, gelten Bodenbetrieb, Crew-Rollen und Flugmodi aus `game_design_v1.md` weiter.

---

## 1. Pitch und Design-Säulen

**Pitch:** Mehrere Nationen ringen auf einer großen Karte um die Vorherrschaft am Himmel. Jede baut Wirtschaft, Flugplätze und Forschung auf und arbeitet sich vom Doppeldecker zum Jet hoch. Du fliegst, betankst, planst, verteidigst oder kommandierst: Jede Aufgabe deiner Nation ist ein Platz, den du übernehmen kannst. Wer zurückfällt, fliegt mit älterer Technik gegen bessere Flugzeuge.

**Säulen:**
1. **Krieg ist Logistik.** Jede Bombe wirkt auf eine sichtbare Versorgungskette, bei den Gegnern wie bei dir.
2. **Hände an der Maschine.** Bodenbetrieb, Flak und Kartentisch sind Gameplay im 3D-Raum, keine reinen Menüs. Das leere Fass im Lager ist die Folge der zerstörten Raffinerie.
3. **Jede Rolle ist ein Sitz, Mensch oder KI.** Das gilt für Pilot, Bordschütze, Tankwart, Flak-Richtschütze und Forschungsleiter genauso wie für den Kommandanten. Die KI füllt jeden Platz aus, Spieler übernehmen ihn jederzeit und geben ihn wieder ab.

---

## 2. Core Loop

- **Minute-zu-Minute:** Luftkampf, Bodenbetrieb, Flak bedienen, Abfangjäger am Plot-Tisch leiten, Konvois umleiten.
- **Einsatz (15–40 min):** Lage → Ziel → Vorbereitung aus den tatsächlichen Lagerbeständen → Flug → Wirkung → Rückkehr → Schadensbericht auf der Karte.
- **Strategie (Stunden):** Produktion, Forschung, Ausbau und Verteidigung priorisieren. Gegnerische Engpässe aufklären und treffen.
- **Kampagne (15–40 h):** Durch fünf Tiers aufsteigen, schneller als die Gegner, bis eine Seite kapituliert.

---

## 3. Wirtschafts- und Versorgungsmodell („light“)

### 3.1 Kette

```
ROHSTOFFE          VERARBEITUNG              PRODUKTION / FORSCHUNG       VERBRAUCH
Holz  (Wald)  ──▶  Sägewerk      ─┐
Erz   (Mine)  ──▶  Hütte (Stahl) ─┼──▶  Flugzeugwerk  ─────────┐
Bauxit(Mine)  ──▶  Alu-Werk (T3+)─┘     Munitionsfabrik ───────┼──▶ Depot ──▶ Flugplatz-/Flak-Lager ──▶ Bodenbetrieb, Flak
Öl  (Ölfeld)  ──▶  Raffinerie (Benzin/Kerosin) ────────────────┘   (Bahn/Straße/Konvoi)
                   Kraftwerk ──(Strom im Radius)──▶ Werke, Forschungsinstitut, Radar, Scheinwerfer
                   Forschungsinstitut ──▶ Forschungspunkte
```

| Ebene | Gebäude | Output | Typische Schwachstelle |
|---|---|---|---|
| Rohstoff | Wald, Erzmine, Ölfeld, Bauxitmine (T3+) | Rohstoff/h | Förderanlage, Abtransport |
| Verarbeitung | Sägewerk, Hütte, Raffinerie, Alu-Werk | Bauholz, Stahl, Treibstoff (Oktanstufe nach Forschung), Aluminium | Raffinerie: großes Ziel, lange Reparatur |
| Energie | Kraftwerk | Strom im Netzradius | Ausfall drosselt alle Abnehmer |
| Produktion | Flugzeugwerk, Munitionsfabrik | Flugzeuge, Munition (auch Flak), Bomben, später Raketen | Endmontage |
| Forschung | Institut, Versuchsflugplatz | Forschungspunkte | klein, hoher Wert |
| Logistik | Bahn, Brücke, Straße, Depot, Konvoi | Ladungen/h | Brücken, Knotenbahnhöfe |

Lesbarkeit: 4 Rohstoffe, 4 Zwischenprodukte, 3 Endprodukte (Flugzeuge, Munition, Treibstoff) und Forschungspunkte. Jedes Gebäude zeigt auf der Karte Symbol und Füllstand. Ein Klick zeigt Herkunft und Abnehmer.

### 3.2 Schäden

| Zustand | Leistung | Wiederherstellung |
|---|---|---|
| Intakt | 100 % | – |
| Beschädigt | 50 % | Reparatur 2–8 h Strategie-Zeit, wenig Material |
| Zerstört | 0 % | Wiederaufbau 12–48 h, viel Material, Bautrupp nötig |

- **Bautrupps sind begrenzt** (z. B. 3 pro Nation, mehr über Forschung). Weil sich die Aufträge in einer Warteschlange stauen, wirken Angriffswellen stärker als Einzelschläge.
- **Folgeschäden:** Fällt das Kraftwerk aus, verlieren alle Abnehmer 50 % Leistung. Fehlt eine Brücke, fließt der Verkehr über einen Umweg mit 70 % weniger Durchsatz. In getroffenen Lagern geht Bestand verloren.
- **Schutz:** Flak, Tarnung, Splitterwälle und verteilte Lager kosten Bauleistung und senken den Schaden (siehe 7.4).

### 3.3 Versorgung des Flugplatzes

Tanklager, Munitionsbunker, Ersatzteil- und Flak-Munitionslager haben **physische Bestände**. Sie werden durch sichtbare Konvois und Züge aufgefüllt.
- Ein leeres Lager bedeutet: kein Fass, kein Tankwagen, die Maschine bleibt am Boden. Die Flak verstummt.
- **Treibstoffqualität:** Fällt die Hochoktan-Raffinerie aus, gibt es nur Ersatzbenzin. Motorleistung und Steigrate sinken spürbar. Jets ohne Kerosin starten nicht.
- **Munitionsknappheit:** Teilbeladung, Gurte müssen rationiert werden, Flak schießt nur noch auf Befehl.
- **Eigene Konvois** sind Begleitschutz-Ziele, der Gegner jagt sie.

Die Infrastruktur-Voraussetzungen pro Tier aus v1 gelten weiter. Dazu kommt eine **industrielle Voraussetzung**:

| Tier | Flugzeuge (Beispiel) | Flugplatz (Details v1) | Industrie | Verteidigung (neu) |
|---|---|---|---|---|
| I | Doppeldecker-Jäger, Aufklärer | Gras 400 m, Fässer | Sägewerk, kleine Raffinerie | Beobachtungsposten, MG-Flak, Attrappen |
| II | Eindecker-Jäger, mittlerer Bomber | Schotter 800 m, Tankwagen | Hütte, Munitionsfabrik | leichte Kanonen-Flak, Horchgerät, Sperrballone |
| III | Kolben-Jäger, schwerer Bomber | 1.400 m befestigt, Hochoktan | Raffinerie St. 2, Kraftwerk, Alu-Werk | schwere Flak, Scheinwerfer, Radar St. 1 |
| IV | Strahljäger, Strahlbomber | Beton 2.000 m, Kerosin | Raffinerie St. 3, Turbinenwerk | radargeleitete Flak, Bodenleitradar |
| V | Mehrzweckjet, Zweisitzer | Beton 2.500 m, Shelter | Elektronikwerk, Lenkwaffenfabrik | Flugabwehrraketen, Datenlink |

**Forschung** verbraucht Forschungspunkte. Die Zweige aus v1 bleiben, dazu kommt ein 8. Zweig **Luftverteidigung** (Flak, Feuerleitung, Ballone, Tarnung, Frühwarnung). **Technologiefluss:** Technik, die eine andere Nation schon besitzt, kostet 30 % weniger. Für geborgene Feindwracks gibt es Bonuspunkte.

---

## 4. Strategische KI der Nationen

**Fairness:** Die KI hat dieselben Regeln und dieselbe Wirtschaft wie die Spieler, ohne versteckte Boni. Der Schwierigkeitsgrad steuert nur Reaktionszeit, Planungstiefe und Aggressivität.

**Aufbau aus Rollen-KIs:** Eine KI-Nation ist die Summe derselben Rollen-KIs, die in Spieler-Nationen leere Plätze füllen (Kommandant, Wirtschaft, Forschung, Logistik, Bau, Luftverteidigung, siehe 7). Jede Rolle ist ein Utility-Planer, der alle 1–2 Strategie-Stunden neu bewertet. Der KI-Kommandant gewichtet die Rollen nach seiner Persönlichkeit:

| Typ | Verhalten | Forschungsweg |
|---|---|---|
| Industrieller | baut breit aus, verteidigt stark, greift spät an | Logistik, Werkstatt, Luftverteidigung |
| Aggressor | viele Jäger, frühe Flugplatz-Angriffe | Bewaffnung, Jäger |
| Bomberdoktrin | wenige, schwere Schläge auf Industrie | Bomber, Navigation |
| Techniker | rennt zur nächsten Ära, verteidigt dünn | Flugzeugbau, Forschung |

**Berechenbarkeit:**
- **Angriffe kündigen sich an:** Die KI sammelt Maschinen und Treibstoff sichtbar am Frontflugplatz. Aufklärung erkennt das 1–3 h im Voraus.
- **Doktrin-Profil:** Nach genug Aufklärung kann man es einsehen.
- **Wiederaufbau ist sichtbar** (Gerüst, Bautrupp), damit gezieltes Nachsetzen möglich ist.

**Gegen Schneeball-Effekte:** Gegen eine übermächtige Nation bilden die KI-Nationen eine angekündigte Koalition. Die KI-Nationen bekämpfen sich auch untereinander.

**Leistung:** Nahe bei Spielern wird voll simuliert, entfernt abstrakt mit denselben Erwartungswerten.

---

## 5. Wie aus der Sandbox Ziele entstehen

- **Aufklärung:** Feindliche Anlagen liegen im Nebel des Krieges. Fotoflüge, Radar und Funkabhörung decken sie auf. Infos **altern**, ein zwei Tage alter Lagerbestand ist unsicher.
- **Lagebesprechung:** Der Kommandant (Mensch oder KI) bekommt 3 Zielvorschläge mit Wirkung und Risiko. Beispiel: „Raffinerie Nord: Feindtreibstoff −40 % für ca. 36 h, starke Flak“. Freies Markieren ist möglich.
- **Dynamische Aufträge:** Feindkonvoi entdeckt (20-min-Fenster), eigener Konvoi braucht Begleitschutz, Wiederaufbau des Feindes fast fertig, Wrack bergen, Crew retten.
- **Alarmstarts:** Beobachtungsposten bzw. Radar melden Verbände. Die Vorwarnzeit hängt vom Ausbau ab und wird vom Luftverteidigungs-Koordinator ausgelöst (siehe 7.4).
- **Kriegsziele:** Etwa „Gegner vor Tier III abschneiden“. Sie bringen Prestige, das man in Bautrupps oder Personal umsetzt.
- **Aufträge an andere Rollen:** Rollen schicken einander Anfragen. Die Logistik fordert Begleitschutz an, die Forschung einen Erprobungsflug, die Luftverteidigung Jäger. Spieler nehmen sie an, sonst übernimmt die KI.

---

## 6. Zeitmodell

- **Eine gemeinsame Kriegsuhr.** Echtzeit 1:1 läuft, solange jemand fliegt, kämpft oder unter Alarm am Boden arbeitet.
- **Koop-Welten:** Zeitraffer bis 60× ist zwischen Einsätzen möglich, wenn alle zustimmen. Er stoppt automatisch bei Radarwarnung, Konvoi-Sichtung oder fertigem Bau. Pausieren ist nur solo möglich.
- **PvP-Welten:** Fester Weltfaktor statt Zeitraffer, z. B. 4× für Bau und Forschung, Flug immer 1:1 (siehe 9).
- **Speichern:** Der Host bzw. Server speichert automatisch bei Landungen und alle 10 min. Clients behalten Profil und Ränge.
- **Tempo:** Ein Tier dauert 3–8 h. Koop-Sitzungen sind 60–120 min lang, eine Kampagne 15–40 h, kleine Karten 4–8 h.

---

## 7. Rollen der Nation: „Jede Rolle ist ein Sitz“

### 7.1 Rollen, Befugnisse, Werkzeuge

Jede Rolle ist ein **Seat** im bestehenden Sitz-System. Spieler und KI liefern dieselben Befehle, nur über andere Werkzeuge. Jede Rolle hat einen festen Ort in der 3D-Basis, ist aber auch per Tablet- bzw. Kartenansicht erreichbar. Unterwegs ist der Zugriff nur lesend.

| Rolle | Befugnisse | Werkzeug | Was sie spannend macht |
|---|---|---|---|
| **Kommandant** | Budgetaufteilung zwischen den Rollen, Zielauswahl, Aufträge an KI-Staffeln, Rollen vergeben, Diplomatie | Strategiekarte am Kartentisch, Lagebesprechung | Zielkonflikte mit knappem Treibstoff, Briefing vor echten Mitspielern, Risiko gegen Wirkung |
| **Wirtschaftsplaner** | Produktionsplanung: was, wie viel, welche Fabrik, Schichten bzw. Überstunden, Notfall-Umrüstung | Produktionstafel (Engpass-Ansicht: Kette mit roten Flaschenhälsen) | Engpass-Puzzle nach jedem Treffer. Überstunden steigern den Ausstoß, erhöhen aber das Ausfallrisiko |
| **Forschungsleiter** | Forschungsreihenfolge, Prototypen, Beutetechnik auswerten | Forschungsbaum-UI mit Voraussetzungen (Flugzeug + Infrastruktur + Industrie) | Erprobungsflüge: Spieler fliegen Prototypen. Erfolg spart Zeit, ein Absturz kostet Zeit. Rennen gegen sichtbare Feindforschung |
| **Logistikoffizier** | Konvoi- und Zugrouten, Lagerverteilung, Prioritäten der Versorgung | Logistikkarte mit Live-Konvois | Konvois live um Bedrohungen herumleiten, Begleitschutz anfordern, Notversorgung nach einer zerstörten Brücke |
| **Bauleiter** | Basisausbau, Bautrupps, Reparatur-Reihenfolge, Pistenkrater | Basisausbau-Ansicht (Draufsicht und Platzieren in 3D) | Layout gegen Bombenteppiche verteilen, Krater unter Zeitdruck verfüllen, um Starts zu ermöglichen |
| **Luftverteidigungs-Koordinator** | Flak, Radar, Posten, Ballone, Tarnung platzieren und priorisieren, Alarmstart auslösen | Plot-Tisch mit Feindverbänden als Markern, Funk zu den Jägern | Feindbomber einschätzen, Jäger per Funk „vektoren“, Flakfeuer freigeben, Munition einteilen |
| **Bodenpersonal** | Tanken, Laden, Aufmunitionieren, Reparieren (wie v1) | Ego- und Third-Person-Ansicht, Befehlsrad | Turnaround-Zeit, Arbeiten unter Beschuss |
| **Flak-/Scheinwerfer-Sitze** | Geschütz bzw. Scheinwerfer direkt bedienen (Richtschütze, Ladeschütze) | Geschützsicht, Visier | Vorhalt schätzen, Teamarbeit mit Scheinwerfern bei Nacht |
| **Pilot und Crew** | wie v1 | Cockpit, Bordstationen | Luftkampf |

### 7.2 Rechte- und Abstimmungsmodell

- **Kommandant:** Er vergibt Rollen (offen, zugewiesen, gesperrt), legt per Schieberegler die **Budgetanteile** fest (Material, Treibstoff, Forschungspunkte) und hat ein Veto. Innerhalb von Budget und Rahmen entscheidet jede Rolle selbst.
- **Rollen übernehmen und abgeben:** Freie oder KI-besetzte Rollen kann jeder übernehmen, wenn sie offen sind, sonst auf Anfrage beim Kommandanten. Beim Abgeben übernimmt die KI den aktuellen Plan nahtlos. Mehrere Spieler können sich eine Rolle als „Stellvertreter“ teilen.
- **Abstimmungen gibt es nur für:** Zeitraffer, Kapitulation bzw. Waffenstillstand und **Abwahl des Kommandanten** (Mehrheit, frühestens 30 min nach Amtsantritt). Ist der Kommandant leer oder offline, führt der KI-Stabschef.
- **Kommunikation:** Rollen-Kanäle (Funk und Telefon) und der Befehlsverlauf sind für alle in der Nation sichtbar. So bleibt nachvollziehbar, wer was entschieden hat.

### 7.3 Wie KI-Rollen Vorschläge machen

- **Berater in jeder Rolle:** Auch eine menschlich besetzte Rolle erhält **Vorschläge** ihrer Rollen-KI in einer Vorschlagsleiste. Jeder Vorschlag hat eine Begründung und eine erwartete Wirkung, z. B. „Sägewerk vor Hangar reparieren: Flugzeugproduktion +30 % ab morgen“. Mit Annehmen, Ablehnen oder „immer so machen“ lässt sich die Assistenz bis zur Automatik stufenlos einstellen.
- **Rollenübergreifend:** Eine KI-Rolle stellt **Anfragen** an Spieler-Rollen, statt an ihnen vorbei zu handeln. Beispiel: Der KI-Logistiker bittet den menschlichen Kommandanten um Begleitschutz. Bleibt die Anfrage unbeantwortet, handelt die KI nach Ablauf einer Frist innerhalb ihrer eigenen Befugnisse.
- **Die KI hält sich an den Rahmen der Spieler:** Budget, Prioritäten und Vetos gelten für die KI genauso.

### 7.4 Verteidigung im Detail

- **Anlagen:** Sie werden über den Forschungszweig Luftverteidigung freigeschaltet (Tabelle 3.3). Beobachtungsposten und Horchgeräte geben Vorwarnung, Radar mehr Reichweite und Genauigkeit. MG-, Kanonen- und schwere Flak decken Höhenbänder ab. Sperrballone zwingen Bomber in größere Höhe, was die Trefferquote senkt. Scheinwerfer machen Nachtbomber sichtbar. Tarnnetze und **Attrappen** (Scheinflugzeuge, Scheinlager) lenken feindliche Bomben ab.
- **Versorgung:** Jede Flak-Stellung hat ein kleines Munitionslager, das per Lkw aus dem Depot nachgefüllt wird. Scheinwerfer und Radar brauchen Strom oder Generator-Treibstoff. Wird die Munitionsfabrik getroffen, wird der Himmel über der eigenen Basis schnell gefährlich.
- **Bemannbare Sitze:** Flakgeschütz (Richtschütze, Ladeschütze), Scheinwerfer und Horchgerät sind standardmäßig KI-besetzt. Ein Spieler am Geschütz trifft besser als die Grund-KI und schlechter als eine Experten-Crew, wie beim Bodenpersonal.
- **Balance:** Flak **stört und beschädigt** (Zielgenauigkeit sinkt, Formationen zerfallen, angeschlagene Maschinen werden leichte Beute für Jäger). Sie ersetzt aber keine Jäger. Die Zahl der Abschüsse durch Flak bleibt moderat.
- **Alarmstart:** Der Koordinator löst ihn aus und bestimmt, wie viele Jäger mit welcher Bereitschaft starten. Damit beginnt der v1-Alarmablauf am Boden.

---

## 8. Siegbedingungen

- **Kapitulation:** Eine Nation kapituliert, wenn ihre **Kriegskraft** (gewichtete Industrie- und Versorgungsleistung) 7 Strategie-Tage unter 25 % des Ausgangswerts liegt, oder per Abstimmung. Es gewinnt die letzte verbliebene Nation bzw. das letzte Bündnis.
- **Kampagnenende:** Optional nach X Tagen mit Punktewertung. Endlos-Sandbox ohne Sieg ist ebenfalls möglich.
- **Optional später:** eine abstrakte Bodenfront als zusätzlicher Siegpfad.

---

## 9. Multiplayer: Koop und PvP auf einer Karte

**Entscheidung des Product Owners:** Auf einer Karte gibt es mehrere **Spieler-Nationen**, jede mit eigener Koop-Gruppe möglich, dazu KI-Nationen. Reines Koop ist der Spezialfall mit einer Spieler-Nation.

### 9.1 Lobby- und Sitzungsmodell
- **Welt-Host:** Im Prototyp und in privaten Runden hostet ein Spieler über eine Steam-Lobby (Listen-Server). Persistente PvP-Welten brauchen mittelfristig einen **Dedicated Server**, der die Welt besitzt.
- **Beitritt:** Spieler treten einer Nation bei, per Einladung oder offener Liste. Innerhalb der Nation wählen sie freie Rollen (siehe 7).
- **Spieler-Nation offline:** Alle Rollen gehen an die **Verwalter-KI**. Sie verteidigt, repariert und baut nach den zuletzt gesetzten Prioritäten, forscht entlang der gesetzten Warteschlange und greift nicht offensiv an.

### 9.2 Fairness
- **Schutzzeit** für neue Nationen: 24–48 h Strategie-Zeit ohne Angriffe aufs Kerngebiet. Sie endet vorzeitig, wenn die Nation selbst angreift.
- **Offline-Schutz:** 50 % weniger Industrieschaden, solange der Verwalter führt.
- **Aufholen:** Technologiefluss, Lieferungen einer neutralen „Schutzmacht“ an zurückgefallene Nationen, angekündigte Koalition gegen den Führenden. Kein Pay-to-Win.

### 9.3 Diplomatie light
- Status pro Nationenpaar: **Krieg / Waffenstillstand / Bündnis**.
- Waffenstillstand gilt mindestens 12 h. Ein Bruch wird öffentlich gemacht und kostet Ansehen.
- Bündnis: gemeinsame Aufklärung und Freundkennung, Lager bleiben getrennt.
- Ein Diplomatie-Kanal verbindet die Kommandanten. KI-Nationen reagieren auf vordefinierte Angebote nach ihrer Persönlichkeit.

### 9.4 Technische Konsequenzen
- **Server-autoritär:** Treffer, Schaden, Verbrauch, Jobs (`RefuelJob` usw.), Lager, Forschung und Rollenrechte prüft der Server. Clients schicken nur Eingaben und Befehle über Seats. Das ist dieselbe Schnittstelle wie die der KI.
- **Anti-Cheat:** Plausibilitätsprüfungen (Geschwindigkeit, Feuerrate, Positionssprünge). Clients erhalten nur, was die eigene Nation aufgeklärt hat (Schutz vor Map-Hacks).
- **Listen-Server sind in PvP manipulierbar.** Für persistente PvP-Welten sind Dedicated Server nötig (Godot-Headless-Export, Serverliste zusätzlich zur Steam-Lobby).
- **Datenmodell ab sofort:** Nation-ID an jedem Seat, Gebäude, Lager, Job und Flugzeug. **Rollen-Seats pro Nation** mit Besetzung Mensch, KI oder Verwalter. Diplomatie als Matrix.

---

## 10. Prototyp (Vertical Slice)

**Ziel:** Beweisen, dass „Wirtschaft stören → Gegner fällt zurück“ spürbar ist, dass Versorgung und Bodenbetrieb bzw. Flak zusammenhängen und dass Rollen nahtlos zwischen Mensch und KI wechseln.

- **Karte** ca. 40 × 40 km: Fluss mit 2 Brücken, Bahnlinie, Straßen.
- **Nationen:** Spieler-Nation + 1 KI-Nation („Industrieller“). Eine zweite KI ist ein Stretch-Ziel.
- **Tier I** mit dem Übergang zu Tier II als Forschungsziel.
- **Wirtschaft:** Wald → Sägewerk → Flugzeugwerk. Öl → Raffinerie → Depot → Flugplatz. Dazu eine Munitionsfabrik. Kein Strom, kein Erz.
- **Zieltypen (5):** Raffinerie, Brücke, Lkw-Konvoi, Munitionsfabrik, Flugplatz.
- **Flugzeuge:** Doppeldecker-Jäger und zweisitziger Aufklärer/leichter Bomber.
- **Systeme:** Schadenszustände, 2 Bautrupps pro Seite, physische Lager, Bodenbetrieb aus v1, Fotoaufklärung, Lagebesprechung, Zeitraffer mit Auto-Stopp, 6–8 Forschungsknoten, Kapitulation über die Kriegskraft (Partie 3–4 h).
- **Nicht-Flug-Rollen (2):**
  1. **Kommandant** (Lagebesprechung, Zielauswahl, Budget-Schieberegler, Rollen vergeben). Er ist nötig, damit überhaupt Ziele entstehen, und testet das Rechtemodell.
  2. **Luftverteidigungs-Koordinator** mit Beobachtungsposten, MG-Flak (bemannbarer Sitz, eigenes Munitionslager), Attrappen und Alarmstart. Er erzeugt Action ohne Cockpit und verbindet Versorgung, Alarmstart und Rollen-Seats.
  - Wirtschaft, Forschung, Logistik und Bau laufen als **KI-Rollen mit sichtbarer Vorschlagsleiste**. So lässt sich das Vorschlagssystem testen, ohne die Werkzeuge schon zu bauen.
- **Koop** mit 2–4 Spielern über Steam-Lobby, nur gegen KI. Das **Datenmodell ist aber schon mehrnational** (Nation-ID, Rollen-Seats, Verwalter-Modus), und Aktionen werden serverseitig geprüft.
- **Nächster Schritt:** PvP-Test mit 2 Spieler-Nationen + 1 KI im Freundeskreis (Listen-Server), dazu Schutzzeit, Diplomatie light und die Rollen Logistik und Forschung als Spielerwerkzeuge.

**Nicht enthalten:** PvP-Betrieb, Dedicated Server, Strom/Erz/Radar, Bodenfront, Tier II+ spielbar, Wetter und Nacht (deshalb keine Scheinwerfer).

---

## 11. Offene Entscheidungen für den Product Owner

1. **Wirtschaftstiefe:** 4 Rohstoffe, 4 Zwischenprodukte, 3 Endprodukte plus Forschungspunkte, drei Schadenszustände, begrenzte Bautrupps. *Empfehlung: ja, so „light“ halten.*
2. **Physische Lager** (Flugplatz und Flak) als Bindeglied zu Bodenbetrieb und Verteidigung, inklusive Ersatztreibstoff mit Leistungsverlust. *Empfehlung: ja, das ist ein Kernmerkmal.*
3. **KI-Fairness:** keine Ressourcenboni, angekündigte Angriffe und Koalitionen, Technologiefluss −30 %. *Empfehlung: ja.*
4. **Nations-KI als Summe der Rollen-KIs:** dieselben KIs, die in Spieler-Nationen leere Rollen füllen. *Empfehlung: ja, das spart Entwicklung und sorgt für Konsistenz.*
5. **Rollenkatalog:** Kommandant, Wirtschaft, Forschung, Logistik, Bau, Luftverteidigung, Bodenpersonal, Flak-/Scheinwerfer-Sitze, Flug-Crew. Ein eigener Nachrichtenoffizier? *Empfehlung: Katalog so annehmen, Aufklärung beim Kommandanten lassen.*
6. **Rechtemodell:** Der Kommandant vergibt Rollen, setzt Budgets und hat ein Veto. Abstimmungen nur für Zeitraffer, Kapitulation/Waffenstillstand und Abwahl. *Empfehlung: ja.*
7. **KI-Assistenz für Spieler-Rollen:** Vorschlagsleiste mit stufenloser Automatik, Anfragen an Spieler mit Frist. *Empfehlung: ja.*
8. **Rolle der Flak:** Sie stört und beschädigt, ersetzt aber keine Jäger. *Empfehlung: ja, Abschussrate niedrig halten.*
9. **Zeitmodell:** Koop mit Zeitraffer bis 60× per Konsens, PvP mit festem Weltfaktor (z. B. 4× Strategie, Flug 1:1). *Empfehlung: ja.*
10. **Multiplayer-Reihenfolge** (Koop + PvP ist entschieden): Prototyp Koop gegen KI, dann privater PvP-Test, persistente PvP-Welten erst mit Dedicated Server. *Empfehlung: ja.*
11. **Offline-Nationen:** Verwalter-KI ohne Offensive, 50 % weniger Industrieschaden. *Empfehlung: ja.*
12. **Schutzzeit und Aufholhilfe:** 24–48 h Schutz, Technologiefluss, Schutzmacht-Lieferungen. *Empfehlung: ja, Werte im PvP-Test tunen.*
13. **Diplomatie light:** Krieg, Waffenstillstand (mindestens 12 h, Bruch öffentlich) und Bündnis (gemeinsame Aufklärung), keine Handelsabkommen. *Empfehlung: ja.*
14. **Server-Strategie:** Listen-Server für Koop und private Runden. Dedicated Server für persistente PvP-Welten als Community-Hosting oder offiziell (Kostenfrage). *Empfehlung: zuerst Community-Hosting.*
15. **Siegbedingung:** Kriegskraft unter 25 % für 7 Tage oder Kapitulation per Abstimmung, Endlosmodus optional, Bodenfront später prüfen. *Empfehlung: ja.*
16. **Prototyp-Rollen:** Kommandant + Luftverteidigungs-Koordinator spielbar, die übrigen Rollen als KI mit Vorschlagsleiste. *Empfehlung: ja.*
17. **Nationen und Flugzeuge:** fiktiv bzw. historisch inspiriert, generisch benannt (Markenrecht, Hoheitszeichen, Balancing). *Empfehlung: unverändert aus v1.*
18. **Flugsteuerung:** Arcade, Realistisch und Simulator auf einem Flugmodell. *Empfehlung: unverändert aus v1.*
19. **Verluste:** Flugzeuge kosten Material, Personal fällt verwundet aus, abgeschossene Crews sind bergbar. *Empfehlung: ja.*
20. **Kartengröße 1.0:** große Karte (ca. 200 × 200 km, 3–4 Nationen) plus 1–2 kleine. *Empfehlung: erst nach dem Prototyp festlegen.*
