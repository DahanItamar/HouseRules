class_name CabinetWinFlash
extends ColorRect
## Shared finite outcome-light sweep for every cabinet.
##
## Explicit Tween-driven uniforms keep timing deterministic and work in the
## shipped GL Compatibility renderer without screen-texture dependencies.

const SHADER_SOURCE := """
shader_type canvas_item;
render_mode unshaded, blend_add;

uniform float energy : hint_range(0.0, 1.0) = 0.0;
uniform float sweep : hint_range(-0.2, 1.2) = -0.15;
uniform vec4 tint : source_color = vec4(1.0, 0.78, 0.30, 1.0);

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float diagonal = UV.x + UV.y * 0.32;
	float beam = 1.0 - smoothstep(0.0, 0.12, abs(diagonal - sweep));
	float edge = smoothstep(0.30, 0.72, length(centered));
	float focus = 1.0 - smoothstep(0.10, 0.74, length(centered));
	float intensity = energy * (beam * 0.66 + edge * 0.20 + focus * 0.14);
	COLOR = vec4(tint.rgb * intensity, intensity * tint.a);
}
"""

var energy_value: float = 0.0
var sweep_value: float = -0.15
var last_tint := Color("f2c84b")
var last_big: bool = false
var _motion: Tween
var _shader_material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = Color.WHITE
	_install_shader()
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	settle()


func play(tint_color: Color, big: bool) -> void:
	settle()
	last_tint = tint_color
	last_big = big
	visible = true
	_shader_material.set_shader_parameter("tint", tint_color)
	if MotionPolicy.is_reduced():
		_set_sweep(0.5)
		_set_energy(0.28)
		_motion = create_tween()
		_motion.tween_interval(MotionPolicy.finite_duration(0.12))
		_motion.tween_method(_set_energy, 0.28, 0.0, MotionPolicy.finite_duration(0.08))
		_motion.tween_callback(_finish)
		return
	var peak := 0.80 if big else 0.55
	var sweep_duration := 0.36 if big else 0.26
	var fade_duration := 0.26 if big else 0.18
	_set_sweep(-0.15)
	_motion = create_tween().set_parallel(true)
	_motion.tween_method(_set_energy, 0.0, peak, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	_motion.tween_method(_set_sweep, -0.15, 1.15, sweep_duration).set_trans(Tween.TRANS_CUBIC).set_ease(
		Tween.EASE_OUT
	)
	_motion.chain().tween_method(_set_energy, peak, 0.0, fade_duration).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	_motion.chain().tween_callback(_finish)


func settle() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	_set_energy(0.0)
	_set_sweep(-0.15)
	visible = false


func is_playing() -> bool:
	return _motion != null and _motion.is_valid() and _motion.is_running()


func _install_shader() -> void:
	var shader := Shader.new()
	shader.code = SHADER_SOURCE
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	material = _shader_material


func _set_energy(value: float) -> void:
	energy_value = clampf(value, 0.0, 1.0)
	if _shader_material != null:
		_shader_material.set_shader_parameter("energy", energy_value)


func _set_sweep(value: float) -> void:
	sweep_value = clampf(value, -0.2, 1.2)
	if _shader_material != null:
		_shader_material.set_shader_parameter("sweep", sweep_value)


func _finish() -> void:
	_set_energy(0.0)
	visible = false
	_motion = null


func _apply_motion_preference(reduced: bool) -> void:
	if reduced and is_playing():
		settle()


func _exit_tree() -> void:
	if MotionPolicy.motion_preference_changed.is_connected(_apply_motion_preference):
		MotionPolicy.motion_preference_changed.disconnect(_apply_motion_preference)
