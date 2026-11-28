// M3.13: Rumpf von ground_decal.gdshader (Flecken, mit Alpha) und ground_flat.gdshader (GD_OPAQUE).
#include "res://world/terrain/ground_detail.gdshaderinc"

uniform sampler2D blob : hint_default_white, filter_linear;
uniform sampler2D base_tex : source_color, hint_default_white, filter_linear_mipmap, repeat_enable;
uniform vec2 base_scale = vec2(1.0);
uniform float use_blob = 1.0;
uniform float alpha_mul = 1.0;
uniform int layer = 6;
uniform float rough = 1.0;
uniform float edge_break = 0.6;

varying vec3 rel;

void vertex() {
	rel = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz - NODE_POSITION_WORLD;
}

void fragment() {
	vec4 b = use_blob > 0.5 ? texture(blob, UV) : vec4(1.0);
	vec3 c = COLOR.rgb * texture(base_tex, UV * base_scale).rgb;
	float a = COLOR.a * b.a * alpha_mul;
	float dist = length(VERTEX);
	vec2 p = rel.xz;
	vec2 dpx = dFdx(p);
	vec2 dpy = dFdy(p);
	float fa = 1.0 - smoothstep(120.0, 450.0, dist);
	float fb = 1.0 - smoothstep(350.0, 1400.0, dist);
	float r = rough;
	if (tex_on > 0.5 && fb > 0.001) {
		vec4 acc = vec4(0.0);
		vec3 accn = vec3(0.0);
		gd_layer(layer, 1.0, p, vec2(0.0), dpx, dpy, 0.5, fa, acc, accn);
		c *= gd_ratio(acc.rgb / acc.w, fb);
		r = mix(rough, accn.z / acc.w, fb);
		// Höhe der Textur (über das Gewicht zurückgerechnet) löst weiche Ränder auf
		float h = pow(acc.w, 1.0 / 3.0) - 0.15;
		a = mix(a, clamp(a * (1.0 + edge_break) - (h - 0.5) * edge_break, 0.0, 1.0), fb * (1.0 - b.a * b.a));
		vec3 nw = gd_normal(vec3(0.0, 1.0, 0.0), vec3(accn.x, 0.0, accn.y) / acc.w, fb);
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
	ALBEDO = c;
#ifndef GD_OPAQUE
	ALPHA = a;
#endif
	ROUGHNESS = r;
	SPECULAR = 0.3;
}
