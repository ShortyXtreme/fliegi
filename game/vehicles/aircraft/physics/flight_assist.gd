class_name FlightAssist
extends RefCounted
## Steuerhilfen: eigene Schicht zwischen PilotIntent und Ruderkommandos.
## ARCADE: Knüppel = gewünschte Dreh-Rate (Roll-/Nickrate), automatische Dämpfung,
##         Koordination per Seitenruder, Stall-Schutz (stetige Anstellwinkel-Begrenzung)
##         und Nicklage-Begrenzung bei geringer Fahrt.
## REALISTIC: Knüppel = Ruderausschlag (Höhenruder oberhalb v_ref abgeschwächt wie eine
##         steigende Knüppelkraft), nur leichte Gierdämpfung, kein Stall-Schutz.

enum Mode { ARCADE, REALISTIC }
const MODE_NAMES := ["Arcade", "Realistisch"]

var data: AircraftData
var stall_protection := true
## Abstand des Begrenzer-Anstellwinkels zum Abriss.
const STALL_MARGIN := deg_to_rad(1.25)
## Begrenzer: Verstärkung auf den AoA-Fehler (Ruder pro rad) und Nickraten-Dämpfung (s).
const LIMIT_K := 4.0
const LIMIT_D := 0.35
const LIMIT_AOA_RATE_D := 0.5
## Nicklage-Begrenzung bei geringer Fahrt: erlaubte Längsneigung bei v = 0 bzw. v = low_speed.
const LOW_SPEED_PITCH_MIN := deg_to_rad(10.0)
const LOW_SPEED_PITCH_MAX := deg_to_rad(80.0)
## Begrenzung setzt ab LOW_SPEED_START · arcade_low_speed weich ein.
const LOW_SPEED_START := 1.25

var _cmd := ControlCommands.new()
var _pitch_i := 0.0
## Letzter Begrenzer-Eingriff (Diagnose/Telemetrie): 0 = keiner.
var limiter_amount := 0.0


func _init(d: AircraftData) -> void:
	data = d


## Höhenruder, das im stationären Flug den Rumpf-Anstellwinkel aoa hält (Vorsteuerung).
func elevator_trim(aoa: float) -> float:
	return data.elevator_per_aoa * (rad_to_deg(aoa) - data.elevator_zero_aoa_deg)


## Realistisch: maximaler Höhenruder-Anteil abhängig von der Fahrt (Knüppelkraft).
func realistic_elevator_scale(v: float) -> float:
	var vref := data.realistic_elevator_ref_speed
	if v <= vref:
		return 1.0
	return pow(vref / v, data.realistic_elevator_exponent)


func apply(intent: PilotIntent, t: FlightTelemetry, dt: float) -> ControlCommands:
	var c := _cmd
	c.throttle = intent.throttle
	c.flaps = intent.flaps
	c.brakes = intent.brakes
	c.gear_down = intent.gear_down
	c.anti_nose_over = intent.assist_mode == Mode.ARCADE
	limiter_amount = 0.0
	var w := t.angular_velocity_local
	var v := maxf(t.airspeed, 15.0)
	if intent.assist_mode == Mode.REALISTIC or t.on_ground and t.airspeed < 20.0:
		c.elevator = intent.pitch
		c.aileron = intent.roll
		c.rudder = intent.yaw
		if intent.assist_mode == Mode.REALISTIC and not t.on_ground:
			c.elevator = intent.pitch * realistic_elevator_scale(t.airspeed)
			c.rudder = clampf(intent.yaw + w.y * 0.15, -1.0, 1.0)  # leichter Gierdämpfer
		_pitch_i = 0.0
		return c

	# --- ARCADE ---
	# Rollen: Wunsch-Rollrate (rad/s). Godot: +z-Rotation = links rollen.
	var roll_rate_cmd := intent.roll * data.arcade_max_roll_rate
	var roll_rate := -w.z
	var ff_roll := roll_rate_cmd / (data.roll_rate_per_mps * v)
	c.aileron = clampf(ff_roll + (roll_rate_cmd - roll_rate) * 0.5, -1.0, 1.0)

	# Nicken: Wunsch-Nickrate; +x-Rotation = Nase hoch.
	var pitch_rate_cmd := intent.pitch * data.arcade_max_pitch_rate
	# Geringe Fahrt: steile Nicklage begrenzen (Nase nicht weiter hoch, sonst Abkippen
	# über das Heck). Wirkt nur auf das Hochnehmen der Nase relativ zum Horizont.
	var v_start := data.arcade_low_speed * LOW_SPEED_START
	if not t.on_ground and t.airspeed < v_start and t.pitch_up_vector != Vector3.ZERO:
		var u := clampf(t.airspeed / v_start, 0.0, 1.0)
		var max_pitch := lerpf(LOW_SPEED_PITCH_MIN, LOW_SPEED_PITCH_MAX, u * u)
		var pitch := t.pitch_attitude
		var over := pitch - max_pitch
		if over > -deg_to_rad(10.0):
			# Anteil der Körper-Nickrate, der die Nase über den Horizont hebt
			var up_share := clampf(t.pitch_up_vector.y / maxf(cos(pitch), 0.1), 0.0, 1.0)
			var lim_rate := -over * 1.0
			if up_share > 0.05:
				var allowed := lim_rate / up_share
				if pitch_rate_cmd > allowed:
					pitch_rate_cmd = allowed
					limiter_amount = maxf(limiter_amount, 0.5)
	var pitch_rate := w.x
	var ff_pitch := pitch_rate_cmd / (data.pitch_rate_per_mps * v)
	var err := pitch_rate_cmd - pitch_rate
	_pitch_i = clampf(_pitch_i + err * dt * 0.8, -0.4, 0.4)
	var elev := ff_pitch + err * 1.6 + _pitch_i
	if t.on_ground:
		_pitch_i = 0.0
	# Stall-Schutz: stetige Begrenzung relativ zur Trimmung am Grenz-Anstellwinkel.
	# max_elev = trim(α_lim) + K·(α_lim − α) − D·q − D_α·α̇ ; ohne Schaltschwelle.
	if stall_protection and not t.on_ground:
		var limit := t.stall_aoa - STALL_MARGIN
		# Bei geringer Fahrt reagiert das Flugzeug träger -> mehr Vorhalt auf α̇.
		var slow := clampf(60.0 / v, 1.0, 3.0)
		var max_elev := elevator_trim(limit) + (limit - t.aoa) * LIMIT_K * slow \
			- w.x * LIMIT_D - maxf(t.aoa_rate, 0.0) * LIMIT_AOA_RATE_D * slow
		max_elev = clampf(max_elev, -1.0, 1.0)
		if elev > max_elev:
			limiter_amount = maxf(limiter_amount, clampf((elev - max_elev) * 2.0, 0.0, 1.0))
			elev = max_elev
			_pitch_i = minf(_pitch_i, maxf(max_elev - ff_pitch - err * 1.6, -0.4))
	c.elevator = clampf(elev, -1.0, 1.0)

	# Gieren: Spieler-Seitenruder + Schiebewinkel-Ausgleich (koordinierte Kurve).
	c.rudder = clampf(intent.yaw + (t.sideslip * 2.5 + w.y * 0.4 if not t.on_ground else 0.0),
		-1.0, 1.0)
	return c
