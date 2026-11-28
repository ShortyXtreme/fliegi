// M3.13: Detail-Ebene aus echten Boden-Texturen (Poly Haven, CC0) – gemeinsam für terrain.gdshader
// und ground_decal.gdshader. Texture2DArray mit 7 Ebenen (GroundTextures.L_*):
//   ter_col RGB Farbe (sRGB, AO eingerechnet), ter_nrm RG Normale (OpenGL, Y nach oben), B Rauheit, A Höhe.
// Die Textur wirkt als Verhältnis Textur / Mittelfarbe (ter_mean) auf die Großfarbe – der
// Flickenteppich und die Palette bleiben, aus der Nähe kommt die echte Struktur dazu.
// Gegen Kachelwiederholung: zwei Maßstäbe (A klein, B 3,3× größer und anders gedreht), je Ebene
// eigener Drehwinkel, Mischung nach Makro-Rauschen; Ebenen-Übergänge nach Höhe geschärft.
// Lage p in Metern (klein, lokal zur Kachel) + Versatz o (groß, nur als fract genutzt) – so bleibt
// die Genauigkeit auch 20 km vom Kartenmittelpunkt erhalten. Ableitungen außerhalb der Zweige (textureGrad).
uniform sampler2DArray ter_col : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray ter_nrm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 ter_mean[7];
uniform float tex_on = 0.0;
// Stufe Hoch: 2K-Farben der Nah-Ebenen (Index GD_HI, -1 = nur 1K)
uniform sampler2DArray ter_col_hi : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float tex_hi = 0.0;
// Stärke der Struktur und Anteil ihrer Eigenfarbe (0 = nur Helligkeit)
uniform float tex_strength = 1.0;
uniform float tex_chroma = 0.65;
uniform float tex_normal = 1.0;

// Kachelgröße je Ebene (m): Wiese, Waldboden, Laub, Schlamm, Fels, Sand, Erde
const float GD_SIZE[7] = float[7](4.0, 3.0, 2.5, 3.0, 6.0, 3.5, 3.0);
const float GD_B = 3.3;
const int GD_HI[7] = int[7](0, 1, 2, 3, -1, -1, 4);
const mat2 GD_ROT = mat2(vec2(0.276, -0.961), vec2(0.961, 0.276));   // -74°

mat2 gd_rot(float a) {
	return mat2(vec2(cos(a), sin(a)), vec2(-sin(a), cos(a)));
}

// Normale (0..1, OpenGL) -> Neigung in Lage-Koordinaten (x, z) bei Drehung R (uv = R·p/s)
vec2 gd_slope(vec4 n, mat2 R) {
	vec2 t = n.xy * 2.0 - 1.0;
	// u wächst mit +x der Bildzeilen, v nach unten; Grün zeigt nach oben (= -v)
	return transpose(R) * vec2(t.x, -t.y);
}

vec4 gd_col(int L, vec2 uv, vec2 gx, vec2 gy) {
	int hi = GD_HI[L];
	if (tex_hi > 0.5 && hi >= 0) {
		return textureGrad(ter_col_hi, vec3(uv, float(hi)), gx, gy);
	}
	return textureGrad(ter_col, vec3(uv, float(L)), gx, gy);
}

// Eine Ebene planar von oben. w = Gewicht, macro = Rauschen 0..1, fa = Anteil Maßstab A (Nähe).
// acc += (Verhältnis·w', w'), accn += (Neigung x/z·w', Rauheit·w')
void gd_layer(int L, float w, vec2 p, vec2 o, vec2 dpx, vec2 dpy, float macro, float fa,
		inout vec4 acc, inout vec3 accn) {
	float s = GD_SIZE[L];
	mat2 RA = gd_rot(float(L) * 0.9 + 0.3);
	mat2 RB = GD_ROT * RA;
	float sb = s * GD_B;
	vec3 cb = vec3(RB * p / sb + fract(RB * o / sb), float(L));
	vec4 colv = gd_col(L, cb.xy, RB * dpx / sb, RB * dpy / sb);
	vec4 nb = textureGrad(ter_nrm, cb, RB * dpx / sb, RB * dpy / sb);
	vec2 sl = gd_slope(nb, RB);
	vec4 nn = nb;
	float ka = fa * (1.0 - clamp(0.2 + 0.5 * macro, 0.0, 1.0));
	if (ka > 0.002) {
		vec3 ca = vec3(RA * p / s + fract(RA * o / s), float(L));
		vec4 cola = gd_col(L, ca.xy, RA * dpx / s, RA * dpy / s);
		vec4 na = textureGrad(ter_nrm, ca, RA * dpx / s, RA * dpy / s);
		colv = mix(colv, cola, ka);
		sl = mix(sl, gd_slope(na, RA), ka);
		nn = mix(nn, na, ka);
	}
	float wh = w * pow(0.15 + nn.a, 3.0);
	vec3 ratio = clamp(colv.rgb / max(ter_mean[L], vec3(0.004)), vec3(0.15), vec3(3.0));
	acc += vec4(ratio * wh, wh);
	accn += vec3(sl * wh, nn.b * wh);
}

// Ergebnis: Verhältnis gedämpft (Eigenfarbe nach tex_chroma, Stärke k)
vec3 gd_ratio(vec3 r, float k) {
	float l = dot(r, vec3(0.2126, 0.7152, 0.0722));
	return mix(vec3(1.0), mix(vec3(l), r, tex_chroma), k * tex_strength);
}

// Welt-Normale aus Neigung g (Welt, xyz) um die Flächen-Normale N (UDN-Mischung)
vec3 gd_normal(vec3 N, vec3 g, float k) {
	g *= k * tex_normal;
	return normalize(N + g - N * dot(g, N));
}
