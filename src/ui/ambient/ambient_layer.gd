class_name AmbientLayer
extends Node2D
## Presentation-only ambient life: painted lights that breathe, soft drifting
## shade and a few sparks. No gameplay reads or changes anything here.
##
## Every value is a pure function of `elapsed`, so captures and tests can sample
## the same frame exactly. Reduced motion holds `elapsed` at the rest frame and
## freezes pools at their average brightness; moving accents disappear.
##
## Drawing happens on two child canvases: `light_canvas` blends additively
## (pools, sparks) and `shade_canvas` blends normally (soft shadows). Subclasses
## draw into them from `_draw_light(canvas)` and `_draw_shade(canvas)`.

## A light pool adds at most this much light at its centre: a pool, never bloom.
const POOL_ALPHA_CAP: float = 0.10
## Drifting ceiling and cloud shade darkens at most this much.
const SHADOW_ALPHA_CAP: float = 0.08
## Brass glints and rune shimmer: a narrow moving streak, masked by the art.
const SWEEP_ALPHA_CAP: float = 0.24
## Firefly and screen sparks: one or two pixels of light.
const SPARK_ALPHA_CAP: float = 0.35
const REST_ELAPSED: float = 0.0
## Long sessions wrap the clock so float precision never degrades the motion.
const WRAP_SECONDS: float = 3600.0

static var _falloff: GradientTexture2D

var elapsed: float = REST_ELAPSED
var reduced_motion: bool = false
var light_canvas: Node2D
var shade_canvas: Node2D
## Painted art the layer sits on, drawn 960x540 from the origin (sweep mask).
var backdrop_texture: Texture2D
## The cabinet this layer dresses, when it sits in a cabinet panel.
var cabinet_id: StringName = &""
var _pool_at := PackedVector2Array()
var _pool_radius := PackedFloat32Array()
var _pool_squash := PackedFloat32Array()
var _pool_color := PackedColorArray()
var _pool_strength := PackedFloat32Array()
var _pool_period := PackedFloat32Array()
var _pool_phase := PackedFloat32Array()
var _pool_depth := PackedFloat32Array()


## Soft radial falloff shared by every pool, shadow and spark: white centre to
## transparent edge. It is a light footprint, not a decorative gradient panel.
static func falloff_texture() -> Texture2D:
	if _falloff == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		gradient.colors = PackedColorArray(
			[
				Color(1, 1, 1, 1.0),
				Color(1, 1, 1, 0.82),
				Color(1, 1, 1, 0.46),
				Color(1, 1, 1, 0.16),
				Color(1, 1, 1, 0.0),
			]
		)
		_falloff = GradientTexture2D.new()
		_falloff.gradient = gradient
		_falloff.fill = GradientTexture2D.FILL_RADIAL
		_falloff.fill_from = Vector2(0.5, 0.5)
		_falloff.fill_to = Vector2(1.0, 0.5)
		_falloff.width = 128
		_falloff.height = 128
	return _falloff


## A slow, slightly irregular breath in [-1, 1]: three incommensurate harmonics
## whose weights sum to one, so no electrical strobe and no random jumps.
static func breath(at_time: float, period: float, phase: float) -> float:
	var cycle := at_time / maxf(period, 0.01) + phase
	return (
		sin(cycle * TAU) * 0.6
		+ sin((cycle * 2.31 + phase * 1.7) * TAU) * 0.28
		+ sin((cycle * 5.73 + phase * 3.1) * TAU) * 0.12
	)


## Stable pseudo-random value in [0, 1) for an integer seed.
static func hash01(key: int) -> float:
	var value := sin(float(key) * 12.9898 + 78.233) * 43758.5453
	return value - floorf(value)


## Alpha of a pool breathing around `strength` by +-`depth`, never above the cap.
static func pool_alpha(
	strength: float, depth: float, at_time: float, period: float, phase: float
) -> float:
	return clampf(strength * (1.0 + depth * breath(at_time, period, phase)), 0.0, POOL_ALPHA_CAP)


func _init() -> void:
	light_canvas = Node2D.new()
	light_canvas.name = "AmbientLight"
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	light_canvas.material = additive
	light_canvas.draw.connect(_on_light_draw)
	add_child(light_canvas)
	shade_canvas = Node2D.new()
	shade_canvas.name = "AmbientShade"
	shade_canvas.draw.connect(_on_shade_draw)
	add_child(shade_canvas)
	# Shade sits under light so a lamp pool is never dimmed by drifting shade.
	move_child(shade_canvas, 0)
	_setup()


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(apply_motion_preference)
	apply_motion_preference(MotionPolicy.is_reduced())


func _process(delta: float) -> void:
	if not reduced_motion:
		elapsed = fmod(elapsed + maxf(delta, 0.0), WRAP_SECONDS)
	if not is_visible_in_tree():
		return
	_advance()
	light_canvas.queue_redraw()
	shade_canvas.queue_redraw()


func apply_motion_preference(reduced: bool) -> void:
	reduced_motion = reduced
	if reduced:
		elapsed = REST_ELAPSED
	set_process(not reduced or _processes_when_reduced())
	_advance()
	light_canvas.queue_redraw()
	shade_canvas.queue_redraw()


## Registers one breathing light pool drawn by `draw_pools`.
func add_pool(
	center: Vector2,
	radius: float,
	squash: float,
	color: Color,
	strength: float,
	period: float,
	phase: float,
	depth: float = 0.3
) -> void:
	_pool_at.append(center)
	_pool_radius.append(radius)
	_pool_squash.append(squash)
	_pool_color.append(color)
	_pool_strength.append(strength)
	_pool_period.append(period)
	_pool_phase.append(phase)
	_pool_depth.append(depth)


func pool_count() -> int:
	return _pool_at.size()


## Reduced motion holds every pool at its average brightness.
func pool_alpha_at(index: int, at_time: float = elapsed) -> float:
	if reduced_motion:
		return clampf(_pool_strength[index], 0.0, POOL_ALPHA_CAP)
	return pool_alpha(
		_pool_strength[index], _pool_depth[index], at_time, _pool_period[index], _pool_phase[index]
	)


func draw_pools(canvas: Node2D) -> void:
	for index: int in range(_pool_at.size()):
		draw_pool(
			canvas,
			_pool_at[index],
			_pool_radius[index],
			_pool_squash[index],
			_pool_color[index],
			pool_alpha_at(index)
		)


## Peak alpha per effect family at `at_time`, for alpha-cap and reduced-motion
## tests: {"pool", "shadow", "sweep", "spark"}.
func sample_alpha_peaks(at_time: float) -> Dictionary:
	var peaks := {"pool": 0.0, "shadow": 0.0, "sweep": 0.0, "spark": 0.0}
	for index: int in range(_pool_at.size()):
		peaks["pool"] = maxf(peaks["pool"], pool_alpha_at(index, at_time))
	return peaks


## Screen rectangles that moving accents (sparks, sweeps, drifting shade) can
## ever touch. Protected gameplay rectangles must stay clear of all of them.
func moving_effect_bounds() -> Array[Rect2]:
	return []


## Rectangles of the soft light pools, which sit under gameplay in draw order.
func pool_bounds() -> Array[Rect2]:
	var bounds: Array[Rect2] = []
	for index: int in range(_pool_at.size()):
		var half := Vector2(_pool_radius[index], _pool_radius[index] * _pool_squash[index])
		bounds.append(Rect2(_pool_at[index] - half, half * 2.0))
	return bounds


## Called once from the constructor after both canvases exist.
func _setup() -> void:
	pass


## Updates non-canvas children (sweep nodes) for the current `elapsed`.
func _advance() -> void:
	pass


func _processes_when_reduced() -> bool:
	return false


func _draw_light(_canvas: Node2D) -> void:
	pass


func _draw_shade(_canvas: Node2D) -> void:
	pass


func _on_light_draw() -> void:
	_draw_light(light_canvas)


func _on_shade_draw() -> void:
	_draw_shade(shade_canvas)


## Draws one elliptical pool of light (or shade) centred on `center`.
func draw_pool(
	canvas: Node2D, center: Vector2, radius: float, squash: float, color: Color, alpha: float
) -> void:
	if alpha <= 0.0005:
		return
	var half := Vector2(radius, radius * squash)
	canvas.draw_texture_rect(
		falloff_texture(), Rect2(center - half, half * 2.0), false, Color(color, alpha)
	)


## Draws a pool cut to `clip`: the texture region is cropped with the rectangle,
## so shade seen through a window never spills onto its frame.
func draw_pool_clipped(
	canvas: Node2D,
	center: Vector2,
	radius: float,
	squash: float,
	color: Color,
	alpha: float,
	clip: Rect2
) -> void:
	if alpha <= 0.0005:
		return
	var half := Vector2(radius, radius * squash)
	var full := Rect2(center - half, half * 2.0)
	var visible_part := full.intersection(clip)
	if visible_part.size.x <= 0.0 or visible_part.size.y <= 0.0:
		return
	var texture := falloff_texture()
	var texel_scale := Vector2(texture.get_size()) / full.size
	var source := Rect2(
		(visible_part.position - full.position) * texel_scale, visible_part.size * texel_scale
	)
	canvas.draw_texture_rect_region(texture, visible_part, source, Color(color, alpha))


## A tiny four-point spark: a dot plus two thin crossed streaks.
func draw_spark(canvas: Node2D, center: Vector2, size: float, color: Color, alpha: float) -> void:
	if alpha <= 0.0005:
		return
	var texture := falloff_texture()
	var tint := Color(color, alpha)
	canvas.draw_texture_rect(
		texture, Rect2(center - Vector2(size, size) * 0.5, Vector2(size, size)), false, tint
	)
	var arm := size * 1.9
	var thin := maxf(size * 0.32, 0.6)
	var arm_tint := Color(color, alpha * 0.55)
	canvas.draw_texture_rect(
		texture, Rect2(center - Vector2(arm, thin) * 0.5, Vector2(arm, thin)), false, arm_tint
	)
	canvas.draw_texture_rect(
		texture, Rect2(center - Vector2(thin, arm) * 0.5, Vector2(thin, arm)), false, arm_tint
	)
