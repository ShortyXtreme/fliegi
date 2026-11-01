shader_type spatial;
// Leuchtspur als Streifen entlang der Flugbahn, um die Bahnachse zur Kamera gedreht.
// Instanz-Transform: origin = Kopf (Geschoss), Spalte z = Vektor zum Schwanz (Länge = Streifen).
// Mindestbreite wächst mit der Entfernung, damit ferne Spuren ≥ 1–2 px bleiben.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform float width = 0.22;
uniform float min_angle = 0.004;
uniform float intensity = 1.6;

varying float v_along;
varying vec4 v_col;

void vertex() {
	vec3 head = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec3 axis = (MODEL_MATRIX * vec4(0.0, 0.0, 1.0, 0.0)).xyz;
	vec3 cam = INV_VIEW_MATRIX[3].xyz;
	vec3 p = head + axis * VERTEX.z;
	vec3 to_cam = cam - p;
	float d = max(length(to_cam), 0.001);
	vec3 side = cross(axis, to_cam / d);
	float sl = length(side);
	side = sl > 1e-5 ? side / sl : vec3(0.0, 1.0, 0.0);
	float w = max(width, d * min_angle);
	p += side * VERTEX.x * w;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(p, 1.0);
	v_along = VERTEX.z;
	v_col = COLOR;
}

void fragment() {
	float across = abs(UV.x * 2.0 - 1.0);
	float core = exp(-across * across * 3.0);
	float tail = 1.0 - v_along;
	ALBEDO = mix(v_col.rgb, vec3(1.0, 0.96, 0.82), core * core * tail) * intensity;
	ALPHA = clamp(v_col.a * (0.3 + 0.7 * core) * (0.35 + 0.65 * tail), 0.0, 1.0);
}
