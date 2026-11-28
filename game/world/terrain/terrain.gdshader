shader_type spatial;
// Gelände-Kacheln (Paket 12, M3.7). Die Höhen kommen aus derselben Höhenkarte wie die
// Physik (texelFetch, gleiche Dreiecksteilung im LOD 0). Oberfläche nach Höhe, Neigung
// und Bodenmaske: Wiese, Felder (Voronoi mit verzogenen Rändern, Hecken), Erde, Wald,
// Fels (triplanar), Sand/Kies am Wasser, Wasser.
// M3.7: Detail-Kacheln aus der Nähe (zwei Maßstäbe, gegeneinander gedreht und per Makro-
// Rauschen gemischt gegen sichtbare Wiederholung), Normal-Detail, Höhenstufen, Feldfrüchte.
// M3.13: echte Boden-Texturen als Detail-Ebene (ground_detail.gdshaderinc, GroundTextures):
// Wiese/Feldrand aerial_grass_rock, Waldboden forest_ground_04 + leaves_forest_ground, Ufer/Schlamm
// brown_mud_leaves_01, Fels rocks_ground_02 (triplanar), Sand/Kies coast_sand_rocks_02, offene
// Erde/Acker dirt_floor. Die Ebenen-Gewichte laufen parallel zur Großfarbe mit (wa, wb). Stufe
// Niedrig (tex_on = 0): die prozeduralen Kacheln wie bisher.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D heightmap : filter_nearest, repeat_disable;
uniform sampler2D mask_tex : filter_linear_mipmap, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
// M3.7: kleine kachelbare Detail-Texturen (zur Laufzeit erzeugt, siehe TerrainWorld._material)
uniform sampler2D detail_tex : filter_linear_mipmap_anisotropic, repeat_enable;   // feines fBm
uniform sampler2D cell_tex : filter_linear_mipmap_anisotropic, repeat_enable;     // Zellen (Schollen, Steine, Risse)
uniform sampler2D detail_nrm : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// M3.8: Uferabstand (R: 64 + 2 · m, < 64 im Wasser, 255 = kein Gewässer), Wasserspiegel (G/B 16 bit · 1/64 m),
// A = 1 am Bach. Je Höhenpunkt (samples²), siehe TerrainGenerator._build_shore.
uniform sampler2D shore_tex : filter_linear, repeat_disable;
// M3.7: Felder (Schläge, Flurstücke) – gemeinsam mit dem Gras-Shader, auf der CPU nachgerechnet
#include "res://world/terrain/fields.gdshaderinc"
#include "res://world/terrain/ground_detail.gdshaderinc"
uniform float spacing = 19.53125;
uniform float half_size = 20000.0;
uniform int samples = 2049;
uniform int tile_cells = 128;
uniform float skirt_depth = 40.0;
// Palette ist auf Cycles-Licht der Vorschau abgestimmt; Godot-Sonne ist schwächer
uniform float albedo_gain = 2.1;
// M3.7: Radius, in dem echte Bäume stehen (Vegetation); darin zeigt der Waldboden statt
// der Kronen-Farbe. 0 = keine Bäume (Kronen-Farbe überall).
uniform float tree_radius = 0.0;

// Szenen-Lage des Gelände-Bezugs (verschiebt sich mit Floating Origin); die Kachel
// ergibt sich aus der Knotenlage (keine Instanz-Uniforms, die im Kompatibilitäts-
// Renderer bei vielen Instanzen fehlschlagen).
uniform vec3 terrain_origin = vec3(0.0);
uniform float lod_step = 1.0;

varying vec2 tpos;
varying float th;
// M3.13: Lage in der Kachel (m, genau) und Kachel-Ursprung (m ab Kartenrand)
varying vec2 tloc;
varying flat vec2 tile_o;

float H(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(samples - 1));
	return texelFetch(heightmap, p, 0).r;
}

void vertex() {
	float tile_m = float(tile_cells) * spacing;
	vec2 tile_idx = round((NODE_POSITION_WORLD.xz - terrain_origin.xz + half_size) / tile_m - 0.5);
	ivec2 g = ivec2(tile_idx) * tile_cells + ivec2(round(VERTEX.xz));
	tloc = vec2(round(VERTEX.xz)) * spacing;
	tile_o = tile_idx * tile_m;
	float h = H(g);
	int s = int(lod_step);
	float hl = H(g - ivec2(s, 0));
	float hr = H(g + ivec2(s, 0));
	float hd = H(g - ivec2(0, s));
	float hu = H(g + ivec2(0, s));
	NORMAL = normalize(vec3(hl - hr, 2.0 * spacing * float(s), hd - hu));
	// Tangentenraum für das Normal-Detail: u = Welt-x, v = Welt-z
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(cross(TANGENT, NORMAL));
	float half_cells = float(tile_cells) * 0.5;
	VERTEX = vec3((VERTEX.x - half_cells) * spacing, h - VERTEX.y * skirt_depth, (VERTEX.z - half_cells) * spacing);
	tpos = vec2(g) * spacing - half_size;
	th = h;
}

// Nicht-ganzzahlige Eingaben (nur Optik, nicht nachgerechnet)
vec2 hash22f(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

float nz(vec2 p) {
	return texture(noise_tex, p).r;
}

const mat2 ROT_A = mat2(vec2(0.799, 0.602), vec2(-0.602, 0.799));   // 37°
const mat2 ROT_B = mat2(vec2(0.276, -0.961), vec2(0.961, 0.276));   // -74°

// Detail-Kachel in zwei Maßstäben, gedreht, je nach Makro-Rauschen gemischt (gegen Wiederholung)
float detail(sampler2D t, vec2 p, float scale, float macro) {
	float a = texture(t, p / scale).r;
	float b = texture(t, ROT_A * p / (scale * 2.7) + 0.31).r;
	return mix(a, b, clamp(0.25 + 0.5 * macro, 0.0, 1.0));
}

void fragment() {
	vec3 wn = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float slope = 1.0 - wn.y;
	vec2 muv = (tpos + half_size) / (2.0 * half_size);
	vec4 m = texture(mask_tex, muv);
	float dist = length(VERTEX);
	// feine Details mit der Entfernung ausblenden (gegen Flimmern)
	float close = 1.0 - smoothstep(60.0, 400.0, dist);
	float near = 1.0 - smoothstep(600.0, 2500.0, dist);
	float mid = 1.0 - smoothstep(3000.0, 9000.0, dist);

	float n1 = nz(tpos / 2300.0);
	float n2 = nz(tpos / 610.0 + 0.37);
	float n3 = mix(0.5, nz(tpos / 97.0 + 0.71), mid);
	float n4 = mix(0.5, nz(tpos / 13.0 + 0.19), near);
	// Detail aus der Nähe: fBm (Grasbüschel, Erdkrume) und Zellen (Schollen, Steine)
	// M3.13: mit echten Texturen nur noch schwach (sonst doppelte Struktur)
	float pclose = close * (1.0 - 0.75 * tex_on);
	float d1 = mix(0.5, detail(detail_tex, tpos, 3.1, n2), pclose);
	float d2 = mix(0.5, detail(cell_tex, tpos, 1.7, n3), pclose);
	float d3 = mix(0.5, detail(detail_tex, ROT_B * tpos, 0.9, n4), pclose * pclose);

	// Farben linear (Palette der Stil-B-Vorschau, art/scripts/preview_scene.py)
	vec3 grass = mix(vec3(0.040, 0.085, 0.016), vec3(0.075, 0.110, 0.025), n1);
	grass *= 0.85 + 0.3 * n2;
	grass *= 0.93 + 0.14 * n3;
	// Höhenstufen: in den Tälern satt, oben trockener und bräunlicher (Bergwiese)
	float alt = smoothstep(350.0, 750.0, th + (n1 - 0.5) * 160.0);
	grass = mix(grass, grass * vec3(1.35, 1.05, 0.75) + vec3(0.02, 0.008, 0.0), alt);
	// Gras-Detail: dunkle Büschel, trockene Halme, Blühflecken (nur nah)
	vec3 grass_d = grass * (0.72 + 0.56 * d1) * (0.9 + 0.2 * d3);
	grass_d = mix(grass_d, grass_d * vec3(1.6, 1.35, 0.7), smoothstep(0.62, 0.8, d3) * 0.5 * close);
	grass = grass_d;

	// Erde (offener Boden): Krume mit Schollen
	vec3 soil = mix(vec3(0.085, 0.060, 0.038), vec3(0.13, 0.095, 0.06), n3) * (0.75 + 0.5 * d1);
	soil *= 0.85 + 0.3 * smoothstep(0.2, 0.6, d2);
	// M3.13: Ebenen-Gewichte (wa: Wiese, Waldboden, Laub, Schlamm; wb: Fels, Sand, Erde, –)
	const vec4 GA = vec4(1.0, 0.0, 0.0, 0.0);
	const vec4 ZA = vec4(0.0);
	const vec4 DB = vec4(0.0, 0.0, 1.0, 0.0);
	vec4 wa = GA;
	vec4 wb = ZA;

	// Felder: Flurstücke (große Voronoi-Zellen mit eigener Ausrichtung), darin
	// gestreckte Schläge mit verzogenen Rändern. Kein Raster, keine Drehung um den
	// Kartenursprung (sonst Strudel).
	vec4 reg;
	vec2 fq;
	vec4 vc = field_cell(tpos, reg, fq);
	float cell = vc.z;
	// Bearbeitungsrichtung je Schlag
	float sang = vc.w * 3.14159;
	vec2 sdir = vec2(cos(sang), sin(sang));
	float row = dot(fq, sdir);
	vec3 fcol;
	float furrow = 0.0;   // Stärke der Reihen/Furchen
	float fdirt = 0.0;    // M3.13: Anteil Erde (dirt_floor) statt Wiese in der Detail-Ebene
	if (cell < 0.14) {           // reifes Getreide (Weizen/Roggen)
		fcol = vec3(0.21, 0.165, 0.065) * (0.85 + 0.3 * d1);
		furrow = 0.25;
		fdirt = 0.35;
	} else if (cell < 0.25) {    // Stoppeln mit Strohresten
		fcol = vec3(0.19, 0.17, 0.11) * (0.8 + 0.4 * smoothstep(0.3, 0.7, d3));
		fcol = mix(fcol, soil, 0.15);
		furrow = 0.4;
		fdirt = 0.55;
	} else if (cell < 0.40) {    // junge Saat (Reihen auf Erde)
		float srow = 0.15 + 0.35 * close * (0.5 + 0.5 * sin(row * 4.2));
		fcol = mix(vec3(0.035, 0.085, 0.022), soil, srow);
		furrow = 0.3;
		fdirt = 0.3 + srow;
	} else if (cell < 0.50) {    // Klee/Heu
		fcol = vec3(0.10, 0.15, 0.035) * (0.8 + 0.4 * d1);
		furrow = 0.1;
	} else if (cell < 0.57) {    // Rüben/Kartoffeln (dunkelgrüne Reihen)
		float srow = 0.3 + 0.4 * close * smoothstep(0.2, 0.9, sin(row * 2.1));
		fcol = mix(vec3(0.03, 0.07, 0.02), soil, srow);
		furrow = 0.35;
		fdirt = srow;
	} else if (cell < 0.67) {    // gepflügt (Furchen)
		fcol = soil * vec3(1.1, 1.0, 0.95);
		furrow = 0.9;
		fdirt = 1.0;
	} else if (cell < 0.69) {    // Senf/Raps (selten, gelb)
		fcol = vec3(0.22, 0.19, 0.045) * (0.85 + 0.3 * d1);
		furrow = 0.1;
	} else {
		fcol = grass * vec3(1.12, 1.06, 0.8);   // Weide
	}
	fcol *= 0.78 + 0.44 * vc.w;
	fcol *= vec3(1.0 + 0.16 * (hash22f(vc.zw * 7.1).x - 0.5), 1.0, 1.0 + 0.2 * (hash22f(vc.zw * 3.3).y - 0.5));
	fcol *= 0.9 + 0.2 * n3;
	// Bearbeitungsstreifen (mittlere Entfernung) und Furchen (nah)
	float stripe = sin(row * 0.8);
	fcol *= 1.0 + stripe * 0.06 * near * step(cell, 0.70);
	fcol *= 1.0 - furrow * 0.25 * close * smoothstep(-0.2, 0.9, sin(row * 6.0 + d1 * 2.0));
	// Feldraine/Hecken an Schlag- und Flurgrenzen, lückig, mit der Entfernung dünner
	float hw = mix(0.05, 0.02, mid);
	float hedge = (1.0 - smoothstep(hw * 0.4, hw, vc.y)) * step(0.4, nz(tpos / 160.0));
	hedge = max(hedge, 1.0 - smoothstep(0.004, 0.012, reg.y));
	// Grasrain zwischen den Schlägen (schmaler als die Hecke, immer da)
	float verge = 1.0 - smoothstep(hw * 0.25, hw * 0.55, vc.y);
	fcol = mix(fcol, grass * 1.1, verge * 0.8);
	fdirt *= 1.0 - verge * 0.8;
	// ganze Schläge an/aus (Feldgrenzen statt weicher Flecken), Rand nur wenig weich
	float fields = smoothstep(0.5, 0.56, m.a * 0.9 + (vc.w - 0.5) * 0.5 + (n2 - 0.5) * 0.15);
	// Wiesen-Parzellen außerhalb der Felder: gemähte Heuwiese heller, Weide dunkler
	vec3 meadow = grass * mix(vec3(0.86, 0.9, 0.9), vec3(1.18, 1.12, 0.88), smoothstep(0.3, 0.7, vc.w));
	meadow = mix(meadow, grass, verge);
	vec3 col = mix(meadow, fcol, fields);
	wa = mix(GA, vec4(1.0 - fdirt, 0.0, 0.0, 0.0), fields);
	wb = mix(ZA, DB * fdirt, fields);
	// Schlaggrenzen als feine dunkle Linien (Furche/Rain) – macht den Flickenteppich lesbar
	col *= 1.0 - (1.0 - smoothstep(hw * 0.3, hw * 0.9, vc.y)) * mix(0.15, 0.35, fields);
	col *= 1.0 - (1.0 - smoothstep(hw * 0.2, hw * 0.7, vc.y)) * 0.18 * mid * (1.0 - fields);
	float hk = hedge * fields * 0.8 * mix(0.5, 1.0, mid);
	col = mix(col, vec3(0.018, 0.04, 0.012) * (0.8 + 0.4 * d1), hk);
	wa = mix(wa, vec4(0.0, 0.0, 1.0, 0.0), hk);
	wb = mix(wb, ZA, hk);

	// Offene Erde: Viehtritt/Gatter auf Weiden, Hangabbrüche an mittleren Neigungen
	float bare = smoothstep(0.74, 0.86, nz(tpos / 55.0 + 0.13) * 0.7 + n2 * 0.3) * (1.0 - fields) * 0.7;
	bare = max(bare, smoothstep(0.17, 0.30, slope + (d1 - 0.5) * 0.08 * close + (n3 - 0.5) * 0.1) * 0.8);
	col = mix(col, soil, bare * (1.0 - m.g));
	wa = mix(wa, ZA, bare * (1.0 - m.g));
	wb = mix(wb, DB, bare * (1.0 - m.g));

	// Feuchte Aue
	col = mix(col, col * vec3(0.75, 0.95, 0.85), clamp(m.b * 1.5, 0.0, 1.0) * (1.0 - step(0.85, m.b)));

	// Wald: dunkle, fleckige Kronen, ausgefranster Rand. Im Baum-Radius Waldboden
	// (Laub, Nadelstreu, Moos) – die Bäume stehen dann als Modelle darauf.
	float fedge = smoothstep(0.4, 0.6, m.r + (nz(tpos / 140.0 + 0.4) - 0.5) * 0.4);
	float crowns = mix(0.5, mix(nz(tpos / 31.0 + 0.6), nz(tpos / 8.0 + 0.2), near * 0.6), mid);
	vec3 forest = mix(vec3(0.016, 0.036, 0.012), vec3(0.040, 0.068, 0.020), crowns * 0.6 + n3 * 0.4);
	forest *= 0.8 + 0.4 * n2;
	vec3 floor_c = mix(vec3(0.05, 0.04, 0.022), vec3(0.035, 0.055, 0.02), smoothstep(0.35, 0.65, d1 * 0.6 + n4 * 0.4));
	floor_c *= 0.8 + 0.4 * d2;
	float fl = tree_radius > 0.0 ? 1.0 - smoothstep(tree_radius * 0.75, tree_radius, dist) : 0.0;
	col = mix(col, mix(forest, floor_c, fl), fedge);
	// Waldboden: Nadelstreu/Moos und Laub nach Rauschen gemischt
	float leafk = smoothstep(0.35, 0.65, nz(tpos / 47.0 + 0.83));
	wa = mix(wa, vec4(0.0, 1.0 - leafk, leafk, 0.0), fedge);
	wb = mix(wb, ZA, fedge);

	// Gemähte Flächen (Flugplätze, Ziel-Plätze)
	vec3 mown = mix(vec3(0.06, 0.10, 0.022), vec3(0.085, 0.12, 0.03), n3) * (0.8 + 0.4 * n4);
	mown *= 0.82 + 0.36 * d1;
	float mk = smoothstep(0.3, 0.8, m.g);
	col = mix(col, mown, mk);
	wa = mix(wa, GA, mk);
	wb = mix(wb, ZA, mk);

	// Fels nach Neigung und Höhe, triplanar (sonst an Steilhängen verzogen)
	float rock = smoothstep(0.30, 0.48, slope + (n2 - 0.5) * 0.15);
	rock = max(rock, smoothstep(720.0, 900.0, th + n2 * 80.0) * smoothstep(0.08, 0.2, slope));
	vec3 wp = vec3(tpos.x, th, tpos.y);
	vec3 bw = pow(abs(wn), vec3(4.0));
	bw /= bw.x + bw.y + bw.z;
	float rc = texture(cell_tex, wp.zy / 7.0).r * bw.x + texture(cell_tex, wp.xz / 7.0).r * bw.y
		+ texture(cell_tex, wp.xy / 7.0).r * bw.z;
	float rf = texture(detail_tex, wp.zy / 2.3).r * bw.x + texture(detail_tex, wp.xz / 2.3).r * bw.y
		+ texture(detail_tex, wp.xy / 2.3).r * bw.z;
	rc = mix(0.5, rc, near);
	rf = mix(0.5, rf, close);
	vec3 rockc = mix(vec3(0.11, 0.10, 0.085), vec3(0.18, 0.16, 0.13), n3) * (0.85 + 0.3 * n4);
	rockc *= (0.7 + 0.5 * smoothstep(0.05, 0.35, rc)) * (0.85 + 0.3 * rf);
	// Flechten/Moos in den Fugen
	rockc = mix(rockc, vec3(0.05, 0.065, 0.03), (1.0 - smoothstep(0.03, 0.15, rc)) * 0.4 * near);
	col = mix(col, rockc, rock);
	wa = mix(wa, ZA, rock);
	wb = mix(wb, vec4(1.0, 0.0, 0.0, 0.0), rock);

	// M3.8: Ufer und Flussbett aus dem Gewässernetz (Wasser selbst: water.gdshader)
	vec2 suv = (tpos + half_size) / spacing;
	float sr = texture(shore_tex, (suv + 0.5) / float(samples)).r * 255.0;
	float edge = (sr - 64.0) * 0.5;               // m zur Wasserkante, < 0 im Lauf
	ivec2 si = clamp(ivec2(round(suv)), ivec2(0), ivec2(samples - 1));
	vec4 sx = texelFetch(shore_tex, si, 0);
	float wlevel = (sx.g * 255.0 * 256.0 + sx.b * 255.0) / 64.0;
	float is_stream = sx.a;
	float wdepth = sr < 254.0 ? wlevel - th : -10.0;
	float n_sh = (n4 - 0.5) * 2.0 + (d1 - 0.5) * close;
	float flat_k = 1.0 - smoothstep(0.10, 0.28, slope);
	// nasser Schlamm direkt an der Kante, Kies-/Sandbänke auf flachem Ufer, sonst Lehm
	vec3 mud = mix(vec3(0.055, 0.045, 0.032), vec3(0.075, 0.062, 0.042), d1) * (0.85 + 0.3 * n3);
	vec3 gravel = mix(vec3(0.17, 0.155, 0.125), vec3(0.12, 0.11, 0.09), smoothstep(0.25, 0.65, d2)) * (0.8 + 0.4 * d1);
	vec3 sand = mix(vec3(0.21, 0.185, 0.13), vec3(0.16, 0.14, 0.10), smoothstep(0.2, 0.6, d2)) * (0.85 + 0.3 * d1);
	vec3 bank = mix(gravel, sand, smoothstep(0.35, 0.65, nz(tpos / 140.0 + 0.3)) * (1.0 - is_stream));
	float bank_w = mix(7.0, 3.5, is_stream) + 3.0 * n_sh;
	// Kies-/Sandbänke nur stellenweise (sonst Wiese bis ans Wasser)
	float bars = smoothstep(0.55, 0.68, nz(tpos / 210.0 + 0.71) + (n2 - 0.5) * 0.3);
	float bank_k = (1.0 - smoothstep(bank_w, bank_w + 3.0, edge)) * flat_k * (1.0 - rock) * mix(bars, 0.7, is_stream);
	col = mix(col, bank, bank_k);
	wa = mix(wa, ZA, bank_k);
	wb = mix(wb, vec4(0.0, 1.0, 0.0, 0.0), bank_k);
	float mud_k = (1.0 - smoothstep(0.3 + 0.8 * n_sh, 1.6 + 1.2 * n_sh, edge)) * (1.0 - rock * 0.6) * (1.0 - bank_k * 0.7);
	// Uferwiese satter/dunkler (Röhricht, Hochstauden)
	col = mix(col, col * vec3(0.8, 1.0, 0.75), (1.0 - smoothstep(3.0, 18.0, edge)) * (1.0 - bank_k) * (1.0 - rock));
	col = mix(col, mud, mud_k);
	// Böschung (steil am Wasser): Lehm statt Gras
	float bk = (1.0 - smoothstep(4.0, 12.0, edge)) * (1.0 - flat_k) * (1.0 - rock);
	col = mix(col, soil * 0.9, bk);
	const vec4 MA = vec4(0.0, 0.0, 0.0, 1.0);
	wa = mix(wa, MA, max(mud_k, bk));
	wb = mix(wb, ZA, max(mud_k, bk));
	// Flussbett unter Wasser: Schlick und Steine, tiefer dunkler
	float under = smoothstep(-0.05, 0.12, wdepth) * step(sr, 250.0);
	vec3 bed = mix(vec3(0.09, 0.08, 0.06), vec3(0.04, 0.045, 0.035), smoothstep(0.3, 2.5, wdepth));
	bed *= 0.75 + 0.5 * smoothstep(0.3, 0.7, d2);
	col = mix(col, bed, under);
	wa = mix(wa, MA, under);
	wb = mix(wb, ZA, under);
	float water = under * smoothstep(0.2, 1.5, wdepth);

	// M3.13: Detail-Ebene aus echten Texturen (Maßstab A bis ~450 m, B bis ~1,4 km)
	vec2 dpx = dFdx(tloc);
	vec2 dpy = dFdy(tloc);
	vec3 dwx = dFdx(wp);
	vec3 dwy = dFdy(wp);
	float fa = 1.0 - smoothstep(120.0, 450.0, dist);
	float fb = 1.0 - smoothstep(350.0, 1400.0, dist);
	float rough_t = 0.95;
	vec3 nw = wn;
	if (tex_on > 0.5 && fb > 0.001) {
		vec4 acc = vec4(0.0);
		vec3 accn = vec3(0.0);
		vec3 accg = vec3(0.0);
		float ws[7] = float[7](wa.x, wa.y, wa.z, wa.w, wb.x, wb.y, wb.z);
		for (int L = 0; L < 7; L++) {
			if (L == 4 || ws[L] < 0.02) {
				continue;
			}
			gd_layer(L, ws[L], tloc, tile_o, dpx, dpy, n2, fa, acc, accn);
		}
		accg = vec3(accn.x, 0.0, accn.y);
		// Fels triplanar (Steilhänge), ein Maßstab je Projektion
		if (ws[4] >= 0.02) {
			float s = GD_SIZE[4];
			vec3 wl = vec3(tloc.x, th, tloc.y);
			vec3 wo = fract(vec3(tile_o.x, 0.0, tile_o.y) / s) * s;
			vec3 q = (wl + wo) / s;
			vec4 cx = textureGrad(ter_col, vec3(q.zy, 4.0), dwx.zy / s, dwy.zy / s);
			vec4 nx = textureGrad(ter_nrm, vec3(q.zy, 4.0), dwx.zy / s, dwy.zy / s);
			vec4 cy = textureGrad(ter_col, vec3(q.xz, 4.0), dwx.xz / s, dwy.xz / s);
			vec4 ny = textureGrad(ter_nrm, vec3(q.xz, 4.0), dwx.xz / s, dwy.xz / s);
			vec4 cz = textureGrad(ter_col, vec3(q.xy, 4.0), dwx.xy / s, dwy.xy / s);
			vec4 nzz = textureGrad(ter_nrm, vec3(q.xy, 4.0), dwx.xy / s, dwy.xy / s);
			vec3 rcol = cx.rgb * bw.x + cy.rgb * bw.y + cz.rgb * bw.z;
			vec4 rn = nx * bw.x + ny * bw.y + nzz * bw.z;
			vec2 tx = nx.xy * 2.0 - 1.0;
			vec2 ty = ny.xy * 2.0 - 1.0;
			vec2 tz = nzz.xy * 2.0 - 1.0;
			vec3 g = vec3(0.0, -tx.y, tx.x) * bw.x + vec3(ty.x, 0.0, -ty.y) * bw.y + vec3(tz.x, -tz.y, 0.0) * bw.z;
			float wh = ws[4] * pow(0.15 + rn.a, 3.0);
			acc += vec4(clamp(rcol / max(ter_mean[4], vec3(0.004)), vec3(0.15), vec3(3.0)) * wh, wh);
			accn.z += rn.b * wh;
			accg += g * wh;
		}
		if (acc.w > 1e-4) {
			col *= gd_ratio(acc.rgb / acc.w, fb);
			rough_t = mix(0.95, accn.z / acc.w, fb);
			nw = gd_normal(wn, accg / acc.w, fb * (1.0 - water));
		}
	}

	ALBEDO = col * albedo_gain;
	ROUGHNESS = mix(rough_t, 0.35, max(water, mud_k * 0.7));
	SPECULAR = mix(0.3, 0.5, max(water, mud_k * 0.5));
	// Normal-Detail nah (Fels stärker), auf Wasser keines; M3.13: mit Texturen aus der Detail-Ebene
	NORMAL_MAP = texture(detail_nrm, tpos / 3.1).rgb;
	NORMAL_MAP_DEPTH = close * mix(0.6, 1.6, max(rock, bare)) * (1.0 - water) * (1.0 - tex_on);
	if (tex_on > 0.5) {
		NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	}
}
