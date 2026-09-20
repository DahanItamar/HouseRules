class_name ProgressMeter
extends Control
## One painted progress bar: the brass-rimmed track with a brushed brass
## capsule filling its channel.
##
## The art is a pair of nine-slices (see
## `assets/production/ui/progression/progression.json`). Both are drawn at a
## scale derived from this control's height, so the 920 px master stays sharp
## at UHD while the bar itself is slim at the 960x540 virtual canvas. The fill
## is clipped rather than squashed, so a bar at 30% shows exactly 30% of the
## channel and never a rounded stub that flatters the number.
##
## `ratio` is always inside 0..1. Motion follows MotionPolicy: an animated
## fill normally, the final width immediately when reduced motion is on.

signal fill_finished

const TRACK: Texture2D = preload("res://assets/production/ui/progression/bar_track.png")
const FILL: Texture2D = preload("res://assets/production/ui/progression/bar_fill.png")
## Source-pixel measurements from progression.json.
const TRACK_SIZE := Vector2(920, 162)
const TRACK_MARGIN: int = 79
const TRACK_RIM: int = 20
const CHANNEL := Rect2(37, 18, 845, 126)
const FILL_SIZE := Vector2(888, 139)
const FILL_MARGIN: int = 65
const FILL_SECONDS: float = 0.42
## A fill this thin cannot be seen; the bar reads as empty instead of as a nub.
const MIN_VISIBLE_RATIO: float = 0.004

var ratio: float = 0.0:
	set(value):
		set_ratio(value)
var _track: NinePatchRect
var _clip: Control
var _fill: NinePatchRect
var _tween: Tween
var _shown_ratio: float = 0.0


func _init() -> void:
	name = "ProgressMeter"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(48, 8)
	size = Vector2(160, 16)
	_track = NinePatchRect.new()
	_track.name = "Track"
	_track.texture = TRACK
	_track.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_track.set_patch_margin(SIDE_LEFT, TRACK_MARGIN)
	_track.set_patch_margin(SIDE_RIGHT, TRACK_MARGIN)
	_track.set_patch_margin(SIDE_TOP, TRACK_RIM)
	_track.set_patch_margin(SIDE_BOTTOM, TRACK_RIM)
	add_child(_track)
	_clip = Control.new()
	_clip.name = "FillClip"
	_clip.clip_contents = true
	_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clip)
	_fill = NinePatchRect.new()
	_fill.name = "Fill"
	_fill.texture = FILL
	_fill.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill.set_patch_margin(SIDE_LEFT, FILL_MARGIN)
	_fill.set_patch_margin(SIDE_RIGHT, FILL_MARGIN)
	_clip.add_child(_fill)
	resized.connect(_layout)


func _ready() -> void:
	_layout()


## Whether a fill lands on its final width at once rather than animating.
## Reduced motion is the player's preference; a meter that is off screen or a
## headless run has nothing to animate for.
static func is_instant(animate: bool, reduced: bool, on_screen: bool, headless: bool) -> bool:
	return not animate or reduced or not on_screen or headless


## Sets the fill. `animate` is only a request: reduced motion, a headless run
## and a meter that is not on screen all land on the final width at once.
func set_ratio(value: float, animate: bool = true) -> void:
	var target := clampf(value, 0.0, 1.0)
	if is_equal_approx(target, _shown_ratio) and _tween == null:
		return
	if _tween != null:
		_tween.kill()
		_tween = null
	var instant := is_instant(
		animate,
		MotionPolicy.is_reduced(),
		is_inside_tree() and is_visible_in_tree(),
		DisplayServer.get_name() == "headless"
	)
	if instant:
		_shown_ratio = target
		_layout()
		fill_finished.emit()
		return
	var from := _shown_ratio
	_tween = create_tween()
	(
		_tween
		. tween_method(
			func(value_step: float) -> void:
				_shown_ratio = value_step
				_layout(),
			from,
			target,
			MotionPolicy.finite_duration(FILL_SECONDS)
		)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.finished.connect(
		func() -> void:
			_tween = null
			fill_finished.emit()
	)


## The fill actually on screen, which lags `ratio` while a fill animates.
func shown_ratio() -> float:
	return _shown_ratio


func fill_width() -> float:
	return _clip.size.x if _clip != null else 0.0


func channel_width() -> float:
	var art_scale := _art_scale()
	return maxf(size.x - (CHANNEL.position.x + TRACK_SIZE.x - CHANNEL.end.x) * art_scale, 0.0)


func _art_scale() -> float:
	return maxf(size.y, 1.0) / TRACK_SIZE.y


func _layout() -> void:
	if _track == null:
		return
	var art_scale := _art_scale()
	_track.scale = Vector2(art_scale, art_scale)
	_track.size = Vector2(maxf(size.x / art_scale, TRACK_MARGIN * 2.0), TRACK_SIZE.y)
	var inset_left := CHANNEL.position.x * art_scale
	var inset_top := CHANNEL.position.y * art_scale
	var inner_width := maxf(size.x - inset_left - (TRACK_SIZE.x - CHANNEL.end.x) * art_scale, 0.0)
	var inner_height := maxf(size.y - inset_top - (TRACK_SIZE.y - CHANNEL.end.y) * art_scale, 1.0)
	_clip.position = Vector2(inset_left, inset_top)
	var visible_ratio := _shown_ratio if _shown_ratio >= MIN_VISIBLE_RATIO else 0.0
	_clip.size = Vector2(inner_width * visible_ratio, inner_height)
	_fill.scale = Vector2(art_scale, art_scale)
	_fill.size = Vector2(
		maxf(inner_width / art_scale, FILL_MARGIN * 2.0), maxf(inner_height / art_scale, 1.0)
	)
