class_name CreditChipIcon
extends Control
## Painted casino chip stack used by the global credit HUD.
##
## The art-deco chip master carries the look; code only adds a restrained idle
## lift and a one-off credit/debit ring when the balance changes.

const CHIP_TEXTURE: Texture2D = preload("res://assets/production/ui/hud_chip_stack.png")
const ICON_SIZE := Vector2(40, 40)

var idle_time: float = 0.0
var transaction_time: float = 0.0
var transaction_direction: int = 0


func _ready() -> void:
	custom_minimum_size = ICON_SIZE
	size = ICON_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())
	queue_redraw()


func _process(delta: float) -> void:
	if MotionPolicy.allows_continuous_motion():
		idle_time = fmod(idle_time + delta, 6.0)
	if transaction_time > 0.0:
		transaction_time = maxf(transaction_time - delta, 0.0)
	queue_redraw()
	if transaction_time <= 0.0 and not MotionPolicy.allows_continuous_motion():
		set_process(false)


func play_transaction(delta_chips: int) -> void:
	transaction_direction = signi(delta_chips)
	transaction_time = MotionPolicy.finite_duration(0.42)
	set_process(true)
	queue_redraw()


func _apply_motion_preference(reduced: bool) -> void:
	if reduced:
		idle_time = 0.0
		transaction_time = 0.0
		transaction_direction = 0
	set_process(not reduced or transaction_time > 0.0)
	queue_redraw()


func _draw() -> void:
	var breath := (
		(sin(idle_time * TAU / 3.2) + 1.0) * 0.5
		if MotionPolicy.allows_continuous_motion()
		else 0.0
	)
	draw_texture_rect(CHIP_TEXTURE, Rect2(Vector2(0.0, -breath * 0.6), ICON_SIZE), false)
	if transaction_time > 0.0:
		var progress := 1.0 - transaction_time / MotionPolicy.finite_duration(0.42)
		var accent := Color("68f0a4") if transaction_direction >= 0 else Color("f2c84b")
		accent.a = (1.0 - progress) * 0.7
		draw_arc(ICON_SIZE * 0.5, 16.0 + progress * 6.0, 0.0, TAU, 32, accent, 1.5, true)
