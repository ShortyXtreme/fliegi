# M3 – Hooks und Hinweise aus Strang H (Pakete 4–6) für Paket 14

Strang H hat keine gemeinsamen Dateien geändert. Für die Integration offen:

1. **Figur anlegen:** `CrewCharacter` (Crew-Spawn aus `AirfieldLayout`) erzeugen, `session.take_seat(ch.crew_seat)`. `session.crew_camera = CrewCamera.new()` in die Szene hängen; `apply_view` ruft `follow()` (Third/Ego-Umschalten verbindet die Kamera selbst mit `CrewCharacter.view_toggle_requested` bzw. `DrivePlayerController.camera_next_requested`).
2. **Maus einfangen im Kontext CREW:** `CrewPlayerController` liest Mausbewegung nur bei `MOUSE_MODE_CAPTURED`. `PlayerSession`/`game.gd` muss beim Wechsel nach CREW/DRIVE die Maus einfangen.
3. **Interaktionspunkte am Flugzeug:** `InteractionPoints.for_aircraft(a)` legt `svc_fuel_cap`, `svc_gun_hatch_L/R`, `svc_engine` (ohne Aktionen, die hängt Strang G per `add_action` + Signale `holding`/`performed` an) und einen Einstiegspunkt mit `seat = pilot_seat` an. Ohne diesen Aufruf findet F (`try_enter`) kein Flugzeug.
4. **Fahrzeuge anlegen:** `FuelTruck.create(liter, sorte)` (Authentisch: 0 l), `AmmoCart.new()`, je `place(pos, yaw)`; `truck.depot = FuelDepot` des Platzes setzen (Befüllen an der Trommel). `AmmoCart.realism`/`CarryItem.apply_realism` für die 25-kg-Kiste aus `MatchRules.ground_realism` setzen.
5. **Rückwärtsfahren:** `DrivePlayerController` mischt die Handbremse in `brakes`; das Fahrmodell fährt nach 0,4 s Bremse im Stand rückwärts – also auch mit gehaltener Handbremse. Vorschlag: eigenes Rückwärts-Bit im `PilotIntent` oder Handbremse getrennt melden.
6. **RefuelJob (Strang G):** Quelle `truck.tank` (`TruckTank`, eine Sorte zugleich, `grade()`), Ankoppeln `truck.hose.couple(aircraft, ServiceMarkers.aircraft_point(a, "svc_fuel_cap"))`, Abkoppeln `uncouple()`, Signal `overstretched` (Wagen fährt weg). Getragenes Schlauchende: `character.carried == truck.hose.end_item`.
7. **RearmJob (Strang G):** Kiste = `CarryItem` mit `store` (eigener `AmmoBunker`, ≤ 500 Schuss) als `store` für `load_gun`; Rest mit `AmmoCart.return_crate()` zurück.
8. **Tankwagen befüllen** läuft direkt über `FuelTruck.fill_from()` (Server-Prüfung, Mengen-Erhalt). Soll das über den `JobBoard` laufen, braucht G einen Job „Wagen nachfüllen“, der `fill_from` aufruft.
9. **Animationen (Paket 12):** `CrewCharacter.anim_tree` setzen (StateMachine unter `parameters/playback` mit den Zuständen `idle, walk, run, carry, hose, work, enter`, optional `parameters/speed`). Modelle: `GroundVehicle.apply_model(node)` übernimmt Marker aus leeren Knoten.
