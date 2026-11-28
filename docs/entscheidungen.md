# Entscheidungslog (Kopie aus dem Projekt, Stand 28.11.2026)

Wird vom Projektleiter gepflegt; maßgeblich ist die Projektversion.

| Datum | Entscheidung |
|---|---|
| 31.10.2026 | Plattform: PC / Steam, eigenständige .exe |
| 31.10.2026 | Team: rein Claude-Agenten; Mensch = Product Owner + Tester |
| 31.10.2026 | Engine: Godot 4 |
| 31.10.2026 | Genre: Luftkampf; Kernfeature: Bodenbetrieb selbst machen, möglichst wie echt |
| 31.10.2026 | Grafikstil B (PBR, Tarnanstrich, leichte Abnutzung) |
| 31.10.2026 | Multiplayer: Jäger = 1 Spieler, Bomber = mehrere Spieler (Crew-Positionen); KI besetzt freie Positionen/Rollen |
| 31.10.2026 | Epoche: Fortschritt über Forschung inkl. Infrastruktur (Personal, Hallen, Piste, Treibstoff, Waffen) |
| 31.10.2026 | Eingabe: Maus+Tastatur und Xbox-Controller |
| 31.10.2026 | Kein Missions-Kern: dynamischer Krieg gegen/mit Nationen, die parallel bauen und forschen; Ziel: gegnerische Entwicklung stören |
| 31.10.2026 | PvP möglich (verschiedene Nationen); nicht-fliegende Rollen von Spielern übernehmbar |
| 31.10.2026 | **Grundregel: Jeder kann jederzeit fliegen, muss aber nicht.** Fliegt ein Rolleninhaber, führt die KI seine Rolle mit eingestellter Automatik |
| 31.10.2026 | Partielänge 1–3 h, keine persistenten Welten; Tempo als Lobby-Einstellung |
| 01.11.2026 | Bodenbetrieb: Third-Person + Ego, 3 Realismusstufen, Reparatur light, Fahrzeuge selbst fahren, Bomben später, Alarmstart |
| 07.11.2026 | Auslieferung in Paketen (Code/Modelle/Karte/Audio, je ≤ 30 MB) |
| 22.11.2026 | Bodenpersonal rekrutieren/ausbilden (M4+): besseres Personal ist bei Handgriffen schneller; Tankdauer hängt nur von Ausrüstung ab (Pumpen, Tankwagen, Munitionswagen) |
| 22.11.2026 | **M4 Grundrichtung:** Wirtschaft Variante A (klare Kette, Schlüsselziele) + Konvoi-Kern aus C. Prinzipien aus recherche_m4_rollen.md (Wirkung in Sekunden sichtbar, entscheiden statt schleppen, eigene Ressource je Rolle, Ereignis alle 2–4 min, Kettenkredit/Bilanz für Nicht-Flieger). Anfragen per Funk zwischen Rollen. |
| 22.11.2026 | **Rollenkatalog:** Einsatzleiter (koordiniert/plant, wichtige Entscheidungen im Team), Nachschub (Logistik + Wirtschaft), Platzleitung (Bau + Luftverteidigung), Werkstatt & Bodenpersonal (Tanken/Munition/Reparatur, schwere Reparaturen, Umbauten, Ausbildung, Forschung/Entwicklung), Aufklärung & Nachrichten (Fotos, Funk abhören, Ziele aufdecken, Vorwarnung), Piloten. Welche in M4 voll spielbar sind, legt Plan M4 fest. |
| 22.11.2026 | **Upgrades je Rolle:** Nachschub: Tankwagen, Konvois, Lager; Platzleitung: Flak, Beobachtungsposten/Radar, Piste/Hallen; Werkstatt: Ausbildung, Pumpen, Werkzeug, Munitionswagen; Aufklärung: Kameras, Funkhorchdienst; Einsatzleiter: Funkreichweite, Planungstisch. Der Rolleninhaber (Spieler oder KI) entscheidet. |
| 22.11.2026 | Zweige/Unterordnung: Spieler können sich einem Rollen-Zweig als Helfer unterordnen |
| 22.11.2026 | Fliegen vs. Rollenarbeit: aus der Luft nur Befehle/Anfragen per Funk (ggf. erst mit Funk-Upgrade). Wichtige Planungen am Boden in der Halle (Planungs-/Kartentisch) |
| 22.11.2026 | Funkgerät (M3.5) mit Kanälen per Zahlentasten; später ein Kanal je Rolle: Spieler-Rolle → Anfrage an den Spieler, sonst antwortet die KI. Tastenbelegung frei. |
| 22.11.2026 | Realismus HUD: keine Lagerbestände im Bild (nur für den Zuständigen), keine Fortschrittsbalken, grobe Funkmeldungen, „Status?“ |

## GDD v2 – Durchgang mit Product Owner
| # | Thema | Ergebnis |
|---|---|---|
| 1 | Wirtschaft light (4 Rohstoffe, 4 Zwischen-, 3 Endprodukte + Forschungspunkte, 3 Schadenszustände, begrenzte Bautrupps) | angenommen |
| 2 | Physische Lager an Flugplatz/Flak, Ersatztreibstoff mit Leistungsverlust | angenommen |
| 3 | Faire KI (keine Boni, Angriffe angekündigt, −30 % bei bekannter Technik, Koalitionen gegen Starke) | angenommen |
| 4 | Nations-KI = Summe der Rollen-KIs | angenommen |
| 6 | Budget-Anträge: Einsatzleiter entscheidet, bei Ablehnung Abstimmung möglich; Abstimmung für Kapitulation/Waffenstillstand/Abwahl | angenommen |
| 7 | KI-Assistenz (Vorschläge, einstellbare Automatik, Anfragen mit Frist) | angenommen |
| 8 | Flak stört/beschädigt, ersetzt keine Jäger | angenommen |
| 9 | Partie-Tempo in der Lobby; Fliegen immer 1:1 | angenommen |
| 10 | Reihenfolge: Koop vs. KI → private PvP-Partien | angenommen |
| 11 | Spieler verlässt Partie → KI übernimmt seine Rollen | angenommen |
| 12 | Schutzphase zu Partiebeginn (~10 min) + Aufholhilfen | angenommen |
| 13 | Diplomatie: Krieg / Waffenstillstand / Bündnis, kein Handel | angenommen |
| 14 | Hosting: Spieler hostet über Steam | angenommen |
| 15 | Sieg: Kriegskraft 10 min unter 25 % oder Kapitulation; Zeitlimit → höchste Kriegskraft | angenommen |
| 17 | Fiktive Nationen, historisch inspirierte Flugzeuge mit erfundenen Namen | angenommen |
| 18 | Steuerungsmodi Arcade/Realistisch/Simulator | angenommen |
| 19 | Pilotenlevel nur innerhalb einer Partie; Abschuss ohne Ausstieg = Pilot verloren; Notausstieg: Level bleibt, Flug-XP erst bei Landung, Flugzeug verloren, Ausfallzeit; Rettung möglich, Gegner kann abfangen | angenommen |
| 20 | Karte Prototyp ca. 40 × 40 km, 1 Spieler-Nation + 1 KI-Nation | angenommen |
