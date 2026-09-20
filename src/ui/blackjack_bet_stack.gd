class_name BlackjackBetStack
extends Control
## Presentation-only wager on the felt: a painted chip stack beside the player's
## hand with a small brass-framed amount plate. The cabinet remains the source of
## truth for stake values; this node only shows them.
##
## Result beats (never touching settlement):
##   win   a matching payout stack slides out from the dealer to sit beside the bet
##   loss  the bet slides across the felt to the dealer and is collected
##   push  the bet stays where it is

enum Settle { NONE, WIN, LOSS, PUSH }

const CHIP_TEXTURE := preload("res://assets/production/blackjack/props/chip_stack_v2.png")
## Top-left of the control on the felt, left of the player's hand lane.
const TABLE_POSITION := Vector2(290, 342)
## Placement starts just nearer the player and settles onto the felt.
const SOURCE_POSITION := Vector2(290, 372)
## In front of the dealer, where collected bets and payouts come from.
const DEALER_POSITION := Vector2(452, 206)
const STACK_SIZE := Vector2(80, 76)
const CHIP_RECT := Rect2(10, 0, 32, 45)
const PAYOUT_OFFSET := Vector2(34, 4)
const PLATE_RECT := Rect2(4, 52, 64, 20)
const COLLECT_SECONDS: float = 0.34
## Between hands the chosen stake waits on the betting spot at this opacity, so
## the bet reads as chips on the table before the deal commits it.
const PREVIEW_ALPHA: float = 0.55
const PAYOUT_SECONDS: float = 0.36

var wager: int = 0
var is_live: bool = false
var preview: bool = false
var settle_kind: Settle = Settle.NONE
## Payout stack offset relative to this control (animated from the dealer).
var payout_offset: Vector2 = PAYOUT_OFFSET
var payout_visible: bool = false
var payout_amount: int = 0
var _placement_tween: Tween
var _settle_tween: Tween


func _ready() -> void:
	custom_minimum_size = STACK_SIZE
	size = STACK_SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	queue_redraw()


## Shows the chosen (not yet committed) stake on the betting spot; 0 hides it.
func show_preview(amount: int) -> void:
	if is_live or settle_kind != Settle.NONE:
		return
	if _placement_tween != null and _placement_tween.is_valid():
		_placement_tween.kill()
	preview = amount > 0
	wager = maxi(amount, 0)
	visible = preview
	position = TABLE_POSITION
	modulate = Color(1, 1, 1, PREVIEW_ALPHA)
	queue_redraw()


func place_wager(amount: int, animated: bool = true) -> void:
	var was_live := is_live
	var was_preview := preview
	preview = false
	wager = maxi(amount, 0)
	is_live = wager > 0
	visible = is_live
	if not is_live:
		return
	if settle_kind != Settle.NONE:
		# A settled bet keeps its end state until the next round clears it.
		queue_redraw()
		return
	if _placement_tween != null and _placement_tween.is_valid():
		_placement_tween.kill()
	modulate = Color.WHITE
	if was_preview and not was_live:
		# The previewed chips are already on the spot: the deal just commits them.
		position = TABLE_POSITION
		if not animated or MotionPolicy.is_reduced():
			modulate.a = 1.0
			queue_redraw()
			return
		modulate.a = PREVIEW_ALPHA
		_placement_tween = create_tween()
		_placement_tween.tween_property(self, "modulate:a", 1.0, 0.16)
		queue_redraw()
		return
	var slide := animated and not was_live and not MotionPolicy.is_reduced()
	position = SOURCE_POSITION if animated and not was_live else TABLE_POSITION
	modulate.a = 0.0 if slide else 1.0
	queue_redraw()
	if not slide:
		position = TABLE_POSITION
		modulate.a = 1.0
		return
	_placement_tween = create_tween().set_parallel(true)
	(
		_placement_tween
		. tween_property(self, "position", TABLE_POSITION, 0.26)
		. set_trans(Tween.TRANS_CUBIC)
		. set_ease(Tween.EASE_OUT)
	)
	_placement_tween.tween_property(self, "modulate:a", 1.0, 0.14)


## Settles the wager for the shown result. Presentation only.
func settle(kind: Settle, amount: int, returned: int = 0) -> void:
	_stop_settle()
	preview = false
	if _placement_tween != null and _placement_tween.is_valid():
		_placement_tween.kill()
	wager = maxi(amount, 0)
	is_live = wager > 0
	visible = is_live
	settle_kind = kind
	position = TABLE_POSITION
	modulate = Color.WHITE
	payout_visible = kind == Settle.WIN
	payout_amount = maxi(returned, wager)
	payout_offset = PAYOUT_OFFSET
	queue_redraw()
	if not is_live:
		return
	if MotionPolicy.is_reduced():
		# Static end state: payout sits beside the bet, a lost bet is collected.
		if kind == Settle.LOSS:
			visible = false
		return
	_settle_tween = create_tween()
	match kind:
		Settle.WIN:
			payout_offset = DEALER_POSITION - TABLE_POSITION
			(
				_settle_tween
				. tween_method(_set_payout_offset, payout_offset, PAYOUT_OFFSET, PAYOUT_SECONDS)
				. set_delay(0.12)
				. set_trans(Tween.TRANS_CUBIC)
				. set_ease(Tween.EASE_OUT)
			)
		Settle.LOSS:
			_settle_tween.set_parallel(true)
			(
				_settle_tween
				. tween_property(self, "position", DEALER_POSITION, COLLECT_SECONDS)
				. set_delay(0.18)
				. set_trans(Tween.TRANS_CUBIC)
				. set_ease(Tween.EASE_IN_OUT)
			)
			_settle_tween.tween_property(self, "modulate:a", 0.0, 0.14).set_delay(
				0.18 + COLLECT_SECONDS - 0.08
			)
		_:
			_settle_tween.tween_interval(0.01)


func clear_wager(animated: bool = true) -> void:
	_stop_settle()
	preview = false
	settle_kind = Settle.NONE
	payout_visible = false
	payout_offset = PAYOUT_OFFSET
	if not is_live:
		visible = false
		return
	is_live = false
	if _placement_tween != null and _placement_tween.is_valid():
		_placement_tween.kill()
	if MotionPolicy.is_reduced() or not animated:
		visible = false
		wager = 0
		modulate = Color.WHITE
		queue_redraw()
		return
	_placement_tween = create_tween().set_parallel(true)
	_placement_tween.tween_property(self, "modulate:a", 0.0, 0.14)
	_placement_tween.finished.connect(
		func() -> void:
			visible = false
			wager = 0
			modulate = Color.WHITE
			queue_redraw()
	)


func is_settling() -> bool:
	return _settle_tween != null and _settle_tween.is_valid() and _settle_tween.is_running()


func _set_payout_offset(offset: Vector2) -> void:
	payout_offset = offset
	queue_redraw()


func _stop_settle() -> void:
	if _settle_tween != null and _settle_tween.is_valid():
		_settle_tween.kill()
	_settle_tween = null


func _apply_motion_preference(reduced: bool) -> void:
	if not reduced:
		return
	if _placement_tween != null and _placement_tween.is_valid():
		_placement_tween.kill()
		position = TABLE_POSITION
		rotation = 0.0
		scale = Vector2.ONE
		modulate = Color.WHITE
	if is_settling():
		_stop_settle()
		position = TABLE_POSITION
		modulate = Color.WHITE
		payout_offset = PAYOUT_OFFSET
		if settle_kind == Settle.LOSS:
			visible = false
	queue_redraw()


func _draw() -> void:
	if not is_live and not preview:
		return
	_draw_chips(Vector2.ZERO)
	if payout_visible:
		_draw_chips(payout_offset)
	var plate := StyleBoxFlat.new()
	plate.bg_color = Color("17161af0")
	plate.border_color = Color("c8a34b")
	plate.set_border_width_all(1)
	plate.set_corner_radius_all(4)
	plate.anti_aliasing = true
	draw_style_box(plate, PLATE_RECT)
	var amount := payout_amount if payout_visible else wager
	draw_string(
		Typography.DISPLAY_FONT,
		PLATE_RECT.position + Vector2(0, 15),
		str(amount),
		HORIZONTAL_ALIGNMENT_CENTER,
		PLATE_RECT.size.x,
		14,
		Color("f1e8d8")
	)


func _draw_chips(offset: Vector2) -> void:
	# Flat contact shadow on the felt, then the painted stack.
	var base := CHIP_RECT.position + offset + Vector2(CHIP_RECT.size.x * 0.5, CHIP_RECT.size.y - 5)
	var shadow := PackedVector2Array()
	for step: int in range(20):
		var angle := TAU * float(step) / 20.0
		shadow.append(base + Vector2(cos(angle) * 17.0, sin(angle) * 6.0 + 2.0))
	draw_colored_polygon(shadow, Color(0.0, 0.03, 0.02, 0.32))
	draw_texture_rect(CHIP_TEXTURE, Rect2(CHIP_RECT.position + offset, CHIP_RECT.size), false)
