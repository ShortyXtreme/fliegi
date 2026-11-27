shader_type spatial;
// M3.7: Bäume und Büsche (MultiMesh, Vertexfarben aus art/scripts/build_vegetation.py).
// Detailstufe je Instanz: mode 0 = nah (LOD0, von der CPU ausgewählt), 1 = mittel (LOD1,
// ohne die Nah-Instanzen und ohne alles hinter lod_r), 2 = fern (LOD2 ab lod_r, schrumpft am
// Rand der Sichtweite in den Boden statt zu ploppen). Wind: Wiegen nach Höhe, Phase und Farbton je Instanz aus der Lage.
render_mode diffuse_burley, specular_schlick_ggx, cull_back;

uniform int mode = 0;
uniform vec3 near_center = vec3(0.0);
uniform float near_r = 0.0;
uniform float lod_r = 380.0;
uniform float far_r = 2200.0;
uniform float wind = 1.0;
global uniform vec4 wind_state;   // M3.8: x, z Richtung „wohin“, y Stärke m/s, w Böe 0..1
uniform float albedo_gain = 3.0;   // Vertexfarben dunkel (Cycles-Palette), Gras ist heller

varying vec3 tint;

void vertex() {
	vec3 io = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	float d = distance(io, cam);
	float keep = 1.0;
	if (mode == 1) {
		if (near_r > 0.0 && distance(io.xz, near_center.xz) < near_r) keep = 0.0;
		if (d > lod_r) keep = 0.0;
	} else if (mode == 2) {
		if (d <= lod_r) keep = 0.0;
		keep *= smoothstep(far_r, far_r * 0.86, d);
	}
	// Farbton und Wind-Phase je Instanz aus der Lage (keine Instanzdaten nötig)
	vec3 hv = fract(sin(vec3(dot(io.xz, vec2(12.9898, 78.233)), dot(io.xz, vec2(39.346, 11.135)),
		dot(io.xz, vec2(73.156, 52.235)))) * 43758.5453);
	float ph = hv.x * 6.2832;
	float h = max(VERTEX.y - 2.5, 0.0);
	// M3.8: Wind aus dem Wetter – Neigung in Windrichtung (Lokalraum der Instanz), Wiegen mit
	// Böen, die in Windrichtung durch den Wald laufen; bei Flaute kaum Bewegung
	vec2 wd = (inverse(mat3(MODEL_MATRIX)) * vec3(wind_state.x, 0.0, wind_state.z)).xz;
	wd = normalize(wd + vec2(1e-5));
	float ws = clamp(wind_state.y / 8.0, 0.0, 1.0);
	float along = dot(io.xz, wind_state.xz);
	float g = sin(TIME * (0.9 + 0.5 * ws) - along * 0.045 + ph * 0.3) * 0.5 + 0.5;
	vec2 sway = wd * h * h * 0.0018 * ws * (0.6 + 0.6 * g + 0.3 * wind_state.w) * wind;
	sway += vec2(sin(TIME * 1.1 + ph), cos(TIME * 0.83 + ph * 1.3)) * h * (0.0015 + 0.006 * ws) * wind;
	// Laub flattert (Laub = grüner als rot), stärker bei Wind
	float leaf = step(COLOR.r * 1.25, COLOR.g);
	sway += leaf * vec2(sin(TIME * (3.7 + 2.0 * ws) + VERTEX.y * 1.7 + ph), cos(TIME * 4.3 + VERTEX.x * 1.9)) * (0.008 + 0.04 * ws) * wind;
	VERTEX.xz += sway;
	VERTEX *= keep;
	tint = vec3(0.8 + 0.4 * hv.y, 0.85 + 0.3 * hv.z, 0.75 + 0.4 * hv.x);
}

void fragment() {
	ALBEDO = COLOR.rgb * tint * albedo_gain;
	ROUGHNESS = 0.9;
	SPECULAR = 0.25;
}
