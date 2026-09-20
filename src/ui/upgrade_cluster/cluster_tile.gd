class_name ClusterTile
extends Control
## One cell of the board: a painted masquerade symbol on a recessed seat.
##
## It animates three bounded beats - a win pulse, a shatter and a settle - and
## knows nothing about clusters, pays or the round.

var symbol: int = 0
## Where this tile sits when nothing is moving, in the grid's space.
var rest_position := Vector2.ZERO
var _glow: float = 0.0
var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pivot_offset = size * 0.5


func set_symbol(index: int) -> void:
	symbol = clampi(index, 0, ClusterTheme.symbol_count() - 1)
	queue_redraw()


## Phase 1: a winning tile brightens and swells, then returns to rest. A bounded
## glow is allowed inside a cabinet screen; it never leaves this control.
func pulse() -> void:
	_stop()
	pivot_offset = size * 0.5
	var duration := ClusterTheme.phase(ClusterTheme.PULSE_SECONDS)
	if MotionPolicy.is_reduced():
		# One static state cue instead of a swell. The ring is held, not flashed,
		# so the cluster stays marked for as long as its number is on screen; the
		# shatter takes it away, exactly as the swelling version does.
		_set_glow(1.0)
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_glow, 0.0, 1.0, duration * 0.4).set_trans(Tween.TRANS_QUAD)
	(
		_tween
		. tween_property(self, "scale", Vector2(1.16, 1.16), duration * 0.4)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_tween.chain().tween_property(self, "scale", Vector2.ONE, duration * 0.6).set_trans(
		Tween.TRANS_QUAD
	)


## Phase 3: the tile leaves the board. The shards are the grid's job.
func shatter() -> void:
	_stop()
	if MotionPolicy.is_reduced():
		visible = false
		return
	var duration := ClusterTheme.phase(ClusterTheme.SHATTER_SECONDS)
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(0.28, 0.28), duration).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(self, "modulate:a", 0.0, duration)
	# The win light goes out with the tile instead of leaving a pale hole behind.
	_tween.tween_method(_set_glow, _glow, 0.0, duration * 0.7)
	_tween.chain().tween_callback(func() -> void: visible = false)


## Ends any beat at once and leaves the tile fully readable.
func settle() -> void:
	_stop()
	scale = Vector2.ONE
	modulate.a = 1.0
	_set_glow(0.0)


func is_animating() -> bool:
	return _tween != null and _tween.is_valid()


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _set_glow(value: float) -> void:
	_glow = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var body := Rect2(Vector2.ZERO, size)
	var tint := ClusterTheme.symbol_tint(symbol)
	# A recessed seat so the painted gem reads as set into the board, not pasted
	# on it. The seat warms toward the symbol's own colour as the tile wins.
	var seat := ClusterTheme.GRID_WELL.lerp(tint, 0.08 + 0.16 * _glow)
	draw_style_box(ClusterTheme.box(seat, tint.darkened(0.55 - 0.40 * _glow), 1, 5), body)
	draw_texture_rect(
		ClusterTheme.symbol_texture(symbol), body, false, Color.WHITE.lerp(tint, 0.18 * _glow)
	)
	if _glow > 0.0:
		# The win ring: one bounded brass outline, no bloom pass.
		draw_style_box(
			ClusterTheme.box(Color(0, 0, 0, 0), Color(ClusterTheme.WIN, _glow), 2, 5),
			body.grow(1.0)
		)
