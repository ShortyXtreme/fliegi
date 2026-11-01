class_name GroundRules
extends Resource
## M3 Vertrag (Paket 0b, gehört Strang G / Paket 2): Zeiten und Raten je Realismus-Stufe
## (Plan §2). Die Werte liegen in ground_rules_{einfach,standard,authentisch}.tres (Paket 2);
## fehlt die Datei, gelten die Standardwerte unten (Stufe Standard) bzw. for_realism().

@export var truck_at_spot := false        # Tankwagen steht schon am Abstellplatz
@export var truck_fill_first := false     # Tankwagen vorher am Lager befüllen (Authentisch)
@export var truck_fill_lps := 20.0
@export var grounding_s := 0.0            # Erden (0 = entfällt)
@export var spark_fire_chance := 0.0      # Erden vergessen
@export var hose_carry := true            # Schlauchende tragen
@export var hose_attach_s := 2.0
@export var cap_and_valve := false        # Tankdeckel öffnen, Ventil auf
@export var pump_lps := 6.0
@export var gun_at_cart_s := 0.0          # Vereinfacht: Munition je MG direkt am Wagen
@export var hatch_s := 1.5
@export var belt_s := 5.0
@export var charge_in_cockpit := false    # Durchladen
@export var crate_kg := 0.0
@export var crate_speed_mul := 1.0
@export var repair_hps := 6.0
@export var repair_needs_toolbox := false
@export var ai_work_mul := 0.8            # KI-Grundpersonal relativ zum Spieler
@export var alarm_work_mul := 1.25        # Alarmstart: KI 25 % schneller

const PATH := "res://ground_ops/data/ground_rules_%s.tres"


static func for_realism(r: int = -1) -> GroundRules:
	if r < 0:
		r = MatchRules.ground_realism
	var p := PATH % MatchRules.ground_realism_name(r)
	if ResourceLoader.exists(p):
		return load(p)
	var g := GroundRules.new()
	match r:
		MatchRules.GroundRealism.EINFACH:
			g.truck_at_spot = true
			g.hose_carry = false
			g.hose_attach_s = 1.0
			g.pump_lps = 30.0
			g.gun_at_cart_s = 3.0
			g.hatch_s = 0.0
			g.belt_s = 0.0
			g.repair_hps = 25.0
		MatchRules.GroundRealism.AUTHENTISCH:
			g.truck_fill_first = true
			g.grounding_s = 3.0
			g.spark_fire_chance = 0.05
			g.cap_and_valve = true
			g.pump_lps = 4.0
			g.charge_in_cockpit = true
			g.crate_kg = 25.0
			g.crate_speed_mul = 0.65
			g.repair_hps = 3.0
			g.repair_needs_toolbox = true
	return g
