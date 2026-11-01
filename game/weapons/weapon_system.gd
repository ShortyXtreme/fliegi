class_name WeaponSystem
extends RefCounted
## Bordwaffen eines Flugzeugs (Plan M2 §2, Paket 2).
## Aufrufstellen in aircraft.gd (fest):
##   _init(aircraft)          beim Bau, nach FlightModel/DamageModel
##   tick(intent, dt)         jeden Physik-Tick (nach DamageModel.filter_intent), nur Server feuert
##   reset()                  in Aircraft.place() (Neustart: Magazine voll)
## Bewaffnung aus AircraftData.loadout_path (WeaponLoadout). Je Waffe ein AmmoMagazine und ein
## Kadenz-Zähler. Geschosse gehen an ProjectileSystem.current; Abzugsphasen werden als
## FireEvent mitgeschrieben (Netzmodell/HitValidator, Paket 5).

enum Group { PRIMARY, SECONDARY }

signal fired(gun_index: int, shot_id: int)
signal trigger_changed(group: int, pressed: bool)

var aircraft: Node3D
## Geladene Bewaffnung (WeaponLoadout aus loadout_path) oder null.
var loadout: Resource = null
## Konvergenzentfernung der Flügelwaffen (m), Plan §2. Setzen über set_convergence().
var convergence := 250.0
var trigger := [false, false]
## Fortlaufende Schussnummer (Seed für Streuung: hash(shooter, gun, shot)).
var shot_counter := 0
## Je Waffe: Magazin, Restzeit bis zum nächsten Schuss (s), justierte Richtung (lokal).
var magazines: Array[AmmoMagazine] = []
var cooldown := PackedFloat32Array()
## Je Waffe Hitze/Ladehemmung (Paket 15; ohne heat_per_shot wirkungslos).
var heat: Array[Heat] = []
var aim_dirs := PackedVector3Array()
## Abzugsphasen (neueste zuletzt, max. MAX_EVENTS), offene Phase hat tick_off = -1.
var fire_events: Array[FireEvent] = []

const MAX_EVENTS := 64


func _init(a: Node3D) -> void:
	aircraft = a
	var d = a.get("data")
	if d != null and d.get("loadout_path") is String and d.loadout_path != "" \
			and ResourceLoader.exists(d.loadout_path):
		loadout = load(d.loadout_path)
	set_loadout(loadout)
	ProjectileSystem.register_target(a)


## Bewaffnung setzen (auch für Tests/andere Typen).
func set_loadout(lo: Resource) -> void:
	loadout = lo
	magazines.clear()
	heat.clear()
	var lw := lo as WeaponLoadout
	if lw != null:
		convergence = lw.convergence
		for m in lw.mounts:
			var t: StringName = m.weapon.ammo_type if m.weapon != null else &""
			magazines.append(AmmoMagazine.new(t, m.ammo))
			heat.append(Heat.new(m.weapon))
	cooldown.resize(magazines.size())
	cooldown.fill(0.0)
	set_convergence(convergence)


func set_convergence(dist: float) -> void:
	convergence = dist
	var lw := loadout as WeaponLoadout
	aim_dirs = lw.aim_directions(dist) if lw != null else PackedVector3Array()


## refill = false (M3): Magazine behalten ihren Inhalt (Restzustand nach Landung).
func reset(refill: bool = true) -> void:
	trigger = [false, false]
	cooldown.fill(0.0)
	for m in magazines:
		if refill:
			m.fill()
	for h in heat:
		h.reset()
	_close_events(-1)


func mounts() -> Array:
	var lw := loadout as WeaponLoadout
	return lw.mounts if lw != null else []


func tick(intent: PilotIntent, dt: float) -> void:
	_set_trigger(Group.PRIMARY, intent.fire_primary)
	_set_trigger(Group.SECONDARY, intent.fire_secondary)
	var ms := mounts()
	if ms.is_empty():
		return
	var server := Authority.is_server()
	for gi in ms.size():
		var m: GunMountDef = ms[gi]
		var c := cooldown[gi] - dt
		var h := heat[gi]
		h.cool(dt)
		if trigger[m.group] and server and m.weapon != null:
			var interval := m.weapon.shot_interval()
			while c <= 0.0 and not magazines[gi].is_empty() and h.can_fire():
				_fire(gi, m, -c)
				c += interval
		cooldown[gi] = maxf(c, 0.0)


## Ein Schuss. late = so viel s liegt der Schuss schon zurück (Kadenz > Tickrate).
func _fire(gi: int, m: GunMountDef, late: float) -> void:
	magazines[gi].take(1)
	var shot_id := shot_counter
	shot_counter += 1
	heat[gi].on_shot(ProjectileSystem.id_of(aircraft), gi, shot_id)
	var xf := aircraft.global_transform
	var base_v: Vector3 = aircraft.get("linear_velocity") if aircraft is RigidBody3D else Vector3.ZERO
	var w := m.weapon
	var sigma := w.dispersion_mrad * 0.001
	var p = aircraft.get("pilot")
	if p != null and p.has_method("dispersion_mul"):
		sigma *= p.dispersion_mul()
	var dir := xf.basis * aim_dirs[gi]
	dir = Ballistics.disperse(dir.normalized(), sigma, ProjectileSystem.id_of(aircraft), gi, shot_id)
	var pos := xf * m.position
	var vel := dir * w.muzzle_velocity + base_v
	pos += vel * late
	var ps := ProjectileSystem.current
	if ps != null:
		ps.spawn(aircraft, gi, shot_id, pos, vel, w)
	fired.emit(gi, shot_id)
	CombatEvents.bus().shot_fired.emit(aircraft, gi, shot_id)


func _set_trigger(g: int, pressed: bool) -> void:
	if trigger[g] == pressed:
		return
	trigger[g] = pressed
	trigger_changed.emit(g, pressed)
	var tick := Engine.get_physics_frames()
	if pressed:
		var e := FireEvent.new()
		e.shooter_id = ProjectileSystem.id_of(aircraft)
		e.gun_group = g
		e.tick_on = tick
		e.shot_first = shot_counter
		fire_events.append(e)
		if fire_events.size() > MAX_EVENTS:
			fire_events.remove_at(0)
	else:
		_close_events(g, tick)


func _close_events(g: int, tick := -1) -> void:
	if tick < 0:
		tick = Engine.get_physics_frames()
	for e in fire_events:
		if e.tick_off < 0 and (g < 0 or e.gun_group == g):
			e.tick_off = tick


## Abzugsphase, in der der Tick liegt (oder null).
func fire_event_at(group: int, tick: int) -> FireEvent:
	for i in range(fire_events.size() - 1, -1, -1):
		var e := fire_events[i]
		if e.gun_group == group and e.contains(tick):
			return e
	return null


func has_weapons(group: int = Group.PRIMARY) -> bool:
	for m in mounts():
		if m.group == group and m.weapon != null:
			return true
	return false


func gun_count() -> int:
	return mounts().size()


func ammo(group: int = Group.PRIMARY) -> int:
	var n := 0
	var ms := mounts()
	for i in ms.size():
		if ms[i].group == group:
			n += magazines[i].count
	return n


func ammo_max(group: int = Group.PRIMARY) -> int:
	var n := 0
	var ms := mounts()
	for i in ms.size():
		if ms[i].group == group:
			n += magazines[i].capacity
	return n


## Mündungsgeschwindigkeit der Gruppe (m/s), für Vorhalt (HUD/KI).
func muzzle_velocity(group: int = Group.PRIMARY) -> float:
	var w := weapon_of_group(group)
	return w.muzzle_velocity if w != null else 800.0


## Erste Waffe der Gruppe (für Ballistik-Tabellen in HUD/KI) oder null.
func weapon_of_group(group: int = Group.PRIMARY) -> WeaponDef:
	for m in mounts():
		if m.group == group and m.weapon != null:
			return m.weapon
	return null


## Nachladen am Platz (M2: InfiniteAmmoStore). store: request(type, n) -> int.
## Rückgabe: nachgeladene Schuss gesamt.
func rearm(store: Object) -> int:
	var n := 0
	for m in magazines:
		n += m.refill(store)
	return n


## M3 (Paket 0b): Gurt in Waffe i einlegen (RearmJob, nur Server). Holt bis zu n Schuss
## (höchstens bis zur Kapazität) aus store (AmmoStore: request/available).
## Rückgabe: geladene Schuss.
func load_gun(i: int, store: Object, n: int) -> int:
	if not Authority.is_server() or i < 0 or i >= magazines.size() or store == null or n <= 0:
		return 0
	var m := magazines[i]
	var need := mini(m.capacity - m.count, n)
	if need <= 0 or not store.has_method("request"):
		return 0
	var got := clampi(int(store.request(m.ammo_type, need)), 0, need)
	m.count += got
	return got


## M3: Füllstand aller Waffen direkt setzen (ServiceState beim Spawn), f 0..1.
func set_ammo_fraction(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	for m in magazines:
		m.count = int(round(m.capacity * f))


## M3: Munition und Kapazität einer Waffe (Statuspanel, RearmJob).
func gun_ammo(i: int) -> int:
	return magazines[i].count if i >= 0 and i < magazines.size() else 0


func gun_capacity(i: int) -> int:
	return magazines[i].capacity if i >= 0 and i < magazines.size() else 0


## Hitze der Gruppe (höchster Wert, 1 = heiß) für das HUD.
func heat_level(group: int = Group.PRIMARY) -> float:
	var v := 0.0
	var ms := mounts()
	for i in ms.size():
		if ms[i].group == group:
			v = maxf(v, heat[i].value)
	return v


func is_jammed(group: int = Group.PRIMARY) -> bool:
	var ms := mounts()
	for i in ms.size():
		if ms[i].group == group and heat[i].jammed:
			return true
	return false
