class_name RearmJob
extends GroundJob
## M3 (Strang G / Paket 2): Munition je Waffe: Kiste, Klappe auf, Gurt, Klappe zu
## (Authentisch zusätzlich Durchladen im Cockpit). Die Kiste reserviert die Schuss aus dem
## Vorrat (store); der Gurt lädt über WeaponSystem.load_gun(i, crate, n). Reste gehen zurück.

var gun_index := 0
## AmmoBunker oder Vorrat des AmmoCart.
var store: AmmoStore = null
## Getragene Kiste (eigener kleiner Vorrat).
var crate: AmmoBunker = null
var loaded := 0
var ammo_type: StringName = AmmoBunker.AMMO_792


func _init() -> void:
	kind = &"rearm"
	steps.assign([&"crate", &"hatch_open", &"belt", &"hatch_close"])


## Steps je Stufe (Authentisch: Durchladen). Vom JobBoard beim Anlegen gerufen.
func configure(r: GroundRules) -> void:
	if r.charge_in_cockpit and not steps.has(&"charge"):
		steps.append(&"charge")


func duration(s: StringName, r: GroundRules) -> float:
	match s:
		&"crate": return r.gun_at_cart_s if r.gun_at_cart_s > 0.0 else r.crate_pick_s
		&"hatch_open", &"hatch_close": return r.hatch_s
		&"belt": return r.belt_s
		&"charge": return r.charge_s
	return 0.0


func point(s: StringName, r: GroundRules) -> String:
	if s in [&"hatch_open", &"belt", &"hatch_close"] and duration(s, r) > 0.0:
		return ServiceMarkers.SVC_GUN_HATCH_L if gun_index % 2 == 0 else ServiceMarkers.SVC_GUN_HATCH_R
	if s == &"charge" and duration(s, r) > 0.0:
		return ServiceMarkers.SVC_ENTRY
	return ""


func rounds_needed() -> int:
	var a := aircraft()
	if a == null:
		return 0
	return maxi(a.weapons.gun_capacity(gun_index) - a.weapons.gun_ammo(gun_index), 0)


func _begin_step(s: StringName, _r: GroundRules) -> bool:
	if s == &"crate":
		var a := aircraft()
		if a == null:
			block(&"no_target")
			return false
		if gun_index < a.weapons.magazines.size():
			ammo_type = a.weapons.magazines[gun_index].ammo_type
		if store == null or store.available(ammo_type) <= 0:
			block(&"store_empty")
			return false
	return true


func _finish_step(s: StringName, r: GroundRules) -> bool:
	match s:
		&"crate":
			var n := store.request(ammo_type, rounds_needed())
			crate = AmmoBunker.new({ammo_type: n})
			crate.label = "Kiste"
			if r.gun_at_cart_s > 0.0:      # Vereinfacht: direkt am Wagen geladen
				_load()
		&"belt":
			_load()
	return true


func _load() -> void:
	var a := aircraft()
	if a == null or crate == null:
		return
	loaded += a.weapons.load_gun(gun_index, crate, crate.available(ammo_type))


func recheck(_r: GroundRules) -> void:
	if blocked_reason == &"store_empty" and store != null and store.available(ammo_type) > 0:
		blocked_reason = &""
	elif blocked_reason == &"no_target" and aircraft() != null:
		blocked_reason = &""


func cleanup() -> void:
	if crate != null and store != null and crate.available(ammo_type) > 0:
		var rest := crate.available(ammo_type)
		crate.request(ammo_type, rest)
		store.give_back(ammo_type, rest)
