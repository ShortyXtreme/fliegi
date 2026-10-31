class_name Autopilot
extends RefCounted
## Gemeinsame Lenk-Helfer für Maus-Zielsteuerung (Spieler) und KI.
## Liefern nur Knüppelwerte (-1..1), die dann als Intent den normalen Weg gehen.
## Idee der Zielrichtungs-Steuerung angelehnt an "MouseFlight" (Brian Hernandez, MIT).

const AGGRESSIVE_TURN_ANGLE := deg_to_rad(12.0)


## Knüppel so stellen, dass die Flugzeugnase in Richtung world_dir zeigt.
## Rückgabe: Vector3(pitch, roll, yaw).
static func steer_to_direction(basis: Basis, world_dir: Vector3, gain: float = 1.0) -> Vector3:
	var local := (basis.inverse() * world_dir).normalized()
	var fwd_comp := -local.z
	var angle_off := acos(clampf(fwd_comp, -1.0, 1.0))
	var pitch := clampf(atan2(local.y, maxf(fwd_comp, 0.05)) * 4.0 * gain, -1.0, 1.0)
	if fwd_comp < 0.0:
		# Ziel liegt hinter uns: kräftig ziehen, Rollen übernimmt die Richtung.
		pitch = 1.0
	var yaw := clampf(atan2(local.x, maxf(fwd_comp, 0.05)) * 2.0 * gain, -1.0, 1.0)
	# Rollen: weit weg -> in Richtung Ziel rollen; nah dran -> Flügel waagerecht.
	var aggressive_roll := clampf(local.x * 3.0 * gain, -1.0, 1.0)
	if local.y < 0.0 and absf(local.x) > 0.05 and angle_off > deg_to_rad(25.0):
		# Ziel unten seitlich: stärker rollen, damit wir "hochziehend" kurven.
		aggressive_roll = signf(local.x)
	var right := basis.x
	var wings_level_roll := clampf(right.y * 2.5, -1.0, 1.0)  # rechte Fläche tief -> nach links rollen
	var w := clampf(angle_off / AGGRESSIVE_TURN_ANGLE, 0.0, 1.0)
	var roll := lerpf(wings_level_roll, aggressive_roll, w)
	return Vector3(pitch, roll, yaw)


## Lageregler: Längsneigung (Grad) halten. Rückgabe Knüppel pitch.
static func hold_pitch_attitude(basis: Basis, pitch_rate: float, target_deg: float) -> float:
	var fwd := -basis.z
	var pitch_deg := rad_to_deg(asin(clampf(fwd.y, -1.0, 1.0)))
	return clampf((target_deg - pitch_deg) * 0.12 - pitch_rate * 1.5, -1.0, 1.0)


## Kurs halten (Bodenlauf): Rückgabe yaw-Knüppel. yaw_rate_right = Gierrate nach rechts (rad/s).
static func hold_heading(basis: Basis, yaw_rate_right: float, target_dir: Vector3) -> float:
	var fwd := -basis.z
	fwd.y = 0.0
	var t := target_dir
	t.y = 0.0
	if fwd.length() < 0.01 or t.length() < 0.01:
		return 0.0
	var err := fwd.normalized().signed_angle_to(t.normalized(), Vector3.UP)  # + = Ziel links
	return clampf(-err * 4.0 - yaw_rate_right * 1.2, -1.0, 1.0)
