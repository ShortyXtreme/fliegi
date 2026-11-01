# M2 – fehlende Hooks / Wünsche von Agent C (KI)

Stand: Pakete 7 und 8 (Branch `m2-ki`). Nur Notizen – keine fremden Dateien geändert.

1. **Ziel-ID veraltet (ProjectileSystem):** `Aircraft.create()` meldet das Flugzeug über
   `WeaponSystem._init` mit der automatisch vergebenen `entity_id` an. Wird `entity_id`
   danach geändert (Tests, Netz, Respawn), behält `Target.id` den alten Wert – die
   Eigenschuss-Ausnahme (`tid == owner_id`) trifft dann das *falsche* Flugzeug, und der
   Gegner wird nie getroffen. Wunsch: `register_target()` aktualisiert `t.id` bei
   bereits bekanntem Node, oder `step()` liest `id_of(node)` je Tick.
   Ersatz in den KI-Tests: `unregister_target` + `register_target` nach dem Setzen.
2. **Hitboxen:** `HitboxSet.intersect_segment` ist Stub (trifft nie). Die KI-Tests nutzen
   `ProxyHitboxes` (Rumpf + Flügel aus `AircraftData`) in `tests/suites/ai/duel_util.gd`.
   Nach Integration von Agent B: Ersatz entfernen, `test_duel_real_kills` läuft dann
   statt „SKIP“ (Bedingung: `DamageModel` meldet `destroyed`).
3. **Treibstoff:** Rückzug bei knappem Treibstoff braucht einen Wert, z. B.
   `FlightTelemetry.fuel_fraction` (0..1). Bis dahin: Rückzug nur bei Schaden/Munition.
4. **Schadenszustand kompakt:** Die KI liest `damage.hp_fraction(zone)` aller Zonen.
   Wunsch: `DamageModel.health_fraction()` bzw. `is_critical()` für Rückzugsentscheidung.
5. **Integration (Paket 14):** `AIPilotBrain` setzt `patrol_center` (Standard: Position bei
   Übernahme), `patrol_altitude` (1.500 m), `home`; Schwierigkeit über
   `AIDifficulty.load_level("rekrut"|"erfahren"|"veteran")`. Die KI nutzt Arcade nur,
   wenn `Aircraft.allowed_assist_modes` es erlaubt.

## Messstand Paket 8 (Ersatz-Trefferzähler, Abschuss ab 20 Treffern)

| Serie | Ersatz-Abschüsse | Feuerfenster/Flugzeug | Zielfehler beim Feuern | Treffer/Schuss | Bodenkoll. |
|---|---|---|---|---|---|
| Flach, Erfahren vs. Erfahren | 1/10 | 7,8 s | 43 mrad | 4,0 % | 0 % |
| Hügel, Erfahren vs. Erfahren | 1/10 | 6,2 s | 43 mrad | 4,0 % | 0 % |
| Veteran vs. Rekrut | 3 : 0 | – | – | – | 0 % |

Log-Hash bei gleichem Seed identisch. **Offen:** Die Abnahme 6 (≥ 8/10 Abschüsse,
Veteran ≥ 7/10) ist noch NICHT erreicht. Engpass ist das Nachführen in Kurvenkämpfen
(gleich starke Flugzeuge, Abriss-Schutz begrenzt die Last). Nächste Schritte: Taktik nach
dem Vorbeiflug (Kurve in die richtige Richtung, High Yo-Yo), schärfere Feuerdisziplin, neu
messen mit echten Hitboxen und Schadensmodell (Agent B).
