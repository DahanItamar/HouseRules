class_name CoreOverclockGauge
extends Control
## The oven temperature gauge: the cabinet's central object and the only live
## multiplier on the screen. The painted brass gauge carries a blank cream dial;
## the heat sweep, the ticks, the needle, the multiplier and what the pizza is
## worth are all drawn on that dial in code, in dark ink so they read against
## the cream.
##
## The needle is on a spring, so it sweeps with a little overshoot instead of
## snapping, and the dial warms in colour as the bake goes on. The multiplier is
## the one thing that must always be readable, so nothing is ever drawn over the
## dial, the number is fitted to the dial rather than clipped, and the pop it
## makes when it crosses a whole multiplier is bounded - and skipped entirely
## under reduced motion, where the needle also tracks the value exactly.

## The dial sweep: 270 degrees from down-left, clockwise, to down-right.
const SWEEP_START: float = 0.75 * PI
const SWEEP_SPAN: float = 1.5 * PI
const TICK_COUNT: int = 25
const NUMBER_SIZE: int = 40
const CAPTION_SIZE: int = 13
const VALUE_SIZE: int = 15
const POP_SECONDS: float = 0.20
const POP_SCALE: float = 0.08
const SETTLE_POP_SCALE: float = 0.18
## The needle spring: under-damped, so it overshoots a little and settles.
const NEEDLE_STIFFNESS: float = 120.0
const NEEDLE_DAMPING: float = 14.0
const NEEDLE_CEILING: float = 1.12
## The kick the needle takes when the pizza burns.
const SLAM_SPEED: float = 9.0
## How hard the needle trembles at full heat, in radians.
const TREMBLE: float = 0.014

signal whole_multiple_passed

var centi: int = 100
var auto_centi: int = 0
## 0 to 1 while the oven comes up to temperature during the countdown.
var charge: float = 0.0
var caption: String = ""
var caption_color := CoreOverclockTheme.TERRACOTTA_DEEP
var value_text: String = ""
var number_color := CoreOverclockTheme.INK
var baking: bool = false
var _needle: float = 0.0
var _needle_speed: float = 0.0
var _pop_left: float = 0.0
var _pop_scale: float = 0.0
var _last_whole: int = 1
var _phase: float = 0.0


func _init() -> void:
	name = "CoreOverclockGauge"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	size = Vector2.ONE * CoreOverclockTheme.GAUGE_SIZE


func _ready() -> void:
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)


## The dial's centre in this control's space.
func dial_centre() -> Vector2:
	return size * CoreOverclockTheme.DIAL_CENTRE


func dial_radius() -> float:
	return size.x * CoreOverclockTheme.DIAL_RADIUS


## The square the multiplier lives in. Nothing else may cover it.
func dial_rect() -> Rect2:
	var radius := dial_radius()
	return Rect2(position + dial_centre() - Vector2.ONE * radius, Vector2.ONE * radius * 2.0)


## The live multiplier. Crossing a whole multiplier gives one bounded pop and
## one tick, which the panel turns into a sound.
func set_centi(value: int) -> void:
	if centi == value:
		return
	centi = value
	var whole := value / 100
	if whole != _last_whole:
		_last_whole = whole
		_pop(POP_SCALE)
		whole_multiple_passed.emit()
	queue_redraw()


func set_charge(value: float) -> void:
	var next := clampf(value, 0.0, 1.0)
	if is_equal_approx(next, charge):
		return
	charge = next
	queue_redraw()


func set_bake_state(is_baking: bool) -> void:
	baking = is_baking
	queue_redraw()


func set_auto_target(value: int) -> void:
	auto_centi = value
	queue_redraw()


func set_caption(text: String, ink: Color) -> void:
	caption = text
	caption_color = ink
	queue_redraw()


## What the pizza is worth right now.
func set_value(text: String) -> void:
	value_text = text
	queue_redraw()


func set_number_color(ink: Color) -> void:
	number_color = ink
	queue_redraw()


## One larger bounded pop when the bake settles.
func settle_pop() -> void:
	_pop(SETTLE_POP_SCALE)


## The burn: the needle is kicked past its stop and settles back.
func slam() -> void:
	if MotionPolicy.is_reduced():
		return
	_needle_speed = SLAM_SPEED
	queue_redraw()


## Where the needle actually points, which lags the value by a spring.
func needle_place() -> float:
	return _needle


func reset() -> void:
	centi = 100
	_last_whole = 1
	_pop_left = 0.0
	_pop_scale = 0.0
	_needle = 0.0
	_needle_speed = 0.0
	baking = false
	charge = 0.0
	queue_redraw()


func _pop(scale_amount: float) -> void:
	if MotionPolicy.is_reduced():
		return
	_pop_scale = scale_amount
	_pop_left = POP_SECONDS
	queue_redraw()


func _process(delta: float) -> void:
	var target := _heat()
	if MotionPolicy.is_reduced():
		if not is_equal_approx(_needle, target):
			_needle = target
			_needle_speed = 0.0
			queue_redraw()
	else:
		var before := _needle
		var accel := (target - _needle) * NEEDLE_STIFFNESS - _needle_speed * NEEDLE_DAMPING
		_needle_speed += accel * delta
		_needle = clampf(_needle + _needle_speed * delta, 0.0, NEEDLE_CEILING)
		if absf(_needle - before) > 0.0002:
			queue_redraw()
		_phase += delta
		if baking:
			queue_redraw()
	if _pop_left > 0.0:
		_pop_left = maxf(_pop_left - delta, 0.0)
		queue_redraw()


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		_pop_left = 0.0
		_phase = 0.0
		_needle = _heat()
		_needle_speed = 0.0
	queue_redraw()


func _heat() -> float:
	return CoreOverclockTheme.heat_of(centi)


func _draw() -> void:
	var heat := _heat()
	var centre := dial_centre()
	var radius := dial_radius()
	_draw_lamp(centre, radius, heat)
	draw_texture_rect(CoreOverclockTheme.GAUGE, Rect2(Vector2.ZERO, size), false)
	_draw_dial_warmth(centre, radius, heat)
	_draw_sweep(centre, radius, heat)
	_draw_ticks(centre, radius)
	_draw_needle(centre, radius)
	_draw_charge(centre, radius)
	_draw_readout(centre, radius)


## The oven light on the glass, warmer the longer the bake runs. Cabinet screens
## may glow; the floor and the HUD may not.
func _draw_lamp(centre: Vector2, radius: float, heat: float) -> void:
	var ink := CoreOverclockTheme.heat_color(heat)
	for index: int in range(5):
		var alpha := (0.05 + heat * 0.12) * (1.0 - float(index) / 5.0)
		draw_circle(centre, radius + 8.0 + float(index) * 6.0, Color(ink, alpha))


## The cream dial itself takes the heat, so the whole face warms as it bakes.
func _draw_dial_warmth(centre: Vector2, radius: float, heat: float) -> void:
	if heat <= 0.0:
		return
	draw_circle(centre, radius * 0.99, Color(CoreOverclockTheme.heat_color(heat), heat * 0.26))


## The heat sweep filled in behind the ticks, and the set timer marked on it.
func _draw_sweep(centre: Vector2, radius: float, heat: float) -> void:
	var ink := CoreOverclockTheme.heat_color(heat)
	draw_arc(
		centre,
		radius * 0.88,
		SWEEP_START,
		SWEEP_START + SWEEP_SPAN,
		96,
		Color(CoreOverclockTheme.INK, 0.10),
		5.0,
		true
	)
	var shown := clampf(_needle, 0.0, 1.0)
	if shown > 0.0:
		draw_arc(
			centre,
			radius * 0.88,
			SWEEP_START,
			SWEEP_START + SWEEP_SPAN * shown,
			96,
			Color(ink, 0.95),
			5.0,
			true
		)
	if auto_centi <= 0:
		return
	var mark := SWEEP_START + SWEEP_SPAN * CoreOverclockTheme.heat_of(auto_centi)
	var direction := Vector2(cos(mark), sin(mark))
	draw_line(
		centre + direction * (radius * 0.76),
		centre + direction * (radius * 0.99),
		CoreOverclockTheme.TERRACOTTA,
		2.5,
		true
	)


func _draw_ticks(centre: Vector2, radius: float) -> void:
	for index: int in range(TICK_COUNT):
		var place := float(index) / float(TICK_COUNT - 1)
		var angle := SWEEP_START + SWEEP_SPAN * place
		var direction := Vector2(cos(angle), sin(angle))
		var major := index % 6 == 0
		draw_line(
			centre + direction * (radius * (0.93 if major else 0.95)),
			centre + direction * (radius * 1.0),
			Color(CoreOverclockTheme.INK, 0.85 if major else 0.45),
			2.0 if major else 1.0,
			true
		)


## A terracotta needle riding the rim, so it never crosses the number.
func _draw_needle(centre: Vector2, radius: float) -> void:
	var tremble := 0.0
	if baking and MotionPolicy.allows_continuous_motion():
		tremble = sin(_phase * 26.0) * TREMBLE * _needle
	var angle := SWEEP_START + SWEEP_SPAN * _needle + tremble
	var direction := Vector2(cos(angle), sin(angle))
	var side := direction.orthogonal()
	var tip := centre + direction * (radius * 1.02)
	var base := centre + direction * (radius * 0.78)
	draw_colored_polygon(
		PackedVector2Array([tip, base + side * 5.0, base - side * 5.0]),
		CoreOverclockTheme.TERRACOTTA_DEEP
	)
	draw_circle(centre + direction * (radius * 0.78), 3.0, CoreOverclockTheme.TERRACOTTA_DEEP)


## The countdown, as the oven coming up to temperature around the dial.
func _draw_charge(centre: Vector2, radius: float) -> void:
	if charge <= 0.0:
		return
	draw_arc(
		centre,
		radius * 1.12,
		-PI * 0.5,
		-PI * 0.5 + TAU * charge,
		64,
		CoreOverclockTheme.EMBER,
		3.0,
		true
	)


## The largest size at or below `wanted` that fits `text` inside `room` pixels.
## The dial is small, so a caption or a five-figure payout set at a fixed size
## runs out over the brass rim; every line on the face is fitted instead.
static func _fitted_size(font: Font, text: String, wanted: int, room: float) -> int:
	var font_size := wanted
	while (
		font_size > 8
		and font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > room
	):
		font_size -= 1
	return font_size


func _draw_readout(centre: Vector2, radius: float) -> void:
	var font: Font = Typography.DISPLAY_FONT
	if not caption.is_empty():
		CoreOverclockTheme.draw_centered(
			self,
			caption,
			centre - Vector2(0.0, radius * 0.56),
			_fitted_size(font, caption, CAPTION_SIZE, radius * 1.30),
			caption_color
		)
	var text := CoreOverclockMath.multiplier_text(centi) + String.chr(0x00D7)
	var font_size := _fitted_size(font, text, NUMBER_SIZE, radius * 1.72)
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var swell := 1.0 + _pop_scale * (_pop_left / POP_SECONDS)
	draw_set_transform(centre, 0.0, Vector2(swell, swell))
	draw_string(
		font,
		Vector2(-text_size.x * 0.5, font.get_ascent(font_size) * 0.5 - 2.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		font_size,
		number_color
	)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if value_text.is_empty():
		return
	CoreOverclockTheme.draw_centered(
		self,
		value_text,
		centre + Vector2(0.0, radius * 0.48),
		_fitted_size(font, value_text, VALUE_SIZE, radius * 1.18),
		CoreOverclockTheme.TERRACOTTA_DEEP
	)
