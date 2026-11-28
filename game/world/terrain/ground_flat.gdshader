shader_type spatial;
// M3.13: undurchsichtige Platzfläche (Pistengrund) mit Boden-Textur – wie ground_decal.gdshader ohne Alpha.
render_mode diffuse_burley, specular_schlick_ggx;

#define GD_OPAQUE
#include "res://world/terrain/ground_decal.gdshaderinc"
