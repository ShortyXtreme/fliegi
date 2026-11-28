shader_type spatial;
// M3.13: Holz für Hallenwände/-tore, Schuppen, Flugleitung, Zaun – weathered_brown_planks bzw.
// wood_peeling_paint_weathered (Poly Haven, CC0). Triplanar im Objektraum (Box-Mapping, die Modelle
// aus den Blender-Skripten bzw. BoxMesh brauchen keine passenden UVs). Bretter waagerecht oder
// senkrecht (vertical). Unten Spritzschmutz. Ohne Textur (Stufe Niedrig): Grundfarbe tint.
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D wood_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_nrm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 wood_mean = vec3(0.1, 0.07, 0.05);
uniform float tex_on = 0.0;
// Grundfarbe (linear): ohne Textur, und als Tönung mit tint_mix (0 = Farbe der Textur)
uniform vec3 tint : source_color = vec3(0.33, 0.24, 0.16);
uniform float tint_mix = 0.0;
uniform float gain = 1.0;
uniform float size = 2.2;
uniform bool vertical = false;
uniform float mud_h = 0.5;
// Bodenhöhe im Objektraum (BoxMesh: -Höhe/2)
uniform float ground_y = 0.0;

varying vec3 lpos;
varying vec3 lnrm;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}

// Projektion mit Achsen a (u) und b (v, Bild nach unten): Farbe, Normale, Neigung im Objektraum
void proj(vec3 q, vec3 a, vec3 b, float w, inout vec3 c, inout vec4 n, inout vec3 g) {
	vec2 uv = vec2(dot(q, a), dot(q, b));
	vec4 nn = texture(wood_nrm, uv);
	c += texture(wood_col, uv).rgb * w;
	n += nn * w;
	vec2 t = nn.xy * 2.0 - 1.0;
	g += (a * t.x - b * t.y) * w;
}

void fragment() {
	vec3 n = normalize(lnrm);
	vec3 base = tint;
	float rough = 0.85;
	if (tex_on > 0.5) {
		vec3 bw = pow(abs(n), vec3(8.0));
		bw /= bw.x + bw.y + bw.z;
		vec3 q = lpos / size;
		vec3 c = vec3(0.0);
		vec4 nn = vec4(0.0);
		vec3 g = vec3(0.0);
		vec3 up = vec3(0.0, -1.0, 0.0);   // v nach unten = Welt nach unten (Bild aufrecht)
		if (vertical) {
			proj(q, vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), bw.x, c, nn, g);
			proj(q, vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), bw.z, c, nn, g);
		} else {
			proj(q, vec3(0.0, 0.0, 1.0), up, bw.x, c, nn, g);
			proj(q, vec3(1.0, 0.0, 0.0), up, bw.z, c, nn, g);
		}
		proj(q, vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), bw.y, c, nn, g);
		vec3 r = clamp(c / max(wood_mean, vec3(0.004)), vec3(0.1), vec3(4.0));
		base = mix(c * gain, tint * r, tint_mix);
		rough = nn.b;
		// AO aus der Textur (A) leicht
		base *= mix(1.0, nn.a, 0.35);
		vec3 nobj = normalize(n + g - n * dot(g, n));
		NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(nobj, 0.0)).xyz);
	}
	// Spritzschmutz unten
	float mud = (1.0 - smoothstep(0.0, mud_h, lpos.y - ground_y)) * 0.55;
	base = mix(base, vec3(0.045, 0.035, 0.025), mud);
	ALBEDO = base;
	ROUGHNESS = mix(rough, 1.0, mud);
	SPECULAR = 0.3;
}
