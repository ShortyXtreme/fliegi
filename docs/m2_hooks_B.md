# M2 – Hooks für Paket 14 (Agent B „Schaden“)

Stand: 01.11.2026. Diese Punkte brauchen Änderungen an gemeinsamen (eingefrorenen) Dateien.

## game.gd
1. **KI-Flugzeug beim SpawnManager registrieren** (`spawn_manager.register(ai_aircraft, ai, respawn)`), sonst startet nach Abschuss nur der Spieler neu.
2. **Respawn-Callable des Spielers** setzt nach dem Neustart auch `player.reset_state()` (geschieht schon über `_on_reset(false)`), die KI braucht ein Gegenstück.
3. **Wracks** legt der SpawnManager im Elternknoten des Flugzeugs ab (bei game.gd = `Game`). Bei Floating Origin (Paket 13) müssen `Wreck` und `Parachute` mitverschoben werden.
4. **Kamera bei Ausstieg:** M2 ohne Third-Person; optional `cam.target = damage.parachute` bis zum Neustart.

## aircraft.gd
5. Bei `damage.is_destroyed` mit `outcome == CRASHED` sollte das Flugzeug eingefroren werden (`freeze = true`), damit das Wrack nicht weiterrutscht; `place()` hebt das wieder auf.
6. `crashed`-Signal und `DamageModel.grounded` doppeln sich; HUD-Text „Crash!“ sollte auf `grounded`/`aircraft_destroyed` umgestellt werden.
7. **Treibstoffmasse:** `damage.fuel.total()` × 0,72 kg/l ist noch nicht in `mass` gekoppelt.

## hud.gd / ui/combat
8. Anzeigen: `damage.fuel.fraction()`, `damage.pilot_wounded()` (Vignette), `spawn_manager.time_to_respawn(a)` (Countdown), `eject_requested(allowed=false)` → „gesperrt“.

## Modellwechsel (Paket 11)
9. `aircraft_visual.gd` lädt das Spielmodell schon selbst (`art/models/fighter_t1_game.glb`, Rot: `*_enemy.glb`, Laufzeit-Import ~1 s, danach gecacht) und animiert es nach `fighter_t1_rig.json`. Die Datei liegt aber **außerhalb von `res://`** und kommt nicht in einen Export. Paket 14: GLBs nach `game/vehicles/aircraft/models/` kopieren (importiert) und `RIG_MODEL`/`model_path` in `fighter_t1.tres` darauf umstellen; das alte `fighter_t1.glb` + `model_offset/rotation/scale` werden dann nicht mehr gebraucht. Gegner-Variante wird über `nation_id != BLUE` beim Eintritt in den Baum gewählt (nation_id vor `add_child` setzen).
11. `game.gd` färbt die KI über `ai_data.body_color` – beim Rig-Modell wirkungslos (Gegner-Texturen im GLB).
12. Kamera Cockpitansicht ruft `set_cockpit_view()` – blendet jetzt auch die Pilotenfigur aus.

## XP
10. „Landung am eigenen Platz“ gibt es noch nicht als Ort; `PilotRecord.bank_xp()` muss Paket 14 (oder Bodenbetrieb) bei Stillstand auf dem eigenen Flugplatz aufrufen. Kills/Assists → `add_xp()` ebenfalls dort (Bus-Listener).
