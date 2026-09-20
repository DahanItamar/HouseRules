class_name SlotSpinButton
extends Button
## Physical primary action for the Elven Court slot control deck.
##
## The seal carries the input that presses it, drawn above the word so a controller
## player never has to guess which button spins the reels.

const GOLD := Color("c9a646")
const GOLD_BRIGHT := Color("ecd27c")
const EMERALD := Color("1f6b4a")
const SILVER := Color("d8d3c2")

var idle_time: float = 0.0


func _ready() -> void:
	text = ""
	flat = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	InputRouter.active_device_changed.connect(func(_device: int) -> void: queue_redraw())
	InputRouter.gamepad_family_changed.connect(func(_family: int) -> void: queue_redraw())
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	focus_mode = Control.FOCUS_ALL
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	MotionPolicy.motion_preference_changed.connect(_apply_motion_preference)
	_apply_motion_preference(MotionPolicy.is_reduced())
	set_process(true)


func _process(delta: float) -> void:
	if disabled or not MotionPolicy.allows_continuous_motion():
		return
	idle_time = fmod(idle_time + delta, 8.0)
	queue_redraw()


func _draw() -> void:
	# Elven Court seal: a flat emerald medallion in a gold ring with a pale
	# silver inner line, flanked by carved laurel leaves. No gradients or glow;
	# keyboard/controller focus adds the shared cyan ring.
	var center := size * 0.5
	var idle_breath := (
		(sin(idle_time * TAU / 1.8) + 1.0) * 0.5
		if not disabled and MotionPolicy.allows_continuous_motion()
		else 0.0
	)
	var active_radius := 35.0 if button_pressed else 37.5 + idle_breath * 0.8
	var gold := (
		GOLD_BRIGHT if is_hovered() or has_focus() else GOLD.lerp(GOLD_BRIGHT, idle_breath * 0.3)
	)
	if disabled:
		gold = Color("6f5d2c")
	var face := Color("14261e") if disabled else EMERALD
	for side: float in [-1.0, 1.0]:
		for leaf: int in range(3):
			var angle := deg_to_rad(-38.0 + leaf * 38.0)
			var base := (
				center
				+ Vector2(side * 46.0, 0.0)
				+ Vector2(side * cos(angle) * 6.0, sin(angle) * 20.0)
			)
			_draw_leaf(base, Vector2(side * cos(angle * 0.6), sin(angle) * 0.55).normalized(), gold)
	draw_circle(center, 45.0, Color("071009"))
	if has_focus():
		draw_arc(center, 47.0, 0.0, TAU, 64, Color("48c5d5"), 2.0, true)
	draw_circle(center, 42.0, gold)
	draw_circle(center, active_radius, face)
	draw_arc(center, active_radius - 4.0, 0.0, TAU, 48, Color(SILVER, 0.75), 1.5, true)
	var label := tr("SLOT_SPIN")
	var text_size := Typography.DISPLAY_FONT.get_string_size(
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22
	)
	draw_string(
		Typography.DISPLAY_FONT,
		center + Vector2(-text_size.x * 0.5, 8.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		22,
		Color("7f8a80") if disabled else Color("f6eed8")
	)
	# The prompt sits inside the seal, above the word, so the two read as one key.
	var spec := InputRouter.glyph_spec(&"interact")
	var glyph_height := 19.0
	var glyph_width := InputGlyph.measure(spec, glyph_height)
	InputGlyph.draw_spec(
		self,
		spec,
		Rect2(
			center + Vector2(-glyph_width * 0.5, -glyph_height - 4.0),
			Vector2(glyph_width, glyph_height)
		)
	)


func _draw_leaf(base: Vector2, direction: Vector2, color: Color) -> void:
	var tip := base + direction * 20.0
	var normal := Vector2(-direction.y, direction.x) * 6.5
	var middle := base.lerp(tip, 0.45)
	draw_colored_polygon(PackedVector2Array([base, middle + normal, tip, middle - normal]), color)
	draw_line(base.lerp(tip, 0.15), base.lerp(tip, 0.8), Color("071009", 0.55), 1.0, true)


func _apply_motion_preference(reduced: bool) -> void:
	if reduced:
		idle_time = 0.0
	set_process(not reduced)
	queue_redraw()
