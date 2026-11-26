shader_type spatial;
// M3.7: Gras-Büschel um die Kamera (MultiMesh in festem Raster, Knoten folgt der Kamera in
// Rasterschritten). Lage, Höhe und Dichte rechnet der Vertex-Shader: Bodenhöhe aus derselben
// Höhenkarte wie das Gelände, Dichte aus der Bodenmaske (kein Gras in Wald, Wasser, Äckern),
// Platzmaske je Flugplatz (R = Grashöhe, G = Abnutzung: Piste kurz, Roll-/Fahrwege und
// Abstellplätze grasfrei, platt gefahrene Bahnen gelblich und niedrig). Zum Rand hin werden
// die Büschel kleiner und seltener (kein harter Rand).
render_mode diffuse_burley, specular_schlick_ggx, cull_disabled;

uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D af_mask : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
#include "res://world/terrain/fields.gdshaderinc"
uniform float spacing = 19.53125;
uniform float half_size = 20000.0;
uniform int samples = 2049;
uniform vec3 terrain_origin = vec3(0.0);
uniform float grid = 0.6;
uniform float radius = 45.0;
uniform float blade_h = 0.45;
// Platzmaske: Mitte (Szene), Halbgröße (x, z) in m
uniform vec3 af_center = vec3(0.0, -100000.0, 0.0);
uniform vec2 af_half = vec2(200.0, 820.0);
uniform float wind = 1.0;
uniform float albedo_gain = 2.1;

varying float vh;
varying float vwear;
varying float vtone;

float H(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(samples - 1));
	return texelFetch(heightmap, p, 0).r;
}

float ground(vec2 t) {
	vec2 f = (t + half_size) / spacing;
	ivec2 i = ivec2(floor(f));
	vec2 u = fract(f);
	float a = mix(H(i), H(i + ivec2(1, 0)), u.x);
	float b = mix(H(i + ivec2(0, 1)), H(i + ivec2(1, 1)), u.x);
	return mix(a, b, u.y);
}

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

void vertex() {
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 cell = floor((base.xz - terrain_origin.xz) / grid + 0.5);   // Gelände-Raster (stabil)
	vec2 h = hash2(cell);
	vec2 h2 = hash2(cell + 17.31);
	vec2 t = (cell + h - 0.5) * grid;
	vec2 wxz = t + terrain_origin.xz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float d = length(wxz - cam.xz);
	vec4 m = textureLod(mask_tex, (t + half_size) / (2.0 * half_size), 0.0);
	float dens = (1.0 - smoothstep(0.35, 0.55, m.r)) * (1.0 - smoothstep(0.55, 0.75, m.b));
	// Äcker (wie im Gelände-Shader): auf Getreide, Stoppeln, Saat, Rüben, Pflug, Senf kein Gras;
	// Klee/Heu kürzer, Weiden normal
	if (m.a > 0.3 && m.g < 0.3) {
		vec4 reg;
		vec2 fq;
		vec4 vc = field_cell(t, reg, fq);
		float n2 = textureLod(noise_tex, t / 610.0 + 0.37, 0.0).r;
		float fields = smoothstep(0.5, 0.56, m.a * 0.9 + (vc.w - 0.5) * 0.5 + (n2 - 0.5) * 0.15);
		float clover = step(0.40, vc.z) * step(vc.z, 0.50);
		float crop = step(vc.z, 0.70) * (1.0 - clover);
		dens *= 1.0 - fields * crop;
		dens *= 1.0 - fields * clover * 0.3;
	}
	float hgt = mix(1.0, 0.55, smoothstep(0.3, 0.8, m.g));   // gemähte Plätze kürzer
	float wear = 0.0;
	vec2 al = (wxz - af_center.xz) / af_half;
	if (abs(al.x) < 1.0 && abs(al.y) < 1.0) {
		vec4 a = textureLod(af_mask, al * 0.5 + 0.5, 0.0);
		hgt *= a.r;
		wear = a.g;
	}
	// zum Rand dünner und kleiner
	float fade = 1.0 - smoothstep(radius * 0.45, radius, d);
	float keep = step(h2.y, fade * 1.15) * step(0.05, dens * hgt) * step(h2.x, dens);
	float s = (0.6 + 0.8 * h.x) * hgt * keep * mix(0.35, 1.0, fade);
	float yaw = h.y * 6.2832;
	float c = cos(yaw);
	float sn = sin(yaw);
	vec3 v = VERTEX;
	float up = UV.y;   // 0 unten, 1 Spitze
	v = vec3(c * v.x + sn * v.z, v.y * blade_h * s, -sn * v.x + c * v.z);
	v.xz *= mix(0.6, 1.0, s);
	// Wind: Böen wandern übers Feld, Spitzen biegen am stärksten
	float gust = sin(TIME * 1.7 + wxz.x * 0.11 + wxz.y * 0.07) * 0.6 + sin(TIME * 3.1 + wxz.x * 0.5) * 0.25;
	v.xz += vec2(0.8, 0.5) * gust * up * up * 0.16 * blade_h * s * wind;
	vec3 world = vec3(wxz.x, ground(t) + terrain_origin.y, wxz.y) + v;
	VERTEX = world - base;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
	vh = up;
	vwear = wear;
	vtone = h2.x;
}

void fragment() {
	// Rückseiten nicht abdunkeln (Halme sind beidseitig)
	NORMAL = FRONT_FACING ? NORMAL : -NORMAL;
	vec3 lo = vec3(0.045, 0.075, 0.018);
	vec3 hi = mix(vec3(0.095, 0.14, 0.036), vec3(0.13, 0.145, 0.045), vtone);
	vec3 col = mix(lo, hi, vh);
	// platt gefahren: gelblich, matter
	col = mix(col, mix(vec3(0.07, 0.065, 0.025), vec3(0.14, 0.125, 0.05), vh), vwear * 0.8);
	ALBEDO = col * albedo_gain;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
