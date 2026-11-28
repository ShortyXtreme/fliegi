shader_type spatial;
// M3.13: Flecken und Flächen am Flugplatz (AirfieldDressing): Rollwege, Abstellfläche, platt gefahrene
// Grasbahnen (dirt_floor) und Pistengrund/Farbflecken (aerial_grass_rock) aus dem Gelände-Array
// (ground_detail.gdshaderinc). Farbe wie bisher aus Instanz-/Vertexfarbe (× base_tex), die Textur
// gibt die Struktur; an den Fleck-Rändern löst die Höhe der Textur die Kante auf (Erde in den Senken).
// Lage relativ zum Platzknoten -> bleibt bei Floating-Origin-Verschiebungen fest.
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

#include "res://world/terrain/ground_decal.gdshaderinc"
