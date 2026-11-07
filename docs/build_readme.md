# Flugkern M3.3 – Testversion „Menü, Controller-Tutorial und Sound“

## Installation
1. Die vorhandene **Flugkern.exe** (Godot 4.7.2) bleibt unverändert.
2. **Alle vier .pck-Dateien** in denselben Ordner wie Flugkern.exe kopieren (alte Flugkern.pck überschreiben):
   `Flugkern.pck`, `Flugkern_modelle.pck`, `Flugkern_karte.pck`, `Flugkern_audio.pck`.
   Fehlt Modelle oder Karte, zeigt das Spiel eine Meldung; fehlt Audio, läuft es ohne Ton.
3. Flugkern.exe starten. Der Fenstertitel muss „Flugkern M3.3“ zeigen.

## Neu in M3.3
- **Sound:** Motor (Sternmotor, Gegner mit Reihenmotor) nach Gas und Fahrt, Fahrtwind, Fahrwerk, Klappen, Aufsetzen, Bauchlandung, MG-Feuer (auch Gegner, räumlich, Doppler beim Vorbeiflug), Treffer, Explosion, Brand, Notausstieg, Schritte, Tankwagen, Pumpe, Kisten, MG-Klappe, Gurt, Werkzeug, Ein-/Aussteigen, Alarm-Sirene, Wind/Vögel, Menü-Klänge. Alle Klänge selbst erzeugt (lizenzfrei, CC0).
- **Lautstärkeregler** im Einstellungsmenü: Gesamt, Motor, Waffen, Umgebung, Menü/UI (Pfeile links/rechts). Cockpit-Ansicht klingt gedämpft.
- **Hauptmenü** zeigt den Flugplatz mit Hallen, Tanklager, Bunker, Wagen und abgestellten Flugzeugen.
- **Tutorial am Controller:** View-Taste **halten** = Schritt überspringen, Menu-Taste → Pausenmenü → „Tutorial beenden“. Die Tutorial-Karte zeigt die Symbole des benutzten Geräts.

## Neu in M3.2
- **Hauptmenü** bei jedem Start: Tutorial (mit Fortschritt), Freies Spiel, Einstellungen (Realismus Flug, Bodenbetrieb, KI-Stufe, Radar, Maus-Empfindlichkeit), Steuerung, Beenden – Maus, Pfeile + Enter oder Stick + A/B. **Im Spiel: Esc bzw. Menu-Taste = Pausenmenü** (gibt die Maus frei). Neustart auf der Piste am Controller nur noch über das Menü (Tastatur R).
- **Geführtes Tutorial:** über das Hauptmenü oder **„Tutorial starten.bat“** (Option `--tutorial`). 7 Schritte: Starten, Fliegen, Zielen auf ein Übungsziel (schießt nicht), Notausstieg, Landen, Abfertigen, Abschluss. **F8** Schritt überspringen, **F7** beenden.
- **Neue Oberfläche:** feste Bildschirmzonen, Ruhezustand ohne Waffen-/Schadensanzeige (erscheint im Kampf oder bei Änderungen), Warnungen oben Mitte, Epochen-Gestaltung (Elfenbein/Messing/Oliv, Schrift Oswald).
- **Tasten-Leiste** unten Mitte: die gerade sinnvollen Tasten als Symbole, automatisch Tastatur oder Xbox-Controller.
- **F1** ist jetzt eine übersichtliche Tafel je Kontext (Tastatur und Controller nebeneinander) und öffnet nicht mehr automatisch.

## Neu in M3.1
- **KI-Mechaniker und Wagen weichen aus:** Wegsuche um Flugzeuge, Wagen, Hallen und laufende Propeller; Wagen bremsen vor Hindernissen und Personen im Fahrweg.
- **Natürlichere Haltung:** In Ruhe hängen die Arme am Körper; Arbeiten und Einsteigen greifen nach vorn.
- **Schnellere Abfertigung:** Tank- und Munitionswagen warten an den Abstellplätzen (mit 2 KI-Helfern ca. 1:30 min).
- **Gebäude:** Alle Hallen sind jetzt Modelle (keine grauen Klötze mehr); Tanklager und Bunker haben Kollision.

## Was ist neu (M3)
- **Start am Boden:** Du sitzt im Jäger am Abstellplatz von Platz Blau (50 % Treibstoff, volle Munition). Nach einem Abschuss steht eine neue Maschine am Abstellplatz (15 % Treibstoff, keine Munition), ohne Treibstoff springt der Motor nicht an.
- **Aussteigen und zu Fuß:** Im Stand **J** bzw. **Steuerkreuz ← 1 s halten**. Zu Fuß: WASD/linker Stick, Maus/rechter Stick, Shift/L3 Sprint, **E/A halten = arbeiten**, G/B ablegen, **F/Y einsteigen**, C/R3 Ego-Sicht, **Tab/LB halten = Befehlsrad**.
- **Selbst abfertigen:** Schlauch am Tankwagen nehmen, am Tankdeckel ankoppeln (E halten), Pumpe läuft, danach abkoppeln. Kiste vom Munitionswagen nehmen, an der MG-Klappe E halten (Klappe, Gurt, Klappe). Reparatur light an den Servicepunkten.
- **Fahrzeuge:** Tankwagen und Munitionswagen selbst fahren (W/RT Gas, S/LT Bremse bzw. rückwärts, Leertaste/B Handbremse, J 1 s aussteigen).
- **KI-Bodenpersonal** (2 Mechaniker je Platz) versorgt gelandete Maschinen automatisch, fährt die Wagen und füllt den Tankwagen am Lager nach. Befehle über das Befehlsrad.
- **Rote KI** startet und landet jetzt selbst auf Platz Rot und wird dort versorgt.
- **Alarmstart** alle 12–15 min oder sofort mit **F9**: Countdown, Zeitwertung, Bestzeit.
- **F1** zeigt die Belegung für Flug, zu Fuß und Fahren.
- Realismus-Stufe in `flugkern.cfg`: `[m3]` `bodenbetrieb="einfach"` / `"standard"` / `"authentisch"`.

## Selbsttest (bitte einmal ausführen)
Der Selbsttest prüft im echten Spiel Treffer und den Bodenbetrieb. Er dauert ca. **4 Minuten** und beendet sich dann selbst. Bitte nichts drücken, solange er läuft.
1. Rechtsklick auf Flugkern.exe → „Verknüpfung erstellen“.
2. Rechtsklick auf die Verknüpfung → „Eigenschaften“ → bei „Ziel“ hinten ` --selbsttest` anhängen, z. B.
   `"C:\Spiele\Flugkern\Flugkern.exe" --selbsttest`
3. Verknüpfung starten. Ablauf: Treffer in beide Richtungen (je 3 s), dann steigt die Figur am Abstellplatz aus, die KI-Mannschaft tankt und munitioniert die leere Maschine, die Figur lädt selbst ein MG und steigt ein, zuletzt startet ein roter Jäger.
4. Ergebnis: `%APPDATA%\Godot\app_userdata\Flugkern M2\logs\selbsttest_JJJJMMTT_HHMMSS.txt`. Die letzte Zeile muss **SELBSTTEST OK** lauten. Bitte diese Datei mitschicken.

## Logs (bei Problemen bitte mitschicken)
Alles unter `%APPDATA%\Godot\app_userdata\Flugkern M2\logs\` (Ordnername bleibt „Flugkern M2“):
- `godot.log`: Spielprotokoll mit Diagnosezeilen „Hitbox-Zonen 9 …“ je Flugzeug und „Diagnose Boden Platz …“ (Lager, Personal, Animationen, Modelle).
- `kampf_*.csv`: jeder Treffer.
- `selbsttest_*.txt`: Ergebnis des Selbsttests.

## Bitte zuerst ausprobieren
1. Selbsttest (oben).
2. Spiel starten, J 1 s halten (aussteigen), um die Maschine gehen, F1 lesen. Tab halten → „Voll abfertigen“ und zusehen, wie die Mechaniker Tankwagen und Munitionswagen holen.
3. Selbst tanken: zum Tankwagen gehen, Schlauch nehmen (E), zum Tankdeckel (Rumpfmitte vor dem Cockpit), E halten.
4. Einsteigen (F), starten, einen Gegner abschießen oder abgeschossen werden, landen, zum gelben Abstellplatz rollen, abfertigen lassen.
5. F9 drücken (Alarmstart) und die Zeit schlagen.
6. Tankwagen fahren: Handbremse (Leertaste) darf ihn nie rückwärts rollen lassen.

Bekannt: Die KI-Mechaniker laufen ohne Wegsuche und dürfen durch Wagen und Flugzeuge hindurchgehen. Funkenbrand (Authentisch) wird nur gemeldet.
