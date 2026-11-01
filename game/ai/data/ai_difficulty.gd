class_name AIDifficulty
extends Resource
## Schwierigkeitsstufe der Kampf-KI (Plan §4). Instanzen: rekrut/erfahren/veteran.tres.

enum Maneuver { BREAK = 1, SCISSORS = 2, SPIRAL = 4 }

@export var display_name := "Erfahren"
## Reaktionsverzögerung der Wahrnehmung (s): Ziel wird erst so spät erkannt und
## seine Lage aus einem um diese Zeit verzögerten Puffer gelesen.
@export var reaction_time := 0.5
## Visuelle Nachführ-Verzögerung beim Zielen (s): Entscheidungen nutzen reaction_time,
## das laufende Anvisieren eines erkannten Ziels nur diese kürzere Verzögerung (Paket 14).
@export var tracking_delay := 0.18
## Feuern nur, wenn die vorhergesagte Ablage am Ziel kleiner ist (m, ~ halbe Spannweite).
@export var fire_max_miss_m := 4.0
## Frontalschuss (Ziel kommt auf uns zu) nur bei dieser kleineren Ablage (m).
@export var fire_max_miss_frontal_m := 2.5
## Zielfehler (mrad, 1σ), langsam wandernd.
@export var aim_error_mrad := 6.0
## Anteil des Nick-Knüppels im Kampf (G-Nutzung); Bodenschutz nutzt immer 100 %.
@export_range(0.1, 1.0) var g_use := 0.8
## Ausweichmanöver (Bitmaske aus Maneuver).
@export_flags("Break", "Schere", "Spirale") var maneuvers := 3
## Feuerdisziplin: maximale Schussentfernung (m) und maximaler Vorhaltfehler (Grad).
@export var fire_range := 400.0
@export var fire_max_error_deg := 2.0
## Feuerstöße (s) und Pausen dazwischen (s).
@export var burst_min := 0.5
@export var burst_max := 1.5
@export var pause_min := 0.4
@export var pause_max := 1.0
## Höhenvorteil, den die KI im Anflug sucht (m über dem Ziel).
@export var altitude_advantage := 300.0
## Bodenschutz-Sicherheitsabstand (m) für die Vorausschau.
@export var ground_margin := 120.0


func has_maneuver(m: int) -> bool:
	return maneuvers & m != 0


static func load_level(level_name: String) -> AIDifficulty:
	return load("res://ai/data/%s.tres" % level_name) as AIDifficulty
