extends CanvasLayer
## Short velvet shutter used for every top-level scene change.

var _fade: ColorRect
var _upper: ColorRect
var _lower: ColorRect
var _rule: ColorRect
var _active: bool = false


func _ready() -> void:
	layer = 100
	_fade = _rect("Fade", Vector2.ZERO, Vector2(960, 540), Color("09070a00"))
	_upper = _rect("UpperShutter", Vector2(0, -270), Vector2(960, 270), Color("120d12"))
	_lower = _rect("LowerShutter", Vector2(0, 540), Vector2(960, 270), Color("120d12"))
	_rule = _rect("BrassSeam", Vector2(0, 269), Vector2(960, 2), Color("c8a34b"))
	_rule.modulate.a = 0.0
	visible = false


func cover() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_active = true
	visible = true
	_fade.color.a = 0.0
	_upper.position.y = -270.0
	_lower.position.y = 540.0
	_rule.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	if MotionPolicy.is_reduced():
		# Retain a brief context-change cue without sweeping the viewport.
		tween.tween_property(_fade, "color:a", 0.72, MotionPolicy.finite_duration(0.12))
	else:
		tween.tween_property(_fade, "color:a", 0.72, 0.18)
		tween.tween_property(_upper, "position:y", 0.0, 0.18)
		tween.tween_property(_lower, "position:y", 270.0, 0.18)
		tween.tween_property(_rule, "modulate:a", 1.0, 0.16)
	await tween.finished


func reveal() -> void:
	if DisplayServer.get_name() == "headless":
		return
	visible = true
	var tween := create_tween().set_parallel(true)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if MotionPolicy.is_reduced():
		tween.tween_property(_fade, "color:a", 0.0, MotionPolicy.finite_duration(0.12))
	else:
		tween.tween_property(_fade, "color:a", 0.0, 0.24)
		tween.tween_property(_upper, "position:y", -270.0, 0.24)
		tween.tween_property(_lower, "position:y", 540.0, 0.24)
		tween.tween_property(_rule, "modulate:a", 0.0, 0.12)
	await tween.finished
	visible = false
	_active = false


func _rect(node_name: String, at: Vector2, dimensions: Vector2, color: Color) -> ColorRect:
	var rect := ColorRect.new()
	rect.name = node_name
	rect.position = at
	rect.size = dimensions
	rect.color = color
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(rect)
	return rect
