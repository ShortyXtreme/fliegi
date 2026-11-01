# M2 – Hooks von Agent D/E (Kampf-HUD, Effekte) für Paket 14

Stand: 01.11.2026 · Branch `m2-hud` · Dateien nur in `ui/combat/`, `weapons/fx/`, Tests in `tests/suites/ui/`, `tests/suites/fx/`.

## Neues HUD-Layout (Tester-Feedback „Schrift zu mittig/unschön“)
1. **Altes Text-HUD ausblenden** (`ui/hud.gd`): Das neue `FlightPanel` (links unten) zeigt Fahrt, Höhe, Grund, Steigen, G, Gas, Klappen, Fahrwerk, Modus, Kamera und alle Warnungen (Stall, Abriss, Fahrwerk, Bauchlandung, Parkbremse). Umschalten ohne Änderung an hud.gd: `CombatHud.replace_legacy_text = true` (z. B. in `game.gd`). Sauberer: in `hud.gd` `_info`, `_warn`, `_warn2` gar nicht mehr anlegen bzw. nur noch `_debug` (F3) und `_help` (F1) behalten. Die FPS zeigt das Panel nur bei `hud.debug_visible` (F3).
2. **Fahrwerk-Meldungen** (`Hud.on_gear_toggled`): kurze Meldungen wie „Einfahren am Boden nicht möglich“ landen heute in `_warn2`. Empfehlung: an `CombatHud.flight_panel` weiterreichen (Methode folgt bei Bedarf) – derzeit zeigt das Panel den Fahrwerkszustand und die Warnungen selbst.
3. **Abriss-Warnung**: Das Panel nutzt dieselbe Schwelle wie hud.gd (`FlightModel.BUFFET_ONSET`). Wird die Schwelle in Paket 14 auf ~1,5° verkürzt, übernimmt das Panel sie automatisch.
4. **F1-Hilfe** liegt oben rechts und überdeckt beim Start den Kill-Feed; unkritisch, da sie sich schließen lässt.
