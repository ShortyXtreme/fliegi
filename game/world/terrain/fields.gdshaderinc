// M3.7: Felder des Geländes (Schläge in Flurstücken) – gemeinsam für terrain.gdshader und
// grass.gdshader. VegetationGen.field_info() rechnet genau das auf der CPU nach (Baumreihen und
// Hecken auf den Grenzen): Permutations-Hash statt sin(), Verzerrung aus kleinen Texturen.
// Bei Änderungen beide Seiten anpassen.
uniform sampler2D warp_lo : filter_linear, repeat_enable;
uniform sampler2D warp_mid : filter_linear, repeat_enable;

// Permutations-Hash (mod 289), exakt in float32 für ganzzahlige Eingaben – gleich auf der CPU
float perm(float x) {
	return mod((34.0 * x + 1.0) * x, 289.0);
}

vec2 hash22(vec2 p) {
	p = mod(p, 289.0);
	return vec2(perm(perm(p.x) + p.y), perm(perm(p.y + 51.0) + p.x)) / 289.0;
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
	return vec4(sqrt(f1), sqrt(f2) - sqrt(f1), hash22(id + vec2(101.0, 37.0)));
}

// Nur die groben Oktaven: für Verzerrungen, sonst falten sich die Felder zu Klecksen
float wlo(vec2 p) {
	return (texture(warp_lo, p).r - 0.5) * 1.6 + 0.5;
}

float wmid(vec2 p) {
	return (texture(warp_mid, p).r - 0.5) * 1.6 + 0.5;
}

// Schlag an tpos (Gelände-Koordinaten): Rückgabe wie voronoi() (y = Abstand zur Schlaggrenze,
// z = Feldfrucht-Klasse, w = Ausrichtung/Helligkeit), reg = Flurstück, fq = Schlag-Koordinaten.
vec4 field_cell(vec2 tpos, out vec4 reg, out vec2 fq) {
	vec2 warp = vec2(wlo(tpos / 1700.0 + 0.11), wlo(tpos / 1700.0 + 0.53)) - 0.5;
	vec2 fp = tpos + warp * 220.0;
	reg = voronoi(fp / 1900.0);
	float ang = reg.z * 3.14159;
	mat2 rot = mat2(vec2(cos(ang), sin(ang)), vec2(-sin(ang), cos(ang)));
	vec2 warp2 = vec2(wmid(tpos / 420.0 + 0.27), wmid(tpos / 420.0 + 0.81)) - 0.5;
	fq = rot * (fp + warp2 * 14.0) + reg.zw * 977.0;
	return voronoi(fq / mix(vec2(310.0, 105.0), vec2(230.0, 150.0), reg.w));
}
