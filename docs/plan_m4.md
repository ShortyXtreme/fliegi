# Plan Meilenstein 4 „Kriegswirtschaft und Rollen“

Stand: 28.11.2026 · Basis: GDD v3 (§2–5, §8, §10), `entscheidungen.md` (22.11.2026: M4-Grundrichtung, Rollenkatalog, Upgrades, Funk, Realismus-HUD), `recherche_m4_wirtschaft.md` (Variante A + Bausteine aus C), `recherche_m4_rollen.md` (P1–P12, Teil 3 und 5), Code M3.11 (main ea82e92) · Godot 4.7.2, Jolt, 60 Hz

## 1. Ziel und Abnahmekriterien

**Ziel:** Am Ende von M4 spielt der Tester eine ganze Partie von 60–90 min gegen die KI-Nation Rot. Beide Seiten haben eine kleine, sichtbare Wirtschaftskette mit acht Gebäuden. Lkw-Kolonnen bringen Treibstoff, Munition, Bomben und Bauholz über Straßen und Brücken zu den Lagern, die der Bodenbetrieb aus M3 schon verbraucht. Der Tester kann als Jagdbomber feindliche Raffinerien, Brücken und Kolonnen angreifen und sieht die Wirkung sofort (Rauch, Funkmeldung, Kolonne dreht um) und nach Minuten (leere Lager, Ersatzbenzin, weniger Feindstarts). Am Planungstisch in der Flugleitung kann er statt zu fliegen Einsatzleiter, Nachschub oder Platzleitung spielen. Die KI-Nation baut, repariert, forscht, kündigt Angriffe an und greift selbst die Wirtschaft des Spielers an.

**Abnahme (messbar):**
1. **Partie:** Eine Partie mit Zeitlimit 75 min läuft headless mit Tempo „Schnell“ ohne Fehler bis zum Ende und endet mit Sieg nach Kriegskraft, Kapitulation (10 min unter 25 %) oder Zeitlimit. Ohne Eingriff des Spielers erreicht die KI-Nation in ≥ 8 von 10 Seeds den Forschungsmeilenstein „Übergang Tier II“ in 30–45 min (Tempo Normal hochgerechnet).
2. **Kette:** Jedes der 8 Gebäude je Nation produziert nach seinen Daten. Mengen bleiben erhalten: Was das Werk abgibt, liegt im Depot, auf einem Lkw oder im Ziellager (Test über 30 min Partiezeit, Summe ±0,1 %). Ein beschädigtes Gebäude leistet 50 %, ein zerstörtes 0 %. Die Engpass-Anzeige nennt je Gebäude genau einen Grund.
3. **Konvoi:** Eine Kolonne fährt Depot → Flugplatz über den Straßengraphen, lädt und entlädt automatisch, und das Ziellager steigt um die Ladung. Fällt eine Brücke, fahren alle betroffenen Kolonnen binnen 5 s über die Furt oder kehren um, und die neue Ankunftszeit steht auf der Karte (Test).
4. **Wirkung in Sekunden:** Jeder Treffer auf ein Schlüsselziel erzeugt ≤ 3 s danach ein sichtbares Zeichen (Rauch/Brand am Modell) und eine Funkmeldung, und die Kriegskraft der getroffenen Nation sinkt sofort (Test je Zieltyp). Folgen in Minuten: Raffinerie zerstört und eine Kolonne verloren → am Ziel-Flugplatz tankt die erste Maschine nach ≤ 25 min Ersatzbenzin (Szenariotest, Seed fest). Ein einzelner Treffer allein entscheidet nichts (Recherche 1.14).
5. **Bodenangriff:** Jagdbomber-Ausrüstung (2 × 50 kg oder 1 × 250 kg) wird am Boden geladen (Job wie M3), verändert Masse und Widerstand und wird über die Sekundärwaffe abgeworfen. 1 × 250 kg im Umkreis von 10 m zerstört eine Holzbrücke, 2 Volltreffer zerstören die Raffinerie. Bordwaffen stoppen einen Lkw mit 6–12 Treffern (Tests).
6. **KI-Nation:** Über 10 Seeds greift Rot nach der Schutzphase im Mittel alle 8–12 min an, kündigt jeden Angriff ≥ 2 min vorher durch Sammeln über dem eigenen Platz an (Postenmeldung bzw. Plot), repariert beschädigte Gebäude in fester Reihenfolge und stellt nach dem ersten Treffer auf ein Schlüsselziel dort Jäger oder Flak dazu. Keine Ressourcenboni (Test: gleiche Daten für beide Nationen).
7. **Rollen:** Einsatzleiter, Nachschub und Platzleitung lassen sich am Planungstisch übernehmen und wieder an die KI abgeben. Jede Aktion läuft über die Rollenprüfung, ein simulierter Client wird abgelehnt (Test). Eine unbesetzte Rolle macht die KI vollständig, aber mit 60–120 s Reaktionszeit. Beim Einsteigen ins Cockpit gilt der Übergabezettel, nach der Landung zeigt eine Zeile, was die KI getan hat.
8. **Takt:** In einer aufgezeichneten Testpartie (headless, KI auf allen Rollen, Ereignisprotokoll) gibt es für jede Nicht-Flieger-Rolle zwischen Minute 10 und 70 höchstens eine Lücke > 4 min ohne Ereignis, das eine Entscheidung erlaubt (Konvoi-Abfahrt, Meldung, Schaden, Anfrage, Lagebesprechung).
9. **Realismus-HUD:** Im Flug und zu Fuß gibt es keine Lagerbestände und keine Fortschrittsbalken. Zahlen sieht nur die zuständige Rolle an ihrer Tafel. Rückmeldungen kommen grob per Funk („Kolonne 2 ist durch, Fasslager gut gefüllt“).
10. **Determinismus und Netztauglichkeit:** Gleicher Seed und gleiche Eingaben ergeben über 30 min Partiezeit denselben Wirtschafts-Log-Hash (Test, zweimal headless). Kein Wirtschafts- oder Konvoizustand hängt an Jolt, an der Kamera oder an der Grafikstufe. Jeder Zustand hat eine kompakte Array-Form.
11. **Leistung:** 2 Nationen mit 8 Gebäuden, 8 Kolonnen (je 2–3 Lkw), 12 Flugzeugen, 8 Flak und 8 Figuren ≤ 6 ms je Physik-Tick headless, ≥ 60 FPS beim Tester (Stufe Mittel).
12. **Export:** Selbsttest mit der exportierten .pck um die Phasen F–H erweitert und grün. Alle Pakete ≤ 30 MB. Alle Tests aus M1–M3 bleiben grün (bekannte Rote wie `test_duels_flat` ausgenommen).

## 2. Umfang

### 2.1 Rollen

Grundlage ist der Rollenkatalog vom 22.11.2026. Die Recherche (Teil 5) empfiehlt „wenige, dichte Sitze“: Bei 1–4 Spielern langweilt ein Sitz mit zu wenig Arbeit sofort (P6). Jede Rolle muss mit KI vollständig funktionieren (P10), und M4 hat noch keinen Mehrspieler. Deshalb sind in M4 drei neue Sitze voll spielbar, die ein einzelner Tester nacheinander ausprobieren kann.

| Rolle | M4-Stand | Was genau | Begründung |
|---|---|---|---|
| **Pilot** | voll spielbar (erweitert) | Jäger wie M3, neu Jagdbomber-Ausrüstung, Tiefangriff mit Bordwaffen, Sichtmeldungen beim Überflug | Bodenangriff ist der Hebel „gegnerische Wirtschaft stören“ |
| **Werkstatt & Bodenpersonal** | voll spielbar (erweitert) | M3-Abfertigung plus Bomben laden (Job), Ausrüstung wechseln (Jäger ↔ Jabo), Vorbestellung per Funk vor der Landung (G2) | G2 ist billig und verbindet Pilot und Boden (Recherche 3.5). Ausbildung siehe Frage 10 |
| **Einsatzleiter** | **neu, voll spielbar** | Schwerpunkt-Marker (K1), Befehlspunkte mit 3 Befehlen (K2: Großangriff, Notreparatur, Sonderkonvoi), Auftragstafel mit Kopfgeld (K3), Lagebesprechung mit 3 Vorschlägen, Forschungsreihenfolge (Vorschlag der KI annehmen oder ändern) | A liefert die Lesbarkeit für ihn (Recherche Teil 4, Punkt 2). Eigene Ressource Befehlspunkte (P3) |
| **Nachschub** | **neu, voll spielbar** | Fahrplantafel mit 3 Kolonnen (L1), Begleitschutz-Anfrage (L2), Lager-Priorität und Mindestbestände (L3), Engpass-Ansicht mit Sonderschicht und Produktionsumstellung der Munitionsfabrik (L4), Kolonne in Wald-Halt schicken (aus L5) | C liefert den Takt (Teil 4, Punkt 1). Ausnahmesteuerung: KI fährt den Standardfahrplan, der Mensch verschiebt |
| **Platzleitung** | **neu, voll spielbar** | Reparatur-Warteschlange mit Behelf/gründlich und sichtbaren Bautrupps (B1, B2), Bau an festen Bauplätzen (Flak, Reservelager, eine Attrappe), Plot-Tisch mit Postenmeldungen (V1), Alarmstart auslösen (V2), grober Jäger-Vektor als Funkspruch (V3 light) | Bau und Luftverteidigung bündeln die Arbeit zwischen Angriffen (B3/B4) und während Angriffen (V1/V2) |
| **Aufklärung & Nachrichten** | nur KI | Beobachtungsposten melden Verbände, Piloten melden beim Überflug Feindgebäude, das Feindbild auf der Karte altert. Die Rolle hat noch keinen Sitz | Ohne Kameras und Funkhorchdienst bleibt dem Menschen zu wenig zu tun. Die Daten (Feindbild mit Alter) braucht trotzdem jeder |
| Jäger-Vektoren im HUD, Foto-Tisch, Funkhorchdienst, bemannbare Flak, Ausbildung | angedeutet bzw. später | Vektor nur als Funkspruch („Verband Kurs Raffinerie, Höhe mittel“), kein HUD-Pfeil. Abgehörter Funk erscheint nur als Meldungstext der KI („Funkverkehr bei Platz Rot nimmt zu“) | Hält M4 im Umfang. Recherche Teil 5 „Nicht in M4“ |

Budget-Regler, Abstimmungen und Abwahl brauchen mehrere Spieler und kommen mit dem Mehrspieler. In M4 gibt es nur die Leitplanken, die auch allein Sinn ergeben: 30 s Rückgängig für Fahrplan, Reparaturliste und Schwerpunkt sowie ein Aktionsprotokoll („wer hat was getan“, Mensch oder KI).

### 2.2 Wirtschaft (Variante A + Konvoi-Kern aus C)

**Kette je Nation (8 Gebäude):**

```
Holzfällerlager ─▶ Sägewerk ─▶ Depot ─(Kolonne)─▶ Flugzeugwerk ─(Tieflader)─▶ Flugplatz (Hangar)
Ölfeld ─▶ Raffinerie ─▶ Depot ─(Kolonne)─▶ Flugplatz: Tanklager, Bunker, Flak-Lager
Munitionsfabrik ─▶ Depot ─(Kolonne)─▶ Flugplatz / Bauhof
Institut ─▶ Forschungspunkte
```

- **Rohstoffe:** Rundholz (Holzfällerlager), Rohöl (Ölfeld). Kein Erz, kein Strom, kein Bauxit (GDD Slice Punkt 8). Die Munitionsfabrik braucht in Tier I keinen Eingang.
- **Werksverkehr ist abstrakt:** Holzfäller → Sägewerk, Ölfeld → Raffinerie und Raffinerie/Sägewerk/Munitionsfabrik → Depot liegen jeweils ≤ 1,5 km auseinander und sind über einen festen Werksweg verbunden (Feldbahn bzw. Rohrleitung als Kulisse). Sie sind über das Gebäude angreifbar, nicht über einzelne Fahrzeuge. Das hält die Zahl der Fahrzeuge klein (Risiko Leistung) und die Kette lesbar.
- **Konvoi-Kern (physisch):** 3 Lkw-Kolonnen je Nation und 1 Tieflader für Flugzeuge. Strecken: Depot → Flugplatz (Treibstoff, Munition, Bomben, Flak-Munition), Depot → Flugzeugwerk (Bauholz), Depot → Bauhof am Flugplatz (Bauholz), Flugzeugwerk → Flugplatz (2 zerlegte Jäger). Be- und Entladen ist immer automatisch (Foxhole-/Reforger-Lehre). Ein Spieler kann einen Kolonnen-Lkw selbst fahren (das Fahrmodell aus M3 gibt es schon) und erhält dafür +10 % Tempo für die Kolonne, ist dazu aber nicht verpflichtet (P2).
- **Lager:** physisch wie M3. Am Flugplatz Tanklager, Munitionsbunker (jetzt mit Bomben und 2-cm-Munition), Flak-Lager und Bauhof (Bauholz). Dazu das Depot (Umschlag) und kleine Eingangslager an jedem Werk. Ein Gebäude, dessen Ausgangslager voll ist, stockt („Ausgang voll“).
- **Flugzeuge sind Ware:** Das Flugzeugwerk baut Jäger, der Tieflader bringt sie zum Hangar, und erst dort sind sie startbereit. Wie hart das den Spieler trifft, klärt Frage 3.
- **Forschung light:** Das Institut erzeugt Forschungspunkte. 5 Tier-I-Knoten mit direkter Wirkung auf die Kette (Tabelle §5) und der Meilenstein „Übergang Tier II“ (braucht 3 der 5 Knoten). Tier-II-Flugzeuge gibt es in M4 nicht. Was der Meilenstein bewirkt, klärt Frage 8.
- **Bau:** 2 Bautrupps je Nation (GDD), die mit einem Lkw sichtbar über die Straßen fahren. Reparatur beschädigter Gebäude, Wiederaufbau zerstörter Gebäude, Behelfsreparatur (B2), Behelfsbrücke an der Furt. Neubau nur an festen Bauplätzen (Frage 7).
- **Schadenszustände:** intakt (Leistung 100 %), beschädigt (unter 70 % HP, Leistung 50 %, Rauch), zerstört (0 HP, Leistung 0 %, Brand, danach Trümmer). Behelfsrepariert: 60 % Leistung, beim nächsten Treffer sofort zerstört. Folgeschaden: Ein zerstörtes Lager verliert 50 % seines Inhalts (Brand), eine Brücke sperrt die Kante im Straßengraphen.
- **Kriegskraft:** gewichtete Summe aus Industrieleistung (40 %), Lagerbeständen (20 %), einsatzbereiten Flugzeugen (30 %) und Forschungsfortschritt (10 %). Wo sie angezeigt wird, klärt Frage 4. Kapitulation nach GDD §8, dazu Zeitlimit und Schutzphase (10 min).

### 2.3 Karte (40 × 40 km, vorhandenes Gelände)

Heute gibt es Gelände, Fluss, 3 Bäche, 2 Flussbrücken (Nord: Fachwerk, Süd: Steinbogen), 2 Flugplätze und 6 geglättete Zielflächen (je Seite „Erzmine“, „Raffinerie/Tanklager“, „Fabrik“). Es gibt **keine Straßen und keine Bahn**. M4 braucht:

1. **Standorte** für 8 Gebäude je Nation. Die vorhandenen Flächen werden umgewidmet: „Erzmine“ wird zu Holzfällerlager + Sägewerk (am Waldrand), „Raffinerie/Tanklager“ wird zu Ölfeld + Raffinerie + Depot + Munitionsfabrik (Industrie-Ballung, gut schützbar, klares Schlüsselziel), „Fabrik“ wird zum Flugzeugwerk. Neu sind eine Fläche für das Institut (nahe Flugplatz), je 3 Bauplätze am Flugplatz und an der Industrie, je 5 Plätze für Beobachtungsposten an den Anflugwegen und je 6 Flak-Stellungen (2 am Flugplatz, 2 an der Industrie, 2 frei für Bauplätze).
2. **Straßennetz** als Graph in den Geländedaten (Knoten, Kanten mit Art Straße/Feldweg/Furt/Brücke, Breite, Höchsttempo). Sichtbar als Fahrbahn im Gelände-Shader (Maskenkanal oder Band-Mesh wie das Wasser) mit Baumfreiraum. Etwa 60–80 km Straße insgesamt.
3. **Engstellen auf den eigenen Wegen.** Alle eigenen Anlagen liegen auf der eigenen Flussseite, die beiden Flussbrücken liegen also auf keinem eigenen Nachschubweg. Deshalb kreuzt die Hauptroute Industrie → Flugplatz jeder Nation einen Bach über eine **Bachbrücke** (Holz, neues Modell, Ziel). Bachaufwärts liegt eine **Furt** (Umweg +60–100 % Fahrzeit, nur Schritttempo). Für Blau ist das der West- oder Südbach, für Rot der Nordbach. Die Lage prüft das Kartenpaket. Die Flussbrücken bekommen eine Straße und bleiben angreifbar. In M4 sind sie die Wege der KI-Suchtrupps und Bautrupps zur Front und ein Kulissenziel mit Kriegskraft-Gewicht. Die volle Bedeutung bekommen sie erst mit einer Bodenfront.
4. **Bahn:** nicht in M4 (Frage 2). Eine Bahnlinie ändert Gelände und Graph ein zweites Mal und kostet einen eigenen Fahrzeugtyp.
5. Die Kartendaten werden neu erzeugt (`tools/build_terrain.gd`). Flugplätze, Pisten, Layouts und Bachläufe bleiben unverändert, nur Flächen, Straßen und Bauplätze kommen dazu. Das Kartenpaket bleibt ≤ 30 MB.

### 2.4 Neue Modelle (Grafik-Agent, Blender-Python, Stil B)

| Prio | Modell | Zustände / Marker | Budget |
|---|---|---|---|
| 1 | Raffinerie (Kolonne, 2 Tanks, Rohrbrücke, Schornstein) | intakt, beschädigt, zerstört, Rauch-/Feuer-Marker `fx_smoke_*` | ≤ 25k Dreiecke |
| 1 | Depot (Lagerhalle, Fassstapel, Rampe) mit sichtbaren Stapeln je Füllstand | 3 Zustände, `stack_*` | ≤ 15k |
| 1 | Lkw (3 t, Pritsche mit Plane), Bautrupp-Lkw (Werkzeug, Bohlen), Tieflader mit Rumpf unter Plane | intakt, Wrack, Marker `seat_driver`, `cargo_*` | ≤ 12k je Stück |
| 1 | Bomben 50 kg und 250 kg, Aufhängung am Jäger (`hardpoint_*` gibt es schon: Flügel je 50 kg, Rumpf 250 kg) | – | ≤ 1k |
| 1 | Bachbrücke Holz (Joch, Bohlen) | intakt, zerstört (Feld eingestürzt), Behelf | prozedural wie `bridges.gd` |
| 2 | Ölfeld (3 Pumpenböcke, animiert), Holzfällerlager + Sägewerk (Halle, Stämme, Gatter), Munitionsfabrik (Hallen, Erdwälle), Flugzeugwerk (große Halle, Vorfeld), Institut (Backsteinbau, Funkmast) | 3 Zustände; Rauch an/aus = läuft/steht (Factorio-Lehre: Zustand aus 1.500 m lesbar) | ≤ 20k je Stück |
| 2 | Flak 2 cm (Einzellafette, Splitterschutz aus Sandsäcken, drehbar), Beobachtungsposten (Holzturm, Fernglas-Figur) | intakt, zerstört, `muzzle`, `pivot_yaw/pitch` | ≤ 8k |
| 2 | Planungstisch mit Karte, Steckfähnchen, Telefon (in die Flugleitung aus M3.4) | `table_use` | ≤ 5k |
| 3 | Gerüst (Wiederaufbau), Trümmerhaufen, Brandflecken (Decals), Attrappe „Schein-Jäger“ aus Holz | – | – |

Animationen der Figur: „Bombe heben/einhängen“ und „am Tisch stehen“ kommen als Keyframes im Blender-Skript dazu (wie M3). Jede fremde Datei kommt mit Lizenz nach `art/licenses/`.

### 2.5 Ausdrücklich NICHT in M4
- Mehrspieler und Netz (Koop, PvP, Steam-Lobby), Speichern/Laden der Partie, Spieler verlässt Partie (siehe §3.4 und Frage 9)
- Diplomatie außer Krieg, Budget-Regler, Abstimmungen, Abwahl
- Zug und Bahnlinie (Frage 2), Schiffe, Lufttransport
- Zweisitziger Bomber und Bordschützen (Frage 1)
- Bodenfront und Sektoren (Variante B), Eroberung
- Bemannbare Flak, Flak-Verlegung, Feuerzonen, Radar, Scheinwerfer, Sperrballone
- Strom, Erz, Bauxit, Tier-II-Flugzeuge und -Gebäude
- Aufklärungskamera und Foto-Tisch, Funkhorchdienst als Spielerwerkzeug, Funktäuschung
- Rettung abgeschossener Piloten per Flugzeug/Lkw, Gefangenschaft und Verhör
- Rekrutieren und Ausbilden von Bodenpersonal (Frage 10), Dienstgrade mit Boni
- Wetter außer Wind, Nacht
- Persönlichkeiten außer „Industrieller“

## 3. Systeme und Verträge

Paket 0 schreibt `docs/m4_vertrag.md` (Form wie `m3_vertrag.md`). Die Namen hier sind die Vorgabe dafür.

**3.1 Kern (neu in `core/`):**
- `MatchRules` ergänzt: `Tempo {SCHNELL, NORMAL, LANG}` mit `tempo_mul()` (1,5/1,0/0,6), `time_limit_min` (Standard 75), `protection_min` (10), `match_seed`, `[m4]`-Konfig und `--tempo=`, `--zeitlimit=`, `--seed=`.
- `EconomyEvents` (Bus wie `GroundEvents`, nur Server): `structure_damaged(id, amount, attacker)`, `structure_state(id, old, new)`, `production_stalled(id, reason)`, `convoy_event(id, kind)` (departed, arrived, rerouted, halted, attacked, lost), `crew_event(id, kind, target)`, `research_done(nation, node)`, `raid_announced(nation, target_hint, eta)`, `plot_report(nation, plot)`, `war_power(nation, value)`, `request_posted/answered/expired(id)`, `match_ended(winner, reason)`. Mit Ereignis-Log und `log_hash()` wie `CombatEvents`.
- `SimClock`: Wirtschaftstakt 1 s Partiezeit (60 Physik-Ticks), zählt Ticks statt Uhrzeit, `sim_time`. Alle Wirtschafts-, Konvoi-, Bau- und Rollen-KIs laufen in diesem Takt in fester Reihenfolge (nach Nation, dann nach Id).
- `SimRng`: Zufall je Teilsystem und Nation aus `match_seed` (kein globales `randf`).

**3.2 Wirtschaft (`economy/`, neu):**
- `StructureDef` (.tres): Art, HP, Rüstklasse (weich/hart), Rezept (Eingang → Ausgang je min), Puffergrößen, Reparatur- und Wiederaufbauzeit, Bauholzkosten, Kriegskraft-Gewicht, Modellpfad. Alle Zahlen aus §5 liegen hier, nicht im Code.
- `Structure` (Node3D in der Welt): `structure_id`, `def`, `nation_id`, `hp`, `state {INTACT, DAMAGED, DESTROYED}`, `makeshift`, `output_mul()`, `take_damage(amount, kind, attacker)` (nur Server), `repair(hp)`, Signal `state_changed`, `to_array()`. Meldet sich als Bodenziel an (3.4).
- `Economy` (Node unter Game, `current`) mit je Nation einer `NationEconomy`: Gebäude, Lager (`FuelSource`/`AmmoBunker` aus M3 wiederverwendet, `AmmoBunker.stock` bekommt die Typen `&"bomb50"`, `&"bomb250"`, `&"20mm"`; neu `TimberStore` für Bauholz), Flugzeugbestand, Forschung, Kriegskraft. `tick()` im SimClock. `bottleneck(structure_id) -> StringName` (genau ein Grund).
- `RoadNet` (`economy/roads/`): Graph aus `TerrainData.roads`, `route(from, to, avoid) -> Route` (A*, deterministisch, Kantenkosten = Länge/Tempo), `block_edge(bridge_id)`, `eta(route)`.
- `Convoy` (Daten, RefCounted): `id`, `nation`, `trucks` (je 6 Ladeplätze, HP, Ladung), `route`, `progress_m`, `state {LOADING, DRIVING, HALT, UNLOADING, RETURNING, LOST}`, `escort_request`. `ConvoyService` (Node) bewegt Kolonnen im SimClock entlang der Route (Abstand 25 m je Lkw, Tempo je Kante), unabhängig von der Kamera. **Treffer brauchen keine Physikkörper:** Jeder Lkw ist eine Trefferbox im Bodenziel-Register (Lehre aus `TreeObstacles`). Modelle (`ConvoyVisual`) erscheinen nur im Umkreis von 6 km um eine Kamera und folgen der Sim-Position mit Glättung. Steuert ein Spieler einen Lkw selbst, gibt die Kolonne diesen Lkw an das Fahrmodell aus M3 ab und nimmt ihn am Ziel wieder auf.
- `BuildCrew` (Daten + Lkw im ConvoyService): Warteschlange je Nation, `queue(order)`, `reorder()`, Arten Reparatur/Wiederaufbau/Behelf/Neubau/Behelfsbrücke. Ein Trupp arbeitet nur am Ort, die Fahrt ist echt.
- `Research`: Knoten aus .tres, `points`, `current`, `choose(node)`, Wirkungen als Multiplikatoren auf `StructureDef`-Werte. `WarPower`: `value(nation)`, `peak`, Kapitulationsuhr. `MatchDirector`: Schutzphase, Zeitlimit, Sieg.

**3.3 Rollen (`roles/`, neu):**
- `RoleService` (Node, `current`): `Role {COMMAND, SUPPLY, FIELD, WORKSHOP, RECON, PILOT}` je Nation. `occupant(nation, role)` (Peer, 0 = KI), `request_take(peer, nation, role)`, `release(peer, role)`, `automation(nation, role)` (nur Vorschläge / Routine automatisch / voll automatisch), `handover(peer, policy)` (Übergabezettel: „wie bisher“, „sparsam“, „aggressiv“).
- **Jede Rollenaktion ist ein Befehl:** `RoleService.submit(peer, nation, role, cmd: Dictionary) -> Result` prüft Server, Besetzung und Recht und legt den Befehl in die Warteschlange des nächsten SimClock-Takts. Die Rollen-KIs rufen dieselbe Funktion mit Peer 0 auf. Das ist dieselbe Regel wie `JobBoard.request_step` in M3: offline ein direkter Aufruf, später ein RPC.
- `RequestBus` (Anfragen-Bus 3.0 C): `post(from_role, to, kind, payload, deadline_s, reward)`, `answer(id, choice)`. Läuft die Frist ab, entscheidet die KI. Im Flug kommen Anfragen über den Funk mit Kurzbefehl (Annehmen / Ablehnen / KI entscheidet).
- `RoleBrain` je Rolle (`ai/roles/`): `CommandBrain` (Ziel-Graph mit Prioritäten, Persönlichkeit Industrieller, Lagebesprechung), `SupplyBrain` (Standardfahrplan, Lagerprioritäten), `FieldBrain` (Reparatur nach Kriegskraft-Gewicht, Alarm nach der zweiten Meldung), `WorkshopBrain` (Dispatch aus M3, Ausrüstung je Auftrag, Forschungswahl), `ReconBrain` (Posten, Feindbild). **Nations-KI = Summe dieser Rollen-KIs** (GDD-Entscheidung 4): Rot benutzt dieselben Klassen wie die freien Sitze von Blau.
- `Intel` je Nation: `known(structure_id) -> {state, stock_hint, seen_at}`, `report(source, entity, quality)`, `age_s(id)`, Plots `{pos, heading, count_min, count_max, alt_band, seen_at}`.
- `ServiceRecord` (Dienstbilanz): je Rolle Kennzahlen und eine Highlight-Zeile alle 10 min. Kettenkredit light: Jede Lieferung trägt die Rolle, die sie veranlasst hat (Mensch oder KI). Starts aus diesem Lager werden anteilig zugeschrieben.

**3.4 Waffen gegen Bodenziele (`weapons/`, `vehicles/aircraft/`):**
- `GroundTargetRegistry`: Bodenziele (Gebäude, Lkw, Flak, Brücke, abgestellte Flugzeuge) als Boxlisten mit Rüstklasse. `ProjectileSystem` prüft Geschosse zusätzlich gegen dieses Register (gleicher Segmenttest wie bei Flugzeugen). MG gegen „hart“ ×0,1, gegen „weich“ ×1,0. Brandchance je Treffer auf Fässer und Tank-Lkw.
- `OrdnanceDef` (.tres: Masse, Widerstandsfläche, Sprengradius innen/außen, Schaden, Zündverzögerung) und `OrdnanceSystem` (Fall mit Luftwiderstand, deterministisch wie die Ballistik, Aufschlag auf `height_at`/Wasser/Brücken, Explosion mit Schadensabfall über das Register und gegen Flugzeuge in der Nähe).
- `StoresState` am Flugzeug: Belegung der Aufhängungen. `WeaponSystem` Gruppe SECONDARY wirft paarweise bzw. einzeln ab. `Aircraft` addiert `stores_mass_kg()` zur Masse (wie die Munitionsmasse aus M3.11) und gibt `stores_drag_area()` über `FlightModifiers` als Zusatzwiderstand ins Flugmodell.
- `LoadOrdnanceJob` (Stub aus M3) wird echt: Bombe vom Wagen nehmen, unter die Aufhängung bringen, einhängen (halten), Zünder scharf machen. Je Realismus-Stufe in `ground_rules_*.tres`.
- **Flak** (`weapons/flak/`): `FlakGun` (Structure + Geschütz) mit eigener `WeaponDef` 2 cm, KI-Zielen über `LeadSolver` mit großer Streuung, Vorrat am Geschütz, Nachschub aus dem Flak-Lager. Stört und beschädigt, ersetzt keine Jäger (GDD 8).

**3.5 KI-Flug (`ai/brain/`):**
- `Sortie` (Auftrag an einen KI-Piloten): Art {PATROL, ESCORT, INTERCEPT, CONVOY_HUNT, STRIKE, RECON_FLIGHT}, Ziel, Zeitfenster, Ausrüstung. `AIPilotBrain` bekommt neue Zustände für Tiefangriff (Anflug, Bahnneigung 30°, Feuer, Abfangen) und Sturzangriff mit Bomben (Anflug in 1.500 m, Sturz 45–60°, Abwurf in 600–800 m, Abfangen). Der Bodenschutz aus M3.11 hat Vorrang vor dem Angriff.
- `SquadronPlanner` je Nation: verteilt KI-Piloten auf Sorties nach den Vorgaben des Einsatzleiters (Mensch oder `CommandBrain`). Sammeln vor einem Angriff (2–5 min Kreisen über dem eigenen Platz, für Posten und Aufklärer sichtbar).

**3.6 Funk und UI (`ui/`):**
- Funkkanäle 5–8 werden angehängt (funk_konzept §3): 5 Werkstatt-Leitung (Ausrüstung, Vorbestellung), 6 Nachschub, 7 Platzleitung, 8 Einsatzleiter. Das Funkgerät bekommt eine zweite Seite (Ziffer 1–4 je Seite, ←/→ blättert) oder Ziffern 1–8, damit nur die Zahlentasten belegt bleiben. Besetzte Rolle → Anfrage an den Spieler, sonst antwortet die KI.
- `PlanningTable` (Interactable am Tisch in der Flugleitung, „E halten: Planungstisch“): öffnet die Strategiekarte mit Reitern je Rolle. Was am Boden außerhalb geht, klärt Frage 6.
- Strategiekarte: Gelände, Straßen, eigene Gebäude mit Ampel und Engpass, eigene Kolonnen mit Ankunftszeit, aufgeklärte Feindziele mit Alter (verblassen), Plots, Schwerpunkt-Ringe. Zahlen nur in den Reitern der zuständigen Rolle (`StockView.visible_for(role)`).
- Im HUD des Fliegers: Schwerpunkt-Ring, Auftragsziel als Marker, Funkanfragen mit Kurzbefehl. Keine Lagerzahlen.

### 3.7 Mehrspieler: nicht bauen, aber vorbereiten

Mehrspieler kommt in M4 nicht (Frage 9 bestätigt das). Begründung: Der Tester spielt allein, und jede Rolle muss ohnehin vollständig mit KI laufen (P10). Die Rollen lassen sich also allein testen, indem man zwischen Sitzen wechselt. Ein Netzpaket würde M4 verdoppeln, ohne die Wirtschaft spielbarer zu machen. Damit M5 den Mehrspieler ohne Umbau aufsetzen kann, gelten in allen Paketen fünf Regeln:
1. Zustand ändert nur der Server (`Authority.is_server()`), Rollen über `RoleService.submit`, Boden über `JobBoard`/`SeatService`. Jeder neue Dienst hat einen Test „simulierter Client abgelehnt“.
2. Die Wirtschaft ist deterministisch: SimClock, SimRng, feste Reihenfolge, keine Uhrzeit, kein Jolt. Der Test zum Log-Hash läuft in der Suite fast mit 5 min und in slow mit 30 min.
3. Jeder Dienst hat `to_array()`/`from_array()` für seinen Zustand (Grundlage für Replikation und für Speichern/Laden in M5).
4. Sichtbarkeit läuft über `Intel` je Nation, damit Clients später nur ihr Feindbild bekommen (GDD §7).
5. Nichts in der Spiellogik hängt an der Kamera, am Floating Origin oder an der Grafikstufe (Konvoi-Treffer, Gebäude-Hitboxen und Posten laufen immer).

## 4. Arbeitspakete

Höchstens 3 Agenten gleichzeitig. Jedes Paket ist nach ≤ 45 min committbar, große Pakete sind in a/b geteilt. Tests liegen unter `tests/suites/<ordner>/`, Screenshots unter `docs/screens_m4/`.

### 4.1 Übersicht

| # | Paket | Ordner (exklusiv) | Abh. | Umfang |
|---|---|---|---|---|
| 0a | Vertrag Kern: MatchRules (Tempo, Zeitlimit, Seed), EconomyEvents, SimClock, SimRng, RoleService-/RequestBus-Stubs, Intel-Stub, Radio-Kanäle 5–8 als Daten | core/, roles/ (Stubs), ground_ops/radio/ | M3.11 | M |
| 0b | Vertrag Spielsysteme: Structure/StructureDef, GroundTargetRegistry-Hook in ProjectileSystem, StoresState + Masse/Widerstand-Hook, OrdnanceDef-Stub, `TerrainData.roads/sites`-Felder, Stubs aller neuen Klassen, `test_contract_m4.gd`, `docs/m4_vertrag.md` | weapons/projectile_system.gd, weapon_system.gd, aircraft.gd, terrain_data.gd, game.gd | 0a | M |
| **Strang W (Wirtschaft)** ||||
| 1 | Economy-Kern: Gebäude, Rezepte, Puffer, Tempo, Zustände, Engpass, Mengen-Erhalt | economy/ (ohne roads/) | 0 | M |
| 2a | RoadNet + Konvoi-Sim (Fahren, Laden, Brücke sperrt, Furt, Wald-Halt) | economy/roads/, economy/convoy/ | 1, 5 (Daten) | M |
| 2b | ConvoyVisual, Lkw-Abgabe an Spieler-Fahrer, Tieflader mit Flugzeugen | economy/convoy/, vehicles/ground/ (nur neue Dateien) | 2a | M |
| 3 | Bautrupps, Reparatur-Warteschlange, Behelf, Neubau an Bauplätzen, Behelfsbrücke | economy/build/ | 1, 2a | M |
| 4 | Forschung light, Kriegskraft, MatchDirector (Schutzphase, Zeitlimit, Kapitulation) | economy/research/, economy/match/ | 1 | S |
| **Strang K (Karte und Welt)** ||||
| 5 | Kartendaten: Standorte, Straßengraph, Bachbrücken, Furten, Bauplätze, Posten- und Flak-Plätze, neu erzeugen | world/terrain/terrain_generator.gd, tools/build_terrain.gd, world/terrain/data/ | 0b | M |
| 6 | Straßen sichtbar (Shader/Band-Mesh, Baumfreiraum), Bachbrücken prozedural und zerstörbar | world/terrain/ (roads, bridges) | 5 | M |
| 7 | Gebäude in der Welt: Structures setzen, Platzhalter, Zustandsdarstellung (Rauch, Brand, Trümmer, Gerüst), Hitboxen | world/structures/ | 1, 5 | M |
| **Strang A (Angriff)** ||||
| 8 | Bordwaffen gegen Bodenziele: Register, Rüstklassen, Lkw-Schaden, Brand, Explosion von Munitions-Lkw | weapons/ground/ | 0b | S |
| 9a | Bomben: OrdnanceSystem, Explosion, Schaden, Splitter, Wasser | weapons/ordnance/ | 8 | M |
| 9b | Jabo-Ausrüstung: StoresState, Abwurf, Masse/Widerstand, Arcade-Aufschlagpunkt | weapons/ordnance/, weapons/data/ | 9a | S |
| 10 | Bomben laden: LoadOrdnanceJob, Bomben im Bunker und auf dem Wagen, Ausrüstung wechseln, KI-Personal | ground_ops/jobs/, ground_ops/data/, ai/ground/ | 9b | M |
| 11 | Flak 2 cm (KI), Flak-Lager, Nachschubbedarf | weapons/flak/ | 8, 1 | S |
| **Strang I (KI)** ||||
| 12a | KI-Tiefangriff und Konvoi-Jagd (Sortie, Zustände, Bodenschutz) | ai/brain/ | 8 | M |
| 12b | KI-Sturzangriff mit Bomben, Begleitschutz, Abfangen | ai/brain/ | 9b, 12a | L |
| 13 | SquadronPlanner, Sammeln vor dem Angriff, Reaktion nach Treffer | ai/air/ | 12a, 4 | M |
| 14 | Rollen-KIs (Command, Supply, Field, Workshop, Recon), Intel, Posten, Plots, Sichtmeldung beim Überflug | ai/roles/, roles/ (ohne UI) | 1–4, 13 | L |
| **Strang R (Rollen und Oberfläche)** ||||
| 15 | RoleService echt, Übergabezettel, Rückgängig, Aktionsprotokoll, RequestBus | roles/ | 0a, 1 | M |
| 16 | Planungstisch + Strategiekarte (Grundansicht) | ui/strategy/ | 15, 5 | M |
| 17a | Reiter Einsatzleiter und Nachschub | ui/strategy/ | 16, 2a | M |
| 17b | Reiter Platzleitung und Werkstatt, Plot-Tisch | ui/strategy/ | 16, 3, 14 | M |
| 18 | Funk 5–8, Anfragen im Flug, HUD-Ring/Auftragsmarker, Dienstbilanz, Partieende-Bildschirm | ui/ground/radio_panel.gd, ui/combat/ (neue Dateien), ui/match/ | 15, 14 | M |
| **Phase 2: Grafik, Integration, Test** ||||
| 19a | Modelle Prio 1: Raffinerie, Depot, Lkw, Tieflader, Bautrupp-Lkw, Bomben, Bachbrücke | art/scripts/build_industry.py, build_vehicles_m4.py, art/models/, game/assets/industry/ | 0b (Markernamen) | L |
| 19b | Modelle Prio 2–3: Ölfeld, Sägewerk, Munitionsfabrik, Flugzeugwerk, Institut, Flak, Posten, Planungstisch, Gerüst, Attrappe; Figur-Posen | dito, characters/crew/anim/ | 19a | L |
| 20 | Integration: Szenario „Partie“, Spieler-Nation mit KI-Flügelleuten, Ersatz des Alarm-Takts aus M3 durch echte Angriffe, Konfig, F1-Hilfe | world/game.gd, world/combat_scenario.gd → world/match_scenario.gd, ui/hud.gd, project.godot | alle | M |
| 21 | Selbsttest (Phasen F–H), Partie-Soak 75 min, Leistung, Export, Doku, Build | world/selbsttest.gd, tests/suites/export/, tools/, docs/ | 20 | M |

### 4.2 Reihenfolge und Parallelität

```
Phase 0  (1 Agent):   0a → 0b
Phase 1  (3 Agenten): W: 1 → 2a → 3 → 4      K: 5 → 6 → 7       A: 8 → 9a → 9b → 11
Phase 2  (3 Agenten): R: 15 → 16 → 17a       I: 12a → 12b → 13   A/G: 10 → 19a
Phase 3  (3 Agenten): R: 17b → 18            I: 14               G: 19b, danach W: 2b
Phase 4  (1–2 Agenten): 20 → 21
```

Kritischer Pfad: 0 → 1 → 2a → 14 → 17b → 20 → 21. Paket 5 (Karte) muss vor 2a fertige Straßendaten liefern. Bis dahin testet 2a auf einem kleinen Test-Straßengraphen in `tests/`. Die Gebäude laufen bis 19 mit Platzhalter-Kisten in der richtigen Größe (Paket 7).

### 4.3 Pakete im Einzelnen

**0a/0b Vertragsschnitt.** *Ziel:* Alle Stränge können parallel arbeiten. *Inhalt:* siehe §3 und Übersicht. Die eingefrorenen Dateien sind die aus M3-Vertrag §1 und zusätzlich `core/*`, `roles/role_service.gd`, `economy/structure.gd`, `economy/structure_def.gd`, `weapons/ground_target_registry.gd`, `weapons/ordnance/ordnance_def.gd`, `vehicles/aircraft/stores_state.gd`, `test_contract_m4.gd`. *Abnahme:* `test_contract_m4` (Stubs vorhanden, Signaturen, EconomyEvents-Log-Hash leer = 0, MatchRules-Tempo parsen, RoleService lehnt simulierten Client ab, ProjectileSystem trifft eine Test-Bodenbox, Masse +250 kg ändert `Aircraft.mass`), alle M1–M3-Tests grün, Export grün. *Risiko:* `aircraft.gd` und `projectile_system.gd` sind heiß. Darum nur Hooks, keine Logik.

**1 Economy-Kern.** *Ziel:* Die Kette läuft headless ohne Welt. *Inhalt:* `StructureDef`-Daten für 8 Gebäude (§5), Rezepte, Puffer, Tempo-Multiplikator, Zustandsfaktoren, Engpass (`input_missing`, `output_full`, `damaged`, `destroyed`, `no_crew`), Forschungs-Multiplikatoren als Hook. *Verträge:* `Economy.current`, `NationEconomy.stock(kind)`, `bottleneck(id)`, `to_array()`. *Abnahme/Tests:* `test_chain_steady` (60 min Partiezeit ungestört: Depot-Zuflüsse ±2 % der Sollwerte aus §5), `test_damage_states` (50 %/0 %, Behelf 60 %), `test_tempo` (Schnell = ×1,5 Produktion), `test_conservation` (±0,1 %), `test_bottleneck_single_reason`, `test_client_rejected`, `test_determinism_hash` (2 Läufe gleich). *Risiko:* Zahlen nicht im Code verstreuen; alles in `.tres`.

**2a RoadNet + Konvoi-Sim.** *Ziel:* Kolonnen bewegen Güter sichtbar und verwundbar. *Inhalt:* A* auf dem Straßengraphen, Tempo je Kante (§5), Kolonne mit 2–3 Lkw im Abstand, Laden/Entladen 60 s je Lkw, Kante gesperrt → Umleitung oder Umkehr, Furt mit Schritttempo, Wald-Halt (Kolonne hält 2 min an der nächsten Waldkante, für KI-Jäger schwer zu entdecken: Erkennungsweite ×0,3), Lkw-HP, Verlust einzelner Lkw (Ladung brennt oder liegt als Kisten herum). *Verträge:* `ConvoyService.dispatch(nation, from, to, cargo, escort) -> id`, `convoys(nation)`, `eta(id)`, `halt(id)`, `EconomyEvents.convoy_event`. *Tests:* `test_convoy_delivers`, `test_bridge_reroute` (≤ 5 s nach Sperre neue Route, ETA länger), `test_ford_speed`, `test_truck_lost_cargo_split`, `test_convoy_independent_of_camera` (gleiches Ergebnis mit und ohne Kamera), `test_perf_8_convoys` (< 0,3 ms je Tick). *Screenshot:* Kolonne auf der Bachbrücke aus 300 m. *Risiko:* Lkw im Gelände ohne echtes Fahrmodell können an Hängen schweben. Darum Höhe aus `height_at`, Neigung aus `normal_at`, Straßen im Kartenpaket mit ≤ 12 % Steigung.

**2b ConvoyVisual und Spieler-Fahrer.** *Ziel:* Lkw sehen echt aus, und der Spieler kann einen fahren. *Inhalt:* Modelle im 6-km-Umkreis, Räder drehen, Staub, Rauch bei Schaden, Übergabe an `GroundVehicle` (Fahrersitz über `SeatService`) und zurück, Tieflader mit 2 Rümpfen. *Tests:* `test_visual_follows_sim` (Abweichung < 0,5 m), `test_player_drives_truck` (Ladung kommt an, Kolonne +10 % Tempo). *Screenshot:* Spieler am Steuer, Kolonne vor ihm.

**3 Bautrupps.** *Ziel:* Wiederaufbau ist sichtbar, begrenzt und angreifbar. *Inhalt:* 2 Trupps je Nation, Bautrupp-Lkw fährt über RoadNet, Gerüst am Gebäude, Reparatur/Wiederaufbau/Behelf nach §5, Bauholz aus dem Bauhof, Neubau an festen Bauplätzen (Flak-Stellung, Reservelager, Attrappe), Behelfsbrücke an der Furt (wird ein eigenes Ziel), Trupp unter Angriff verloren (5 min Ersatz). *Verträge:* `BuildCrew.queue(nation, order)`, `reorder(nation, ids)`, `crews(nation)`. *Tests:* `test_repair_times` (±10 %), `test_makeshift_breaks_on_hit`, `test_crew_drives_to_site`, `test_crew_lost_under_attack`, `test_no_timber_blocks`. *Screenshot:* Gerüst an der Raffinerie, Bautrupp-Lkw davor.

**4 Forschung, Kriegskraft, Partie.** *Ziel:* Die Partie hat einen Bogen und ein Ende. *Inhalt:* 5 Knoten + Meilenstein (§5), Wirkung als Multiplikator, Technologiefluss −30 %. Kriegskraft-Formel, Höchstwert, Kapitulationsuhr, Zeitlimit, Schutzphase (endet für eine Nation vorzeitig, wenn sie selbst angreift). *Tests:* `test_research_36min` (ungestört 33–40 min bis zum Meilenstein bei Normal), `test_war_power_drops_on_hit` (sofort), `test_capitulation_10min`, `test_time_limit_winner`, `test_protection_phase`. 

**5 Kartendaten.** *Ziel:* Die Karte trägt die Wirtschaft. *Inhalt:* §2.3 Punkt 1–3 und 5. Straßen folgen dem Gelände mit ≤ 12 % Steigung, meiden Wasser außer an Brücken und Furten und bekommen eine geebnete Trasse (5 m breit, Böschung). Jede Nation hat auf der Hauptroute Industrie → Flugplatz genau eine Bachbrücke und eine Furt (Umweg +60–100 %). Bauplätze, Posten, Flak-Plätze als Marker in `TerrainData.sites`. *Tests:* `test_roads_connected` (alle Standorte je Nation erreichbar), `test_road_slope_max`, `test_bridge_on_main_route` (Sperre verlängert ETA um 60–100 %), `test_airfields_unchanged` (Layouts, Pistenhöhe gleich), `test_pack_size_map` (≤ 30 MB). *Screenshot:* Übersichtskarte mit Straßen und Standorten (`tools/plot_roads.py`). *Risiko:* Neue Höhen brechen Tests im Gelände (Wind-Gitter, Flusstests). Gegenmittel: nur lokale Glättung an den neuen Flächen, Flugplatzflächen unangetastet, Gelände-Tests vor dem Commit.

**6 Straßen und Bachbrücken sichtbar.** *Inhalt:* Fahrbahn im Gelände-Shader (Maske + Spurrillen) oder Band-Mesh, Vegetation spart die Trasse aus (Baumkollision `TreeObstacles` ebenso), Bachbrücken (Holzjoch) prozedural wie `bridges.gd` mit Zustand intakt/zerstört/Behelf, Flussbrücken bekommen eine Zerstörungsvariante (ein Feld fällt). *Tests:* `test_no_trees_on_road`, `test_bridge_states_collision` (zerstörte Brücke: keine Fahrbahn-Kollision). *Screenshot:* Bachbrücke intakt und zerstört aus 800 m.

**7 Gebäude in der Welt.** *Inhalt:* Structures an den Standorten, Platzhalter-Kisten in Modellgröße, bis Paket 19 die Modelle liefert, Zustandsdarstellung (Rauch an = läuft, Rauchsäule = beschädigt, Brand und Trümmer = zerstört, Gerüst = Bau), Hitboxen ins Register, Depot zeigt Stapel je Füllstand. *Tests:* `test_structure_hitboxes_registered`, `test_state_visuals_switch`, `test_smoke_visible_1500m` (Screenshot-Test, nur visuell geprüft). *Screenshot:* Raffinerie intakt / beschädigt / zerstört aus 1.500 m Höhe (Abnahme 4).

**8 Bordwaffen gegen Bodenziele.** *Inhalt:* Segmenttest gegen das Register, Rüstklassen, Brand an Fässern und Tank-Lkw (Brand frisst Ladung, nach 20 s Wrack), Munitions-Lkw explodiert bei Brand, Treffer-Debug (F3) zeigt Bodenziele. *Tests:* `test_strafe_truck_6_12_hits`, `test_mg_vs_hard_target`, `test_fuel_truck_fire`, `test_ammo_truck_explodes`, `test_ground_hits_server_only`. 

**9a Bomben.** *Inhalt:* Fall mit Luftwiderstand (wie `Ballistics`, eigener k), Zünder mit 0,5 s Verzögerung (Tiefangriff-Selbstschutz), Explosion mit innerem/äußerem Radius und linearem Abfall, Schaden an Structures, Lkw, Flugzeugen am Boden und in der Luft (eigene Maschine unter 100 m Abwurfhöhe gefährdet), Krater-/Fontänen-Effekt (CrashFx wiederverwenden). *Tests:* `test_bomb_fall_time` (aus 1.000 m ≈ 14–15 s, ±5 %), `test_blast_falloff`, `test_bridge_one_250kg`, `test_refinery_two_hits`, `test_bomb_in_water`, `test_self_damage_low_release`. *Screenshot:* Einschlag 250 kg neben der Raffinerie.

**9b Jabo-Ausrüstung.** *Klärung Bomben vs. Bomber:* Ein Jagdbomber-Loadout am vorhandenen Jäger reicht für M4. Das Modell hat schon drei Aufhängungen (Flügel je 50 kg, Rumpf 250 kg). Es braucht also kein neues Flugzeug, keine neue Flugphysik und keinen Schützenplatz, und die historische Vorlage (Bf 109 E-4/B, Hurricane IIB) passt zu Tier I. Weiche Ziele (Lkw, Flak, Fasslager) gehen auch mit Bordwaffen, harte Ziele (Raffinerie, Brücke, Werk) nur mit Bomben. Ein zweisitziger Bomber ist eine Entscheidung für den PO (Frage 1). *Inhalt:* Ausrüstungen „Jäger“ (nur MG), „Jabo leicht“ (2 × 50 kg), „Jabo schwer“ (1 × 250 kg). Masse und Zusatzwiderstand nach §5. Abwurf über die Sekundärwaffe (V / mittlere Maustaste / LT). Arcade: Aufschlagpunkt-Marker wie der Vorhaltepunkt. Realistisch: nur eine Marke im Reflexvisier. *Tests:* `test_jabo_mass_drag` (Höchstgeschwindigkeit mit 250 kg 25–40 km/h geringer, Steigrate −15–25 %), `test_release_pairs`, `test_impact_predictor_accuracy` (< 5 m Abweichung ohne Wind), Bodenschutz-Regression KI. 

**10 Bomben laden.** *Inhalt:* `LoadOrdnanceJob` mit Schritten je Stufe (Einfach: 3 s am Wagen; Standard: Bombe vom Wagen nehmen, tragen bzw. Karren schieben, einhängen 4 s halten, Zünder 2 s; Authentisch: 250 kg nur mit Helfer oder Winde, Zündersicherung vergessen = Blindgänger), Bomben als Typen im Bunker und auf dem Munitionswagen (4 × 50 kg oder 1 × 250 kg je Wagen), Befehl „Ausrüstung: Jäger/Jabo“ im Befehlsrad und auf Kanal 5, KI-Personal lädt nach Auftrag. *Tests:* `test_load_times_per_stage` (±10 %), `test_bomb_conservation`, `test_cart_bomb_slots`, `test_ai_loads_for_sortie`, `test_client_rejected`. *Screenshot:* Mechaniker hängt eine 250-kg-Bombe ein.

**11 Flak.** *Inhalt:* `FlakGun` als Structure mit Geschütz, Erfassung über Posten bzw. eigene Sicht 3 km, Zielen mit LeadSolver und Streuung 8 mrad, Feuerstöße, Selbstzerlegung nach 2.200 m (Sprengwölkchen), Vorrat 600 Schuss am Geschütz, Nachfüllen aus dem Flak-Lager, Treffer eigener Flugzeuge möglich (wenn Eigenbeschuss an). *Tests:* `test_flak_hit_rate` (Jabo-Anflug durch 2 Geschütze: im Mittel 1–3 Treffer, ≤ 15 % Abschüsse über 20 Läufe), `test_flak_consumes_store`, `test_flak_empty_silent`. *Screenshot:* Flak feuert auf anfliegenden Jabo.

**12a KI-Tiefangriff und Konvoi-Jagd.** *Inhalt:* Sortie-Arten CONVOY_HUNT und STRIKE (nur MG), Anflug, Bahn 20–30°, Feuerstoß, Abfangen ≥ 150 m über Grund, zweiter Anflug aus anderer Richtung, Abbruch bei Feindjägern. *Tests:* 10 Seeds gegen eine Kolonne: ≥ 7/10 stoppen ≥ 1 Lkw, 0 Bodenberührungen. 

**12b KI-Sturzangriff, Begleitschutz, Abfangen.** *Inhalt:* Sturz 45–60°, Abwurf 600–800 m, Abfangen mit g-Grenze, Streukreis je Stufe (Rekrut 60 m, Erfahren 40 m, Veteran 25 m), ESCORT (Abstand zum Bomber halten, Feindjäger abdrängen), INTERCEPT (auf Plot vektoriert). *Tests:* 10 Seeds gegen die Raffinerie: ≥ 6/10 mindestens beschädigt, 0 Bodenberührungen; Begleitschutz bleibt ≤ 1,5 km beim Schützling. *Risiko:* Bodenkollision im Sturz. Deshalb Abwurfhöhe konservativ, Bodenschutz hat Vorrang, die Regression läuft mit Hügel-Seeds.

**13 SquadronPlanner.** *Inhalt:* Verteilen der KI-Piloten auf Sorties nach Schwerpunkten, Sammeln 2–5 min vor einem Angriff (Kreisen über dem Platz, `raid_announced` mit Zielhinweis-Unschärfe), Reaktion nach Treffer (Schlüsselziel bekommt für 15 min eine Patrouille und, falls ein Bauplatz frei ist, eine Flak), Mindestreserve 2 Jäger zur Platzverteidigung. *Tests:* `test_raid_interval` (8–12 min Mittel über 10 Seeds), `test_raid_announced_2min`, `test_reaction_after_hit`, `test_no_bonus_resources`.

**14 Rollen-KIs und Intel.** *Inhalt:* `CommandBrain` (Ziel-Graph mit Prioritäten nach Kriegskraft-Gewicht ÷ Abwehr, Persönlichkeit Industrieller: Raffinerie, dann Konvois, dann Brücke), `SupplyBrain` (Standardfahrplan nach Mindestbeständen, Begleitschutz bei Feindsichtung, Wald-Halt bei Postenmeldung), `FieldBrain` (Reparatur nach Gewicht, Alarm nach zweiter Meldung), `WorkshopBrain` (Ausrüstung je Sortie, Forschungswahl), `ReconBrain` (5 Posten je Nation, Meldungen mit Unschärfe, Sichtmeldung beim Überflug ≤ 3 km und ≤ 1.500 m über Grund, Feindbild altert). Reaktionszeit 60–120 s je Entscheidung. Vorschlagsleiste: jede KI legt ihren nächsten Schritt mit Begründung als Vorschlag ab, den der Mensch übernehmen oder ändern kann. *Tests:* `test_ai_nation_full_match` (Rot ohne Spieler 75 min: Kette läuft, Reparaturen, ≥ 5 Angriffe, Forschung), `test_reaction_time_window`, `test_intel_ages`, `test_plot_fuzzy_count`, `test_same_classes_both_nations`. 

**15 RoleService.** *Inhalt:* Übernehmen/Abgeben, Automatik-Stufen, Übergabezettel beim Einsteigen, Bericht nach der Landung, 30 s Rückgängig, Aktionsprotokoll, RequestBus mit Frist und KI-Rückfall. *Tests:* `test_take_release`, `test_submit_rights`, `test_client_rejected`, `test_handover_policy`, `test_undo_30s`, `test_request_expires_to_ai`.

**16 Planungstisch und Strategiekarte.** *Inhalt:* Tisch in der Flugleitung als Interactable, Vollbild-Karte (Gelände-Relief aus der Höhenkarte, Straßen, Gebäude mit Ampel, Kolonnen mit ETA, Feindbild mit Alter, Plots, Schwerpunkte), Zoom/Verschieben mit Maus und Pad, Reiterleiste je Rolle, Übernehmen-Knopf. Keine Zahlen außerhalb der Rollen-Reiter. *Tests:* Smoke, `test_map_hides_stocks_without_role`, Pad-Navigation. *Screenshot:* Strategiekarte Gesamtansicht.

**17a Reiter Einsatzleiter und Nachschub.** *Inhalt:* Einsatzleiter: Schwerpunkt setzen (max. 2, Verlegen 90 s Sperre), Befehlspunkte und 3 Befehle, Auftragstafel mit Kopfgeld (+0/+25/+50 %), Lagebesprechung alle 8–10 min mit 3 Vorschlägen (Wirkung in Kriegskraft-%, Risiko, benötigte Maschinen), Forschungswahl. Nachschub: Fahrplantafel (Ladung in Paletten je Lkw, Route, Abfahrt), Begleitschutz anfordern, Mindestbestände und Rangfolge der Lager, Engpass-Ansicht, Sonderschicht, Munitionsfabrik umstellen, Wald-Halt. *Tests:* jeder Befehl ein Test über `submit`, `test_briefing_three_options`, `test_bounty_paid_on_landing`. *Screenshot:* je Reiter.

**17b Reiter Platzleitung und Werkstatt.** *Inhalt:* Platzleitung: Reparaturliste per Ziehen, Behelf/gründlich, Bauplätze, Plot-Tisch (Plots schieben, Kurs schätzen, mögliche Ziele mit ETA), Alarmstart mit Anzahl Maschinen (startet den Countdown aus M3), Vektor-Funkspruch an einen Jäger. Werkstatt: Ausrüstung je Maschine, Vorbestellungen, Lagerstände Platz. *Tests:* `test_alarm_from_plot`, `test_repair_reorder`, `test_vector_radio`. *Screenshot:* Plot-Tisch mit zwei Plots.

**18 Funk, HUD, Bilanz.** *Inhalt:* Kanäle 5–8 mit Befehlen, Funkgerät mit 8 Kanälen, Anfragen im Flug mit Kurzbefehl, Schwerpunkt-Ring und Auftragsmarker im HUD, Meldungen „Ziel brennt – Feind-Kriegskraft deutlich gesunken“ (grob, ohne Zahl im Flug), Dienstbilanz alle 10 min, Einsatzbilanz der Piloten mit verursachter Ausfallzeit, Partieende-Bildschirm mit Auszeichnungen (Stratege, Rückgrat, Wiederaufbau, Boxencrew). *Tests:* `test_radio_8_channels`, `test_request_shortcut_in_flight`, `test_no_stock_numbers_in_hud`, `test_service_record_highlight`.

**19a/b Modelle.** Siehe §2.4. *Tests:* Import-Smoke, Mesh-Anzahl > 0 auch im Export, Marker vorhanden, Dreiecksbudget, Paketgröße. *Screenshots:* jedes Modell in Vorschau und in der Welt.

**20 Integration.** *Inhalt:* Neues Szenario „Partie“ ersetzt in der Hauptszene „1 gegen 3“ (das alte Szenario bleibt als Option `--szenario=luftkampf`). Blau: Spieler + 4 KI-Piloten, 6 Abstellplätze. Rot: 6 KI-Piloten. Wirtschaft beider Nationen, Rollen-KIs auf allen freien Sitzen. Der feste Alarmstart alle 12–15 min aus M3 entfällt, Alarme kommen aus echten Angriffen (F9 bleibt Debug). Startoptionen `--tempo=`, `--zeitlimit=`, `--seed=`, `--rolle=nachschub` (direkt am Tisch starten). F1-Hilfe für den Kontext „Planungstisch“, Versionsanzeige „M4“. *Tests:* Hauptszenen-Test 5 min headless ohne Fehler, Sitzwechsel Cockpit ↔ Tisch ↔ Lkw.

**21 Selbsttest und Build.** *Neue Selbsttest-Phasen:* **F** Kolonne fährt Depot → Platz Blau im Zeitraffer, das Lager steigt. **G** Bombe trifft eine Test-Structure, der Zustand wechselt, eine Funkmeldung kommt. **H** Planungstisch öffnen und Rolle Nachschub übernehmen über echte Aktionen. Diagnose: Gebäude 16, Straßenknoten, Modelle geladen, Wirtschafts-Hash. Dazu ein Partie-Soak über 75 min Tempo Schnell (`tools/soak.gd` erweitert: Speicher, Knoten, Kolonnen, Gebäude-Zustände). *Abnahme:* §1 Punkte 1, 10, 11, 12.

### 4.4 Risiken

1. **Umfang.** M4 ist etwa doppelt so groß wie M3. Gegenmittel: harte Grenzen aus §2.5, die Kann-Teile (Attrappe, Spieler fährt Lkw, Vektor-Funk, Dienstbilanz-Auszeichnungen) liegen in späten Paketen und dürfen auf M4.1 rutschen. Nach Phase 1 gibt es einen Zwischenstand für den Tester (nur Kette, Kolonnen, Bomben, KI-Angriffe ohne Rollen-Tafeln).
2. **Spielspaß der Nicht-Flieger-Rollen.** Die Tafeln können zur Zahlenwand werden. Gegenmittel: Engpass statt Statistik, Ausnahmesteuerung, Takt-Messung (Abnahme 8), Tester-Durchgang „20 min nur Nachschub“ nach Paket 17a.
3. **KI-Bodenangriff.** Stürze und Tiefflug erhöhen die Bodenkollisionen. Gegenmittel: Bodenschutz hat Vorrang, Seed-Regressionen im Gelände, konservative Abwurfhöhen.
4. **Karte neu erzeugen** bricht Gelände-, Wind- und Flugplatz-Tests. Gegenmittel: nur lokale Änderungen, Flugplatzflächen gesperrt, Gelände-Suite vor jedem Commit von Paket 5.
5. **Leistung:** Kolonnen, Flak und Gebäude-Effekte. Gegenmittel: Sim ohne Physikkörper, Modelle nur im 6-km-Umkreis, Rauch über GPU-Partikel mit Entfernungsstufen, Messung in Paket 2a und 21.
6. **Balance:** Zu große Lager machen Angriffe wirkungslos, zu kleine machen die Partie zum Hungerspiel. Gegenmittel: alle Werte in `.tres`, ein Balance-Skript (`tools/economy_sim.gd`) rechnet 75 min ohne Grafik in Sekunden, und Paket 4 misst die Zeit bis zum Meilenstein.
7. **Snowballing:** Wer zuerst die Raffinerie trifft, gewinnt. Gegenmittel (Baustein 12): Schlüsselziele bekommen nach dem ersten Treffer mehr Abwehr, Wiederaufbau ist garantiert, Behelf geht schnell, und es gibt keine dauerhafte Zerstörung.
8. **Determinismus:** Ein versehentliches `randf()` oder eine Uhrzeit in der Wirtschaft bricht den Hash. Gegenmittel: Log-Hash-Test in fast, Code-Prüfung in Paket 21.
9. **Export:** neue Ressourcen fehlen in der .pck (Lehre M2.2). Gegenmittel: Diagnosezeilen in der Pflicht-Suite export.

## 5. Spielablauf einer M4-Testpartie (75 min, Tempo Normal)

Aufstellung: Blau = Tester + 4 KI-Piloten, Rot = 6 KI-Piloten. Der Tester wechselt zwischen Cockpit, Planungstisch und Boden. Wo er nicht sitzt, arbeitet die KI. Prinzip: ein Ereignis alle 2–4 min, Wirkung in Sekunden sichtbar.

| Zeit | Ereignis | Was der Tester sieht und entscheidet |
|---|---|---|
| 0:00 | Partiestart, Schutzphase 10 min. Tester steht am Planungstisch, Rolle Einsatzleiter | Karte: eigene Kette mit grünen Ampeln, Feindgebäude grau („Lage bekannt, Zustand unbekannt“). Erste Lagebesprechung: „Aufklärung Ost“, „Konvoi-Schutz“, „Raffinerie-Angriff vorbereiten“ |
| 0:02 | Kolonne 1 fährt (Depot → Platz Blau, 12 Paletten) | Nachschub-KI meldet „Kolonne 1 rollt, Ankunft in 14 min“. Tester legt Schwerpunkt „Raffinerie Ost“ |
| 0:04 | Tester steigt ins Cockpit (Übergabezettel „wie bisher“), Aufklärungsflug Richtung Osten | Funk: „Einsatzleiter-KI übernimmt“. Start mit 2 KI-Flügelleuten |
| 0:08 | Überflug Industrie Ost in 1.200 m | Sichtmeldung: Raffinerie Ost, 2 Flak, Depot gut gefüllt. Auf der Karte wird das Ziel farbig |
| 0:10 | Schutzphase endet. Rot-Posten melden den Aufklärer | KI-Jäger von Rot starten (Plot auf Rots Seite). Tester dreht ab, kurzer Luftkampf |
| 0:13 | Landung. Vorbestellung per Funk „Bomben schwer“ | Bodenpersonal hängt die 250-kg-Bombe ein, der Tester tankt selbst. Bericht nach der Landung: „KI: Kolonne 2 losgeschickt, Lagebesprechung verschoben“ |
| 0:16 | Kolonne 1 kommt an | Funk: „Kolonne 1 ist durch, Fasslager gut gefüllt“ |
| 0:18 | Rot sammelt 3 Maschinen über Platz Rot | Posten-Plot „ca. 2–4 Maschinen, kreisen“. Platzleitung-KI: „Angriff erwartet in 3–5 min“ |
| 0:20 | Tester startet mit Jabo + 2 KI-Begleitern Richtung Raffinerie Ost | Funk-Anfrage der Platzleitung: „Alarmstart 2 Maschinen?“ → Kurzbefehl „Annehmen“ |
| 0:23 | Rots Angriff auf Kolonne 2 an der Bachbrücke West | 1 Lkw brennt, Funk: „Kolonne 2 angegriffen, ein Lkw verloren“. Blaue Alarmjäger fangen ab |
| 0:26 | Sturzangriff auf Raffinerie Ost, Volltreffer | ≤ 3 s: Rauchsäule, Funk „Raffinerie Ost beschädigt – Feind-Kriegskraft deutlich gesunken“. Flak schießt, ein Treffer im Flügel |
| 0:30 | Rückflug, Landung | Einsatzbilanz: „Raffinerie Ost beschädigt, Ausfall ca. 6 min, +XP, Schwerpunkt-Bonus +25 %“ |
| 0:32 | Tester geht an den Tisch, übernimmt **Nachschub** | Engpass-Ansicht: „Munitionsfabrik: Ausgang voll“. Er stellt auf Bomben um und plant Kolonne 3 mit Begleitschutz |
| 0:35 | Rot-Bautrupp fährt zur Raffinerie Ost (aus dem Feindbild, falls ein Posten oder Flieger ihn sieht) | Lagebesprechung schlägt „Bautrupp abfangen“ vor (Auftrag mit Kopfgeld +25 %). Ein KI-Jäger nimmt an |
| 0:38 | Kolonne 3 fährt, ein KI-Jäger als Schutz | Postenmeldung „Feindjäger über Straße Süd“ → Tester schickt Kolonne 3 in den Wald-Halt. Funk: „Kolonne 3 verdeckt im Wald“ |
| 0:42 | Rots großer Angriff (4 Maschinen) auf die Bachbrücke West | Brücke fällt. Kolonnen drehen um, die Karte zeigt die Furt-Route (+80 %). Tester wechselt zur **Platzleitung** |
| 0:44 | Platzleitung: Reparaturliste | Entscheidung: Behelfsbrücke an der Furt (5 min) oder Wiederaufbau der Brücke (10 min)? Er wählt Behelf und setzt die Brücke auf Platz 2 der Liste |
| 0:48 | Forschung „Hochoktan-Verfahren“ fertig | Funk: „Raffinerie West arbeitet besser“. Kriegskraft steigt |
| 0:50 | Fasslager Platz Rot läuft leer (Folge der Raffinerie und eines abgefangenen Konvois) | Ein Feindjäger startet mit Ersatzbenzin (−12 % Leistung, Sichtmeldung im Luftkampf: „Rauchspur, langsam“) |
| 0:53 | Tester fliegt Konvoi-Jagd auf der Straße Ost (Auftrag) | 2 Lkw brennen, Munitions-Lkw explodiert. Funk: „Feindkolonne gestoppt“ |
| 0:58 | Behelfsbrücke fertig, Kolonne 1 nimmt sie | Funk: „Brücke West (Behelf) offen“. Die Ampel wird gelb (60 % Leistung, empfindlich) |
| 1:02 | Rot greift Platz Blau an (Tanklager) | Sirene, Alarmstart, das Bodenpersonal rennt (M3). Das Tanklager wird beschädigt, 50 % Inhalt brennt. Platzleitung: Reparatur an Platz 1 |
| 1:06 | Lagebesprechung: „Großangriff Depot Ost“ (3 Befehlspunkte) | Tester setzt den Befehl ein: Alle KI-Staffeln fliegen 5 min aufs Depot Ost, er fliegt mit |
| 1:10 | Depot Ost zerstört | Feind-Kriegskraft fällt unter 40 %. Rot zieht Jäger zur Verteidigung zusammen (Reaktion) |
| 1:12 | Rot erreicht den Forschungsmeilenstein nicht (Institut ungestört, aber Industrie zu schwach) | Blau erreicht „Übergang Tier II“: Funkmeldung an alle |
| 1:15 | Zeitlimit | Partieende-Bildschirm: Sieger nach Kriegskraft, Dienstbilanz je Rolle, Auszeichnungen |

## 6. Balancing-Startwerte (Tempo Normal)

Alle Werte liegen in `.tres`. „/min“ heißt Partieminute, Tempo multipliziert Produktion, Forschung, Bau und Reparatur, aber nicht Fahren und Fliegen.

**Verbrauch (Bezug):** Seit M3.10 kostet ein Abschuss etwa 2,5-mal so viel Munition. Eine Maschine kommt im Mittel mit 20 % Restmunition zurück, eine Abfertigung lädt also ≈ 800 Schuss nach, und der Tank braucht ≈ 250 l (von 360 l). Bei 5–6 Maschinen und im Mittel 4 Einsätzen je Stunde (Flug 10–12 min, Abfertigung 2–4 min, Wartezeiten) braucht ein Platz je Stunde ≈ 5.500 l Flugbenzin, ≈ 18.000 Schuss, ≈ 12 Bomben 50 kg bzw. 4 × 250 kg und ≈ 600 Schuss 2 cm.

| Bereich | Wert | Begründung |
|---|---|---|
| **Produktion** |||
| Holzfällerlager | 0,5 t Rundholz/min, Puffer 20 t | Sägewerk ausgelastet |
| Sägewerk | 0,5 t Rundholz → 0,4 t Bauholz/min | 24 t/h: Werk 12 t/h, Bau 4–8 t/h, Rest Puffer |
| Ölfeld | 150 l Rohöl/min, Puffer 9.000 l | – |
| Raffinerie | 150 l Rohöl → 100 l Flugbenzin + 30 l Ersatz/min | 6.000 l/h ≈ 1,1 × Verbrauch: ungestört knapp positiv, beschädigt (50 %) sofort negativ |
| Munitionsfabrik | Modus „Gurte“ 350 Schuss/min; „gemischt“ 200 Schuss + 0,25 Bombe 50 kg/min; „Bomben“ 60 Schuss + 0,5 Bombe 50 kg/min (250 kg zählt wie 4 × 50 kg); 2 cm immer 15 Schuss/min | Gurte 21.000/h ≈ 1,15 × Verbrauch, Umstellen ist eine echte Entscheidung (L4) |
| Flugzeugwerk | 1 Jäger je 10 min, braucht 2 t Bauholz, Eingangspuffer 8 t | 6 Jäger/h ersetzt die Verluste aus 2–3 Luftkämpfen |
| Institut | 10 Forschungspunkte/min | Meilenstein nach ≈ 36 min ungestört (GDD 30–40 min) |
| Sonderschicht (L4) | +30 % für 5 min, danach −30 % für 3 min, Abklingzeit 10 min | Recherche L4 |
| **Lager** (Kapazität / Start) |||
| Tanklager Platz | Flugbenzin 8.000 / 4.000 l, Ersatz 3.000 / 2.000 l | Start nur halb voll, damit der Nachschub ab Minute 15 zählt. Voll reicht es ≈ 85 min ohne Nachschub, halb ≈ 45 min |
| Munitionsbunker Platz | 7,92 mm 40.000 / 24.000 Schuss (M3.11: Kapazität 40.000); Bomben 16 / 8 × 50 kg und 4 / 2 × 250 kg; 2 cm 6.000 / 3.000 | 24.000 Schuss ≈ 80 min Verbrauch. Die Bomben reichen nur für ≈ 3 Jabo-Einsätze, Bomben sind also Nachschub-Sache |
| Depot | Treibstoff 20.000 / 4.000 l (davon 1.000 Ersatz), Munition 100.000 / 30.000 Schuss, Bomben 40 / 12, Bauholz 30 / 10 t | kleiner Startpuffer, damit Störungen in Minuten ankommen. Fällt Flugbenzin unter 2.000 l, laden Kolonnen anteilig Ersatz |
| Bauhof Platz | Bauholz 12 / 6 t | 2 Wiederaufbauten |
| Flak-Geschütz | 600 Schuss am Geschütz | ≈ 2 min Dauerfeuer |
| Zerstörtes Lager | verliert 50 % des Inhalts | GDD Folgeschaden |
| **Konvois** |||
| Kolonnen je Nation | 3 Kolonnen à 2 Lkw + 1 Tieflader (2 Jäger) | 3 Lkw je Kolonne über Forschung „Kolonnenführung“ |
| Lkw | 6 Paletten: 1 Palette = 600 l Treibstoff **oder** 5.000 Schuss **oder** 4 × 50 kg / 1 × 250 kg **oder** 600 Schuss 2 cm **oder** 1 t Bauholz | 3 t Nutzlast (Opel-Blitz-Klasse), gerundet für Lesbarkeit |
| Tempo | Straße 30 km/h, Feldweg 18 km/h, Brücke 15 km/h, Furt 6 km/h, Kolonne mit Spieler am Steuer +10 % | Kolonne 1939 ≈ 25–35 km/h; Hauptroute 7–9 km ≈ 15–18 min |
| Laden / Entladen | 60 s je Lkw, automatisch | kein Kistenschleppen (P2) |
| Takt | KI-Standardfahrplan: Abfahrt, sobald ein Ziellager unter seinen Mindestbestand fällt, frühestens alle 6 min je Kolonne | ergibt mit 3 Kolonnen ≈ 1 Abfahrt alle 5–8 min je Nation |
| Lkw-HP | 80 HP, weich. Tank-Lkw: 15 % Brandchance je MG-Treffer; Munitions-Lkw explodiert nach 8 s Brand (Radius 15 m) | 6–12 MG-Treffer stoppen einen Lkw |
| Wald-Halt | 2 min, Erkennungsweite ×0,3 | Recherche L5 |
| **Bauzeiten** (Reparatur beschädigt → intakt / Wiederaufbau zerstört, Bauholz) |||
| Tanklager, Bunker, Flak-Lager, Flak | 2 / 8 min, 1 / 2 t | schnell, damit der Platz nicht stirbt |
| Raffinerie | 6 / 15 min, 2 / 5 t | GDD-Obergrenze, stärkstes Schlüsselziel |
| Munitionsfabrik, Flugzeugwerk | 5 / 14 min, 2 / 4 t | – |
| Depot | 4 / 12 min, 2 / 4 t | – |
| Sägewerk, Holzfäller, Ölfeld, Institut | 3 / 10 min, 1 / 3 t | – |
| Bachbrücke (Holz) | – / 10 min, – / 4 t. Behelfsbrücke an der Furt 5 min, 2 t | Brücke kennt nur intakt/zerstört |
| Flussbrücke (Stahl/Stein) | 8 / 15 min, 3 / 6 t | – |
| Neubau Flak-Stellung / Reservelager / Attrappe | 4 / 6 / 2 min, 1 / 3 / 1 t | – |
| Behelf | 50 % der Zeit, 60 % Leistung, bei Treffer sofort zerstört | Recherche B2 |
| Bautrupps | 2 je Nation, Lkw 30 km/h, verloren unter Angriff → 5 min Ersatz; Platzleitung vor Ort +25 % | GDD |
| **Schaden** |||
| Zustände | intakt ≥ 70 % HP (100 %), beschädigt < 70 % (50 %), zerstört 0 HP (0 %) | GDD 3 Zustände |
| Gebäude-HP | Lager 400, Flak 150, Hangar 1.200, Holzbrücke 800, Flussbrücke 2.400, Raffinerie 2.400, Depot 1.800, Werke 2.000, Institut 1.200, Lkw 80 | Raffinerie: 1 × 250 kg = beschädigt, 2 = zerstört |
| MG 7,92 mm | 10 je Treffer (wie M3.10), gegen hart ×0,1, gegen weich ×1,0 | Bordwaffen gegen Gebäude fast wirkungslos, gegen Lkw/Fässer stark |
| Bombe 50 kg | 400 Schaden, voll bis 5 m, auf 0 bei 20 m | – |
| Bombe 250 kg | 1.600 Schaden, voll bis 10 m, auf 0 bei 40 m; Flugzeug ≤ 60 m beschädigt | – |
| Jabo-Ausrüstung | 2 × 50 kg: +110 kg, Zusatzwiderstand 0,02 m²; 1 × 250 kg: +270 kg (mit Träger), 0,035 m² | ≈ Bf 109 E-4/B: −30 km/h, Steigen −20 % |
| Flak 2 cm | 280 Schuss/min, 900 m/s, 90 Schaden je Treffer (Empfehlung aus der Waffenprüfung), Streuung 8 mrad, wirksam bis 2.000 m | 1–3 Treffer je Jabo-Anflug durch 2 Geschütze |
| **Forschung** (Kosten in Forschungspunkten, Wirkung) |||
| Hochoktan-Verfahren | 60 FP, Raffinerie +25 % Flugbenzin | – |
| Gurtfertigung | 60 FP, Munitionsfabrik +25 % | – |
| Kolonnenführung | 60 FP, 3 Lkw je Kolonne | – |
| Flak-Zielgerät | 60 FP, Flak-Streuung −30 % | – |
| Schnellbau | 60 FP, Bautrupps +25 % | – |
| Übergang Tier II | 180 FP, braucht 3 der 5 Knoten | 3 × 60 + 180 = 360 FP ≈ 36 min |
| Technologiefluss | −30 % auf einen Knoten, den die andere Nation schon hat | GDD |
| **Partie und Rollen** |||
| Schutzphase / Zeitlimit / Kapitulation | 10 min / 75 min / 10 min unter 25 % des eigenen Höchstwerts | GDD |
| Kriegskraft-Gewichte | Industrie 40 %, Lager 20 %, Flugzeuge 30 %, Forschung 10 % | Bodenangriffe wirken sofort über Industrie und Lager |
| KI-Angriffe | ab Minute 10 alle 8–12 min, Sammeln 2–5 min vorher, 2–4 Maschinen | Recherche V: 5–8 min, etwas ruhiger wegen nur einer KI-Nation |
| Befehlspunkte | +1 alle 3 min, +1 je erfülltes Schwerpunktziel, max. 5; Großangriff 3, Notreparatur 2, Sonderkonvoi 2 | Recherche K2 |
| Lagebesprechung | alle 8–10 min oder auf Abruf, 3 Vorschläge | Recherche Baustein 9 |
| Rollen-KI Reaktionszeit | 60–120 s je Entscheidung | P10 |
| Beobachtungsposten | 5 je Nation, sehen Flugzeuge bis 8 km, Meldung nach 20–40 s, Anzahl ±50 %, Höhe in 3 Bändern | V1 |
| Flugzeugbestand | Blau Start 6 (+ Spieler-Maschine), Rot 7, Hangar max. 10 | – |

**Prüfwerte für das Balance-Skript:** (a) Ungestört bleiben alle Lager einer Nation über 75 min zwischen 25 % und 90 %. (b) Raffinerie zerstört (15 min) → das Depot-Flugbenzin fällt binnen 10 min unter 2.000 l, und die nächste Kolonne fährt mit Ersatzanteil. Zusammen mit einer verlorenen Kolonne tankt der Platz nach 15–25 min Ersatz. (c) Zwei verlorene Kolonnen hintereinander → eine Stunde lang Teilbeladung bei Munition oder Bomben. (d) Kein Lager läuft über, solange der Nachschub nicht absichtlich hortet.

## 7. Offene Fragen an den Product Owner

1. **Womit greifen wir Bodenziele an?**
   - **A (Empfehlung):** Der vorhandene Jäger bekommt eine Bomben-Ausrüstung (zwei kleine oder eine große Bombe). Einen eigenen Bomber gibt es erst im nächsten Meilenstein. Das ist schnell spielbar und passt zur Epoche.
   - B: Zusätzlich schon in M4 ein zweisitziger leichter Bomber mit Heckschütze. Das bringt deutlich mehr Arbeit (neues Flugzeug, Schützenplatz, Schützen-KI), und die Wirtschaft wird später fertig.
   - C: Nur Bordwaffen, keine Bomben. Dann lassen sich Raffinerie und Brücken nicht zerstören.

2. **Soll es in M4 schon einen Zug geben?**
   - **A (Empfehlung):** Nein, nur Lkw-Kolonnen auf Straßen. Bahnlinie und Zug kommen später.
   - B: Ja, ein von der KI gefahrener Zug auf einer neuen Bahnlinie als besonders wertvolles Ziel. Das kostet eine zweite Kartenänderung und einen eigenen Fahrzeugtyp.

3. **Sind die Flugzeuge auch für dich begrenzt?** (Neue Maschinen kommen aus dem Flugzeugwerk.)
   - **A (Empfehlung):** Ja, für alle gleich. Steht keine freie Maschine im Hangar, kannst du einem KI-Piloten seine Maschine abnehmen.
   - B: Du hast immer eine Maschine, nur die KI-Piloten sind begrenzt.
   - C: Unbegrenzt wie bisher. Das Flugzeugwerk ist dann nur ein Ziel für die Kriegskraft.

4. **Wo siehst du die Kriegskraft (den Stand der Partie)?**
   - **A (Empfehlung):** Nur am Planungstisch und in der Lagebesprechung. Im Flug kommt eine grobe Funkmeldung („Feind deutlich geschwächt“).
   - B: Immer als kleiner Balken im Bild.
   - C: Erst am Partieende.

5. **Wie viel weißt du über die feindliche Wirtschaft?**
   - **A (Empfehlung):** Wo die feindlichen Gebäude stehen, zeigt die Karte von Anfang an. Ihren Zustand (beschädigt, Lager voll oder leer) siehst du nur nach Aufklärung durch Überflug oder Posten, und das Wissen veraltet.
   - B: Alles muss erst entdeckt werden, auch der Standort.
   - C: Alles ist immer sichtbar.

6. **Musst du für die Planung zum Tisch laufen?**
   - **A (Empfehlung):** Planen (Fahrplan, Reparaturen, Befehle) geht nur am Planungstisch in der Flugleitung. Am Boden kannst du überall die Karte ansehen und funken, im Flug nur funken.
   - B: Am Boden öffnet eine Taste überall die volle Planung.
   - C: Nur am Tisch, sonst gar keine Karte.

7. **Wo darf die Platzleitung neu bauen** (Flak-Stellung, Reservelager, Attrappe)?
   - **A (Empfehlung):** Auf festen Bauplätzen (je 3 am Flugplatz und an der Industrie).
   - B: Frei auf der Karte.
   - C: In M4 gar kein Neubau, nur Reparatur.

8. **Was bringt der Forschungsmeilenstein „Übergang Tier II“?** (Tier-II-Flugzeuge gibt es in M4 noch nicht.)
   - **A (Empfehlung):** Einen großen Bonus auf die Kriegskraft und eine Meldung an alle. Die Partie läuft weiter.
   - B: Sofortsieg, wenn der Gegner zu diesem Zeitpunkt unter der Hälfte seiner Kriegskraft liegt.
   - C: Nur eine Anzeige ohne Wirkung.

9. **Soll M4 schon Koop mit einem zweiten Spieler bringen?**
   - **A (Empfehlung):** Nein. M4 bleibt Einzelspieler mit Rollenwechsel und wird so gebaut, dass Koop direkt danach in M5 kommt (zusammen mit Speichern und Laden).
   - B: Ja, Koop zu zweit schon in M4. Dann werden Wirtschaft und Rollen später fertig.

10. **Kommt die Ausbildung des Bodenpersonals schon in M4?**
    - **A (Empfehlung):** Nein, zusammen mit dem Anwerben von Personal in einem späteren Meilenstein.
    - B: Eine kleine Version in M4: KI-Helfer, mit denen du oft gemeinsam abfertigst, werden in drei Stufen schneller.

### Wichtige Dateien für die Umsetzung
- /home/claude/fliegi/game/weapons/projectile_system.gd (Bodenziel-Register)
- /home/claude/fliegi/game/vehicles/aircraft/aircraft.gd (Außenlasten: Masse, Widerstand)
- /home/claude/fliegi/game/ground_ops/supply/ammo_bunker.gd, fuel_depot.gd (Lager mit `take_damage`-Haken aus M3)
- /home/claude/fliegi/game/ground_ops/jobs/load_ordnance_job.gd (Stub aus M3)
- /home/claude/fliegi/game/ground_ops/radio/radio_channel.gd (Kanäle 5–8 anhängen)
- /home/claude/fliegi/game/world/terrain/terrain_generator.gd, terrain_data.gd, bridges.gd (Standorte, Straßen, Brücken)
- /home/claude/fliegi/game/ai/brain/ai_pilot_brain.gd (Bodenangriff, Bodenschutz)
- /home/claude/fliegi/game/core/match_rules.gd (Tempo, Zeitlimit, Seed)
- /home/claude/fliegi/game/world/combat_scenario.gd, game.gd (Szenario „Partie“)
