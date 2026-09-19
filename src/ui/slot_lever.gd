class_name SlotLever
extends Node2D
## Mouse-accessible mechanical lever that mirrors the primary spin action.

signal pressed

var disabled: bool = false:
	set(value):
		disabled = value
		if _hit_target != null:
			_hit_target.disabled = value
		queue_redraw()

var _hit_target: Button


func _ready() -> void:
	_hit_target = Button.new()
	_hit_target.name = "LeverHitTarget"
	_hit_target.position = Vector2(-30, -125)
	_hit_target.size = Vector2(118, 250)
	_hit_target.focus_mode = Control.FOCUS_NONE
	_hit_target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hit_target.tooltip_text = tr("SLOT_SPIN")
	_hit_target.accessibility_name = tr("SLOT_SPIN")
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		_hit_target.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_hit_target.pressed.connect(func() -> void: pressed.emit())
	_hit_target.mouse_entered.connect(queue_redraw)
	_hit_target.mouse_exited.connect(queue_redraw)
	add_child(_hit_target)
	_hit_target.disabled = disabled
	queue_redraw()


func settle() -> void:
	rotation = 0.0


func _draw() -> void:
	var base := Vector2.ZERO
	var handle := Vector2(0, -92)
	var dim := 0.68 if disabled else 1.0
	var hovered := _hit_target != null and _hit_target.is_hovered() and not disabled
	var hover_lift := 0.08 if hovered else 0.0

	draw_circle(base + Vector2(3, 4), 24.0, Color("0504058c") * dim)
	draw_circle(base, 23.0, Color("2a1517") * dim)
	draw_circle(base, 18.0, Color("6b1723") * dim)
	draw_arc(base, 20.0, 0.0, TAU, 32, Color("c8a34b") * dim, 3.0)
	draw_line(base, handle, Color("090709") * dim, 11.0, true)
	draw_line(base, handle, Color("c8a34b") * dim, 6.0, true)
	draw_circle(handle + Vector2(2, 3), 18.0, Color("05040580") * dim)
	draw_circle(handle, 17.0, Color("71101f") * dim)
	draw_circle(
		handle + Vector2(-4, -5),
		6.0,
		Color(0.95, 0.76, 0.43, 0.52 + hover_lift) * dim
	)
	draw_arc(handle, 16.0, 0.0, TAU, 32, Color("f2c84b") * dim, 2.0)
