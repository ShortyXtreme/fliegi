class_name FlightTelemetry
extends RefCounted
## Messwerte des Flugmodells pro Tick (für HUD, Steuerhilfen, KI, Tests).

var airspeed: float = 0.0          # m/s (wahre Fahrt gegenüber der Luft; M3.8: mit Wind ≠ Geschwindigkeit über Grund)
var ias: float = 0.0               # m/s, angezeigte Fahrt (Audit 11/2026, ISA-Dichte, ohne Instrumentenfehler)
var mach: float = 0.0              # Machzahl (ISA-Schallgeschwindigkeit)
var wave_drag_coef: float = 0.0    # Kompressibilitäts-Widerstandsbeiwert (0 unter M_crit)
var ground_speed: float = 0.0      # m/s über Grund (M3.8)
var wind: Vector3 = Vector3.ZERO   # m/s, Wind am Flugzeug (M3.8)
var wind_info: WindSample = null   # M3.9: Anteile (mittel, Böe, Hang, Thermik, Rollböe)
var altitude: float = 0.0          # m über Meeresspiegel (Welt-Y)
var height_agl: float = 0.0        # m über Grund (Raycast)
var aoa: float = 0.0               # rad, Anstellwinkel Rumpf
var sideslip: float = 0.0          # rad
var stall_amount: float = 0.0      # 0..1, Abriss am Hauptflügel
var stall_aoa: float = 0.26        # rad, Abriss-Anstellwinkel (Rumpf, aktuelle Klappen)
var stall_aoa_base: float = 0.26   # rad, Abriss-Anstellwinkel ohne Klappen
var aoa_rate: float = 0.0          # rad/s
var prop_wash: float = 0.0         # m/s, Geschwindigkeitszuwachs im Propellerstrahl (Audit 11/2026)
var downwash: float = 0.0          # rad, Abwind am Höhenleitwerk
## Treibstoff-Füllstand 0..1 (setzt Aircraft aus damage.fuel, Paket 14).
var fuel_fraction: float = 1.0
var buffet: float = 0.0            # 0..1, Vorwarnung/Schütteln vor und im Abriss
var g_load: float = 1.0
var thrust: float = 0.0            # N
var throttle_actual: float = 0.0
var engine_power_fraction: float = 0.0  # M3.11: Wellenleistung / Nennleistung (Verbrauch)
var coolant_temp: float = 80.0          # M3.11: °C
var radiator: float = 0.5               # M3.11: Kühlerklappe 0..1
var prop_moment: Vector3 = Vector3.ZERO # M3.11: Propellerwirkungen (Körper, N m, nach Trimmung/Hilfe)
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
