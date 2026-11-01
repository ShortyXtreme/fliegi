# Flugkern M2.2 – Testversion „Trefferfix“

## Installation
1. Die vorhandene **Flugkern.exe** (Godot 4.7.2) bleibt unverändert.
2. Diese **Flugkern.pck** in denselben Ordner kopieren und die alte überschreiben.
3. Flugkern.exe starten. Der Fenstertitel muss „Flugkern M2.2“ zeigen.

## Was ist behoben
- **In M2.1 gab es überhaupt keine Treffer, weder auf dich noch auf Gegner.** Ursache: Beim Erstellen der Windows-Version gingen die Trefferzonen der Flugzeuge verloren (Godot wandelt die Datendatei beim Export in ein anderes Format um, dabei fielen alle Zonen weg). Die Geschosse flogen deshalb einfach durch die Flugzeuge hindurch. In unseren Tests aus dem Projektordner war alles in Ordnung, deshalb fiel der Fehler nicht auf. Jetzt wird die Datei unverändert übernommen. Jeder Build wird außerdem vor der Auslieferung mit dem Selbsttest (unten) geprüft.

## Selbsttest (bitte einmal ausführen)
Der Selbsttest prüft im echten Spiel, ob Treffer funktionieren. Er dauert ca. 10 s und beendet sich dann selbst.
1. Rechtsklick auf Flugkern.exe → „Verknüpfung erstellen“.
2. Rechtsklick auf die Verknüpfung → „Eigenschaften“ → bei „Ziel“ hinten ` --selbsttest` anhängen, z. B.
   `"C:\Spiele\Flugkern\Flugkern.exe" --selbsttest`
3. Verknüpfung starten. Ein Gegner erscheint 250 m vor dir, du schießt 3 s automatisch. Dann schießt ein Gegner 3 s von hinten auf dich.
4. Ergebnis: `%APPDATA%\Godot\app_userdata\Flugkern M2\logs\selbsttest_JJJJMMTT_HHMMSS.txt`. Die letzte Zeile muss **SELBSTTEST OK** lauten. Bitte diese Datei mitschicken.

## Logs (bei Problemen bitte mitschicken)
Alles unter `%APPDATA%\Godot\app_userdata\Flugkern M2\logs\`:
- `godot.log`: Spielprotokoll. Beim Start stehen dort jetzt Zeilen wie
  `Diagnose PlayerAircraft: Hitbox-Zonen 9 …, Waffen 2 …`. Steht dort „Hitbox-Zonen 0“, ist etwas kaputt.
- `kampf_JJJJMMTT_HHMMSS.csv`: jeder Treffer (auch abgelehnte), eine Datei je Spielstart.
- `selbsttest_*.txt`: Ergebnis des Selbsttests.

## Bitte prüfen
1. Selbsttest ausführen (siehe oben).
2. Normal spielen: Erscheinen mit F3 jetzt Treffer am Gegner („Leitwerk −10“ usw.) und unter „Getroffen von“?
3. Ändert sich die Schadensskizze unten rechts, wenn du getroffen wirst?

Alle anderen Funktionen und die Steuerung sind wie in M2.1 (Treffer-Debug F3, Zoom rechte Maustaste/Z, Einstellungen in `flugkern.cfg`).
