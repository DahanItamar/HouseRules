class_name CabinetHost
extends Control
## Presentation-only mini-game host built from stacked, pre-aligned pose masters.
##
## Every pose is a complete transparent production painting. A beat changes pose
## with a cross-fade between two stacked sprites (the incoming pose fades in on
## top while the outgoing pose fades out underneath), so the person never bobs or
## translates as a rigid cut-out. Idle life is a one-pixel breath that scales the
## figure from its planted foot/rail anchor. The host never reads or writes game
## state: CabinetPanel names the beat, MotionPolicy decides how it is shown.
##
## Reduced motion keeps the static master pose on screen and acknowledges each
## beat with one bounded cue bar, mirroring BlackjackDealerPresenter.


## One authored pose master. `anchor` is the source-pixel point that must land
## on the shared foot/rail anchor; `ratio` rescales poses painted at a different
## figure size so every pose keeps the same stature on screen.
class Pose:
	var id: StringName
	var texture: Texture2D
	var anchor: Vector2
	var ratio: float
	var used_rect: Rect2

	func _init(
		pose_id: StringName,
		pose_texture: Texture2D,
		pose_anchor: Vector2,
		pose_used_rect: Rect2,
		pose_ratio: float = 1.0
	) -> void:
		id = pose_id
		texture = pose_texture
		anchor = pose_anchor
		used_rect = pose_used_rect
		ratio = pose_ratio


const CUE_REST_ALPHA: float = 0.0
const CUE_HOLD_SECONDS: float = 0.16
const CUE_FADE_SECONDS: float = 0.12
## Maximum idle breath at the top of the head, in virtual pixels.
const BREATH_PIXELS: float = 1.0

var host_texture: Texture2D
var master_pose: StringName = &""
var rest_pose: StringName = &""
var current_pose: StringName = &""
var last_beat: StringName = &"idle"
var fade_seconds: float = 0.18
var lean_radians: float = 0.0
var breath_period: float = 4.2
var display_scale: float = 0.14
## Where the shared anchor sits, in this control's local space.
var anchor_point: Vector2 = Vector2.ZERO
var cue_color: Color = Color("c8a34b")
## Flat contact shadow under a host that stands on a visible floor (zero = none).
var contact_shadow_size: Vector2 = Vector2.ZERO
## Shadow centre relative to the anchor (both shoes, not just the front one).
var contact_shadow_offset: Vector2 = Vector2.ZERO

var _poses: Dictionary = {}
var _pose_order: Array[StringName] = []
var _sprites: Dictionary = {}
var _figure: Node2D
var _contact_shadow: Polygon2D
var _cue: ColorRect
var _pose_tween: Tween
var _beat_tween: Tween
var _cue_tween: Tween
var _elapsed: float = 0.0
var _figure_height: float = 1.0


## Registers a pose master. The first pose becomes the master/rest pose.
func add_pose(pose: Pose) -> void:
	_poses[pose.id] = pose
	if not _pose_order.has(pose.id):
		_pose_order.append(pose.id)
	if master_pose == &"":
		master_pose = pose.id
		rest_pose = pose.id
		host_texture = pose.texture
	if is_node_ready():
		_build_sprite(pose)
		_layout_sprites()


## Legacy single-texture entry point kept for simple hosts and older callers.
func configure(texture: Texture2D, display_size: Vector2) -> void:
	size = display_size
	var image_size := Vector2(texture.get_width(), texture.get_height())
	display_scale = minf(display_size.x / image_size.x, display_size.y / image_size.y)
	anchor_point = Vector2(display_size.x * 0.5, display_size.y)
	add_pose(
		Pose.new(
			&"idle",
			texture,
			Vector2(image_size.x * 0.5, image_size.y),
			Rect2(Vector2.ZERO, image_size)
		)
	)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if contact_shadow_size != Vector2.ZERO:
		# Flat, unblurred shadow where the shoes meet the floor; it grounds the
		# figure without glow or gradients and never breathes with the body.
		_contact_shadow = Polygon2D.new()
		_contact_shadow.name = "HostContactShadow"
		var points := PackedVector2Array()
		for step: int in range(24):
			var angle := TAU * float(step) / 24.0
			points.append(Vector2(cos(angle), sin(angle)) * contact_shadow_size * 0.5)
		_contact_shadow.polygon = points
		_contact_shadow.color = Color(0.0, 0.0, 0.0, 0.42)
		add_child(_contact_shadow)
	_figure = Node2D.new()
	_figure.name = "HostFigure"
	add_child(_figure)
	for id: StringName in _pose_order:
		_build_sprite(_poses[id])
	_cue = ColorRect.new()
	_cue.name = "HostStateCue"
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue.color = cue_color
	_cue.modulate.a = CUE_REST_ALPHA
	add_child(_cue)
	_layout_sprites()
	_settle_to(_rest_for_policy())
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	if not MotionPolicy.allows_continuous_motion():
		return
	_elapsed += delta
	# Chest-rise breath: scale from the planted anchor so feet never slide and
	# the head moves at most BREATH_PIXELS.
	var breath := (sin(_elapsed * TAU / breath_period) * 0.5 + 0.5) * BREATH_PIXELS
	_figure.scale = Vector2(1.0, 1.0 + breath / maxf(_figure_height, 1.0))


## Current master used for identity checks (unique person per game).
func portrait_texture() -> Texture2D:
	return host_texture


func pose_ids() -> Array[StringName]:
	return _pose_order.duplicate()


func pose_texture(id: StringName) -> Texture2D:
	var pose: Pose = _poses.get(id)
	return pose.texture if pose != null else null


func visible_pose_texture() -> Texture2D:
	return pose_texture(current_pose)


## Head displacement caused by the idle breath, in virtual pixels.
func breath_offset_pixels() -> float:
	if _figure == null:
		return 0.0
	return absf(_figure.scale.y - 1.0) * _figure_height


## Painted bounds of the pose on screen (parent space).
func pose_bounds(id: StringName) -> Rect2:
	var pose: Pose = _poses.get(id)
	if pose == null:
		return Rect2(position, Vector2.ZERO)
	var pose_scale := display_scale * pose.ratio
	var top_left := anchor_point + (pose.used_rect.position - pose.anchor) * pose_scale
	return Rect2(position + top_left, pose.used_rect.size * pose_scale)


## Bounds of the pose currently on screen.
func visual_bounds() -> Rect2:
	return pose_bounds(current_pose if current_pose != &"" else master_pose)


## Union of every pose a beat can show: the worst case the lane must contain.
func lane_bounds() -> Rect2:
	var bounds := pose_bounds(master_pose)
	for id: StringName in _pose_order:
		bounds = bounds.merge(pose_bounds(id))
	return bounds


func has_active_gesture() -> bool:
	return (
		(_beat_tween != null and _beat_tween.is_running())
		or (_pose_tween != null and _pose_tween.is_running())
	)


## Changes the pose the host settles on when no beat is running.
func set_rest_pose(id: StringName) -> void:
	if not _poses.has(id) or rest_pose == id:
		return
	rest_pose = id
	if not has_active_gesture() and not MotionPolicy.is_reduced():
		show_pose(rest_pose)


## Plays a beat: `steps` is [[pose_id, hold_seconds], ...]. A negative hold keeps
## that pose until the next beat; otherwise the host returns to its rest pose.
func play_beat(beat: StringName, steps: Array) -> void:
	_stop_beat()
	last_beat = beat
	if MotionPolicy.is_reduced():
		_settle_to(_rest_for_policy())
		_play_reduced_cue()
		return
	if steps.is_empty():
		return
	# The first pose starts on the same frame as the beat; later steps are timed.
	var first: Array = steps[0]
	show_pose(first[0])
	if float(first[1]) < 0.0:
		return
	_beat_tween = create_tween()
	_beat_tween.tween_interval(float(first[1]))
	for index: int in range(1, steps.size()):
		var step: Array = steps[index]
		_beat_tween.tween_callback(show_pose.bind(step[0]))
		if float(step[1]) < 0.0:
			return
		_beat_tween.tween_interval(float(step[1]))
	_beat_tween.tween_callback(_return_to_rest)


func reset_feedback() -> void:
	_stop_beat()
	last_beat = &"idle"
	_settle_to(_rest_for_policy())
	_stop_cue()


## Cross-fades to a pose. Reduced motion never changes the static pose.
func show_pose(id: StringName) -> void:
	if not _poses.has(id) or _figure == null:
		return
	if MotionPolicy.is_reduced():
		_settle_to(_rest_for_policy())
		return
	if id == current_pose and (_pose_tween == null or not _pose_tween.is_running()):
		return
	var outgoing_id := current_pose
	_finish_pose_tween()
	if fade_seconds <= 0.0 or outgoing_id == &"" or outgoing_id == id:
		_settle_to(id)
		return
	var incoming: Sprite2D = _sprites[id]
	var outgoing: Sprite2D = _sprites[outgoing_id]
	_figure.move_child(incoming, _figure.get_child_count() - 1)
	incoming.visible = true
	incoming.modulate.a = 0.0
	outgoing.visible = true
	outgoing.modulate.a = 1.0
	current_pose = id
	_pose_tween = create_tween().set_parallel(true)
	(
		_pose_tween
		. tween_property(incoming, "modulate:a", 1.0, fade_seconds)
		. set_trans(Tween.TRANS_SINE)
		. set_ease(Tween.EASE_OUT)
	)
	# The outgoing pose stays opaque underneath for the first half, so the
	# overlap never dips into a see-through ghost.
	_pose_tween.tween_property(outgoing, "modulate:a", 0.0, fade_seconds * 0.5).set_delay(
		fade_seconds * 0.5
	)
	if not is_zero_approx(lean_radians):
		# Weight shift: the upper body leans a hair while the feet stay planted.
		var lean := lean_radians if id != rest_pose else -lean_radians * 0.5
		(
			_pose_tween
			. tween_property(_figure, "skew", lean, fade_seconds * 0.5)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_OUT)
		)
		(
			_pose_tween
			. chain()
			. tween_property(_figure, "skew", 0.0, fade_seconds)
			. set_trans(Tween.TRANS_SINE)
			. set_ease(Tween.EASE_IN_OUT)
		)
	_pose_tween.finished.connect(_settle_to.bind(id), CONNECT_ONE_SHOT)


func _return_to_rest() -> void:
	show_pose(rest_pose)


func _rest_for_policy() -> StringName:
	return master_pose if MotionPolicy.is_reduced() else rest_pose


func _build_sprite(pose: Pose) -> void:
	if _figure == null or _sprites.has(pose.id):
		return
	var sprite := Sprite2D.new()
	sprite.name = "Pose_%s" % pose.id
	sprite.texture = pose.texture
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	sprite.visible = false
	_figure.add_child(sprite)
	_sprites[pose.id] = sprite


func _layout_sprites() -> void:
	if _figure == null:
		return
	_figure.position = anchor_point
	if _contact_shadow != null:
		_contact_shadow.position = anchor_point + contact_shadow_offset
	for id: StringName in _sprites.keys():
		var pose: Pose = _poses[id]
		var sprite: Sprite2D = _sprites[id]
		var pose_scale := display_scale * pose.ratio
		sprite.scale = Vector2.ONE * pose_scale
		sprite.position = -pose.anchor * pose_scale
	var master: Pose = _poses.get(master_pose)
	if master != null:
		_figure_height = (master.anchor.y - master.used_rect.position.y) * display_scale
		var body_width := master.used_rect.size.x * display_scale * 0.42
		if _cue != null:
			_cue.size = Vector2(maxf(body_width, 24.0), 3.0)
			_cue.position = anchor_point + Vector2(-_cue.size.x * 0.5, 4.0)


func _settle_to(id: StringName) -> void:
	_finish_pose_tween()
	if _figure == null or not _sprites.has(id):
		current_pose = id
		return
	current_pose = id
	for sprite_id: StringName in _sprites.keys():
		var sprite: Sprite2D = _sprites[sprite_id]
		sprite.visible = sprite_id == id
		sprite.modulate.a = 1.0
	_figure.skew = 0.0


func _finish_pose_tween() -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
		_pose_tween = null
		_settle_to(current_pose)
	_pose_tween = null


func _stop_beat() -> void:
	if _beat_tween != null and _beat_tween.is_valid():
		_beat_tween.kill()
	_beat_tween = null


func _play_reduced_cue() -> void:
	# One fixed, finite cue acknowledges the beat while the pose stays still.
	_stop_cue()
	if _cue == null:
		return
	_cue.color = cue_color
	_cue.modulate.a = 1.0
	_beat_tween = create_tween()
	_beat_tween.tween_interval(MotionPolicy.finite_duration(CUE_HOLD_SECONDS))
	_beat_tween.tween_property(
		_cue, "modulate:a", CUE_REST_ALPHA, MotionPolicy.finite_duration(CUE_FADE_SECONDS)
	)


func _stop_cue() -> void:
	if _cue_tween != null and _cue_tween.is_valid():
		_cue_tween.kill()
	_cue_tween = null
	if _cue != null:
		_cue.modulate.a = CUE_REST_ALPHA


func _apply_motion_preference(reduced: bool) -> void:
	set_process(not reduced)
	if reduced:
		_stop_beat()
		_elapsed = 0.0
		if _figure != null:
			_figure.scale = Vector2.ONE
		_settle_to(_rest_for_policy())
		_stop_cue()
	elif _figure != null and not has_active_gesture():
		_settle_to(rest_pose)
