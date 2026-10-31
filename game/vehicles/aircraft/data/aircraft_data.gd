class_name AircraftData
extends Resource
## Alle Kennwerte eines Flugzeugtyps. Instanzen liegen als .tres in data/.

@export var display_name: String = "Flugzeug"
@export var tier: int = 1

@export_group("Masse")
@export var mass: float = 2500.0
## Trägheitsmomente um Körperachsen (x = Nicken, y = Gieren, z = Rollen), kg m².
@export var inertia: Vector3 = Vector3(7000, 11000, 6000)

@export_group("Antrieb")
@export var engine_power_w: float = 700000.0
@export var static_thrust_n: float = 12000.0
@export var prop_efficiency: float = 0.8
@export var engine_position: Vector3 = Vector3(0, 0, -2.6)
## Wie schnell der Motor dem Gashebel folgt (pro Sekunde).
@export var throttle_response: float = 1.5
## Volldruckhöhe des Laders (m): bis hier volle Leistung, darüber Leistung ∝ Luftdichte.
@export var engine_critical_altitude: float = 4000.0
## Exponent der weichen Minimum-Bildung Standschub/Leistungsschub (kleiner = mehr
## Propellerverlust bei mittlerer Fahrt, z. B. im Steigflug).
@export var prop_blend_exponent: float = 4.0
## Leerlauf-Gasstellung (leichter Vorwärtsschub bei Gas 0).
@export var idle_throttle: float = 0.04

@export_group("Aerodynamik")
@export var surfaces: Array[AeroSurfaceDef] = []
## Widerstandsfläche des Rumpfs (Cd * A), m².
@export var fuselage_drag_area: float = 0.12
## Seitliche Widerstandsfläche des Rumpfs, m².
@export var fuselage_side_area: float = 3.0
## Abwind am Höhenleitwerk: dε/dα (Abwindwinkel pro Flügel-Anstellwinkel).
@export var downwash_gradient: float = 0.4
## Zusätzliche Nickdämpfung (Flügel/Rumpf, Cmq, negativ = dämpfend).
@export var pitch_damping_cmq: float = -6.0
## Mittlere Flügeltiefe (m), Bezugslänge für die Nickdämpfung.
@export var mean_chord: float = 1.85

@export_group("Fahrwerk")
@export var wheels: Array[WheelDef] = []
## Widerstandsfläche des ausgefahrenen Fahrwerks (Cd * A), m².
@export var gear_drag_area: float = 0.08
## Dauer für Ein- bzw. Ausfahren (s).
@export var gear_transition_time: float = 6.5
## Höchstgeschwindigkeit mit ausgefahrenem Fahrwerk (m/s), darüber HUD-Warnung.
@export var gear_max_speed: float = 300.0 / 3.6

## Kufenpunkte unter dem Rumpf (Bauchlandung), relativ zum Schwerpunkt.
@export var belly_points: PackedVector3Array = PackedVector3Array([
	Vector3(0, -0.55, -2.0), Vector3(0, -0.55, 0.3), Vector3(0, -0.45, 3.5)])

@export_group("Kollision")
@export var fuselage_box_center: Vector3 = Vector3(0, 0, 0.6)
@export var fuselage_box_size: Vector3 = Vector3(1.0, 1.1, 8.2)
@export var wing_box_center: Vector3 = Vector3(0, -0.35, 0.0)
@export var wing_box_size: Vector3 = Vector3(10.6, 0.22, 1.9)

@export_group("Darstellung")
## Pfad zu einem .glb/.tscn-Modell. Fehlt die Datei, wird ein Platzhalter gebaut.
@export_file("*.glb", "*.gltf", "*.tscn") var model_path: String = ""
@export var model_offset: Vector3 = Vector3.ZERO
@export var model_rotation_deg: Vector3 = Vector3.ZERO
@export var model_scale: float = 1.0
## > 0: Modell automatisch so skalieren, dass die Spannweite (größte X-Ausdehnung) passt.
@export var model_fit_span: float = 0.0
@export var cockpit_eye: Vector3 = Vector3(0, 0.95, 0.9)
@export var propeller_position: Vector3 = Vector3(0, 0, -3.3)
@export var body_color: Color = Color(0.32, 0.5, 0.3)
@export var accent_color: Color = Color(0.95, 0.8, 0.2)

@export_group("Steuerhilfen")
## Rollrate pro (m/s) Fahrt bei vollem Querruder (Vorsteuerung der Arcade-Hilfe).
@export var roll_rate_per_mps: float = 0.022
## Nickrate pro (m/s) Fahrt bei vollem Höhenruder (Vorsteuerung).
@export var pitch_rate_per_mps: float = 0.012
@export var arcade_max_roll_rate: float = 2.2
@export var arcade_max_pitch_rate: float = 0.9
## Höhenruder-Trimmung pro Grad Rumpf-Anstellwinkel (gemessen, für den Stall-Schutz).
@export var elevator_per_aoa: float = 0.04
## Rumpf-Anstellwinkel (Grad), bei dem das Höhenruder in Neutralstellung trimmt.
@export var elevator_zero_aoa_deg: float = -0.5
## Unterhalb dieser Fahrt (m/s) begrenzt Arcade die Längsneigung (gegen Abkippen über das Heck).
@export var arcade_low_speed: float = 150.0 / 3.6
## Realistisch: oberhalb dieser Fahrt (m/s) wird der Höhenruder-Ausschlag mit (v_ref/v)^k
## begrenzt (simulierte Knüppelkraft).
@export var realistic_elevator_ref_speed: float = 260.0 / 3.6
@export var realistic_elevator_exponent: float = 1.0

@export_group("Start")
## Höhe des Schwerpunkts über Grund im Stand (für Spawn auf der Piste).
@export var ground_height: float = 1.62
@export var ground_pitch_deg: float = 9.0
