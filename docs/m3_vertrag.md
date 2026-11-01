# M3-Vertrag (Paket 0 „Vertragsschnitt“, Teile 0a und 0b)

Stand: 01.11.2026 · Basis: `docs/plan_m3.md` §3, §6 und die Entscheidungen des Product Owners · Code: `game/` (Godot 4.7.2)

Dieses Dokument legt fest, welche Schnittstellen nach Paket 0 feststehen und welche Dateien welchem Strang **exklusiv** gehören. Die Stränge G, H, C, Grafik und HUD arbeiten parallel und ändern nur ihre eigenen Dateien. Die gemeinsamen Dateien ändert danach nur noch Paket 14 (Integration).

## 1. Regeln

1. **Gemeinsame Dateien sind eingefroren.** Das sind alle Dateien aus M2-Vertrag §1 und zusätzlich: `control/*` (inkl. `seat_service.gd`, `player_session.gd`, `drive_player_controller.gd`, `intents/crew_intent.gd`), `core/*` (inkl. `ground_events.gd`, `match_rules.gd`, `authority.gd`, `input_bindings.gd`), `vehicles/aircraft/aircraft.gd`, `vehicles/aircraft/service_state.gd`, `vehicles/aircraft/physics/fuel_system.gd`, `vehicles/aircraft/damage/damage_model.gd`, `weapons/weapon_system.gd`, `weapons/ammo_store.gd`, `weapons/ammo_infinite_store.gd`, `ground_ops/service_markers.gd`, `world/terrain/terrain_world.gd`, `world/game.gd`, `ui/hud.gd`, `world/combat_scenario.gd`, `project.godot`, `tests/test_runner.gd`, `tests/test_suite.gd`, die Vertragstests `tests/suites/test_contract_m2.gd` und `test_contract_m3.gd`. Braucht ein Strang einen neuen Hook, notiert er ihn im Bericht für Paket 14 und baut bis dahin eine Ersatzlösung in den eigenen Dateien.
2. **Stub-Dateien gehören dem genannten Strang.** Er darf sie vollständig umschreiben. Die Signaturen aus Abschnitt 2 muss er beibehalten, neue Methoden und Felder darf er ergänzen.
3. **Tests:** Jeder Strang legt seine Tests unter `tests/suites/<ordner>/` an (`extends TestSuite`). Der Läufer findet sie automatisch und setzt vor jedem Test zusätzlich `GroundEvents` und `Authority.simulate_client` zurück.
4. **Nur der Server ändert Zustand.** Jede Zustandsänderung am Boden läuft über `JobBoard` oder `SeatService` (bzw. die Lager-/Waffen-/Schadensfunktionen, die auf `Authority.is_server()` prüfen). Einen simulierten Client testet man mit `Authority.simulate_client = true`.
5. **Mengen-Erhalt:** Treibstoff und Munition entstehen nie aus dem Nichts. Was `draw()`/`request()` liefert und `FuelSystem.add()`/`load_gun()` nicht annimmt, geht mit `deposit()`/`give_back()` zurück.
6. **Das Verhalten von M2 bleibt bis Paket 14 erhalten:** Der Spieler startet voll auf der Piste, `PlayerController.exit_on_ground` ist aus, und `AirfieldPhases` liefert `COMBAT`. Alle M1/M2-Tests und die Suite `export` müssen jederzeit grün bleiben.

## 2. Schnittstellen

### 2.1 Steuerung (0a, `control/`, eingefroren)
| Klasse | Inhalt |
|---|---|
| `CrewIntent` | `move: Vector2` (x rechts, y vorn, Länge ≤ 1), `look_yaw`, `look_pitch` (absolut, rad), `sprint`, `interact` (gehalten), `drop`, `enter`, `wheel_open` (gehalten), `wheel_choice` (-1 = keiner), `view_toggle`. `to_array()` = `[move.x, move.y, look_yaw, look_pitch, wheel_choice, bits]`, `from_array()`, `copy_from()`, `clamp_values()`, Bits `BIT_SPRINT=1 … BIT_VIEW_TOGGLE=32` |
| `Controller` | zusätzlich `compute_crew_intent(dt) -> CrewIntent`, `peer_id` (0 = KI/Server, sonst Mensch), `session` (Besitzer mit `controller_for(role)`), `is_ai()` |
| `Seat` | `Role {PILOT, GUNNER, BOMBARDIER, CREW, DRIVER, PASSENGER}` (alte Indizes unverändert), `entry_offset` (lokal), `entry_position()`, `poll_crew(dt)`, `crew_intent`, `is_human_occupied()`, `ENTRY_RANGE = 3 m`, `MAX_SWITCH_SPEED = 1 m/s` |
| `SeatService` | Node unter Game, `SeatService.current`. `request_enter(peer, character, seat) -> Result`, `request_exit(peer, seat) -> Result`, `Result {OK, NOT_SERVER, BAD_PEER, TOO_FAR, MOVING, NO_GROUND, OCCUPIED, INVALID, NO_CHARACTER}`, `result_text()`, `rider_of(seat)`, Signal `ai_displaced(controller, seat)`. Die Figur hat `crew_seat: Seat` und optional `on_entered_seat(seat)`/`on_exited_seat(seat, pos)`. Fahrzeuge melden optional `seat_speed()`/`seat_on_ground()`. Sendet `GroundEvents.seat_changed` |
| `PlayerSession` | Controller `flight` (PlayerController), `crew` (CrewPlayerController), `drive` (DrivePlayerController), `controller_for(role)`, `take_seat(seat)`, `apply_view(seat)`, `context`, Felder `camera_rig`, `crew_camera`, `hud`, `ground_hud`, Signale `context_changed`, `seat_changed`. Hört auf `exit_requested` → `SeatService.request_exit` |
| `PlayerController` | neu `exit_on_ground` (Standard aus), `exit_mode`, Signal `exit_requested`: Halten von J / Steuerkreuz ← 1 s am Boden mit < 1 m/s = Aussteigen, sonst Notausstieg wie M2 |
| `DrivePlayerController` | Kontext DRIVE → `PilotIntent` (throttle, brakes, yaw = Lenkung), Signal `exit_requested` |

### 2.2 Kern (0a, `core/`, eingefroren)
- `InputBindings`: `Context {FLIGHT, CREW, DRIVE}`, `GLOBAL_ACTIONS`, `CONTEXT_ACTIONS`, `actions_for(ctx)`, `in_context(action, ctx)`, `EXIT_HOLD_TIME`. Jede Aktion steht in einem Kontext. Innerhalb eines Kontexts (inklusive GLOBAL) ist jede Taste nur einmal belegt (`test_binding_conflicts`, `test_binding_contexts`).
- Belegung: **FLIGHT** wie M2 (J / Steuerkreuz ← = Aussteigen im Stand bzw. Notausstieg). **CREW**: WASD/linker Stick, Maus/rechter Stick, Shift/L3 Sprint, E/A Interagieren (halten), G/B Ablegen, F/Y Einsteigen, Tab/LB Befehlsrad (halten), C/R3 Ego/Third. **DRIVE**: W/RT Gas, S/LT Bremse bzw. rückwärts, A D/linker Stick Lenken, Leertaste/B Handbremse, J/Steuerkreuz ← 1 s Aussteigen, E/A, Tab/LB, C/Y Kamera. **GLOBAL**: F1/Back, Esc.
- `GroundEvents` (Bus, `bus()`/`reset()`): `job_added(id, kind, target)`, `job_progress(id, step, progress, worker)`, `job_done(id, target)`, `job_blocked(id, reason)`, `depot_changed(depot)`, `turnaround(aircraft, seconds, helpers)`, `seat_changed(peer, from, to)`, `alarm_started(seconds)`, `alarm_ended(success)`.
- `MatchRules`: `GroundRealism {EINFACH, STANDARD, AUTHENTISCH}`, `ground_realism` (Standard), `StartKind {FIRST, AFTER_LOSS, AFTER_LANDING}`, `start_fuel(kind)`/`start_ammo(kind)` (50 %/100 %, 15 %/0 %, -1 = Rest), `parse_ground_realism()`, `ground_realism_name()`, `load_ground_config(path, args)` (`[m3] bodenbetrieb=`, `--boden=`; die Kommandozeile gewinnt).
- `Authority.simulate_client`, `Authority.reset()`.

### 2.3 Spielsysteme (0b, eingefroren)
- `Aircraft.place(xf, speed, throttle, gear_down, refill = true, service = null)`: Mit `refill = false` bleiben Schäden, Treibstoff und Munition erhalten. `service` (`ServiceState`) wird danach angewendet. `place_on_ground(pos, dir, refill, service)`, `service_point(marker)`, `seat_on_ground()`, `seat_speed()`. `pilot_seat.entry_offset` = `svc_entry`.
- `ServiceState`: `fuel_fraction`, `ammo_fraction` (< 0 = behalten), `grade_mix`, `fresh_airframe`, `make()`, `full()`, `keep()`, `for_start(kind)`, `apply(aircraft)`.
- `FuelSystem`: `GRADE_AVIATION`/`GRADE_ERSATZ`, `grade_mix`, `add(l, grade) -> angenommen`, `space()`, `power_mul()` (= 1 − 0,12 × Anteil), `set_fraction(f, mix)`. `to_array()` bleibt bei 2 Werten, die Sorte läuft separat.
- `DamageModel`: `engine_power_mul ×= fuel.power_mul()`, `repair(zone, hp) -> repariert` (nur Server, nur für Zonen > 0 HP ohne Brand, nicht für abgeschossene Maschinen), `can_repair(zone)`.
- `WeaponSystem`: `reset(refill = true)`, `load_gun(i, store, n) -> geladen` (nur Server), `set_ammo_fraction(f)`, `gun_ammo(i)`, `gun_capacity(i)`.
- `AmmoStore`: `request(type, n)`, `available(type)`, `give_back(type, n)`. `InfiniteAmmoStore.available` ist praktisch unbegrenzt.
- `TerrainWorld.airfield_layout(i) -> AirfieldLayout`: lädt `res://ground_ops/airfield/data/airfield_<i>.tres` oder erzeugt einen Ersatzplan.
- `ServiceMarkers` (feste Namen): Flugzeug `svc_fuel_cap`, `svc_gun_hatch_L`, `svc_gun_hatch_R`, `svc_entry`, `svc_engine`. Fahrzeug `hose_reel`, `seat_driver`, `seat_passenger`, `ground_clip`, `crate_slot_1..6`. Gebäude `door`, `fuel_tap`, `ammo_door`. Figur `hand_R`, `hand_L`, `carry`. `aircraft_point(a, name)` liest die Marker (`AircraftMarkers.points`, leere GLB-Knoten) und nimmt sonst eine Ersatzposition aus der Geometrie.

### 2.4 Stub-Klassen (gehören dem Strang)
| Klasse | Datei | Feste Signaturen | Strang |
|---|---|---|---|
| `FuelSource` | `ground_ops/supply/fuel_source.gd` | `draw(grade, l)`, `deposit(grade, l)`, `available(grade)`, `capacity(grade)`, `total()`, Signal `changed` | G |
| `FuelDepot` | `ground_ops/supply/fuel_depot.gd` | `extends FuelSource`, aviation 8.000 l / ersatz 3.000 l, `hp`, `destroyed`, `to_array()`/`from_array()`, `position` | G |
| `AmmoBunker` | `ground_ops/supply/ammo_bunker.gd` | `extends AmmoStore`, `AMMO_792` 20.000, `stock`, `hp`, `destroyed`, `changed`, `to_array()` | G |
| `GroundRules` | `ground_ops/data/ground_rules.gd` | Resource mit Zeiten und Raten, `for_realism(r)` (lädt `ground_rules_<stufe>.tres`) | G |
| `GroundJob`, `RefuelJob`, `RearmJob`, `RepairJob`, `LoadOrdnanceJob` | `ground_ops/jobs/` | `id`, `kind`, `target`, `steps`, `step_index`, `progress`, `worker`, `blocked_reason`, `priority`, `step(name, dt, rules) -> bool`, `advance()`. Refuel: `source`, `grade`, `target_fraction`. Rearm: `gun_index`, `store`. Repair: `zone`. LoadOrdnance: `hardpoint`, `ordnance`, in M3 blockiert | G |
| `JobBoard` | `ground_ops/job_board.gd` | Node, `current`, `add_job`, `get_job`, `jobs_for`, `claim`, `request_step(peer, job_id, step, dt)`, `cancel`, `rules` | G |
| `Turnaround` | `ground_ops/turnaround.gd` | `start`, `tick`, `finish`, `alarm_left`, `BEST_PATH` | G |
| `GroundCrewBrain` | `ai/ground/ground_crew_brain.gd` | `extends Controller`, `Command` (8 Befehle), `COMMAND_LABELS`, `Priority`, `PROP_ZONE`, `LOD_RANGE`, `command(cmd, target)`, `compute_crew_intent` | G |
| `Interactable`, `InteractionQuery` | `ground_ops/interaction/` | `marker`, `target`, `actions` `{id, label, hold_s, needs_item}`, `add_action`, `actions_for`; `pick(from, forward, candidates)`, `RANGE` 2,5 m | H |
| `CrewCharacter`, `CrewCamera`, `CrewPlayerController` | `characters/crew/` | `crew_seat`, `carried`, `WALK_SPEED` 1,6, `SPRINT_SPEED` 4,5, `on_entered_seat`/`on_exited_seat`; `Mode {THIRD, EGO}`, `follow()`, `toggle_view()`; `compute_crew_intent`, `view_toggle_requested` | H |
| `GroundVehicle`, `FuelTruck`, `AmmoCart` | `vehicles/ground/` | `driver_seat`, `passenger_seat`, `MAX_SPEED` 35 km/h, `seat_speed`/`seat_on_ground`; `tank: FuelSource` 2.000 l, `HOSE_LENGTH` 12 m; `store: AmmoBunker`, 6 Kisten | H |
| `AirfieldLayout`, `RunwayControl` | `ground_ops/airfield/` | Abstellplätze, Rollweg-Graph (`taxi_nodes`, `taxi_edges`, `hold_node`, `runway_node`, `parking_nodes`), Pisten-Enden, Lager, Bunker, Hangar, Crew-/Fahrzeug-Spawn, `to_scene`, `parking_transform`, `taxi_neighbors`, `make_default`; `request`/`release`/`is_free` | C |
| `AirfieldPhases` | `ai/brain/airfield_phases.gd` | `Phase {PARKED … TAXI_IN}`, `tick(aircraft, intent, dt) -> bool`, `set_phase`, Konstanten 60 %/80 %, 20/135/160 km/h | C |
| `GroundHud` | `ui/ground/ground_hud.gd` | `create(hud)` (wie CombatHud) | HUD |

## 3. Eigentum je Strang (exklusiv)

| Strang | Pakete | Dateien/Ordner |
|---|---|---|
| **G Bodenlogik** | 1, 2, 3, 7a, 7b | `ground_ops/supply/`, `ground_ops/jobs/`, `ground_ops/job_board.gd`, `ground_ops/turnaround.gd`, `ground_ops/data/` (inkl. `.tres`), `ai/ground/`; Tests `tests/suites/ground_ops/`, `tests/suites/ai_ground/` |
| **H Figur und Fahrzeuge** | 4, 5, 6 | `characters/crew/` (ohne `anim/`), `ground_ops/interaction/`, `vehicles/ground/`; Tests `tests/suites/crew/`, `tests/suites/vehicles/` |
| **C KI-Flug** | 8, 9a, 9b, 10 | `ground_ops/airfield/` (inkl. `data/*.tres`), `ai/brain/` (inkl. `airfield_phases.gd`), `world/spawn_manager.gd`, `characters/pilot_record.gd`; Tests `tests/suites/airfield/`, `tests/suites/ai/` |
| **Grafik** | 11, 12a/b | `art/scripts/build_airfield_props.py`, `art/scripts/build_crew.py`, `art/scripts/build_game_aircraft.py` (nur `svc_*`-Marker), `art/models/`, `art/licenses/`, `game/assets/ground/`, `characters/crew/anim/`; Tests `tests/suites/art/` |
| **HUD** | 13 | `ui/ground/`; Tests `tests/suites/ui_ground/` |
| **Integration** | 14 | alle gemeinsamen Dateien (Abschnitt 1), `world/combat_scenario.gd`, `ui/hud.gd`, `project.godot`, F1-Hilfe, `docs/changelog.md`, `game/README.md` |
| **Selbsttest/Build** | 15 | `world/selbsttest.gd`, `tests/suites/export/`, `docs/` (außer diesem Vertrag), Build-Skripte |

Lesen darf jeder Strang alles. Dateien anderer Stränge nutzt er nur über die Schnittstellen aus Abschnitt 2.

## 4. Was Paket 14 noch verdrahten muss (bewusst offen)
- `PlayerSession` in `game.gd` anlegen (`adopt_flight(player)`), `camera_rig`/`hud`/`crew_camera`/`ground_hud` setzen und `flight.exit_on_ground = true` schalten. Für jeden Sitzwechsel ist ein Hauptszenen-Test nötig.
- Der Spieler-Start am Abstellplatz mit `ServiceState.for_start(FIRST)`, danach `AFTER_LOSS`/`AFTER_LANDING` über den SpawnManager (Paket 10 liefert ihn).
- `GroundHud.create(hud)` als einzige Zeile in `hud.gd`, F1-Hilfe je Kontext (`InputBindings.CONTEXT_NAMES`).
- `AIPilotBrain` ruft `AirfieldPhases.tick()` auf (Paket 9 im eigenen Ordner `ai/brain/`), und `combat_scenario.gd` spawnt KI-Maschinen am Boden.
- Alarmstart (Debugtaste, alle 12–15 min), Lager und Fahrzeuge je Platz aus `airfield_layout(i)` anlegen, `[m3]`-Konfig dokumentieren, Versionsanzeige „M3“.
