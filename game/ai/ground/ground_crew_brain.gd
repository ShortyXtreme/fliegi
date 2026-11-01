class_name GroundCrewBrain
extends Controller
## M3 Stub (Paket 0b, gehört Strang G / Pakete 7a–7b): KI-Bodenpersonal. Liefert einen
## CrewIntent, läuft auf dem Rollweg-Graph (AirfieldLayout), nimmt Jobs vom JobBoard nach
## Priorität, hält PROP_ZONE Abstand zum laufenden Propeller. Befehlsrad: command().
## Sim-LOD: ohne Spieler im Umkreis LOD_RANGE abstrakt über dieselben Job-Schritte.

enum Command { FULL_SERVICE, FUEL_ONLY, AMMO_ONLY, QUICK_SERVICE, TRUCK_TO_ME, FOLLOW, REPAIR, PAUSE }
const COMMAND_LABELS := ["Voll abfertigen", "Nur tanken", "Nur Munition", "Schnellabfertigung",
	"Tankwagen zu mir", "Folgen", "Reparieren", "Zurück/Pause"]
enum Priority { REFILL_VEHICLE, AI_AIRCRAFT, PLAYER_AIRCRAFT, ALARM }
const PROP_ZONE := 5.0
const LOD_RANGE := 2000.0

var work_mul := 0.8
var job_id := 0
var abstract_mode := false


## Befehl aus dem Befehlsrad (target = Zielmaschine oder null).
func command(_cmd: int, _target: Node) -> bool:
	return false


func compute_crew_intent(_dt: float) -> CrewIntent:
	return CrewIntent.new()
