class_name ClusterChargeBar
extends Control
## The upgrade rail above the board: the painted brass bar with one lamp per rung
## of the multiplier ladder and a fill that shows how close the next rung is.
##
## Destroyed symbols charge it. It is a readout, not a decision: the panel tells
## it how many symbols the round has destroyed so far and it lights the rungs the
## paytable says that charge has earned.

## Painted end caps, tiled middle: the diamond band repeats instead of smearing.
const BAR_INSET := Vector2(16, 9)

var thresholds: PackedInt32Array = PackedInt32Array()
var multipliers: PackedInt32Array = PackedInt32Array()
var base_multiplier: int = 1
var charge: int = 0
var multiplier: int = 1
var _fill: float = 0.0
var _flash: float = 0.0
var _flash_tween: Tween
var _plate: NinePatchRect
var _lamps: Lamps


func _init() -> void:
	name = "ClusterChargeBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	position = ClusterTheme.BAR_RECT.position
	size = ClusterTheme.BAR_RECT.size


func build(paytable: UpgradeClusterPaytable) -> void:
	thresholds = paytable.charge_thresholds
	multipliers = paytable.multipliers
	base_multiplier = paytable.base_multiplier
	multiplier = base_multiplier
	# The painted rail. Its height is drawn at source scale so the rails keep
	# their thickness; only the length repeats.
	_plate = NinePatchRect.new()
	_plate.name = "BarPlate"
	_plate.texture = ClusterTheme.MULTIPLIER_BAR
	_plate.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE_FIT
	for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_plate.set_patch_margin(side, ClusterTheme.BAR_PATCH)
	var kit_scale := size.y / float(ClusterTheme.MULTIPLIER_BAR.get_height())
	_plate.scale = Vector2.ONE * kit_scale
	_plate.size = Vector2(size.x / kit_scale, ClusterTheme.MULTIPLIER_BAR.get_height())
	add_child(_plate)
	# A Control draws itself *under* its children, so the lamps live in their own
	# child above the painted rail instead of behind its opaque centre.
	_lamps = Lamps.new()
	_lamps.bar = self
	_lamps.size = size
	add_child(_lamps)
	queue_redraw()


## `next_charge` is how many symbols the round has destroyed so far.
func set_charge(next_charge: int, next_multiplier: int) -> void:
	var stepped := next_multiplier > multiplier
	charge = maxi(next_charge, 0)
	multiplier = next_multiplier
	_fill = _progress()
	if stepped:
		_play_step()
	_redraw()


func reset() -> void:
	_stop()
	charge = 0
	multiplier = base_multiplier
	_fill = 0.0
	_flash = 0.0
	_redraw()


## How far the bar has come toward the next unlit rung, 0..1. A fully lit ladder
## reads as full.
func _progress() -> float:
	var previous: int = 0
	for index: int in range(thresholds.size()):
		if charge < thresholds[index]:
			var span := float(thresholds[index] - previous)
			return clampf(float(charge - previous) / maxf(span, 1.0), 0.0, 1.0)
		previous = thresholds[index]
	return 1.0


func _play_step() -> void:
	_stop()
	AudioService.play(&"chip")
	if MotionPolicy.is_reduced():
		_flash = 0.0
		return
	_flash = 1.0
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, ClusterTheme.phase(0.30)).set_trans(
		Tween.TRANS_QUAD
	)


func _set_flash(value: float) -> void:
	_flash = value
	_redraw()


func _stop() -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = null


func settle() -> void:
	_stop()
	_flash = 0.0
	_redraw()


func has_active_motion() -> bool:
	return _flash_tween != null and _flash_tween.is_valid()


func flash() -> float:
	return _flash


func fill() -> float:
	return _fill


## The lamp rectangle for rung `index`, inside the painted rail.
func lamp_rect(index: int) -> Rect2:
	var inner := Rect2(BAR_INSET, size - BAR_INSET * 2.0)
	var count := maxi(multipliers.size(), 1)
	var slot := inner.size.x / float(count)
	return Rect2(
		Vector2(inner.position.x + slot * float(index) + 2.0, inner.position.y + 2.0),
		Vector2(slot - 4.0, inner.size.y - 4.0)
	)


func _redraw() -> void:
	queue_redraw()
	if _lamps != null:
		_lamps.queue_redraw()


## The rungs and the charge rule, drawn over the painted rail.
class Lamps:
	extends Control

	var bar: ClusterChargeBar

	func _init() -> void:
		name = "Rungs"
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if bar == null:
			return
		var font := Typography.DISPLAY_FONT
		for index: int in range(bar.multipliers.size()):
			var rect := bar.lamp_rect(index)
			var lit := (
				bar.multipliers[index] <= bar.multiplier and bar.multiplier > bar.base_multiplier
			)
			var current := bar.multipliers[index] == bar.multiplier
			var face := ClusterTheme.HARLEQUIN_GREEN if lit else Color(ClusterTheme.INSET, 0.72)
			if current:
				face = face.lerp(ClusterTheme.WIN, 0.32 + 0.45 * bar.flash())
			var border := ClusterTheme.EDGE_BRIGHT if lit else ClusterTheme.HAIRLINE
			draw_style_box(ClusterTheme.box(face, border, 1, 3), rect)
			var ink := ClusterTheme.TEXT if lit else ClusterTheme.TEXT_DISABLED
			var font_size := 13
			draw_string(
				font,
				Vector2(
					rect.position.x,
					(
						rect.get_center().y
						+ (font.get_ascent(font_size) - font.get_descent(font_size)) * 0.5
					)
				),
				"%dx" % bar.multipliers[index],
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				font_size,
				ink
			)
		# The charge toward the next rung: one thin brass rule along the foot.
		if bar.fill() > 0.0:
			draw_rect(
				Rect2(
					Vector2(ClusterChargeBar.BAR_INSET.x, size.y - 5.0),
					Vector2((size.x - ClusterChargeBar.BAR_INSET.x * 2.0) * bar.fill(), 2.0)
				),
				ClusterTheme.EDGE_BRIGHT
			)
