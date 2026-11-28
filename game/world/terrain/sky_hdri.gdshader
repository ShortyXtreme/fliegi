shader_type sky;
// M3.13: Himmel aus zwei HDRI-Panoramen (Poly Haven, CC0): klar (kloofendal_48d_partly_cloudy) und
// bedeckt (quarry_cloudy), überblendet nach der Bedeckung aus dem Wetter (TerrainWorld._update_sky).
// Die Sonne im Panorama ist auf eine Leuchtdichte von 24 begrenzt (tools/prep_polyhaven.py) – das
// direkte Licht kommt von der DirectionalLight3D. Unter dem Horizont Dunstfarbe statt des fremden
// Bodens im Foto (die Karte endet nach 20 km im Nebel).

uniform sampler2D sky_clear : filter_linear, repeat_enable, hint_default_black;
uniform sampler2D sky_overcast : filter_linear, repeat_enable, hint_default_black;
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform float energy_clear = 1.0;
uniform float energy_overcast = 0.5;
// Drehung des bedeckten Panoramas (Anteil einer Umdrehung), damit sein hellster Fleck zur Sonne passt
uniform float u_offset_overcast = 0.0;
uniform vec3 below_color = vec3(0.34, 0.37, 0.45);

void sky() {
	vec2 uv = SKY_COORDS;
	vec3 c = texture(sky_clear, uv).rgb * energy_clear;
	if (overcast > 0.001) {
		vec3 o = texture(sky_overcast, uv + vec2(u_offset_overcast, 0.0)).rgb * energy_overcast;
		c = mix(c, o, overcast);
	}
	float below = smoothstep(0.0, -0.08, EYEDIR.y);
	COLOR = mix(c, below_color * mix(1.0, 0.7, overcast), below);
}
