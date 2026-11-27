shader_type spatial;
// M3.8: Fließgewässer (Hauptfluss, Bäche). Band-Meshes entlang der Mittellinie (RiverWater),
// Wasserspiegel eben quer zum Lauf. Die Uferlinie ergibt sich je Pixel aus der echten
// Geländehöhe (dieselbe Höhenkarte und Dreiecksteilung wie Physik/Gelände): Wassertiefe =
// Spiegel − Boden, ≤ 0 = kein Wasser. Fließrichtung je Vertex (UV2 = Richtung · m/s),
// Wellen aus zwei gegeneinander versetzten Phasen (Flowmap-Verfahren, kein Strecken),
// Kräuselung in Windrichtung (globaler Wind), Himmelsspiegelung mit Fresnel,
// Tiefenfärbung, Uferschaum und weicher Rand.
// Fern (gröbere Gelände-LODs schneiden das Bett nicht mehr ein) wird die Fläche etwas
// angehoben; die Uferlinie bleibt dank der Höhenkarte trotzdem genau.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec4 wind_state;   // x, z Windrichtung (wohin, Einheitsvektor), y Stärke m/s am Boden (10 m), w Böe 0..1

uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D wave_nrm : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform float spacing = 19.53125;
uniform float half_size = 20000.0;
uniform int samples = 2049;
uniform vec3 sky_top : source_color = vec3(0.24, 0.42, 0.72);
uniform vec3 sky_horizon : source_color = vec3(0.68, 0.75, 0.82);
uniform vec3 deep_col : source_color = vec3(0.012, 0.03, 0.032);
uniform vec3 shallow_col : source_color = vec3(0.07, 0.075, 0.05);
uniform float reflect_gain = 0.42;

varying vec2 tpos;
varying float level;
varying vec2 flow;
varying float fade;
varying float far_k;

float H(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(samples - 1));
	return texelFetch(heightmap, p, 0).r;
}

// wie TerrainWorld.height_at_terrain (Diagonale (i+1, j)–(i, j+1))
float ground(vec2 t) {
	vec2 f = clamp((t + half_size) / spacing, vec2(0.0), vec2(float(samples - 1)));
	ivec2 i = min(ivec2(floor(f)), ivec2(samples - 2));
	vec2 u = f - vec2(i);
	float h10 = H(i + ivec2(1, 0));
	float h01 = H(i + ivec2(0, 1));
	if (u.x + u.y <= 1.0) {
		float h00 = H(i);
		return h00 + (h10 - h00) * u.x + (h01 - h00) * u.y;
	}
	float h11 = H(i + ivec2(1, 1));
	return h11 + (h01 - h11) * (1.0 - u.x) + (h10 - h11) * (1.0 - u.y);
}

void vertex() {
	tpos = VERTEX.xz;
	level = VERTEX.y;
	flow = UV2;
	fade = COLOR.r;
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(wp, INV_VIEW_MATRIX[3].xyz);
	// grobe Gelände-LODs (ab 3,2 km bzw. 9 km) liegen im Tal höher als das Bett
	VERTEX.y += smoothstep(2700.0, 3200.0, d) * 3.5 + smoothstep(8200.0, 9000.0, d) * 8.0;
	far_k = smoothstep(1500.0, 6000.0, d);
}

vec2 nrm2(vec2 uv) {
	return texture(wave_nrm, uv).rg * 2.0 - 1.0;
}

void fragment() {
	float depth = level - ground(tpos);
	if (depth <= 0.0 || fade <= 0.001) {
		discard;
	}
	float spd = length(flow);
	// Flowmap: zwei Phasen, je halbe Periode versetzt, überblendet beim Zurückspringen
	float per = 2.6;
	float ph0 = fract(TIME / per);
	float ph1 = fract(TIME / per + 0.5);
	float bl = abs(1.0 - 2.0 * ph0);
	vec2 o0 = flow * ph0 * per;
	vec2 o1 = flow * ph1 * per;
	vec2 n = mix(nrm2((tpos - o0) / 6.5), nrm2((tpos - o1) / 6.5 + 0.37), bl) * 0.55;
	n += mix(nrm2((tpos - o0 * 0.7) / 17.0 + 0.11), nrm2((tpos - o1 * 0.7) / 17.0 + 0.61), bl) * 0.45;
	// Kräuselung in Windrichtung (Windstärke aus dem Wetter)
	vec2 wd = wind_state.xz;
	float ws = wind_state.y;
	float rip = clamp(ws / 8.0, 0.0, 1.0) * (0.7 + 0.3 * wind_state.w);
	vec2 wuv = tpos / 2.4 - wd * TIME * (0.25 + ws * 0.06);
	n += nrm2(wuv) * rip * 0.8 + nrm2(wuv * 0.43 + 0.29) * rip * 0.5;
	// Strömung macht unruhiger, Ferne glatter (gegen Flimmern)
	float rough_k = (0.18 + 0.12 * clamp(spd, 0.0, 2.0) + 0.25 * rip) * mix(1.0, 0.35, far_k);
	vec3 nw = normalize(vec3(n.x * rough_k, 1.0, n.y * rough_k));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// Tiefe: flach schlammig-hell, tief dunkel-grün
	float dk = smoothstep(0.15, 2.6, depth);
	vec3 body = mix(shallow_col, deep_col, dk);
	// großflächige Tönung (Schwebstoffe, Wasserpflanzen): bricht das gleichmäßige Band auf
	float tone = texture(foam_tex, tpos / 380.0 + 0.13).r;
	body *= vec3(0.8 + 0.45 * tone, 0.85 + 0.35 * tone, 0.9 + 0.2 * tone);
	// Fresnel + Himmel
	vec3 vw = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);   // zum Betrachter
	float cosv = clamp(dot(nw, vw), 0.0, 1.0);
	float fres = 0.02 + 0.98 * pow(1.0 - cosv, 5.0);
	vec3 r = reflect(-vw, nw);
	vec3 sky = mix(sky_horizon, sky_top, smoothstep(0.0, 0.55, r.y));
	// Uferschaum: schmaler Saum, wandert mit der Strömung
	float fn = texture(foam_tex, (tpos - o0 * 0.6) / 4.0).r * (1.0 - bl) + texture(foam_tex, (tpos - o1 * 0.6) / 4.0 + 0.5).r * bl;
	float foam = (1.0 - smoothstep(0.02, 0.22 + 0.25 * fn, depth)) * smoothstep(0.35, 0.65, fn) * (1.0 - far_k);
	// Strömungsstreifen in der Mitte (schwach, nur nah)
	float streak = smoothstep(0.62, 0.8, texture(foam_tex, vec2(tpos.x, tpos.y) / 11.0 - flow * TIME * 0.09).r) * 0.25 * (1.0 - far_k) * dk;
	foam = clamp(foam + streak * clamp(spd - 0.6, 0.0, 1.0), 0.0, 1.0);

	ALBEDO = mix(body * (1.0 - fres), vec3(0.75, 0.77, 0.75), foam);
	EMISSION = sky * fres * reflect_gain * (1.0 - foam);
	ROUGHNESS = mix(0.06, 0.6, foam);
	SPECULAR = 0.5;
	METALLIC = 0.0;
	// Rand: weich auslaufen (keine harte Kante am Ufer)
	float edge = smoothstep(0.0, 0.12, depth);
	float a = mix(0.45, 0.93, dk);
	ALPHA = clamp(max(a, fres) + foam * 0.6, 0.0, 1.0) * edge * fade;
}
