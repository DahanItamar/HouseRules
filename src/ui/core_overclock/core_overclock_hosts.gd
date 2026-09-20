class_name CoreOverclockHosts
extends Control
## The two of Corsair's Reach's crew, who watch the run together.
##
## They are not two sprites. Each state of the run is ONE painted frame with
## both women in it -- the blonde standing in the left lane, the dark-haired one
## in the right, the whole middle of the frame transparent so the chart and the
## climb read between them. Generating the pair together is the point: there is
## no way for one of them to celebrate while the other winces, because a state is
## a single picture of both.
##
## Every frame is cut to the same canvas, so changing state never moves either
## woman by a pixel; only the feeling changes. The cabinet asks for a state and
## this cross-fades to it, or cuts straight to it under reduced motion.
##
## Presentation only: it reads nothing and decides nothing about the run.

const FADE_SECONDS: float = 0.22

var current_state: StringName = &"ready"

var _layers: Dictionary = {}
var _fade: Tween


func _init() -> void:
	name = "CorsairCrew"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = Vector2.ZERO
	size = Vector2(960, 540)


func _ready() -> void:
	for state: StringName in CoreOverclockTheme.HOST_STATES:
		var layer := TextureRect.new()
		layer.name = "Hosts_%s" % state
		layer.texture = CoreOverclockTheme.HOST_STATES[state]
		layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer.stretch_mode = TextureRect.STRETCH_SCALE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.position = Vector2.ZERO
		layer.size = size
		layer.modulate.a = 1.0 if state == current_state else 0.0
		add_child(layer)
		_layers[state] = layer


## Every state the pair can be in, in the order the run moves through them.
func state_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for state: StringName in CoreOverclockTheme.HOST_STATES:
		ids.append(state)
	return ids


func state_texture(state: StringName) -> Texture2D:
	return CoreOverclockTheme.HOST_STATES.get(state, null) as Texture2D


## Brings `state` forward. Both women change together because they are one frame.
func show_state(state: StringName) -> void:
	if not _layers.has(state) or state == current_state:
		return
	var leaving: TextureRect = _layers[current_state]
	var arriving: TextureRect = _layers[state]
	current_state = state
	if _fade != null:
		_fade.kill()
		_fade = null
	if MotionPolicy.is_reduced() or DisplayServer.get_name() == "headless":
		for layer: TextureRect in _layers.values():
			layer.modulate.a = 0.0
		arriving.modulate.a = 1.0
		return
	_fade = create_tween().set_parallel(true)
	_fade.tween_property(leaving, "modulate:a", 0.0, FADE_SECONDS)
	_fade.tween_property(arriving, "modulate:a", 1.0, FADE_SECONDS)


## Back to the pair waiting for the next run.
func reset_to_ready() -> void:
	show_state(&"ready")
