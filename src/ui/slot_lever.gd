class_name SlotLever
extends Node2D
## Mouse-accessible mechanical lever that mirrors the primary spin action.

signal pressed

const ARM := preload("res://assets/production/slot/elven/lever_arm.png")
## Centre of the rounded pivot cap in the arm master (tools/art/slot_elven_prepare.py).
const ARM_PIVOT := Vector2(88.5, 1002)
## ~110 px from pivot to crystal tip on the 960x540 canvas.
const ARM_SCALE: float = 0.112

var disabled: bool = false:
	set(value):
		disabled = value
		if _hit_target != null:
			_hit_target.disabled = value
		queue_redraw()

var _hit_target: Button


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_hit_target = Button.new()
	_hit_target.name = "LeverHitTarget"
	# Covers shaft and crystal (>= 44 px wide) while staying inside TV-safe x.
	_hit_target.position = Vector2(-32, -112)
	_hit_target.size = Vector2(64, 128)
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
	# Elven Court lever: the painted silver-and-emerald arm pivots in the carved
	# mount painted on the cabinet flank. Hover brightens it; disabled dims it.
	var tint := Color(1, 1, 1)
	if disabled:
		tint = Color(0.62, 0.66, 0.64)
	elif _hit_target != null and _hit_target.is_hovered():
		tint = Color(1.12, 1.12, 1.08)
	draw_circle(Vector2(1, 2), 9.0, Color(0.02, 0.05, 0.03, 0.55))
	draw_texture_rect(ARM, Rect2(-ARM_PIVOT * ARM_SCALE, ARM.get_size() * ARM_SCALE), false, tint)
