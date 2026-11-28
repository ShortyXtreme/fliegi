class_name GEffectOverlay
extends ColorRect
## M3.11: Bildschirmeffekt der g-Toleranz (PilotGTolerance) für den Spieler: Grauschleier
## mit Tunnelblick, Blackout (schwarz), Redout (rot). Liegt über dem 3D-Bild und dem HUD.
## Arcade: Effekt mit ARCADE_STRENGTH abgeschwächt. Einstellung „g-Effekte“ (GameSettings)
## schaltet ihn ab (enabled = false); die Grenzen gelten trotzdem (KI, Spieler-Pilot).

static var enabled := true
const ARCADE_STRENGTH := 0.55
const MAX_BLACK := 0.96

const SHADER := """
shader_type canvas_item;
uniform float grey = 0.0;
uniform float black = 0.0;
uniform float red = 0.0;
uniform float aspect = 1.777;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	float r = length(p) / (0.5 * length(vec2(aspect, 1.0)));
	// Tunnelblick: Rand dunkelt mit dem Grauschleier von außen nach innen zu
	float edge = 1.0 - grey * 0.75;
	float tunnel = smoothstep(edge - 0.35, edge + 0.05, r) * grey;
	float veil = grey * 0.30;
	float a_grey = clamp(max(tunnel, veil), 0.0, 1.0);
	vec3 col = mix(vec3(0.18), vec3(0.0), tunnel);
	float a = a_grey;
	// Redout: rote Tönung, am Rand stärker
	float a_red = red * (0.55 + 0.4 * smoothstep(0.2, 1.0, r));
	col = mix(col, vec3(0.45, 0.0, 0.0), clamp(a_red / max(a + a_red, 1e-3), 0.0, 1.0));
	a = max(a, a_red);
	// Blackout: alles schwarz
	col = mix(col, vec3(0.0), black);
	a = max(a, black);
	COLOR = vec4(col, a);
}
"""

var tolerance: PilotGTolerance = null
var strength := 1.0
var _mat: ShaderMaterial


func _init() -> void:
	name = "GEffectOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color(0, 0, 0, 0)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	material = _mat


## Werte für einen Frame (auch headless testbar). Rückgabe [grey, black, red] nach Stärke.
static func levels(t: PilotGTolerance, on: bool) -> Vector3:
	if t == null or not on:
		return Vector3.ZERO
	var k := ARCADE_STRENGTH if t.arcade else 1.0
	return Vector3(t.grey * k, minf(t.black * k, MAX_BLACK), t.red * k)


func update_from(t: PilotGTolerance) -> void:
	tolerance = t
	var l := levels(t, enabled)
	visible = l.length() > 0.001
	if not visible:
		return
	_mat.set_shader_parameter("grey", l.x)
	_mat.set_shader_parameter("black", l.y)
	_mat.set_shader_parameter("red", l.z)
	var sz := size if size.y > 0.0 else Vector2(16, 9)
	_mat.set_shader_parameter("aspect", sz.x / maxf(sz.y, 1.0))
