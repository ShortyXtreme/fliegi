# M2 – Hooks von Agent A (Waffen) für Paket 14

Stand: 01.11.2026 · Branch `m2-waffen` · Pakete 1, 2, 5, 15 fertig. Kein gemeinsamer Hook ist zwingend; alles läuft mit den Vertrags-Aufrufstellen.

## Optional / empfohlen
1. **`tests/test_runner.gd` `_reset_globals()`**: `ProjectileSystem.reset_targets()` aufrufen. Heute entfernt das System ungültige Ziele selbst; der Aufruf macht Tests unabhängig voneinander.
2. **`world/game.gd`**: nichts nötig. Das `ProjectileSystem` legt seinen `HitValidator` selbst an (`HitValidator.current`). Bei Neustart der Welt `projectiles.validator.clear()`.
3. **HUD (Agent D)**: neue Lesefunktionen `weapons.heat_level(group)`, `weapons.is_jammed(group)`, `weapons.weapon_of_group(group)` (Ballistik-Tabelle für Vorhalt), `weapons.ammo()/ammo_max()`.
4. **Effekte (Agent E)**: Signale `ProjectileSystem.spawned(slot)` und `impact(slot, position, velocity, kind, target, zone)`; Lesen über `active_slots()`, `tracer_slots()`, `position(i)`, `prev_position(i)`, `velocity(i)`, `weapon_of(i)`, `shooter_of(i)`, `gun_of(i)`.
5. **Schaden (Agent B)**: Flugzeuge werden erst getroffen, wenn `HitboxSet.intersect_segment()` echte Zonen liefert (Stub gibt `{}`). Treffer rufen `aircraft.damage.apply_hit(zone, damage, shooter, local_point)` nur auf dem Server und nach dem HitValidator. Eigenbeschuss: `hit_confirmed` mit Schaden 0, solange `MatchRules.friendly_fire_damage` aus ist.
6. **Netz (später)**: `FireEvent.to_array()/from_array()` übertragen statt Geschosse; `HitValidator.HitReport.latency` mit der RTT des Peers füllen.

## Hinweise
- Die Kollisionsmaske `Layers.MASK_PROJECTILE_RAY` trifft in der TestWorld den Physik-Boden (Einschlag „WORLD“ statt „GROUND“). Das ist gewollt, solange es keinen Gelände-Provider gibt.
- Boden-/Gebäudeziele ohne `entity_id` bekommen über `ProjectileSystem.id_of()` eine feste negative Ersatz-ID.
