# UI-Konzept M3.2 (Phase 1: Redesign, Phase 2: Tutorial folgt)

Anlass: Tester-Feedback M3.1 – „zu unübersichtlich, Tasten schwer zu merken, sieht nicht schön aus“;
früher: Flug-Panel links unten, epochengerechte Anzeigen, Notausstieg-Hinweis nur kurz.

## 1. Bestandsaufnahme (Stand M3.1)

| Kontext | Element | Position | Befund |
|---|---|---|---|
| Flug | Flug-Panel (Fahrt, Höhe, G, Steigen, Gas, Klappen, Fahrwerk, Modus, Kamera, „Linksklick: Maus fangen“) | links unten | Fußzeile überladen (Kamera, Maushinweis) |
| Flug | Warnungen (Stall, Fahrwerk, Bauchlandung, Parkbremse) | über dem Flug-Panel | Warnungen am Rand statt im Blick |
| Flug | Waffen + Schadensskizze | rechts unten | immer sichtbar, auch im Ruhezustand |
| Flug | Kompassband / Radar-Light / Kill-Feed | oben Mitte / oben links / oben rechts | ok |
| Flug | „Notausstieg möglich [J halten]“ | Mitte oben | dauerhaft sichtbar (Tester: nur kurz) |
| Flug (Stand) | Statuspanel mit 2. Schadensskizze | rechts über dem Waffen-Panel | **Skizze doppelt**, Ecke überladen |
| Flug | F1-Hilfe: Monospace-Textblock, 30 Zeilen | rechts oben, über Kompass/Feed | unlesbar, verdeckt HUD |
| Zu Fuß | Statuspanel (Treibstoff, MG, Skizze, Arbeiten) | links unten | ok |
| Zu Fuß | Lagerleiste | oben Mitte | immer sichtbar, belegt Meldungszone |
| Zu Fuß | Abfertigungszeit / Alarm | rechts oben / oben Mitte | ok |
| Zu Fuß | Interaktionshinweis mit eigener Tastenkappe | Mitte unten | ok, eigener Stil |
| Zu Fuß | Befehlsrad + Text „Tab loslassen …“ | Mitte | Text doppelt zur Belegung |
| Zu Fuß/Fahren | F1-Hilfe als Tabelle (Text „Tab“, „LB“) | rechts oben | Tasten nur als Text |
| Debug | F3 Treffer-Debug, Shift+F3 Kräfte | links/Mitte | bleibt (nur Theme) |

Keine dauerhafte Anzeige der gerade sinnvollen Tasten – man muss die Hilfe öffnen.

## 2. Konzept

**Feste Zonen** (alle Kontexte): links unten Zustand (Flugzeug im Flug, Maschine/Figur am Boden) ·
rechts unten Waffen/Schaden (im Cockpit im Stand: Statuspanel statt Waffen-Panel, eine Skizze) ·
unten Mitte **Tasten-Leiste** · oben Mitte nur Kompass + Meldungen/Alarm (Warnungen ab Stufe 1) ·
oben links Radar bzw. Lager · oben rechts Kill-Feed bzw. Abfertigungszeit · Mitte frei (Zielhilfen,
Interaktionshinweis, Befehlsrad, Hilfe-Tafel).

**Hierarchie / Ruhezustand minimal:** Waffen/Schaden nur bei Kampf (erkannter Feind < 2,5 km),
nach Änderung (8 s, Munition oder Schaden) oder bei Mangel (< 20 %, Ladehemmung), sanft ein-/ausgeblendet.
Lagerleiste nur nahe Lager (60 m) oder Maschine (15 m). Grundabstand nur unter 400 m. Notausstieg-Hinweis
5 s, danach in der Tasten-Leiste. Parkbremse/Bremse als kleines Schild im Flug-Panel.

**Tasten-Leiste:** 3–6 Einträge je Lage (`KeyBar.entries_for`), Symbole aus der echten Belegung
(`KeyGlyphs.token` liest InputMap), Gerät automatisch (zuletzt benutzt). Beispiele: am Flugzeug zu Fuß
[F] Einsteigen [Tab] Befehle [C] Ansicht [F1] Hilfe; weg vom Flugzeug [Shift] Sprinten …; im Stand im
Cockpit [Shift] Gas geben [J] Aussteigen; im Kampf [Leertaste] Feuer [Z] Zielzoom; Rad offen: wählen/
wechseln/loslassen. Gezeichnete Kappen: Elfenbein-Tasten, Maus mit markierter Taste, Xbox A/B/X/Y
farbig gedeckt, LB/RT, Steuerkreuz mit Pfeil, Sticks L/R. Interaktionshinweis nutzt dieselben Symbole.

**F1-Hilfe:** Tafel in der Bildmitte, Reiter Flug/Zu Fuß/Fahren (aktueller hervorgehoben), Gruppen
(Fliegen, Kamera, Kämpfen, Allgemein bzw. Bewegen, Arbeiten …), Tastatur und Controller nebeneinander
(Spalte des aktiven Geräts hell), zwei Kurztipps. Eine Klasse für alle Kontexte (`GroundHelp`).

**Visuelle Sprache Tier I:** Palette Elfenbein (Werte), Khaki (Beschriftung), Messing (Akzent, Kanten),
Oliv (ok), Bernstein/gedecktes Rot nur für Warnungen; halbtransparentes warmes Dunkel, 4-px-Ecken,
Messingkante + feine Innenlinie. Schrift Inter (OFL, liegt bei) – Überschriften in gesperrten Versalien
(Tafelbeschriftung). Eine besser passende OFL-Schrift (z. B. Oswald) war im Netz der Umgebung nicht
ladbar; Austausch = eine Zeile in `HudStyle`.

**Epochen-Themes:** `ui/theme/hud_palette.gd` (Resource) + `epoch_t1.tres` + Godot-Theme
`hud_theme_t1.tres`. `HudStyle.apply(palette)` schaltet alle Panels um; spätere Epochen bekommen eine
eigene .tres (z. B. Jets: grünliches Glas-HUD).

## 3. Dateien

Neu: `ui/theme/*`, `ui/common/key_glyphs.gd`, `ui/common/key_bar.gd`, `ui/combat/alert_stack.gd`,
`tools/screenshot_m3_2.gd`, `tests/suites/ui/test_ui_m3_2.gd`. Geändert: `hud_style.gd`, `hud.gd`
(Hilfe), `combat_hud.gd`, `flight_panel.gd`, `target_overlay.gd`, `ground_hud.gd`, `ground_help.gd`,
`interaction_hint.gd`, `command_wheel.gd`. Screenshots: `docs/screens_m3/ui_m3_2_*.png`
(`…_vorher_*` = Stand M3.1).

## 4. Phase 2 (umgesetzt)

Geführtes Tutorial (`tutorial/`, 7 Schritte, Karte rechts, Tasten über die Tasten-Leiste) sowie
Hauptmenü und Pausenmenü (`ui/menu/`) im selben Theme; Einstellungen in `user://flugkern.cfg`.
