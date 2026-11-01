class_name GroundRules
extends Resource
## M3 (Strang G / Paket 2): Zeiten und Raten je Realismus-Stufe (Plan §2).
## Die Werte liegen in ground_rules_{einfach,standard,authentisch}.tres; fehlt eine Datei,
## gelten die Werte aus defaults_for(). Zeiten in Sekunden Arbeit für den Spieler (Faktor 1);
## KI-Grundpersonal arbeitet mit ai_work_mul, im Alarm zusätzlich mit alarm_work_mul.

@export var realism := 1                  # MatchRules.GroundRealism
@export_group("Tanken")
@export var truck_at_spot := false        # Tankwagen steht schon am Abstellplatz
@export var truck_fill_first := false     # Tankwagen vorher am Lager befüllen (Authentisch)
@export var truck_fill_lps := 20.0
@export var grounding_s := 0.0            # Erden (0 = entfällt)
@export var spark_fire_chance := 0.0      # Erden vergessen
@export var hose_carry := true            # Schlauchende tragen
@export var hose_length := 12.0
@export var hose_attach_s := 2.0
@export var hose_detach_s := 2.0
@export var cap_and_valve := false        # Tankdeckel öffnen, Ventil auf
@export var cap_valve_s := 0.0
@export var pump_lps := 6.0
@export var pump_watch := false           # Füllstand selbst beobachten, sonst Überlauf
@export var overflow_lps_lost := 1.0      # Anteil, der beim Überlaufen verloren geht
@export_group("Munition")
@export var gun_at_cart_s := 0.0          # Vereinfacht: Munition je MG direkt am Wagen
@export var crate_pick_s := 0.5
@export var hatch_s := 1.5
@export var belt_s := 5.0
@export var charge_in_cockpit := false    # Durchladen
@export var charge_s := 0.0
@export var crate_kg := 0.0
@export var crate_speed_mul := 1.0
@export_group("Reparatur")
@export var repair_hps := 6.0
@export var repair_needs_toolbox := false
@export_group("Personal")
@export var ai_work_mul := 0.8            # KI-Grundpersonal relativ zum Spieler
@export var alarm_work_mul := 1.25        # Alarmstart: KI 25 % schneller
@export var work_range := 3.0             # Abstand Figur–Servicepunkt für Arbeitsschritte
@export_group("Sim-LOD Wege")
@export var walk_speed := 1.6
@export var truck_speed := 7.0
@export var truck_trip_m := 150.0         # Tanklager <-> Abstellplatz
@export var cart_trip_m := 60.0           # Munitionswagen/Bunker <-> Abstellplatz
@export var crate_walk_m := 8.0           # Wagen -> MG-Klappe
@export var hose_walk_m := 12.0
@export var spot_walk_m := 6.0            # zwischen zwei Servicepunkten
@export var mount_s := 3.0                # in den Wagen steigen, anlassen

const PATH := "res://ground_ops/data/ground_rules_%s.tres"


static func for_realism(r: int = -1) -> GroundRules:
	if r < 0:
		r = MatchRules.ground_realism
	var p := PATH % MatchRules.ground_realism_name(r)
	if ResourceLoader.exists(p):
		var res := load(p) as GroundRules
		if res != null:
			return res
	return defaults_for(r)


## Code-Rückfall (und Quelle für ground_ops/data/make_ground_rules.gd). Maßgeblich sind die .tres.
static func defaults_for(r: int) -> GroundRules:
	var g := GroundRules.new()
	g.realism = r
	match r:
		MatchRules.GroundRealism.EINFACH:
			g.truck_at_spot = true
			g.hose_carry = false
			g.hose_attach_s = 1.0
			g.hose_detach_s = 0.0
			g.pump_lps = 30.0
			g.gun_at_cart_s = 3.0
			g.crate_pick_s = 0.0
			g.hatch_s = 0.0
			g.belt_s = 0.0
			g.repair_hps = 25.0
			g.crate_walk_m = 4.0
			g.hose_walk_m = 4.0
		MatchRules.GroundRealism.AUTHENTISCH:
			g.truck_fill_first = true
			g.grounding_s = 3.0
			g.spark_fire_chance = 0.05
			g.cap_and_valve = true
			g.cap_valve_s = 3.0
			g.pump_lps = 4.0
			g.pump_watch = true
			g.charge_in_cockpit = true
			g.charge_s = 2.0
			g.crate_kg = 25.0
			g.crate_speed_mul = 0.65
			g.repair_hps = 3.0
			g.repair_needs_toolbox = true
	return g
