class_name FlightTelemetry
extends RefCounted
## Messwerte des Flugmodells pro Tick (für HUD, Steuerhilfen, KI, Tests).

var airspeed: float = 0.0          # m/s (wahre Fahrt)
var altitude: float = 0.0          # m über Meeresspiegel (Welt-Y)
var height_agl: float = 0.0        # m über Grund (Raycast)
var aoa: float = 0.0               # rad, Anstellwinkel Rumpf
var sideslip: float = 0.0          # rad
var stall_amount: float = 0.0      # 0..1, Abriss am Hauptflügel
var stall_aoa: float = 0.26        # rad, Abriss-Anstellwinkel (Rumpf, aktuelle Klappen)
var stall_aoa_base: float = 0.26   # rad, Abriss-Anstellwinkel ohne Klappen
var aoa_rate: float = 0.0          # rad/s
var downwash: float = 0.0          # rad, Abwind am Höhenleitwerk
var buffet: float = 0.0            # 0..1, Vorwarnung/Schütteln vor und im Abriss
var g_load: float = 1.0
var thrust: float = 0.0            # N
var throttle_actual: float = 0.0
var on_ground: bool = false
var wheels_in_contact: int = 0
var belly_contact: bool = false    # Rumpf schleift am Boden (Bauchlandung)
var gear_extension: float = 1.0    # 0 = eingefahren, 1 = ausgefahren
var gear_down_cmd: bool = true     # Sollzustand Fahrwerk
var gear_blocked: bool = false     # Einfahren verweigert (Gewicht auf den Rädern)
var gear_overspeed: bool = false   # Fahrwerk draußen und zu schnell
var climb_rate: float = 0.0        # m/s
var pitch_attitude: float = 0.0    # rad, Längsneigung über dem Horizont
var pitch_up_vector: Vector3 = Vector3.ZERO  # Rumpf-Hochachse in Weltkoordinaten
var angular_velocity_local: Vector3 = Vector3.ZERO  # x Nicken, y Gieren, z Rollen (rad/s)
var aero_force: Vector3 = Vector3.ZERO
var thrust_force: Vector3 = Vector3.ZERO
var gear_force: Vector3 = Vector3.ZERO
var weight_force: Vector3 = Vector3.ZERO
var lift: float = 0.0              # N, Komponente senkrecht zur Bahn
var drag: float = 0.0              # N, Komponente entgegen der Bahn
var commands: ControlCommands = ControlCommands.new()
var assist_mode: int = 0
