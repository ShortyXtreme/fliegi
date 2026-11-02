class_name RefuelJob
extends GroundJob
## M3 (Strang G / Paket 2): Tanken. Schritte bringen, erden, ankoppeln, pumpen, abkoppeln.
## Nimmt aus FuelSource.draw(grade, l) (Tankwagen oder Lager) und gibt an FuelSystem.add(l, grade)
## bzw. an eine andere FuelSource (Tankwagen am Lager befüllen, target = Fahrzeug mit tank).
## Pumpen läuft nach dem Ankoppeln selbsttätig (JobBoard.tick); in Authentisch stoppt es nicht von
## selbst: wer nicht beobachtet und abkoppelt, lässt überlaufen (spilled, Brandgefahr).

## Quelle (FuelDepot oder Tank des FuelTruck) und Sorte.
var source: FuelSource = null
var grade: StringName = FuelSystem.GRADE_AVIATION
## Ersatz nehmen, wenn die gewünschte Sorte leer ist.
var allow_fallback := true
## Ziel-Füllstand 0..1 (Befehl „Schnellabfertigung“: 0,5).
var target_fraction := 1.0
## Optional: Knoten der Quelle (Tankwagen) für die Schlauchreichweite im Schritt „bring“.
var source_node: Node3D = null
## Optional: Ziel ist eine FuelSource (Wagen am Lager befüllen) statt eines Flugzeugtanks.
var dest_source: FuelSource = null
var pumped := 0.0
var spilled := 0.0
var grounded := false
var spark_fire := false
## Deterministisches Würfeln (Funkenbrand) je Job.
var rng_seed := 0


func _init() -> void:
	kind = &"refuel"
	steps.assign([&"bring", &"ground", &"attach", &"pump", &"detach"])


func duration(s: StringName, r: GroundRules) -> float:
	match s:
		&"ground": return r.grounding_s
		&"attach": return r.hose_attach_s + (r.cap_valve_s if r.cap_and_valve else 0.0)
		&"detach": return r.hose_detach_s + (r.cap_valve_s * 0.5 if r.cap_and_valve else 0.0)
		&"pump": return liters_needed() / maxf(_rate(r), 0.01)
	return 0.0


func point(s: StringName, r: GroundRules) -> String:
	if dest_source != null:
		return ""
	if s in [&"ground", &"attach", &"detach"] and duration(s, r) > 0.0:
		return ServiceMarkers.SVC_FUEL_CAP
	return ""


func autonomous(s: StringName, _r: GroundRules) -> bool:
	return s == &"pump"


func can_skip(s: StringName, r: GroundRules) -> bool:
	return s == &"pump" or (s == &"ground" and r.grounding_s > 0.0)


## Liter bis zum Ziel-Füllstand.
func liters_needed() -> float:
	if dest_source != null:
		return maxf(dest_source.capacity(grade) * target_fraction - dest_source.available(grade), 0.0)
	var a := aircraft()
	if a == null:
		return 0.0
	var f := a.damage.fuel
	var cap := f.capacity[0] + f.capacity[1]
	return maxf(cap * target_fraction - f.total(), 0.0)


func fill_reached() -> bool:
	return liters_needed() <= 0.01


func source_in_reach(r: GroundRules) -> bool:
	if dest_source != null:
		# Paket 14 „Wagen nachfüllen“: Wagen (target) muss am Lager stehen.
		return target == null or not target.has_method("in_fill_range") or bool(target.call("in_fill_range", source))
	if r.truck_at_spot or source_node == null:
		return true
	var a := aircraft()
	if a == null:
		return true
	var cap := a.service_point(ServiceMarkers.SVC_FUEL_CAP)
	return source_node.global_position.distance_to(cap) <= r.hose_length + 2.0


func _begin_step(s: StringName, r: GroundRules) -> bool:
	match s:
		&"bring":
			if source == null:
				block(&"depot_empty")
				return false
			if not source_in_reach(r):
				return false
			var g := source.pick_grade(grade, allow_fallback)
			if g == &"":
				block(&"depot_empty")
				return false
			grade = g
		&"ground":
			grounded = true
		&"pump":
			if not grounded and r.spark_fire_chance > 0.0:
				var rng := RandomNumberGenerator.new()
				rng.seed = hash([rng_seed, id])
				if rng.randf() < r.spark_fire_chance:
					spark_fire = true
					GroundEvents.bus().job_blocked.emit(id, &"spark_fire")
	return true


func _finish_step(s: StringName, r: GroundRules) -> bool:
	match s:
		&"attach": _couple_hose()
		&"detach": _uncouple_hose()
		&"pump": return fill_reached() and not r.pump_watch
	return true


## Schlauch des Tankwagens (FuelTruck.hose, Strang H) am Tankdeckel an-/abkoppeln.
func hose() -> Object:
	if source_node == null or not is_instance_valid(source_node):
		return null
	var h = source_node.get("hose")
	return h if h is Object and h.has_method("couple") else null


func _couple_hose() -> void:
	var h := hose()
	var a := aircraft()
	if h != null and a != null and not h.is_coupled():
		h.couple(a, ServiceMarkers.aircraft_point(a, ServiceMarkers.SVC_FUEL_CAP))


func _uncouple_hose() -> void:
	var h := hose()
	if h != null and h.is_coupled() and h.coupled_to == aircraft():
		h.uncouple()


func cleanup() -> void:
	_uncouple_hose()


## Pumpen um dt Sekunden (autonom, vom JobBoard). Rückgabe: true = Schritt fertig.
func pump(dt: float, r: GroundRules) -> bool:
	if current_step() != &"pump" or blocked_reason != &"" or source == null:
		return false
	var want := _rate(r) * dt
	var need := liters_needed()
	var got := 0.0
	if dest_source != null:
		got = source.transfer_to_source(dest_source, grade, minf(want, need))
	else:
		var a := aircraft()
		if a == null:
			block(&"no_target")
			return false
		got = source.transfer_to_tank(a.damage.fuel, grade, minf(want, need))
		if r.pump_watch and need <= 0.01:
			# Überlauf: was weiter gepumpt wird, läuft daneben (gezählt, Mengen-Erhalt).
			var over := source.draw(grade, want)
			spilled += over
	pumped += got
	elapsed += dt
	var total := maxf(pumped + liters_needed(), 0.01)
	progress = clampf(pumped / total, 0.0, 1.0)
	if source.is_empty(grade) and not fill_reached():
		var g := source.pick_grade(grade, allow_fallback)
		if g == &"":
			GroundEvents.bus().job_blocked.emit(id, &"depot_empty")
			return true   # Rest fehlt: weiter zum Abkoppeln, Hinweis gemeldet
		grade = g
	return fill_reached() and not r.pump_watch


## Pumprate: Flugzeug pump_lps, Wagen am Lager befüllen truck_fill_lps.
func _rate(r: GroundRules) -> float:
	return r.truck_fill_lps if dest_source != null else r.pump_lps


func recheck(r: GroundRules) -> void:
	if blocked_reason == &"depot_empty" and source != null and source.pick_grade(grade, allow_fallback) != &"":
		blocked_reason = &""
	elif blocked_reason == &"no_target" and aircraft() != null:
		blocked_reason = &""
	if r == null:
		return
