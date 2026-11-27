class_name Parachute
extends Node3D
## Fallschirm (M2-Platzhalter, ohne Third-Person), seit der Prüfung Boden mit Physik:
## Absprung mit der Fahrt des Flugzeugs, freier Fall mit Luftwiderstand (CDA_BODY), nach PULL_DELAY
## Reißleine, Entfaltung über INFLATE_TIME (Fläche wächst ~ t²), dann Rundkappe (CDA_OPEN).
## Luftwiderstand wirkt auf die Fahrt gegenüber der Luft (Weather.wind_at): der Schirm treibt mit
## dem Wind, Thermik hebt ihn. Sinkrate offen ≈ SINK_RATE auf Meereshöhe, mit der Höhe ∝ 1/√ρ.
## Öffnungsstoß opening_g (größte Verzögerung in g). Landung: Boden oder Wasserspiegel.
## survives = false: Ausstieg zu tief (DamageModel) oder Aufprall schneller als LAND_KILL_SPEED
## (Schirm nicht offen; ins Wasser das Doppelte). Danach LINGER_TIME s liegen, dann weg.
## Sollwerte: Irvin 24 ft 5,5–7,5 m/s (RAF AP3456), Öffnung ≈ 2 s (≤ 3 s, FAA), Öffnungsstoß bis
## ≈ 9 g bei hoher Fahrt (AP3456), freier Fall ≈ 54 m/s.

const SINK_RATE := 6.0
const MASS := 90.0                 # Pilot mit Kombi und Schirm (kg)
const CDA_BODY := 0.5              # m², freier Fall (taumelnd/Bauchlage): ≈ 54 m/s
const CDA_OPEN := 2.0 * MASS * 9.81 / (1.225 * SINK_RATE * SINK_RATE)   # ≈ 40 m² (Ø 7,3 m, C_D ≈ 0,95)
const PULL_DELAY := 1.0
const INFLATE_TIME := 2.0
const LAND_KILL_SPEED := 10.0      # senkrecht (m/s), ≈ Sturz aus 5 m
const GRAVITY := 9.81
const LINGER_TIME := 10.0

signal landed(parachute: Parachute)

var pilot: PilotRecord
var survives := true
## Geschwindigkeit (m/s, Szene) und Zeit seit dem Absprung.
var velocity := Vector3.ZERO
var age := 0.0
var on_ground := false
var in_water := false
## Größte Verzögerung beim Öffnen (g) und Aufprallgeschwindigkeit senkrecht (m/s).
var opening_g := 0.0
var landing_speed := 0.0
var _linger := 0.0
var _canopy: Node3D


static func spawn_from(a: Node3D, rec: PilotRecord, survives_jump: bool) -> Parachute:
	var p := Parachute.new()
	p.name = "Parachute"
	p.pilot = rec
	p.survives = survives_jump
	p.velocity = a.linear_velocity if a is RigidBody3D else Vector3.ZERO
	var parent := a.get_parent()
	if parent != null:
		parent.add_child(p)
		p.global_position = a.global_position + a.global_transform.basis.y * 2.0
		if not DisplayServer.get_name() == "headless":
			p._build_visual()
	if not survives_jump and rec != null:
		rec.on_killed()
	return p


func _build_visual() -> void:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 3.65
	s.height = 3.0
	s.is_hemisphere = true
	m.mesh = s
	m.position = Vector3(0, 5, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.85)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.material_override = mat
	add_child(m)
	_canopy = m
	m.scale = Vector3.ONE * 0.05


## Wirksame Widerstandsfläche (m²) zur Zeit t nach dem Absprung.
static func cda_at(t: float) -> float:
	if t < PULL_DELAY:
		return CDA_BODY
	var k := clampf((t - PULL_DELAY) / INFLATE_TIME, 0.0, 1.0)
	return CDA_BODY + (CDA_OPEN - CDA_BODY) * k * k


func is_open() -> bool:
	return age >= PULL_DELAY + INFLATE_TIME


func _physics_process(dt: float) -> void:
	if on_ground:
		_linger += dt
		if _linger >= LINGER_TIME:
			queue_free()
		return
	step(dt)


## Ein Schritt (auch aus Tests). Widerstand halb-implizit: v_rel /= 1 + k |v_rel| dt (stabil).
func step(dt: float) -> void:
	age += dt
	var pos := global_position
	var w := Weather.wind_at(pos)
	velocity.y -= GRAVITY * dt
	var rel := velocity - w
	var k := 0.5 * FlightModel.air_density(pos.y) * cda_at(age) / MASS
	var f := 1.0 / (1.0 + k * rel.length() * dt)
	var drag := rel * (f - 1.0) / dt
	velocity = w + rel * f
	if age > PULL_DELAY:
		opening_g = maxf(opening_g, drag.length() / GRAVITY)
	pos += velocity * dt
	if _canopy != null:
		var kk := clampf((age - PULL_DELAY) / INFLATE_TIME, 0.0, 1.0)
		_canopy.scale = Vector3.ONE * maxf(kk, 0.05)
	var g := WorldGround.height_at(pos.x, pos.z)
	var wl := WorldGround.water_level_at(pos.x, pos.z)
	var surface := g if is_nan(wl) else maxf(g, wl)
	global_position = pos
	if pos.y <= surface:
		global_position.y = surface
		landing_speed = -velocity.y
		in_water = not is_nan(wl) and wl > g
		on_ground = true
		if survives and landing_speed > LAND_KILL_SPEED * (2.0 if in_water else 1.0):
			survives = false
			if pilot != null:
				pilot.on_killed()
		velocity = Vector3.ZERO
		landed.emit(self)
