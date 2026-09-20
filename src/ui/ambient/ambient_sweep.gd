class_name AmbientSweep
extends Node2D
## One narrow additive streak that crosses a rectangle: a glint travelling over
## painted brass, or a shimmer running down carved runes.
##
## The streak is masked by the painted art itself (the texture the rectangle
## sits on), so only bright brass or stone catches the light and dark wood or
## felt beside it stays untouched. An optional ellipse mask replaces the texture
## mask for round objects such as a roulette bowl. The node stays hidden, and
## costs nothing, between sweeps.

const SHADER_CODE := """
shader_type canvas_item;
render_mode blend_add;

uniform sampler2D mask_texture : filter_linear_mipmap, hint_default_white;
uniform bool use_mask_texture = false;
uniform vec2 view_size = vec2(960.0, 540.0);
uniform vec4 sweep_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 ellipse = vec4(0.0);
uniform float progress = -1.0;
uniform float strength = 0.0;
uniform float band = 0.1;
uniform float slant = 0.35;
uniform bool vertical = false;
uniform float warm_bias = 0.0;
uniform float band_height = 0.0;
uniform float band_transmission = 1.0;
uniform vec3 tint : source_color = vec3(1.0, 0.92, 0.74);

varying vec2 local_position;

void vertex() {
	local_position = VERTEX;
}

void fragment() {
	vec2 uv = (local_position - sweep_rect.xy) / sweep_rect.zw;
	float along = vertical ? uv.y + (uv.x - 0.5) * slant : uv.x + (uv.y - 0.5) * slant;
	float distance_to_streak = (along - progress) / band;
	float streak = exp(-distance_to_streak * distance_to_streak * 2.2);
	float mask = 1.0;
	if (use_mask_texture) {
		vec3 art = texture(mask_texture, local_position / view_size).rgb;
		float luminance = dot(art, vec3(0.299, 0.587, 0.114));
		mask = smoothstep(0.2, 0.6, luminance);
		mask *= mix(1.0, clamp((art.r - art.b) * 3.0, 0.0, 1.0), warm_bias);
	}
	if (ellipse.z > 0.0) {
		vec2 offset = (local_position - ellipse.xy) / ellipse.zw;
		mask *= 1.0 - smoothstep(0.72, 1.0, length(offset));
	}
	vec2 edge = min(uv, vec2(1.0) - uv);
	float fade = smoothstep(0.0, 0.06, min(edge.x, edge.y));
	float band_factor = local_position.y < band_height ? band_transmission : 1.0;
	COLOR = vec4(tint, streak * mask * fade * strength * band_factor);
}
"""

static var _shader: Shader

var rect := Rect2()
var progress: float = -1.0
var strength: float = 0.0
var _material: ShaderMaterial


static func shared_shader() -> Shader:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER_CODE
	return _shader


func _init() -> void:
	_material = ShaderMaterial.new()
	_material.shader = shared_shader()
	material = _material
	visible = false


## `mask` is the art under the rectangle, drawn at `view_size` from the origin.
func configure(
	area: Rect2,
	mask: Texture2D,
	tint: Color,
	options: Dictionary = {},
) -> void:
	rect = area
	_material.set_shader_parameter(
		"sweep_rect", Vector4(area.position.x, area.position.y, area.size.x, area.size.y)
	)
	_material.set_shader_parameter("use_mask_texture", mask != null)
	if mask != null:
		_material.set_shader_parameter("mask_texture", mask)
	_material.set_shader_parameter("tint", Vector3(tint.r, tint.g, tint.b))
	_material.set_shader_parameter("vertical", bool(options.get("vertical", false)))
	_material.set_shader_parameter("band", float(options.get("band", 0.1)))
	_material.set_shader_parameter("slant", float(options.get("slant", 0.35)))
	_material.set_shader_parameter("warm_bias", float(options.get("warm_bias", 0.0)))
	_material.set_shader_parameter("band_height", float(options.get("band_height", 0.0)))
	_material.set_shader_parameter(
		"band_transmission", float(options.get("band_transmission", 1.0))
	)
	var oval: Rect2 = options.get("ellipse", Rect2())
	_material.set_shader_parameter(
		"ellipse",
		Vector4(oval.get_center().x, oval.get_center().y, oval.size.x * 0.5, oval.size.y * 0.5)
	)
	queue_redraw()


## `at` runs from -0.2 (before the rectangle) to 1.2 (past it). A strength of
## zero hides the node entirely.
func show_progress(at: float, streak_strength: float) -> void:
	progress = at
	strength = clampf(streak_strength, 0.0, AmbientLayer.SWEEP_ALPHA_CAP)
	var active := strength > 0.0005
	if visible != active:
		visible = active
	if active:
		_material.set_shader_parameter(&"progress", progress)
		_material.set_shader_parameter(&"strength", strength)


func _draw() -> void:
	draw_rect(rect, Color.WHITE)
