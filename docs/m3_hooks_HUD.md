# M3 Hooks Paket 13 (Boden-HUD) – für Paket 14 und Strang G/H

Stand: 02.11.2026 · Branch `m3-hud` · keine gemeinsame Datei geändert. Code: `game/ui/ground/`, Tests `tests/suites/ui_ground/` (12 Tests), Vorschau `ui/ground/preview/ground_hud_preview.gd`, Screens `docs/screens_m3/hud_boden_*.png`.

## Bausteine
| Datei | Inhalt |
|---|---|
| `ground_hud.gd` | `GroundHud.create(hud)`, ordnet alles an, liest Daten, Kontext, Eingabe (Befehlsrad, F1) |
| `ground_hud_data.gd` | reine Datensammlung (`aircraft_status`, `stock`, `interaction`, `worker_name`, `clock` …), headless testbar |
| `interaction_hint.gd` | „[E] halten: Gurt einlegen“ / Pad „[A]“, „Kiste fehlt“, „Lager leer“, Fortschrittsring, Literanzeige beim Pumpen |
| `command_wheel.gd` | 8 Befehle aus `GroundCrewBrain.COMMAND_LABELS`, Ziel in der Mitte, Signal `command_chosen(cmd, target)` |
| `aircraft_status_panel.gd` | Treibstoff l/% + Sorte, MG L/R, Zonenskizze (Unterklasse von `WeaponPanel`), Jobs mit Bearbeiter |
| `stock_bar.gd`, `turnaround_display.gd`, `parking_guide.gd`, `ground_help.gd` | Lagerleiste, Abfertigungszeit/Sterne/Bestzeit + Alarm-Banner, Bodenmarke + Pfeil, F1-Hilfe je Kontext |

## Paket 14 (Integration)
1. `hud.gd`: `ground_hud = GroundHud.create(self); add_child(ground_hud)` (eine Zeile wie CombatHud).
2. **Nicht** `session.ground_hud = …` setzen: `PlayerSession.apply_view` würde das Boden-HUD im Flug abschalten, es braucht aber auch im Cockpit Bodenmarke, Statuspanel nach der Landung und Alarm. Stattdessen `ground_hud.session = session` (Kontext wird gelesen) oder `set_context(ctx)` bei `context_changed`. Alternativ in `apply_view` die Zeile `_set_active(ground_hud, …)` streichen.
3. Datenquellen setzen (fehlt eine, bleibt das Element aus): `character` (Spielerfigur), `board` (sonst `JobBoard.current`), `depot` (FuelDepot), `bunker` (AmmoBunker), `turnaround`, `dispatch` (GroundCrewDispatch des eigenen Platzes; liefert `aircraft` für Statuspanel/Rad), optional `aircraft_list`. Nach der Landung: `has_parking_target = true`, `parking_target = layout.parking_transform(i).origin` (bei Erreichen/Aussteigen wieder `false`).
4. Flug-HUD im Boden-Kontext: `GroundHud` blendet ersatzweise `hud.combat` (Prozess aus) und `_info/_warn/_warn2/_aim_marker/_nose_marker/_help` aus und im Flug wieder ein (`manage_flight_hud`, Standard an). Sauberer: in `hud.gd` je Kontext schalten und `manage_flight_hud = false`.
5. F1: `hud.gd` toggelt sein Flug-Hilfefenster auch zu Fuß. Das Boden-HUD versteckt es dort und zeigt `GroundHelp`. Für eine einheitliche Hilfe kann `hud.gd` `GroundHelp.help_rows(ctx)` nutzen (Flug, zu Fuß, Fahren).
6. Meldungen `GroundCrewDispatch.announced(text, a)` gehen noch nicht ans Boden-HUD (Kill-Feed `add_text` wäre der Ort).

## Strang G (Paket 7b, Befehlsrad)
- Das Rad ruft beim Loslassen `GroundHud.issue_command(cmd, target)`: Signal `command_issued(cmd, target)`, dann `command_receiver` (Callable), sonst **`dispatch.command(cmd, target)`**, falls vorhanden, sonst `command(cmd, target)` an jedem `dispatch.crews[i]` (bzw. dessen `brain`). `cmd` = `GroundCrewBrain.Command`, `target` = Zielmaschine (kann null sein). Vorschlag: `GroundCrewDispatch.command()` verteilt selbst.
- Bearbeiter-Namen: `display_name` am Worker-Knoten (sonst Knotenname), Spielerfigur = „Du“.

## Strang H / Paket 14 (Eingabe)
- Während das Rad offen ist, markiert das HUD Mausbewegung als behandelt (`CrewPlayerController._unhandled_input` dreht dann nicht). Der rechte Stick dreht aber weiter die Kamera: `CrewPlayerController` sollte bei `wheel_open` den Blick einfrieren.
- Ziel wechseln im Rad: Mausrad bzw. Steuerkreuz ←/→ (direkt gelesen, keine neue Aktion). `CrewIntent.wheel_choice` bleibt -1; die Auswahl liegt im HUD.
- Pumpen: Liter kommen aus `RefuelJob.pumped`/`liters_needed()` des Jobs im Schritt `pump` am Tankdeckel; der Ring zeigt dort den Füllanteil.
