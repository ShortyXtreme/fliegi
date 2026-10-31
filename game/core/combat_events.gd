class_name CombatEvents
extends RefCounted
## Zentraler Ereignis-Bus für Kampf (Vertrag Paket 0 – Signaturen nur in Paket 14 ändern).
## Zugriff: CombatEvents.bus().aircraft_destroyed.connect(...)
## Gesendet wird nur auf dem Server (Authority.is_server()); ab M3 repliziert.
## Parameter sind Nodes (meist Aircraft); für Logs/Netz zählt deren entity_id.
## Optionales Ereignis-Log (log_enabled) für deterministische Regression (Log-Hash).

enum Cause { UNKNOWN, WING_BROKEN, PILOT_KILLED, EJECTED, CRASH, ENGINE, FIRE, FRIENDLY }

## Ein Geschoss wurde erzeugt. gun_index = Index im Loadout, shot_id = eindeutig je Schütze.
signal shot_fired(shooter: Node, gun_index: int, shot_id: int)
## Server hat einen Treffer bestätigt (nach HitValidator). zone = DamageModel.Zone.
signal hit_confirmed(shooter: Node, target: Node, zone: int, damage: float)
## Schaden wurde angewendet (auch Brand, Aufprall). attacker darf null sein.
signal aircraft_damaged(aircraft: Node, zone: int, damage: float, attacker: Node)
## Abschuss. killer = Kredit (letzter Schütze ≤ MatchRules.kill_credit_window) oder null.
signal aircraft_destroyed(victim: Node, killer: Node, cause: int)
## Pilot ist ausgestiegen. pilot = PilotRecord (characters/) oder null.
signal pilot_ejected(aircraft: Node, pilot: RefCounted)
## Ausgestiegener Pilot ist zurück (Rettung oder Ausfallzeit vorbei). rescuer darf null sein.
signal pilot_rescued(pilot: RefCounted, rescuer: Node)

static var _bus: CombatEvents = null

var log_enabled := false
var event_log: PackedStringArray = []


static func bus() -> CombatEvents:
	if _bus == null:
		_bus = CombatEvents.new()
	return _bus


## Neuer Bus ohne Verbindungen (Testläufer vor jedem Test, Partie-Neustart).
static func reset() -> void:
	_bus = CombatEvents.new()


static func entity_id(n: Object) -> int:
	if n == null or not is_instance_valid(n):
		return -1
	var v = n.get("entity_id")
	return v if v is int else -1


func _init() -> void:
	# Methoden statt Lambdas: keine Referenz-Zyklen (Bus ist RefCounted).
	shot_fired.connect(_on_shot)
	hit_confirmed.connect(_on_hit)
	aircraft_damaged.connect(_on_damaged)
	aircraft_destroyed.connect(_on_destroyed)
	pilot_ejected.connect(_on_ejected)
	pilot_rescued.connect(_on_rescued)


func _on_shot(s: Node, g: int, id: int) -> void:
	_rec("shot", [entity_id(s), g, id])


func _on_hit(s: Node, t: Node, z: int, d: float) -> void:
	_rec("hit", [entity_id(s), entity_id(t), z, snappedf(d, 0.01)])


func _on_damaged(a: Node, z: int, d: float, at: Node) -> void:
	_rec("dmg", [entity_id(a), z, snappedf(d, 0.01), entity_id(at)])


func _on_destroyed(v: Node, k: Node, c: int) -> void:
	_rec("kill", [entity_id(v), entity_id(k), c])


func _on_ejected(a: Node, _p: RefCounted) -> void:
	_rec("eject", [entity_id(a)])


func _on_rescued(_p: RefCounted, r: Node) -> void:
	_rec("rescue", [entity_id(r)])


func _rec(kind: String, args: Array) -> void:
	if not log_enabled:
		return
	var tick := Engine.get_physics_frames()
	var parts := PackedStringArray()
	for x in args:
		parts.append(str(x))
	event_log.append("%d:%s:%s" % [tick, kind, ",".join(parts)])


## Hash über das Ereignis-Log (Ticks relativ zum ersten Eintrag).
func log_hash() -> int:
	if event_log.is_empty():
		return 0
	var t0 := int(event_log[0].get_slice(":", 0))
	var parts := PackedStringArray()
	for e in event_log:
		var t := int(e.get_slice(":", 0))
		parts.append(str(t - t0) + e.substr(e.find(":")))
	return "\n".join(parts).hash()
