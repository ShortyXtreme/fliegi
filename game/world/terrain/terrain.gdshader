shader_type spatial;
// Gelände-Kacheln (Paket 12). Die Höhen kommen aus derselben Höhenkarte wie die
// Physik (texelFetch, gleiche Dreiecksteilung im LOD 0). Oberfläche nach Höhe, Neigung
// und Bodenmaske: Wiese, Felder (Voronoi mit verzogenen Rändern, Hecken), Wald, Fels, Wasser.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform float spacing = 19.53125;
uniform float half_size = 20000.0;
uniform int samples = 2049;
uniform int tile_cells = 128;
uniform float skirt_depth = 40.0;

instance uniform vec2 tile_idx;
instance uniform float lod_step = 1.0;

varying vec2 tpos;
varying float th;

float H(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(samples - 1));
	return texelFetch(heightmap, p, 0).r;
}

void vertex() {
	ivec2 g = ivec2(tile_idx) * tile_cells + ivec2(round(VERTEX.xz));
	float h = H(g);
	int s = int(lod_step);
	float hl = H(g - ivec2(s, 0));
	float hr = H(g + ivec2(s, 0));
	float hd = H(g - ivec2(0, s));
	float hu = H(g + ivec2(0, s));
	NORMAL = normalize(vec3(hl - hr, 2.0 * spacing * float(s), hd - hu));
	float half_cells = float(tile_cells) * 0.5;
	VERTEX = vec3((VERTEX.x - half_cells) * spacing, h - VERTEX.y * skirt_depth, (VERTEX.z - half_cells) * spacing);
	tpos = vec2(g) * spacing - half_size;
	th = h;
}

vec2 hash22(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// x = F1, y = F2 - F1 (Randabstand), zw = Zell-Hash
vec4 voronoi(vec2 p) {
	vec2 ip = floor(p);
	vec2 fp = fract(p);
	float f1 = 8.0;
	float f2 = 8.0;
	vec2 id = vec2(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 b = vec2(float(i), float(j));
			vec2 o = hash22(ip + b);
			o = 0.15 + 0.7 * o;
			vec2 r = b + o - fp;
			float d = dot(r, r);
			if (d < f1) {
				f2 = f1;
				f1 = d;
				id = ip + b;
			} else if (d < f2) {
				f2 = d;
			}
		}
	}
	return vec4(sqrt(f1), sqrt(f2) - sqrt(f1), hash22(id * 1.37 + 0.5));
}

float nz(vec2 p) {
	return texture(noise_tex, p).r;
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = 1.0 - wn.y;
	vec2 muv = (tpos + half_size) / (2.0 * half_size);
	vec4 m = texture(mask_tex, muv);
	float dist = length(VERTEX);

	float n1 = nz(tpos / 2300.0);
	float n2 = nz(tpos / 610.0 + 0.37);
	float n3 = nz(tpos / 97.0 + 0.71);
	float n4 = nz(tpos / 13.0 + 0.19);

	// Wiese
	vec3 grass = mix(vec3(0.22, 0.31, 0.11), vec3(0.34, 0.40, 0.17), n1);
	grass *= 0.86 + 0.28 * n2;
	grass = mix(grass, grass * vec3(1.08, 1.02, 0.86), smoothstep(0.55, 0.8, n3));

	// Felder: verzogenes Voronoi, leicht gestreckt; Farbe je Zelle
	vec2 warp = vec2(nz(tpos / 1500.0 + 0.11), nz(tpos / 1500.0 + 0.53)) - 0.5;
	vec2 fp = tpos + warp * 520.0;
	float ang = 0.55 + (n1 - 0.5) * 1.6;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 fq = rot * fp;
	vec4 vc = voronoi(fq / vec2(420.0, 260.0));
	float cell = vc.z;
	vec3 fcol;
	if (cell < 0.22) fcol = vec3(0.60, 0.53, 0.30);        // reifes Getreide
	else if (cell < 0.36) fcol = vec3(0.50, 0.46, 0.30);   // Stoppeln
	else if (cell < 0.52) fcol = vec3(0.30, 0.40, 0.15);   // junge Saat
	else if (cell < 0.64) fcol = vec3(0.40, 0.46, 0.22);   // Klee/Heu
	else if (cell < 0.76) fcol = vec3(0.35, 0.27, 0.19);   // gepflügt
	else fcol = grass * 1.04;                               // Weide
	fcol *= 0.9 + 0.2 * vc.w;
	fcol *= 0.92 + 0.16 * n3;
	// Bearbeitungsstreifen je Feld (nur in der Nähe)
	float sang = vc.w * 3.14159;
	float stripe = sin(dot(fq, vec2(cos(sang), sin(sang))) * 0.9);
	float sfade = 1.0 - smoothstep(250.0, 900.0, dist);
	fcol *= 1.0 + stripe * 0.05 * sfade * step(cell, 0.76);
	// Feldraine/Hecken an den Zellgrenzen, lückig
	float hedge = (1.0 - smoothstep(0.012, 0.03, vc.y)) * step(0.35, n3);
	float fields = m.a * smoothstep(0.35, 0.65, m.a + (n2 - 0.5) * 0.6);
	vec3 col = mix(grass, fcol, fields);
	col = mix(col, vec3(0.13, 0.20, 0.08), hedge * fields * 0.85);

	// Feuchte Aue
	col = mix(col, col * vec3(0.8, 0.95, 0.85), clamp(m.b * 1.5, 0.0, 1.0) * (1.0 - step(0.85, m.b)));

	// Wald: dunkle, fleckige Kronen
	float fedge = smoothstep(0.35, 0.6, m.r + (n3 - 0.5) * 0.35);
	vec3 forest = mix(vec3(0.07, 0.14, 0.06), vec3(0.15, 0.24, 0.09), n4 * 0.6 + n3 * 0.4);
	forest *= 0.85 + 0.3 * n2;
	col = mix(col, forest, fedge);

	// Gemähte Flächen (Flugplätze, Ziel-Plätze)
	vec3 mown = mix(vec3(0.33, 0.42, 0.18), vec3(0.40, 0.47, 0.22), n3);
	col = mix(col, mown, smoothstep(0.3, 0.8, m.g));

	// Fels nach Neigung und Höhe
	float rock = smoothstep(0.28, 0.45, slope + (n2 - 0.5) * 0.15);
	rock = max(rock, smoothstep(720.0, 900.0, th + n2 * 80.0) * smoothstep(0.08, 0.2, slope));
	vec3 rockc = mix(vec3(0.38, 0.36, 0.32), vec3(0.52, 0.49, 0.44), n3) * (0.85 + 0.3 * n4);
	col = mix(col, rockc, rock);

	// Wasser
	float water = smoothstep(0.8, 0.95, m.b);
	col = mix(col, vec3(0.10, 0.17, 0.18), water);

	ALBEDO = col;
	ROUGHNESS = mix(0.95, 0.12, water);
	SPECULAR = mix(0.35, 0.6, water);
}
