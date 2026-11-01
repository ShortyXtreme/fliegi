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
// Palette ist auf Cycles-Licht der Vorschau abgestimmt; Godot-Sonne ist schwächer
uniform float albedo_gain = 2.1;

// Szenen-Lage des Gelände-Bezugs (verschiebt sich mit Floating Origin); die Kachel
// ergibt sich aus der Knotenlage (keine Instanz-Uniforms, die im Kompatibilitäts-
// Renderer bei vielen Instanzen fehlschlagen).
uniform vec3 terrain_origin = vec3(0.0);
uniform float lod_step = 1.0;

varying vec2 tpos;
varying float th;

float H(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(samples - 1));
	return texelFetch(heightmap, p, 0).r;
}

void vertex() {
	float tile_m = float(tile_cells) * spacing;
	vec2 tile_idx = round((NODE_POSITION_WORLD.xz - terrain_origin.xz + half_size) / tile_m - 0.5);
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
	// feine Details mit der Entfernung ausblenden (gegen Flimmern)
	float near = 1.0 - smoothstep(600.0, 2500.0, dist);
	float mid = 1.0 - smoothstep(3000.0, 9000.0, dist);

	float n1 = nz(tpos / 2300.0);
	float n2 = nz(tpos / 610.0 + 0.37);
	float n3 = mix(0.5, nz(tpos / 97.0 + 0.71), mid);
	float n4 = mix(0.5, nz(tpos / 13.0 + 0.19), near);

	// Farben linear (Palette der Stil-B-Vorschau, art/scripts/preview_scene.py)
	vec3 grass = mix(vec3(0.040, 0.085, 0.016), vec3(0.075, 0.110, 0.025), n1);
	grass *= 0.85 + 0.3 * n2;
	grass *= 0.93 + 0.14 * n3;

	// Felder: Flurstücke (große Voronoi-Zellen mit eigener Ausrichtung), darin
	// gestreckte Schläge mit verzogenen Rändern. Kein Raster, keine Drehung um den
	// Kartenursprung (sonst Strudel).
	vec2 warp = vec2(nz(tpos / 1700.0 + 0.11), nz(tpos / 1700.0 + 0.53)) - 0.5;
	vec2 fp = tpos + warp * 600.0;
	vec4 reg = voronoi(fp / 1900.0);
	float ang = reg.z * 3.14159;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 warp2 = vec2(nz(tpos / 420.0 + 0.27), nz(tpos / 420.0 + 0.81)) - 0.5;
	vec2 fq = rot * (fp + warp2 * 70.0) + reg.zw * 977.0;
	vec4 vc = voronoi(fq / mix(vec2(330.0, 190.0), vec2(260.0, 260.0), reg.w));
	float cell = vc.z;
	vec3 fcol;
	if (cell < 0.16) fcol = vec3(0.20, 0.16, 0.06);        // reifes Getreide
	else if (cell < 0.28) fcol = vec3(0.15, 0.12, 0.055);  // Stoppeln
	else if (cell < 0.46) fcol = vec3(0.05, 0.11, 0.018);  // junge Saat
	else if (cell < 0.60) fcol = vec3(0.10, 0.13, 0.03);   // Klee/Heu
	else if (cell < 0.70) fcol = vec3(0.11, 0.075, 0.04);  // gepflügt
	else fcol = grass * vec3(1.12, 1.06, 0.8);             // Weide
	fcol *= 0.85 + 0.3 * vc.w;
	fcol *= 0.9 + 0.2 * n3;
	// Bearbeitungsstreifen je Schlag (nur nah)
	float sang = vc.w * 3.14159;
	float stripe = sin(dot(fq, vec2(cos(sang), sin(sang))) * 0.8);
	fcol *= 1.0 + stripe * 0.06 * near * step(cell, 0.70);
	// Feldraine/Hecken an Schlag- und Flurgrenzen, lückig, mit der Entfernung dünner
	float hw = mix(0.05, 0.02, mid);
	float hedge = (1.0 - smoothstep(hw * 0.4, hw, vc.y)) * step(0.4, nz(tpos / 160.0));
	hedge = max(hedge, 1.0 - smoothstep(0.004, 0.012, reg.y));
	// ganze Schläge an/aus (Feldgrenzen statt weicher Flecken), Rand nur wenig weich
	float fields = smoothstep(0.5, 0.56, m.a * 0.9 + (vc.w - 0.5) * 0.5 + (n2 - 0.5) * 0.15);
	vec3 col = mix(grass, fcol, fields);
	col = mix(col, vec3(0.018, 0.04, 0.012), hedge * fields * 0.8 * mix(0.5, 1.0, mid));

	// Feuchte Aue
	col = mix(col, col * vec3(0.75, 0.95, 0.85), clamp(m.b * 1.5, 0.0, 1.0) * (1.0 - step(0.85, m.b)));

	// Wald: dunkle, fleckige Kronen, ausgefranster Rand
	float fedge = smoothstep(0.4, 0.6, m.r + (nz(tpos / 140.0 + 0.4) - 0.5) * 0.4);
	float crowns = mix(0.5, nz(tpos / 31.0 + 0.6), mid);
	vec3 forest = mix(vec3(0.016, 0.036, 0.012), vec3(0.040, 0.068, 0.020), crowns * 0.6 + n3 * 0.4);
	forest *= 0.8 + 0.4 * n2;
	col = mix(col, forest, fedge);

	// Gemähte Flächen (Flugplätze, Ziel-Plätze)
	vec3 mown = mix(vec3(0.06, 0.10, 0.022), vec3(0.085, 0.12, 0.03), n3) * (0.8 + 0.4 * n4);
	col = mix(col, mown, smoothstep(0.3, 0.8, m.g));

	// Fels nach Neigung und Höhe
	float rock = smoothstep(0.30, 0.48, slope + (n2 - 0.5) * 0.15);
	rock = max(rock, smoothstep(720.0, 900.0, th + n2 * 80.0) * smoothstep(0.08, 0.2, slope));
	vec3 rockc = mix(vec3(0.11, 0.10, 0.085), vec3(0.18, 0.16, 0.13), n3) * (0.85 + 0.3 * n4);
	col = mix(col, rockc, rock);

	// Wasser
	float water = smoothstep(0.8, 0.95, m.b);
	col = mix(col, vec3(0.02, 0.04, 0.045), water);

	ALBEDO = col * albedo_gain;
	ROUGHNESS = mix(0.95, 0.12, water);
	SPECULAR = mix(0.3, 0.6, water);
}
