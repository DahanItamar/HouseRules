class_name ClusterMathPopup
extends Control
## Phase 2 of a cascade: the win for the clusters that just pulsed, popped over
## them on an elastic tween, held, then floated up and faded.
##
## It shows exactly what the machine just worked out - "0.32 x256" - so the
## multiplier is never something the player has to infer. It is presentation
## only: it is handed the numbers and reports when it has finished.

## Kept inside the board, and never over a rectangle the player must keep
## reading, by `anchor_for`.
const MARGIN: float = 6.0
const POP_SCALE := Vector2(1.18, 1.18)
const RISE_PIXELS: float = 26.0

var base_units: int = 0
var multiplier: int = 1
var _label_size := Vector2(150, 38)


func _init() -> void:
	name = "ClusterMathPopup"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = _label_size
	pivot_offset = size * 0.5
	visible = false
	z_index = 20


## Where the popup should sit for a cluster centred on `centre`: over the
## cluster, pushed back inside the board and clear of the protected readouts.
func anchor_for(centre: Vector2) -> Vector2:
	var board := ClusterTheme.GRID_RECT
	var top_left := centre - size * 0.5
	top_left.x = clampf(top_left.x, board.position.x + MARGIN, board.end.x - size.x - MARGIN)
	top_left.y = clampf(top_left.y, board.position.y + MARGIN, board.end.y - size.y - MARGIN)
	return top_left


## Runs the whole beat and returns when it is over. Awaited by the panel, so the
## shatter can never start while the number is still being read.
func play(units: int, times: int, centre: Vector2) -> void:
	base_units = units
	multiplier = times
	position = anchor_for(centre)
	pivot_offset = size * 0.5
	visible = true
	queue_redraw()
	AudioService.play(&"confirm")
	if MotionPolicy.is_reduced():
		# One static, bounded hold. The number is the point; the elastic is not.
		scale = Vector2.ONE
		modulate.a = 1.0
		var still := create_tween()
		still.tween_interval(
			(
				ClusterTheme.phase(ClusterTheme.MATH_POP_SECONDS)
				+ ClusterTheme.phase(ClusterTheme.MATH_HOLD_SECONDS)
			)
		)
		await still.finished
		visible = false
		return
	scale = Vector2(0.45, 0.45)
	modulate.a = 0.0
	var pop := create_tween().set_parallel(true)
	(
		pop
		. tween_property(self, "scale", POP_SCALE, ClusterTheme.MATH_POP_SECONDS)
		. set_trans(Tween.TRANS_ELASTIC)
		. set_ease(Tween.EASE_OUT)
	)
	pop.tween_property(self, "modulate:a", 1.0, ClusterTheme.MATH_POP_SECONDS * 0.5)
	pop.chain().tween_property(self, "scale", Vector2.ONE, 0.10).set_trans(Tween.TRANS_QUAD)
	await pop.finished
	var hold := create_tween()
	hold.tween_interval(ClusterTheme.MATH_HOLD_SECONDS)
	await hold.finished
	var rise := create_tween().set_parallel(true)
	(
		rise
		. tween_property(
			self, "position:y", position.y - RISE_PIXELS, ClusterTheme.MATH_RISE_SECONDS
		)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	rise.tween_property(self, "modulate:a", 0.0, ClusterTheme.MATH_RISE_SECONDS)
	await rise.finished
	visible = false


func settle() -> void:
	visible = false
	scale = Vector2.ONE
	modulate.a = 1.0


## The text the popup shows, e.g. "0.32 x256" (or "0.32" with no upgrade yet).
func win_text() -> String:
	var amount := ClusterTheme.bet_text(base_units)
	if multiplier <= 1:
		return amount
	return "%s  x%d" % [amount, multiplier]


func _draw() -> void:
	var body := Rect2(Vector2.ZERO, size)
	draw_style_box(
		ClusterTheme.box(Color(ClusterTheme.VOID, 0.86), ClusterTheme.EDGE_BRIGHT, 2, 6), body
	)
	var font := Typography.DISPLAY_FONT
	var font_size := 26 if multiplier <= 1 else 23
	draw_string(
		font,
		Vector2(0, size.y * 0.5 + (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5),
		win_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		size.x,
		font_size,
		ClusterTheme.WIN
	)
