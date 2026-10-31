# Game Design Document v3 – Partie-Krieg

Arbeitstitel: *Flugzeug Spiel* · PC/Steam · Godot 4 · stilisiert-realistisch
Status: Gilt ab sofort und berücksichtigt alle 20 Entscheidungen des Product Owners. v1 und v2 bleiben als Historie. Wo v3 schweigt, gelten Bodenbetrieb, Crew-Rollen und Flugmodi aus v1 sowie Wirtschaft und Rollen aus v2.

---

## 1. Pitch und Säulen

**Pitch:** Zwei bis vier Nationen führen auf einer Karte einen **Luftkrieg von 1–3 Stunden**. Jede baut Wirtschaft, Flugplätze und Forschung auf und steigt in der Partie mehrere Epochen auf. Wer die Raffinerien, Brücken und Fabriken des Gegners trifft, bremst seinen Fortschritt, und wer zurückfällt, fliegt mit älterer Technik gegen bessere Flugzeuge.

**Säulen:**
1. **Krieg ist Logistik.** Jede Bombe wirkt auf eine sichtbare Versorgungskette.
2. **Hände an der Maschine.** Bodenbetrieb, Flak und Kartentisch sind Gameplay im 3D-Raum.
3. **Jede Rolle ist ein Sitz, Mensch oder KI.** Die KI füllt jeden Platz, Spieler übernehmen und geben jederzeit ab.
4. **Jeder darf jederzeit fliegen, keiner muss.**

---

## 2. Partie-Ablauf und Tempo

**Ablauf einer Partie (Normal, ca. 90–120 min):**
1. **Schutzphase (ca. 10 min):** keine Angriffe auf Kerngebiete. Aufbau, Aufklärung und erste Jägerflüge sind möglich. Die Schutzphase endet für eine Nation vorzeitig, wenn sie selbst angreift.
2. **Frühphase:** Wirtschaft hochfahren, Konvois jagen, erste Raffinerie-Angriffe.
3. **Epochensprünge:** Nach dem ersten Tier-Wechsel ist das Rennen offen sichtbar.
4. **Endphase:** Kapitulation einer Nation oder Zeitlimit.

**Lobby-Einstellungen:**

| Einstellung | Optionen | Wirkung |
|---|---|---|
| **Tempo** | Schnell / Normal / Lang | Multiplikator auf Produktion, Forschung, Bau und Reparatur (1,5× / 1× / 0,6×). **Fliegen ist immer 1:1.** |
| **Startepoche** | Tier I–IV | Startausstattung passt zur Epoche (Piste, Treibstoff, Personal) |
| **Zeitlimit** | aus / 60 / 90 / 120 / 180 min | Bei Ablauf gewinnt die Nation mit der höchsten Kriegskraft |
| **Kartengröße** | klein / mittel / groß (ab 1.0) | Anzahl der Nationen und Ziele |
| **Flugmodi** | Arcade / Realistisch / Simulator erlaubt | wie v1 |

**Epochen pro Partie:** Ein Tier-Wechsel dauert bei Tempo Normal etwa **30–40 min** ungestörte Forschung, bei gezielter Störung durch den Gegner deutlich länger. Realistisch sind **2–3 Tiers pro Partie**. Wer alle fünf Epochen erleben will, wählt eine spätere Startepoche oder Tempo „Lang“. Empfohlene Voreinstellungen: „Pioniere“ (Start I, meist bis III) und „Jetzeitalter“ (Start III, meist bis V).

**Begründung:** Forschung muss sich lohnen, ohne dass jede Partie bei Tier V endet. Der Wechsel ist ein Höhepunkt, den man ein- bis zweimal pro Partie erleben soll.

---

## 3. Wirtschaft und Versorgung (aus v2, gestrafft)

**Kette:** Rohstoffe (Holz, Erz, Öl, Bauxit ab T3) → Verarbeitung (Sägewerk, Hütte, Raffinerie, Alu-Werk) → Produktion und Forschung (Flugzeugwerk, Munitionsfabrik, Institut, mit Strom aus dem Kraftwerk) → Depot → Bahn, Straße oder Konvoi → **physische Lager** am Flugplatz und an den Flak-Stellungen → Bodenbetrieb und Flak.

**Schäden:** Gebäude sind intakt (100 %), beschädigt (50 %, Reparatur 2–6 min) oder zerstört (0 %, Wiederaufbau 8–15 min mit Bautrupp). Die Zeiten gelten für Tempo Normal. Bautrupps sind begrenzt (2–3 pro Nation), deshalb wirken Angriffswellen stärker als Einzelschläge. Folgeschäden: Ein Kraftwerksausfall drosselt alle Abnehmer, eine fehlende Brücke zwingt zum Umweg.

**Versorgung im Bodenbetrieb:** Ist das Lager leer, gibt es keinen Start. Fehlt Hochoktan, wird Ersatzbenzin getankt, was Leistung kostet. Bei Munitionsmangel gibt es nur Teilbeladung. Jets brauchen Kerosin.

**Tier-Voraussetzungen:** Es gelten die Tabelle aus v2 (Flugplatz, Industrie, Verteidigung) und die 8 Forschungszweige (inkl. Luftverteidigung). Der **Technologiefluss** bleibt: Technik, die eine andere Nation schon besitzt, kostet 30 % weniger.

---

## 4. Nations-KI

Eine KI-Nation besteht aus denselben **Rollen-KIs**, die in Spieler-Nationen freie Rollen füllen. Es gibt keine Ressourcenboni, der Schwierigkeitsgrad steuert nur Reaktionszeit, Planungstiefe und Aggressivität. Die Persönlichkeiten aus v2 bleiben: Industrieller, Aggressor, Bomberdoktrin, Techniker.

Für die Spieler bleibt die KI berechenbar: Angriffe kündigen sich durch Sammeln am Frontflugplatz an (je nach Tempo 2–5 min vorher erkennbar), Wiederaufbau ist sichtbar, und gegen eine führende Nation bildet sich eine angekündigte Koalition.

---

## 5. Rollen: „Jede Rolle ist ein Sitz“

### 5.1 Katalog (aus v2, angenommen)

| Rolle | Kernbefugnis | Werkzeug |
|---|---|---|
| Kommandant | Zielauswahl, Budgetaufteilung, Rollen vergeben, Diplomatie, Veto | Kartentisch, Lagebesprechung |
| Wirtschaftsplaner | Produktionsplanung, Schichten | Produktionstafel mit Engpass-Ansicht |
| Forschungsleiter | Forschungsreihenfolge, Prototypen | Forschungsbaum-UI |
| Logistikoffizier | Konvoirouten, Lagerverteilung | Logistikkarte |
| Bauleiter | Ausbau, Bautrupps, Reparatur-Reihenfolge | Basisausbau-Ansicht |
| Luftverteidigungs-Koordinator | Flak, Radar, Posten, Ballone, Attrappen, Alarmstart | Plot-Tisch, Funk |
| Bodenpersonal | Tanken, Laden, Aufmunitionieren, Reparieren | Ego- und Third-Person-Ansicht, Befehlsrad |
| Flak- und Scheinwerfer-Sitze | Geschütz direkt bedienen | Geschützsicht |
| Pilot und Crew | Fliegen, Bordwaffen | Cockpit, Bordstationen |

### 5.2 Grundregel Fliegen

- **Jeder Spieler kann jederzeit fliegen.** Ein Rolleninhaber, der ins Cockpit steigt, behält seine Rolle. Solange er fliegt, führt die Rollen-KI sie mit der **eingestellten Automatik-Stufe**.
- **Meldungen im Flug:** Wichtige Ereignisse wie Angriffswarnung, Budgetantrag, Zerstörung eines Schlüsselgebäudes oder Anfrage einer anderen Rolle kommen als Funkspruch mit Kurzbefehl an (z. B. „Annehmen“, „Ablehnen“, „KI entscheidet“).
- Wer nach der Landung zurück an den Arbeitsplatz geht, übernimmt nahtlos wieder.

### 5.3 Rechte und Budget

- Der **Kommandant** vergibt Rollen und setzt Budgetanteile (Material, Treibstoff, Forschungspunkte). Er hat ein Veto.
- **Budgetantrag:** Jede Rolle kann mehr Budget beantragen. Der Kommandant entscheidet. Lehnt er ab, kann der Antragsteller eine **Abstimmung** in der Nation verlangen, wobei eine einfache Mehrheit der anwesenden Spieler entscheidet. Pro Rolle ist das höchstens einmal alle 5 min möglich.
- Weitere Abstimmungen gibt es nur über Kapitulation bzw. Waffenstillstand und über die Abwahl des Kommandanten (frühestens 10 min nach Amtsantritt).
- **KI-Assistenz:** Jede Rolle hat eine Vorschlagsleiste mit Begründung und erwarteter Wirkung. Die Automatik ist in Stufen einstellbar (nur Vorschläge / Routine automatisch / voll automatisch). KI-Rollen stellen Anfragen an Spieler-Rollen mit Frist, statt an ihnen vorbei zu handeln.

### 5.4 Verteidigung

Die Verteidigung bleibt wie in v2: Forschungszweig Luftverteidigung, eigene Flak-Munitionslager, bemannbare Geschütze. Flak stört und beschädigt, ersetzt aber keine Jäger. Den Alarmstart löst der Koordinator aus, sonst die KI.

---

## 6. Piloten: Level, Tod, Notausstieg, Rettung

**Ziel:** Den Kampf zu gewinnen und zu landen muss immer attraktiver sein als auszusteigen.

### 6.1 Pilotenlevel (nur innerhalb der Partie)

Jeder Spieler hat in der Partie einen **aktuellen Piloten**. Flug-XP gibt es für Abschüsse, Bodenziele, Aufklärungsfotos, Begleitschutz und Rettungen. Die XP werden **erst bei der Landung am eigenen Flugplatz** gutgeschrieben, als „Einsatzbilanz“ beim Abrollen in den Hangar. Ein Feldflugplatz bzw. Vorfeldplatz der eigenen Nation zählt ebenfalls.

| Level | XP (Normal) | Bonus (kumulativ) |
|---|---|---|
| 1 Rekrut | 0 | – |
| 2 Flugzeugführer | 100 | **G-Toleranz +10 %** (Blackout/Redout später), Ausstieg 1 s schneller |
| 3 Erfahrener Pilot | 250 | **Sichtweite für Feindkontakte +15 %** (Marker erscheinen früher), Motor-Überlastzeit +20 % |
| 4 Veteran | 450 | **Streuung der Bordwaffen −10 %**, Verwundungschance −25 % |
| 5 Ass | 700 | **Rufzeichen und Abzeichen sichtbar** (Gegner sehen ein Ass), Flügelmann-KI folgt Befehlen präziser, +1 Staffelplatz für KI-Flügelmänner |

Die Boni sind bewusst moderat und betreffen eher Wahrnehmung und Belastbarkeit als reine Feuerkraft. Ein Level-1-Spieler mit gutem Können schlägt so weiterhin einen Level-5-Gegner. Im Simulator-Modus entfällt der Streuungsbonus und wird durch +10 % Munitionsvorrat ersetzt.

### 6.2 Abschuss ohne Ausstieg

Stürzt der Pilot ab oder stirbt er im Cockpit, ist er **verloren**, ebenso wie die nicht gutgeschriebenen Flug-XP. Der Spieler erhält sofort einen **neuen Piloten auf Level 1** und kann mit dem nächsten verfügbaren Flugzeug starten. Das Flugzeug ist verloren und kostet Material.

### 6.3 Notausstieg

- **Nur möglich bei schwerem Schaden oder Feuer:** Motorausfall, Brand, Steuerflächen oder Tragwerk kritisch, Pilot verwundet. Sonst ist die Option gesperrt, was das HUD anzeigt.
- **Folgen:** Das **Level bleibt**, die **Flug-XP des laufenden Einsatzes sind verloren**, und das **Flugzeug ist immer verloren**.
- **Ausfallzeit** bei Tempo Normal:
  - über eigenem Gebiet: **2 min**, dann Rückkehr zur Basis (Fahrzeug, Zeitsprung im Ladebildschirm),
  - über Feindgebiet: **Rettungsfenster 4 min**, danach **Gefangenschaft**. Der Pilot ist dann 10 min nicht verfügbar, und der Gegner erhält Forschungspunkte („Verhör“). Der Spieler kann während der Ausfallzeit eine **Nicht-Flug-Rolle** übernehmen oder mit einem neuen Level-1-Piloten fliegen. Kehrt der alte Pilot zurück, wählt der Spieler, welchen er behält.
- **Am Boden:** Der ausgestiegene Spieler steuert seinen Piloten in Third-Person (verstecken, Signalpistole, zum Wasser oder Waldrand laufen).

### 6.4 Rettung und Gegenspiel

- **Retter:** zweisitziges Flugzeug mit Landung auf Feld oder Wiese, ab Tier II Wasserflugzeug, Lkw oder Kübelwagen über Land. Ein Retter wird per dynamischem Auftrag gerufen, jeder Spieler kann ihn annehmen, sonst übernimmt die KI.
- **Belohnung für den Retter:** Flug-XP. Der gerettete Pilot ist sofort wieder verfügbar und bekommt einen kleinen Bonus („Zurück aus dem Feindesland“, +25 XP bei Landung).
- **Gegner:** Er sieht abgestürzte Piloten, die von seinen Posten gemeldet werden, und kann einen **Suchtrupp** (Fahrzeug, KI oder Spieler) schicken oder die Rettungsmaschine abfangen. Wer den Piloten gefangen nimmt, erhält Forschungspunkte.

**Warum Landen attraktiver bleibt:** Landen sichert XP und das Flugzeug, Aussteigen kostet beides. Wer abstürzt, verliert den Piloten, deshalb gilt: Wer kann, landet. Wer nicht kann, steigt aus, weil das Level so erhalten bleibt.

---

## 7. Multiplayer und Hosting

- **Modell:** Mehrere Spieler-Nationen (jeweils als Koop-Gruppe) plus KI-Nationen auf einer Karte. Reines Koop ist der Spezialfall mit einer Spieler-Nation.
- **Hosting:** Ein Spieler hostet über eine Steam-Lobby (Listen-Server). Community-Server (Godot-Headless) sind optional und kommen später. **Keine offiziellen Server.**
- **Spielstand:** Partien sind **speicherbar**. Verlässt der Host die Partie, wird automatisch gespeichert, und jeder Teilnehmer kann den Stand später erneut hosten.
- **Spieler verlässt die Partie:** Die KI übernimmt seine Rollen **defensiv**: verteidigen, reparieren, nach den gesetzten Prioritäten weiterbauen, keine eigenen Offensiven. Verlassen alle Spieler einer Nation die Partie, führt die Verwalter-KI die ganze Nation defensiv.
- **Aufholhilfen:** Technologiefluss, Lieferungen der Schutzmacht an zurückgefallene Nationen, angekündigte Koalition gegen den Führenden.
- **Diplomatie light:** Krieg, Waffenstillstand (mindestens 10 min, ein Bruch wird öffentlich) und Bündnis (gemeinsame Aufklärung).
- **Technik:** Server-autoritär (Treffer, Verbrauch, Jobs, Lager, Rollenrechte). Plausibilitäts-Checks, und Clients sehen nur, was die eigene Nation aufgeklärt hat. In PvP-Runden mit Listen-Server hat der Host prinzipiell einen Vorteil. Das wird für private Runden akzeptiert, und Community-Server lösen es später.

---

## 8. Siegbedingungen

- **Kapitulation:** Eine Nation kapituliert, wenn ihre **Kriegskraft 10 min lang unter 25 %** des eigenen Höchstwerts liegt, oder per Abstimmung.
- **Zeitlimit (Lobby):** Bei Ablauf gewinnt die Nation (bzw. das Bündnis) mit der **höchsten Kriegskraft**.
- **Kriegskraft** ist die gewichtete Summe aus Industrieleistung, Lagerbeständen, einsatzbereiten Flugzeugen und Tier-Stufe. Sie ist jederzeit als Balken für alle Nationen sichtbar, die bekannten Feindwerte mit Unschärfe nach Aufklärungsalter.

---

## 9. Karten

- **Prototyp:** ca. 40 × 40 km, 1 Spieler-Nation + 1 KI-Nation.
- **1.0:** mehrere Kartengrößen, z. B. klein (40 km, 2 Nationen), mittel (80 km, 3), groß (120–150 km, 4). Die genauen Größen werden nach den Prototyp-Tests festgelegt.

---

## 10. Prototyp-Umfang (Vertical Slice)

**Ziel des Slice:** Eine vollständige Partie von 60–90 min in Tier I spielen, Koop mit 1–4 Spielern gegen 1 KI-Nation. Spielbare Rollen: **Pilot, Kommandant, Bodenbetrieb**. Alle anderen Rollen sind KI mit Vorschlagsleiste.

**Fundament und Netzwerk**
1. **Nation-Datenmodell:** Nation-ID an Seat, Gebäude, Lager, Job, Flugzeug, Fahrzeug. Diplomatie-Matrix ist angelegt (nur „Krieg“ aktiv).
2. **Rollen-Seats:** Jede Rolle ist ein Seat mit der Besetzung Mensch, KI oder Verwalter. Übernehmen und Abgeben jederzeit, Rechteprüfung serverseitig.
3. **Listen-Server über Steam-Lobby**, server-autoritär für Treffer, Verbrauch, Jobs und Lager.
4. **Lobby-Einstellungen:** Tempo (Schnell/Normal/Lang), Zeitlimit, Flugmodi. Startepoche ist auf Tier I fest.
5. **Speichern und Laden** des Partiestands: Autosave beim Verlassen des Hosts, neu hosten aus dem Speicherstand.
6. **Spieler verlässt Partie:** Die KI übernimmt dessen Rollen defensiv.

**Welt und Wirtschaft**
7. **Karte 40 × 40 km:** Fluss mit 2 Brücken, 1 Bahnlinie, Straßennetz, 2 Haupt-Flugplätze (Graspiste) und Nebel des Krieges.
8. **Wirtschaftskette Tier I:** Wald → Sägewerk → Flugzeugwerk. Ölfeld → Raffinerie → Depot. Dazu eine Munitionsfabrik. Kein Strom und kein Erz.
9. **Logistik:** Lkw-Konvois und ein Zug (KI-gesteuert) transportieren physisch vom Depot zu den Lagern am Flugplatz (Fasslager, Munitionszelt).
10. **Schadenssystem:** 3 Zustände pro Gebäude, 2 Bautrupps pro Nation, Reparatur-Warteschlange, Brücken-Umweg.
11. **Zieltypen (5):** Raffinerie, Brücke, Lkw-Konvoi, Munitionsfabrik, Flugplatz (Hangar und Lager).
12. **Forschung:** 6–8 Knoten in Tier I und das Ziel „Übergang Tier II“ als Sieg-Meilenstein. Forschungsbaum-UI in einfacher Form (für den Kommandanten lesbar, gesteuert von der KI-Forschung).
13. **Kriegskraft-Berechnung** mit Anzeige als Balken, Kapitulation (10 min unter 25 %) und Zeitlimit-Wertung.

**Rolle Pilot**
14. **Flugzeuge:** Doppeldecker-Jäger (1 Sitz) und Aufklärer/leichter Bomber (Pilot + Heckschütze), für beide Nationen mit eigener Markierung. Flugmodi Arcade und Realistisch.
15. **Bewaffnung:** MG mit begrenzter Munition, leichte Bomben, Aufklärungskamera (Fotos decken Ziele auf).
16. **Schadensmodell nach Zonen** inklusive Brand und den Ausstiegsbedingungen (nur bei schwerem Schaden oder Feuer).
17. **Pilotenlevel 1–5** mit den Boni aus 6.1. XP-Gutschrift erst bei der Landung, Verlust bei Absturz, neuer Pilot auf Level 1.
18. **Notausstieg und Rettung:** Fallschirm, Pilot in Third-Person am Boden, Ausfallzeit, Gefangenschaft nach Rettungsfenster, Rettung per Zweisitzer-Landung oder Lkw. Gegnerische KI-Suchtrupps.
19. **KI-Piloten und Flügelmänner** über dieselbe Seat-Schnittstelle, Befehlsrad (Formation, Angriff, Rückkehr).

**Rolle Kommandant**
20. **Kartentisch und Strategiekarte:** Gebäude, Füllstände, Aufklärungsalter, eigene Konvois. Auch im Flug abrufbar (nur lesend).
21. **Lagebesprechung:** 3 KI-Zielvorschläge mit Wirkung und Risiko, freie Zielmarkierung, Aufträge an KI-Staffeln.
22. **Budget-Schieberegler** für Produktion, Forschung und Bau. Budgetanträge der KI-Rollen und Abstimmung bei Ablehnung.
23. **Rollenvergabe** (offen/zugewiesen/gesperrt) und Abwahl-Abstimmung.
24. **Meldungen im Flug:** Funksprüche mit Kurzbefehl (Annehmen, Ablehnen, KI entscheidet). Die Rolle läuft im Flug mit der eingestellten Automatik weiter.

**Rolle Bodenbetrieb**
25. **Jobs:** `RefuelJob` (Fass und Handpumpe), `RearmJob` (MG-Gurte), `LoadOrdnanceJob` (leichte Bomben von Hand), `RepairJob` (Schnellreparatur), Motorstart per Propeller.
26. **Kopplung an die Lager:** Jobs verbrauchen echten Lagerbestand, ein leeres Lager blockiert den Job mit Hinweis.
27. **KI-Bodenpersonal** (Mechaniker, Waffenwart) mit Befehlsrad und Prioritätenliste.
28. **Alarmstart:** Beobachtungsposten melden Verbände, und der Countdown löst den Bodenbetrieb unter Zeitdruck aus. Zeitwertung für die Abfertigung am Boden.

**KI-Nation**
29. **Gegnerische Nation** aus Rollen-KIs mit Persönlichkeit „Industrieller“ und denselben Regeln. Die KI baut auf, forscht, repariert und verteidigt, greift an und kündigt Angriffe sichtbar an.
30. **Schutzphase** von ca. 10 min zu Partiebeginn.

**Nicht im Slice:** Luftverteidigungs-Koordinator und bemannbare Flak (nächster Schritt), PvP, Diplomatie außer Krieg, Tier II+ spielbar, Strom/Erz/Radar, Wasserflugzeuge, Wetter und Nacht, Community-Server.

**Nächste Schritte nach dem Slice:** Luftverteidigung als Spielerrolle, PvP mit 2 Spieler-Nationen und Diplomatie light, Tier II, weitere Spielerwerkzeuge für Wirtschaft, Forschung und Logistik.

---

## 11. Noch zu klären (klein, im Prototyp testen)

1. Tempo-Multiplikatoren und Tier-Dauer (Ziel: 30–40 min pro Tier bei Normal).
2. XP-Schwellen und Größe der Level-Boni.
3. Gewichtung der Kriegskraft und Kapitulationsschwelle.
4. Länge des Rettungsfensters und der Gefangenschaft je Tempo.
