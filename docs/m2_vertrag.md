# M2-Vertrag (Paket 0 „Vertragsschnitt“)

Stand: 31.10.2026 · Basis: `docs/plan_m2.md` §7 · Code: `game/` (Godot 4.7.2)

Dieses Dokument legt fest, welche Schnittstellen nach Paket 0 feststehen und welche Dateien welchem Arbeitspaket-Agenten **exklusiv** gehören. Die Arbeitspakete A–F laufen parallel und ändern nur ihre eigenen Dateien. Die gemeinsamen Dateien ändert danach nur noch Paket 14 (Integration).

## 1. Regeln

1. **Gemeinsame Dateien sind eingefroren:** `vehicles/aircraft/aircraft.gd`, `physics/flight_model.gd`, `physics/aero_surface.gd`, `physics/prop_engine.gd`, `world/game.gd`, `ui/hud.gd`, `tests/test_runner.gd`, `tests/test_suite.gd`, `core/*`, `control/*`, `project.godot`, `data/aircraft_data.gd`, `data/fighter_t1.tres`, `tools/build_fighter_t1.gd`. Änderungen daran macht nur Paket 14. Braucht ein Paket einen neuen Hook, notiert es ihn in seinem Bericht für Paket 14 und baut bis dahin eine Ersatzlösung in den eigenen Dateien.
2. **Stub-Dateien gehören dem genannten Agenten.** Er darf sie vollständig umschreiben. Die Signaturen in Abschnitt 2 muss er beibehalten, neue Methoden und Felder darf er ergänzen.
3. **Tests:** Jeder Agent legt seine Tests als eigene Datei unter `tests/suites/<ordner>/` an (`extends TestSuite`, Methoden `test_*` geben `[ok, text]` zurück). Der Läufer findet sie automatisch. Lange Tests markiert er mit `const SUITE := "slow"` oder `const TEST_SUITES := {"test_x": "slow"}`.
4. **Daten:** `.tres`-Dateien liegen im Ordner des Agenten. Die Pfade sind in `fighter_t1.tres` schon eingetragen (siehe 2.3).
5. **Nur der Server ändert Zustand** (`Authority.is_server()`): Treffer, Schaden, Abschuss, Neustart, Diplomatie.
6. Die M1/M1.1-Tests (`tests/suites/test_flight_m1.gd`) und die Vertragstests (`tests/suites/test_contract_m2.gd`) müssen jederzeit grün bleiben. Neutrale Modifier ändern die Flugphysik nicht.

## 2. Schnittstellen

### 2.1 Kern (`core/`, eingefroren)
| Datei | Klasse | Inhalt |
|---|---|---|
| `nations.gd` | `Nations` | `BLUE=0`, `RED=1`, `NONE=-1`, `Relation {ALLIED, NEUTRAL, WAR}`, `relation(a,b)`, `is_hostile(a,b)`, `is_friendly(a,b)`, `set_relation(a,b,r)` (Server), `reset()`, `display_name(n)`, `color(n)` |
| `combat_events.gd` | `CombatEvents` | Bus über `CombatEvents.bus()`, `reset()`. Signale: `shot_fired(shooter, gun_index, shot_id)`, `hit_confirmed(shooter, target, zone, damage)`, `aircraft_damaged(aircraft, zone, damage, attacker)`, `aircraft_destroyed(victim, killer, cause)`, `pilot_ejected(aircraft, pilot)`, `pilot_rescued(pilot, rescuer)`. `Cause {UNKNOWN, WING_BROKEN, PILOT_KILLED, EJECTED, CRASH, ENGINE, FIRE, FRIENDLY}`. Ereignis-Log: `log_enabled`, `event_log`, `log_hash()` (Ticks relativ, für die Duell-Regression), `entity_id(node)` |
| `layers.gd` | `Layers` | `WORLD`, `AIRCRAFT`, `GROUND_VEHICLE`, `CHARACTER`, `WRECK`, `SENSOR`; Masken `MASK_AIRCRAFT`, `MASK_GROUND_RAY`, `MASK_GEAR_RAY`, `MASK_PROJECTILE_RAY` (Namen auch in `project.godot`) |
| `spotting.gd` | `Spotting` | `spot_range(viewer, target, mode=-1) = base(mode) × aircraft_visibility(viewer) × crew_level_mul(level) + radar_bonus(viewer, target)`, `can_spot()`, `register_radar()`/`unregister_radar()`, `reset()`. Startwerte: 5.000 m Arcade, 3.000 m Realistisch, +10 % je Beobachter, ×1,15 ab Level 3, +3.000 m Radar |
| `radar_station.gd` | `RadarStation` | Stub für Bodenradar: `position`, `radius`, `nation_id`, `operational`, `covers(p)` |
| `match_rules.gd` | `MatchRules` | Lobby-Werte: `friendly_fire_damage` (aus), `respawn_delay` 15 s, `wreck_lifetime` 30 s, `kill_credit_window` 30 s, `spot_mode` (`SpotMode {ARCADE, REALISTIC}`), `lead_indicator`, `radar_light`, `reset()` |
| `world_ground.gd` | `WorldGround` | `height_at(x, z)` ohne Physik; Gelände meldet sich mit `set_provider(obj)` an (ohne Provider: y = 0) |
| `world_origin.gd` | `WorldOrigin` | `offset`, `to_abs()`, `to_local()` (Stub für Paket 13) |

### 2.2 Steuerung (`control/`, eingefroren)
- `PilotIntent`: neue Felder `fire_primary`, `fire_secondary`, `eject`. `to_array()[8]` enthält die Tasten-Bits (`BIT_FIRE_PRIMARY=1`, `BIT_FIRE_SECONDARY=2`, `BIT_EJECT=4`). `from_array()` liest auch alte Arrays mit 8 Einträgen.
- `eject` setzt der Controller erst nach 1 s Halten (`InputBindings.EJECT_HOLD_TIME`). Das Flugzeug reagiert auf die steigende Flanke. Die KI setzt `eject` direkt.
- `PlayerController`: Signal `eject_hold_changed(progress)` und Feld `eject_hold_progress` (0..1) für das HUD.

### 2.3 Flugzeug (eingefroren, Hooks fest)
- `Aircraft`: `nation_id`, `entity_id` (eindeutig), `crew_level`, `pilot: PilotRecord`, `weapons: WeaponSystem`, `damage: DamageModel`, `is_hostile_to(node)`. Signal `eject_requested(aircraft, allowed)` (allowed = `damage.can_eject()`). Layer `AIRCRAFT`, Maske `MASK_AIRCRAFT`.
- Ablauf je Physik-Tick in `_physics_process`: `seat.poll` → `damage.filter_intent(intent, dt)` → Eject-Flanke → `weapons.tick(intent, dt)` → `damage.tick(dt)`.
- `_on_body_entered` → `damage.on_impact(body, velocity)`. `place()` → `damage.reset()` und `weapons.reset()`.
- `FlightModifiers` (`physics/flight_modifiers.gd`, schreibt Agent B, liest nur das Flugmodell): je Fläche `lift[i]`, `drag[i]`, `control[i]`, `set_stuck(i, wert)`/`release_stuck(i)`, dazu `engine_power_mul`, `engine_failed`, `extra_drag_area`, `reset()`, `is_neutral()`. Index i = Index in `AircraftData.surfaces` (= `AeroSurface.index`): 0–2 `wing_R_root/mid/tip`, 3–5 `wing_L_root/mid/tip` (2 und 5 = Querruder), 6–7 `htail_R/L`, 8 `vtail`.
- Die Hooks wirken an diesen Stellen: `AeroSurface.compute(..., lift_mul, drag_add)`, Ruderkommando über `FlightModifiers.control_command(i, cmd)` in `FlightModel`, `PropEngine.update(..., mods)` und der Rumpfwiderstand in `FlightModel`. `aircraft.damage.modifiers` ist dasselbe Objekt wie `aircraft.flight.modifiers`.
- `AircraftData` (neu): `loadout_path`, `damage_profile_path`, `markers_path`, `cockpit_visibility`, `crew_count`. In `fighter_t1.tres` stehen die Pfade schon (die Dateien fehlen noch, die Stubs laufen ohne sie):
  - `res://weapons/data/loadout_fighter_t1.tres` (A)
  - `res://vehicles/aircraft/damage/data/damage_profile_t1.tres` (B)
  - `res://vehicles/aircraft/data/markers/fighter_t1_markers.tres` (B, Paket 3)

### 2.4 Stub-Klassen (gehören dem Agenten)
| Klasse | Datei | Feste Signaturen |
|---|---|---|
| `WeaponSystem` | `weapons/weapon_system.gd` | `_init(aircraft)`, `tick(intent, dt)`, `reset()`, `has_weapons(group)`, `gun_count()`, `ammo(group)`, `ammo_max(group)`, `muzzle_velocity(group)`, `rearm(store)`, `convergence`, `Group {PRIMARY, SECONDARY}`, Signale `fired(gun_index, shot_id)` und `trigger_changed(group, pressed)` |
| `ProjectileSystem` | `weapons/projectile_system.gd` | Node, genau eine je Welt, `ProjectileSystem.current`, `spawn(shooter, gun_index, shot_id, pos, vel, weapon) -> int`, `active_count()`, `clear()` |
| `WeaponFx` | `weapons/fx/weapon_fx.gd` | Node3D unter `Game`, `enabled` (headless false); liest nur Bus und ProjectileSystem |
| `DamageModel` | `vehicles/aircraft/damage/damage_model.gd` | `Zone {ENGINE, FUEL_L, FUEL_R, WING_L, WING_R, TAIL, COCKPIT}`, `_init(aircraft, modifiers)`, `apply_hit(zone, damage, attacker, local_point)`, `hp_fraction(zone)`, `tick(dt)`, `filter_intent(intent, dt)`, `can_eject()`, `pilot_wounded()`, `on_impact(body, velocity)`, `reset()`, `to_array()`/`from_array()`, `hitboxes`, `is_destroyed`, `last_attacker`, Signale `zone_changed`, `destroyed(cause, killer)` |
| `HitboxSet` | `vehicles/aircraft/damage/hitbox_set.gd` | `from_aircraft_data(d)`, `bounding_radius`, `intersect_segment(p0, p1) -> {zone, t, point}` (lokal) |
| `CombatHud` | `ui/combat/combat_hud.gd` | `create(hud)`, Feld `hud` (liest `hud.aircraft`, `hud.player` und `hud.camera_rig` in jedem Frame). Registriert über genau eine Zeile in `hud.gd` |
| `AIPilotBrain` | `ai/brain/ai_pilot_brain.gd` | `extends Controller`, `compute_intent(dt)`, `difficulty`, `rng_seed` |
| `TerrainWorld` | `world/terrain/terrain_world.gd` | `height_at(x, z)`, `runway_spawn(i)`, `RUNWAY_DIR`; meldet sich bei `WorldGround` an |
| `SpawnManager` | `world/spawn_manager.gd` | Node unter `Game`, `register(aircraft, controller, respawn_callable)`, `unregister()`, `respawn_now()`, Signal `respawned` |
| `PilotRecord` | `characters/pilot_record.gd` | `id`, `level`, `xp_banked`, `xp_pending`, `alive`, `dispersion_mul()`, `spot_range_mul()` |

### 2.5 Hauptszene und Tests (eingefroren)
- `Game` legt `projectiles`, `weapon_fx` und `spawn_manager` an. Spieler = Blau, KI = Rot. Der Spieler ist beim SpawnManager registriert. `CombatEvents.reset()` beim Start.
- `TestSuite` (`tests/test_suite.gd`): `world`, `projectiles`, `make_world()` (überschreibbar, z. B. für eine Duell-Arena oder `TerrainWorld`), `before_each()`/`after_each()`, Helfer `_spawn()`, `_seat()`, `_step()`, `kmh()`.
- Der Läufer setzt vor jedem Test `CombatEvents`, `Nations`, `MatchRules`, `Spotting` und `WorldGround` zurück. Optionen: `--suite=fast|slow|all`, `--only=`, `--file=`, `--list`.

## 3. Eigentum je Agent (exklusiv)

| Agent | Pakete | Dateien/Ordner |
|---|---|---|
| **A Waffen** | 1, 2, 5, 15 | `weapons/*.gd` (außer `fx/`): `weapon_system.gd`, `projectile_system.gd`, `ballistics.gd`, `weapon_def.gd`, `gun_mount_def.gd`, `lead_solver.gd`, `ammo_*.gd`, `fire_event.gd`, `hit_validator.gd`, `transform_history.gd`, `heat.gd`; `weapons/data/`; `tests/suites/weapons/` |
| **B Schaden** | 3, 4, 6, 11 | `vehicles/aircraft/damage/` (inkl. `data/`, `fx_*.gd`), `physics/flight_modifiers.gd`, `physics/fuel_system.gd` (neu), `tools/extract_markers.gd`, `vehicles/aircraft/data/markers/`, `world/spawn_manager.gd`, `characters/`, **ab Paket 11 exklusiv** `aircraft_visual.gd`; `tests/suites/damage/` |
| **C KI** | 7, 8 | `ai/brain/`, `ai/perception.gd`, `ai/data/`, `tests/suites/ai/`, `tests/duel_arena.gd`, `tests/suites/test_duels.gd` (Suite „slow“) |
| **D HUD** | 9 | `ui/combat/`, `tests/suites/hud/` |
| **E Effekte** | 10 | `weapons/fx/`, `tests/suites/fx/` |
| **F Welt** | 12, 13 | `world/terrain/`, `tools/build_terrain.gd`, `world/origin_shifter.gd`, `core/world_origin.gd` (Ausnahme vom Kern-Freeze), `tests/suites/world/` |
| **Integration** | 14 | alle gemeinsamen Dateien (Abschnitt 1), `world/combat_scenario.gd`, `ai/ai_controller.gd`, `docs/changelog.md`, `game/README.md`, F1-Hilfe |

Lesen darf jeder Agent alles. Dateien anderer Agenten nutzt er nur über die Schnittstellen aus Abschnitt 2.

## 4. Was Paket 14 noch verdrahten muss (bewusst offen)
- In `game.gd` das Szenario „1 gegen 3“ (`combat_scenario.gd`), `AIPilotBrain` statt `AIController` und `TerrainWorld` statt `TestWorld` (umschaltbar).
- Den SpawnManager mit `CombatEvents.aircraft_destroyed`/`pilot_ejected` verbinden. Das kann Paket 6 auch selbst im SpawnManager tun, weil er `CombatEvents.bus()` kennt.
- `eject_requested` → Ausstieg (Paket 6 kann im DamageModel bzw. SpawnManager darauf hören, `aircraft.eject_requested.connect(...)`), HUD-Hinweis „gesperrt“ (Paket 9 hört ebenfalls auf das Signal).
- `ProjectileSystem.current` in Tests: Der Läufer legt in jeder Testwelt eins an.
- HUD-Versionsanzeige und `project.godot` auf „M2“ stellen, Changelog, Build.
