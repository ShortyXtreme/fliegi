class_name DamageProfile
extends Resource
## Schadensprofil eines Flugzeugtyps (Paket 4). Alle Kampfwerte in der .tres (Plan §3).
## Reihenfolge der HP wie DamageModel.Zone: engine, fuel_tank_L, fuel_tank_R, wing_L,
## wing_R, tail, cockpit.

@export var hp: PackedFloat32Array = [120.0, 80.0, 80.0, 200.0, 200.0, 120.0, 100.0]

@export_group("Motor")
## Unter dieser HP-Quote: leichte Leistungseinbuße, Ölspur, Festfress-Timer.
@export var engine_light_below := 0.7
@export var engine_light_power := 0.85
@export var engine_seize_time := 90.0
## Unter dieser HP-Quote: starke Leistungseinbuße und Brandrisiko je Treffer.
@export var engine_heavy_below := 0.3
@export var engine_heavy_power := 0.5
@export var engine_fire_chance := 0.1

@export_group("Tanks")
@export var tank_capacity_l := 180.0
## Leckrate (l/s) bei 0 HP, proportional zum Schaden.
@export var leak_max_lps := 1.5
@export var tank_fire_chance := 0.08
## Verbrauch bei Vollgas (l/s) und im Leerlauf.
@export var burn_full_lps := 0.09
@export var burn_idle_lps := 0.01

@export_group("Flügel")
## Auftriebsverlust der Flügelflächen bei 0 HP (vor dem Bruch), linear.
@export var wing_lift_loss := 0.35
@export var wing_drag_max := 0.02
## Ab dieser HP-Quote fällt das Querruder des Flügels aus.
@export var aileron_off_below := 0.5
## Flügelbruch: Auftrieb der äußeren Flächen bzw. der Wurzel.
@export var broken_outer_lift := 0.0
@export var broken_root_lift := 0.4

@export_group("Leitwerk")
## Ruderwirksamkeit bei 0 HP.
@export var tail_control_min := 0.3
## Gesamtschaden (Summe aller Zonen), ab dem die Zelle zerbricht (Paket 14: TTK 15–40
## Treffer auch bei verteilten Treffern; 10 Schaden je MG-Treffer).
@export var structure_hp := 320.0
## Chance je Treffer (× Schadensquote), dass ein Ruder klemmt.
@export var tail_stuck_chance := 0.25
## Unter dieser HP-Quote gilt das Leitwerk als kritisch (Notausstieg erlaubt).
@export var tail_critical_below := 0.3

@export_group("Cockpit")
@export var wounded_below := 0.6
@export var wound_input_mul := 0.7
@export var wound_noise := 0.15

@export_group("Brand")
@export var fire_dps := 4.0
@export var fire_spread_time := 10.0
@export var fire_extinguish_speed_kmh := 450.0
@export var fire_extinguish_rate := 0.15

@export_group("Sonstiges")
## Zusätzliche Widerstandsfläche Cd·A (m²) je voll zerstörter Zone (Einschusslöcher).
@export var hole_drag_area := 0.015
## Bauchlandung: höchstens diese Fahrt (m/s), Sinkrate (m/s) und Querlage (Grad).
@export var belly_max_speed := 50.0
@export var belly_max_sink := 6.0
@export var belly_max_bank_deg := 20.0
## Unter dieser Fahrt (m/s) zählen Berührungen nicht als Aufprall.
@export var impact_ignore_speed := 8.0
## Unter dieser Höhe (m über Grund) überlebt der Pilot den Ausstieg nicht.
@export var eject_min_agl := 30.0


static func load_for(d: Resource) -> DamageProfile:
	if d != null:
		var p = d.get("damage_profile_path")
		if p is String and not p.is_empty() and ResourceLoader.exists(p):
			var r = load(p)
			if r is DamageProfile:
				return r
	return DamageProfile.new()
