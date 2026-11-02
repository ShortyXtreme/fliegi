# M3 Hooks Strang G (Bodenlogik) – für Paket 14 und die Stränge H und C

Stand: 01.11.2026 · Branch `m3-g` · Pakete 1, 2, 3, 7a und 7b fertig (m3-h mit Paket 6 eingemergt)

## Gemeinsame Dateien (nicht geändert, Vorschlag für Paket 14)
1. `core/ground_events.gd`: `depot_changed(depot: Node)`. Die Lager (`FuelSource`, `FuelDepot`, `AmmoBunker`) sind RefCounted. Das Senden klappt, weil Signale den Typ nicht prüfen, aber ein typisierter Empfänger `func(d: Node)` scheitert. Vorschlag: den Parameter auf `Object` ändern.
2. `AmmoBunker.AMMO_792` ist jetzt `&"7.92mm"` (wie `WeaponDef.ammo_type`). Vorher stand dort `&"7.92"`, und damit lud der Bunker keine MGs.
3. **Änderung in H-Hoheit (freigegeben vom Projektmanager):** `vehicles/ground/ammo_cart.gd` hat jetzt `const AMMO := AmmoBunker.AMMO_792` statt `&"7.92"`. Sonst lieferte `take_crate()` 0 Schuss (Test `test_ammo_cart_crates` war rot). Weitere Stellen mit "7.92" ohne "mm" gibt es nicht.

## Paket 14 (Integration)
- `JobBoard` als Kind von Game anlegen (`rules = GroundRules.for_realism()`, nach `MatchRules.load_ground_config`).
- Je Platz einen `GroundCrewDispatch` anlegen: `board`, `depot = FuelDepot.new()`, `store = AmmoBunker.new()`, `setup_from_layout(TerrainWorld.airfield_layout(i))`, `watch_root = Game`, `player_aircraft = [Spieler-Maschine]`. Das Signal `announced(text, a)` geht an die HUD-Meldung („Blau 1 gelandet“).
- Je KI-Mechaniker: `CrewCharacter` + `GroundCrewBrain` (`dispatch`, `board`), `crew_seat.possess(brain)`. `GroundCrewBrain.player_probe` soll die Spielerpositionen liefern (für die Sim-LOD), sonst gilt die aktive Kamera.
- `Turnaround`: `start(a)` beim Aussteigen am Abstellplatz, `tick(dt)` je Frame (`board` setzen, `realism`), Anzeige über `elapsed`, `last_stars`, `best_time()`. Alarm: `start_alarm(180, a, depot, store)` (Debugtaste, alle 12–15 min), Countdown über `alarm_left`.
- Lagerleiste: `FuelDepot.available(grade)`, `AmmoBunker.available(AMMO_792)`, Signal `changed`.

## Strang H (Figur, Fahrzeuge)
- Die Interaktion ruft `JobBoard.current.request_step(peer, job.id, job.current_step(), dt)`. Vorher einmal `claim(peer, id, figur)`. Wo die Figur stehen muss, liefert `job.point(step, rules)` (ServiceMarkers-Name). Die Hinweistexte kommen aus `GroundJob.block_text(reason)`.
- Kiste: Nach dem Schritt `crate` liegen die Schuss in `RearmJob.crate` (AmmoBunker). Bitte als `CarryItem.store` verwenden.
- Reparatur in Authentisch: `RepairJob.has_toolbox()` prüft `figur.carried.kind == &"tool"`.
- Tankwagen: Bitte `RefuelJob.source = truck.tank` und `source_node = truck` setzen. Der Schritt „bring“ gilt dann erst, wenn der Wagen ≤ Schlauchlänge + 2 m vom Tankdeckel entfernt steht. FuelHose ankoppeln/abkoppeln = Schritte `attach`/`detach`.

## Strang C (KI-Flug)
- `AirfieldPhases` soll erst dann Gas geben, wenn `GroundCrewBrain.zone_clear(a)` gilt. Im PARKED-Zustand bleibt das Gas auf 0, sonst gilt der Propeller als drehend (`prop_danger`), und das Personal arbeitet nicht.
- Die Mindestmengen für den Start (60 %/80 %) liest die Phase selbst. Die Abfertigung legt der Dispatch automatisch an.

## Paket 7b (fertig): Befehlsrad und Fahrzeuge
- Befehlsrad-API: `GroundCrewBrain.wheel_entries()` liefert `[{id, label}]` mit 8 Befehlen. `GroundCrewBrain.issue(cmd, target, crew=[])` gibt Job-Befehle an alle, „Tankwagen zu mir“ und „Folgen“ an die nächste Figur. `brain.command(cmd, target)` gilt nur auf dem Server. `FULL_SERVICE` mit `null` schaltet zurück auf Automatik.
- Paket 14: `dispatch.fuel_truck = FuelTruck` und `dispatch.ammo_cart = AmmoCart` des Platzes setzen, außerdem `truck.depot = dispatch.depot` und `depot.position` (macht `setup_from_layout`). Tankjobs nehmen dann aus `truck.tank`. Die KI geht zum Wagen, steigt über `SeatService` ein, fährt ihn auf ~7 m an den Tankdeckel, steigt aus und koppelt den Schlauch an (`RefuelJob` ruft `hose.couple/uncouple`). In Authentisch befüllt sie den Wagen vorher am Lager mit `FuelTruck.fill_from`. Den Munitionswagen fährt sie heran, wenn er weiter als 15 m weg steht. Munition entnimmt sie direkt aus `cart.store`; die KI trägt dabei keinen `CarryItem`.
- Ohne `SeatService.current` steigt die KI direkt per `possess` ein und aus (Ersatz).

## Offen
- „Wagen nachfüllen“ als eigener Job (Priorität `REFILL_VEHICLE`) fehlt. Ein leerer Tankwagen blockiert den Job mit „Lager leer“, nur in Authentisch füllt die KI ihn im Zuge des Tankjobs auf.
- Ein Funkenbrand (Authentisch, Erden vergessen) meldet nur `job_blocked(id, &"spark_fire")` und hat noch keine Brandwirkung (Feuerlöschen ist laut Plan §7 außerhalb).
- Die KI fährt auf direktem Weg ohne Rollweg-Graph und weicht Flugzeugen nicht aus (in Tests unauffällig).

## Hinweise
- Der Motor verbraucht auch im Leerlauf am Abstellplatz Treibstoff. Darum tankt der Dispatch erst ab 3 % Lücke nach (`TOP_UP_MARGIN`).
- Gesamtzeiten im Sim-LOD (Test `test_turnaround_totals`, Personal sprintet ab 25 m): Einfach 22/14 s, Standard 128/84 s, Authentisch 248/131 s (solo/2 Helfer). Alle liegen unter den Richtzeiten aus §2, also ist Abnahme 1 erfüllt. Die Schrittzeiten stimmen auf ±10 % (`test_times_per_stage`). Zum Feintuning: `ground_rules_*.tres` (Abschnitt „Sim-LOD Wege“).
