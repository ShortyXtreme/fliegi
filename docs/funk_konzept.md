# Funk-Konzept (M3.5)

Stand: 22.11.2026 · Code: `game/ground_ops/radio/` (Daten), `game/ui/ground/radio_panel.gd` (Funkgerät), `game/ui/ground/ground_hud.gd` (Eingabe, Verteilung)

## 1. Bedienung (wie das Funkmenü in DCS)

- **Funk-Taste** (Standard Tab / LB) öffnet das Funkgerät unten rechts. Es zeigt die **Kanalliste**, der zuletzt benutzte Kanal ist markiert (gespeichert in `user://flugkern.cfg`, `[m3_5] funk_kanal`).
- **Ziffer 1–4** wählt den Kanal, danach zeigt das Panel dessen Befehle. **Ziffer 1–4** führt den Befehl aus, das Panel schließt sich.
- **Rücktaste / B**: zurück zur Kanalliste, in der Kanalliste schließen. **Funk-Taste oder Esc** schließt.
- **Pfeil ←/→ bzw. LB/RB** wechselt den Kanal. Am Controller wählen Steuerkreuz ↑↓ und A.
- Das Panel braucht keine Maus und blockiert die Bewegung nicht. Solange es offen ist, gehören A/B am Pad dem Funk (`RadioPanel.pad_capture`).
- Alle Funk-Tasten sind Aktionen der InputMap (`crew_wheel`, `radio_channel_1..4`, `radio_cmd_1..4`, `radio_back`, `radio_prev/next`, `radio_up/down/select`) in eigenen Eingabe-Kontexten `RADIO` (Kanalliste) und `RADIO_CMD` (Befehle). Sie sind unter Einstellungen › Tastenbelegung frei einstellbar.

## 2. Kanäle als Daten

`RadioChannel {id, number, name, role (Empfänger-Rolle), speaker, freq, commands[]}` und `RadioCommand {id, label, command, hint, children}` (höchstens eine Unterebene). `RadioChannel.default_channels()` liefert:

| Kanal | Rolle | Befehle |
|---|---|---|
| 1 Tankwart (3,150 MHz) | `fuel` | Tankwagen rufen (nur heranfahren) · Tankwagen wegschicken · Volltanken (danach aufräumen, zurück) · Status? |
| 2 Munition (3,275 MHz) | `ammo` | Munitionswagen rufen · Munitionswagen wegschicken · Aufmunitionieren (danach aufräumen, zurück) · Status? |
| 3 Reparatur (3,400 MHz) | `repair` | Mechaniker rufen · Mechaniker wegschicken · Reparieren (danach zurück) · Status? |
| 4 Bodenpersonal (3,525 MHz) | `ground_crew` | Kompletter Ablauf (Tanken, Munition, Reparatur, alles zurück) · Alle wegschicken · Status? · Wetter? (M3.8: „Wind aus Südwest, mäßig, böig.“) |

Die Zuteilung an Mechaniker erfolgt automatisch (`GroundCrewDispatch.free_crews`): ein freier Mechaniker (kein Auftrag, kein Job), sonst der nächste; „Kompletter Ablauf“ geht an alle freien. Ein Befehl an eine Maschine schaltet deren Automatik aus (Handbetrieb, Jobs für den Spieler reserviert); die Automatik gilt wieder nach dem nächsten Start der Maschine.

## 3. Spätere Rollen-Kanäle (5+)

Neue Kanäle werden in `default_channels()` (bzw. später je Platz/Partie) **nur angehängt**:

| Kanal | Rolle | Gedachte Befehle |
|---|---|---|
| 5 Werkstatt-Leitung | `workshop` | Reparaturplan, Ersatzteile anfordern, Maschine abnehmen |
| 6 Nachschub | `supply` | Treibstoff/Munition anfordern, Lagerstand melden |
| 7 Platzleitung | `tower` | Rollfreigabe, Startfreigabe, Landefolge |
| 8 Einsatzleiter | `command` | Auftrag, Alarmstart, Lagebericht |

**Besetzte Rolle:** Sitzt ein Spieler auf der Rolle (`operator_peer != 0`), geht der Befehl als **Anfrage** an ihn (`RadioChannel.request_sent`), seine Antwort kommt über `answer()` als Antwortzeile zurück. **Unbesetzte Rolle:** die KI handelt (`receiver.call(command, target, channel_id)`).

## 4. Rückmeldung: Funk statt Balken (Realismus-Regel)

- **Keine Fortschrittsbalken und keine Prozentanzeigen** für Aufgaben (Tanken, Munition, Reparatur, Pumpen) – weder in der Mannschaftsanzeige noch beim Selbermachen. Rückmeldung beim Selbermachen nur über Geräusch, das Flugzeug selbst und die Tankanzeige im Cockpit (Instrument). Im Arcade-Modus höchstens eine dezente Zeile „Tanken läuft …“.
- Die KI meldet sich per Funk **im jeweiligen Kanal** in grober Sprache, mit kurzem Funk-Klang (Einstellung „Funk-Klang“; M3.6: Klick + Rauschen beim Senden, Rauschen + Doppelton beim Empfang): Start („Tankwart: Fange an zu tanken.“), etwa halb („Halb voll.“), fertig („Tank voll, räume ab.“ / „Munitionswart: Linke Seite fertig.“), Aufräumen, Probleme („Problem: Lager leer.“, „Schlauch reicht nicht“).
- **Status?** in jedem Kanal: grobe Antwort („Tanke noch, etwa drei Viertel.“, „Dauert noch ein paar Minuten.“).
- Ein kleiner Punkt am Kanal zeigt, dass dort gerade jemand arbeitet.

## 5. Lagerbestände

Tanklager und Munitionsbunker erscheinen **nicht** im normalen HUD. Abfrage nur über `StockView.visible_for(role)` / `StockView.query(role, depot, bunker)` – sichtbar für die Rollen Nachschub (`supply`) und Werkstatt & Bodenpersonal (`workshop`) an ihrer Tafel bzw. am Planungstisch. Das Debug-Overlay (F3) zeigt sie weiter.
