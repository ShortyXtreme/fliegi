class_name HudPalette
extends Resource
## Epochen-Theme des HUD (M3.2): Farben, Rahmen, Schrift-Theme. Je Epoche/Tier eine .tres
## (Tier I: epoch_t1.tres). HudStyle.apply(palette) schaltet um; alle HUD-Elemente zeichnen
## über HudStyle und übernehmen das Theme sofort. Spätere Epochen (Jets: HUD-Leitlinien,
## grünliche Glasanzeige) bekommen eine eigene Palette, ohne Code in den Panels zu ändern.

@export var epoch_name := "Tier I – späte 1930er"
## Godot-Theme für Control-Knoten (Schrift, Label-Farben); wird den HUD-Wurzeln zugewiesen.
@export var theme: Theme
@export_group("Flächen")
@export var bg := Color(0.125, 0.105, 0.072, 0.82)
@export var bg_edge := Color(0.80, 0.68, 0.42, 0.32)
@export var bg_inner_edge := Color(1, 1, 1, 0.05)
@export var corner_radius := 4
@export var shadow := Color(0, 0, 0, 0.55)
@export_group("Text")
@export var label := Color(0.73, 0.69, 0.58)
@export var value := Color(0.95, 0.92, 0.84)
@export var dim := Color(0.73, 0.69, 0.58, 0.58)
## Überschriften in gesperrten Versalien (Zeichenabstand in px).
@export var heading_spacing := 2
@export_group("Akzente")
@export var accent := Color(0.86, 0.72, 0.42)
@export var ok := Color(0.62, 0.74, 0.40)
@export var caution := Color(0.96, 0.70, 0.26)
@export var warning := Color(0.90, 0.32, 0.24)
@export var friend := Color(0.52, 0.68, 0.88)
@export var enemy := Color(0.92, 0.36, 0.28)
@export_group("Tastensymbole")
@export var key_face := Color(0.93, 0.89, 0.78)
@export var key_text := Color(0.12, 0.11, 0.09)
@export var key_edge := Color(0.55, 0.47, 0.32)
