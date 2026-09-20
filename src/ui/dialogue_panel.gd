class_name DialoguePanel
extends Control
## Flat near-black speech panel with brass rules, the speaker's name and a
## brass-framed portrait cameo that is part of the panel. Keyboard, controller
## and mouse navigable.
##
## Nothing of the speaker extends outside the panel: the cameo shows head to
## mid-torso, cropped by its frame, on the side nearest the speaker (or the
## nearest screen edge) and always turned toward the text. In a room where the
## speaker is painted in, the caller anchors the panel beside them and a small
## brass pointer marks who is talking. The panel never covers the player, HUD
## controls or interaction targets: the caller passes those rectangles and the
## first placement that clears them is used. While text reveals, the cameo
## breathes (under 1% scale) and gives a small head-and-shoulder talk bob (under
## 2 px). Reduced motion shows a static cameo and the whole line at once.

signal choice_selected(choice_id: StringName)

const SURFACE := Color("0e0b0df5")
const CAMEO_SURFACE := Color("080607")
const BUTTON_FILL := Color("1b1417")
const BUTTON_HOVER := Color("2a1f22")
const BUTTON_PRESSED := Color("0c0a0c")
const BRASS := Color("c8a34b")
const IVORY := Color("f1e8d8")
const CYAN := Color("48c5d5")
const SAFE_RECT := Rect2(48, 27, 864, 486)
const MIN_TARGET: float = 44.0
const PANEL_SIZE := Vector2(460, 144)
const CAMEO_SIZE := Vector2(112, 124)
const CAMEO_MARGIN: float = 10.0
const POINTER_SIZE: float = 8.0
const REVEAL_CHARS_PER_SECOND: float = 60.0
const BREATH_PERIOD: float = 3.6
const BREATH_SCALE: float = 0.006
const TALK_PERIOD: float = 0.34
const TALK_BOB: float = 1.5
## Placements for a speaker who is not in the room, tried in order. The cameo
## sits on the side nearest the screen edge.
const LAYOUTS: Array[Dictionary] = [
	{"name": &"bottom_left", "panel": Rect2(48, 369, 460, 144), "cameo_side": &"left"},
	{"name": &"top_left", "panel": Rect2(48, 70, 460, 144), "cameo_side": &"left"},
	{"name": &"bottom_right", "panel": Rect2(452, 369, 460, 144), "cameo_side": &"right"},
	{"name": &"top_right", "panel": Rect2(452, 70, 460, 144), "cameo_side": &"right"},
]

var layout_name: StringName = &""
var cameo_side: StringName = &"left"
var blocking: bool = true
var _panel: Panel
var _rules: Array[ColorRect] = []
var _name_label: Label
var _body: InputPromptLabel
var _cameo_frame: Panel
var _cameo_clip: Control
var _cameo: TextureRect
var _pointer: Polygon2D
var _buttons: Array[Button] = []
var _choice_ids: Array[StringName] = []
var _speaker_faces_right: bool = true
var _pointer_target := Vector2.ZERO
var _revealing: bool = false
var _reveal_progress: float = 0.0
var _time: float = 0.0
var _open: bool = false


func _init() -> void:
	name = "DialoguePanel"
	size = Vector2(960, 540)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func _ready() -> void:
	if _panel == null:
		_build()
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)


func is_open() -> bool:
	return _open


func is_revealing() -> bool:
	return _revealing


func panel_rect() -> Rect2:
	return Rect2(_panel.position, _panel.size)


## The cameo window in screen space; always inside `panel_rect()`.
func cameo_rect() -> Rect2:
	return Rect2(_panel.position + _cameo_frame.position, _cameo_frame.size)


## The screen-space rectangle the panel and its pointer occupy.
func occupied_rect() -> Rect2:
	var rect := panel_rect()
	if _pointer.visible:
		for point: Vector2 in _pointer.polygon:
			rect = rect.expand(_panel.position + point)
	return rect


func speaker_text() -> String:
	return _name_label.text


func body_text() -> String:
	return _body.text


func visible_body_characters() -> int:
	return _body.visible_characters


func portrait() -> Texture2D:
	var atlas := _cameo.texture as AtlasTexture
	return atlas.atlas if atlas != null else null


func cameo_texture_rect() -> TextureRect:
	return _cameo


func pointer_visible() -> bool:
	return _pointer.visible


func choice_buttons() -> Array[Button]:
	return _buttons.duplicate()


func choice_ids() -> Array[StringName]:
	return _choice_ids.duplicate()


## True when the cameo's figure is turned toward the text column.
func speaker_faces_text() -> bool:
	var facing_right := _speaker_faces_right != _cameo.flip_h
	return facing_right == (cameo_side == &"left")


## Shows one line. `speaker` is {"name", "texture", "region", "faces_right"};
## `choices` is [{"id", "label", "action"?}]: an optional input action draws its
## glyph on the button. The line may carry input tokens such as `{move}`.
## `placement` optionally anchors the panel near a painted speaker:
## {"panel": Rect2, "cameo_side": StringName, "pointer": Vector2}.
## `hard` rectangles must stay uncovered; `soft` ones are avoided when possible.
func present(
	speaker: Dictionary,
	text_value: String,
	choices: Array[Dictionary],
	hard: Array[Rect2] = [],
	soft: Array[Rect2] = [],
	is_blocking: bool = true,
	placement: Dictionary = {}
) -> void:
	if _panel == null:
		_build()
	blocking = is_blocking
	_speaker_faces_right = bool(speaker.get("faces_right", true))
	var atlas := AtlasTexture.new()
	atlas.atlas = speaker.texture
	atlas.region = speaker.region
	_cameo.texture = atlas
	_name_label.text = String(speaker.name)
	_body.template = text_value
	_apply_layout(_choose(placement, hard, soft), placement)
	_set_choices(choices)
	_open = true
	visible = true
	_time = 0.0
	if MotionPolicy.is_reduced():
		_finish_reveal_now()
	else:
		_revealing = true
		_reveal_progress = 0.0
		_body.visible_characters = 0
	_apply_rest_pose()
	# A non-blocking line never takes focus, so confirm still reaches the floor.
	if blocking and not _buttons.is_empty():
		focus_when_ready(_buttons[0])
	elif not blocking:
		_release_focus()


func close() -> void:
	_open = false
	_revealing = false
	visible = false
	_apply_rest_pose()
	_release_focus()


## Moves the open line to a placement that clears the given rectangles
## without restarting its text.
func relayout(hard: Array[Rect2], soft: Array[Rect2] = [], placement: Dictionary = {}) -> void:
	if not _open:
		return
	var chosen := _choose(placement, hard, soft)
	if chosen.name == layout_name:
		return
	var choices := _current_choices()
	_apply_layout(chosen, placement)
	_set_choices(choices)


func finish_reveal() -> void:
	_finish_reveal_now()


## Keyboard/controller navigation. Returns true when the event was used.
func handle_input(event: InputEvent) -> bool:
	if not _open:
		return false
	if event.is_action_pressed("interact"):
		if _revealing:
			_finish_reveal_now()
			return true
		var focused := get_viewport().gui_get_focus_owner()
		if focused is Button and _panel.is_ancestor_of(focused):
			(focused as Button).pressed.emit()
		elif not _buttons.is_empty():
			_buttons[0].pressed.emit()
		return true
	if not blocking:
		return false
	for action: String in ["move_left", "move_up"]:
		if event.is_action_pressed(action):
			_step_focus(-1)
			return true
	for action: String in ["move_right", "move_down"]:
		if event.is_action_pressed(action):
			_step_focus(1)
			return true
	return false


## The first placement that clears every hard rectangle, preferring one that
## also clears the soft ones; otherwise the least-overlapping placement.
static func choose_layout(
	hard: Array[Rect2], soft: Array[Rect2] = [], candidates: Array[Dictionary] = LAYOUTS
) -> Dictionary:
	var best: Dictionary = candidates[0]
	var best_score := INF
	for candidate: Dictionary in candidates:
		var rect: Rect2 = candidate.panel
		var score := 0.0
		for blocked: Rect2 in hard:
			if rect.intersects(blocked):
				score += 1000.0 + rect.intersection(blocked).get_area() * 1000.0
		for avoided: Rect2 in soft:
			if rect.intersects(avoided):
				score += 1.0 + rect.intersection(avoided).get_area()
		if score < best_score:
			best_score = score
			best = candidate
		if is_zero_approx(score):
			break
	return best


## Focuses a control after this frame's layout, unless it was freed or hidden.
static func focus_when_ready(button: Control) -> void:
	var button_id := button.get_instance_id()
	(
		(func() -> void:
			var target := instance_from_id(button_id) as Control
			if target != null and target.is_visible_in_tree():
				target.grab_focus())
		. call_deferred()
	)


func _process(delta: float) -> void:
	if not _open:
		return
	if _revealing:
		_reveal_progress += delta * REVEAL_CHARS_PER_SECOND
		_body.visible_characters = int(_reveal_progress)
		if _body.visible_characters >= _body.get_total_character_count():
			_finish_reveal_now()
	if not MotionPolicy.allows_continuous_motion():
		return
	_time += delta
	# Breathing lifts the chest from the frame's lower edge; while a line is
	# revealing, a small head-and-shoulder bob rides on top.
	var breath := (sin(_time * TAU / BREATH_PERIOD) + 1.0) * 0.5 * BREATH_SCALE
	_cameo.scale = Vector2(1.0 + breath * 0.4, 1.0 + breath)
	var bob := absf(sin(_time * TAU / TALK_PERIOD)) * TALK_BOB if _revealing else 0.0
	_cameo.position = Vector2(0.0, -bob)


func _choose(placement: Dictionary, hard: Array[Rect2], soft: Array[Rect2]) -> Dictionary:
	if placement.has("panel"):
		var anchored := {
			"name": &"anchored",
			"panel": placement.panel,
			"cameo_side": placement.get("cameo_side", &"left"),
		}
		var candidates: Array[Dictionary] = [anchored]
		candidates.append_array(LAYOUTS)
		return choose_layout(hard, soft, candidates)
	return choose_layout(hard, soft)


func _apply_layout(chosen: Dictionary, placement: Dictionary) -> void:
	layout_name = chosen.name
	cameo_side = chosen.cameo_side
	var rect: Rect2 = chosen.panel
	_panel.position = rect.position
	_panel.size = rect.size
	var width := rect.size.x
	var height := rect.size.y
	_rules[0].size.x = width - 32.0
	_rules[1].position.y = height - 7.0
	_rules[1].size.x = width - 32.0
	var cameo_x := CAMEO_MARGIN if cameo_side == &"left" else width - CAMEO_MARGIN - CAMEO_SIZE.x
	_cameo_frame.position = Vector2(cameo_x, (height - CAMEO_SIZE.y) * 0.5)
	_cameo_frame.size = CAMEO_SIZE
	_cameo_clip.size = CAMEO_SIZE - Vector2(2, 2)
	_cameo.size = _cameo_clip.size
	_cameo.pivot_offset = Vector2(_cameo.size.x * 0.5, _cameo.size.y)
	# The figure turns toward the text column: mirror it when it would face away.
	_cameo.flip_h = _speaker_faces_right != (cameo_side == &"left")
	var text_x := CAMEO_MARGIN * 2.0 + CAMEO_SIZE.x if cameo_side == &"left" else 16.0
	var text_width := width - CAMEO_SIZE.x - CAMEO_MARGIN * 2.0 - 22.0
	_name_label.position = Vector2(text_x, 10)
	_name_label.size = Vector2(text_width, 22)
	_body.position = Vector2(text_x, 32)
	_body.size = Vector2(text_width, height - 32.0 - MIN_TARGET - 16.0)
	_pointer_target = Vector2.ZERO
	if chosen.name == &"anchored":
		_pointer_target = placement.get("pointer", Vector2.ZERO)
	_place_pointer()


func _place_pointer() -> void:
	_pointer.visible = _pointer_target != Vector2.ZERO
	if not _pointer.visible:
		return
	var rect := panel_rect()
	var local := _pointer_target - rect.position
	var edge_y := clampf(local.y, 16.0, rect.size.y - 16.0)
	var edge_x := rect.size.x if local.x >= rect.size.x else 0.0
	var tip := POINTER_SIZE if edge_x > 0.0 else -POINTER_SIZE
	_pointer.polygon = PackedVector2Array(
		[
			Vector2(edge_x, edge_y - POINTER_SIZE),
			Vector2(edge_x + tip, edge_y),
			Vector2(edge_x, edge_y + POINTER_SIZE),
		]
	)


func _finish_reveal_now() -> void:
	_revealing = false
	if _body != null:
		_body.visible_characters = -1


func _apply_rest_pose() -> void:
	if _cameo != null:
		_cameo.scale = Vector2.ONE
		_cameo.position = Vector2.ZERO


func _on_motion_preference_changed(reduced: bool) -> void:
	if reduced:
		_finish_reveal_now()
		_apply_rest_pose()


func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	if focused != null and is_ancestor_of(focused):
		focused.release_focus()


func _step_focus(step: int) -> void:
	if _buttons.is_empty():
		return
	var focused := get_viewport().gui_get_focus_owner()
	var index := _buttons.find(focused as Button)
	index = clampi(index + step, 0, _buttons.size() - 1) if index >= 0 else 0
	_buttons[index].grab_focus()
	AudioService.play(&"move")


func _current_choices() -> Array[Dictionary]:
	var choices: Array[Dictionary] = []
	for index: int in range(_buttons.size()):
		var choice := {"id": _choice_ids[index], "label": _buttons[index].text}
		var prompt := _buttons[index] as PromptButton
		if prompt != null and prompt.action != &"":
			choice["action"] = prompt.action
		choices.append(choice)
	return choices


func _set_choices(choices: Array[Dictionary]) -> void:
	for button: Button in _buttons:
		_panel.remove_child(button)
		button.queue_free()
	_buttons.clear()
	_choice_ids.clear()
	var count := choices.size()
	if count == 0:
		return
	var column_x := _body.position.x
	var column_width := _body.size.x
	var width := minf(180.0, (column_width - 8.0 * (count - 1)) / count)
	var x := column_x + column_width - (width * count + 8.0 * (count - 1))
	for index: int in range(count):
		var choice: Dictionary = choices[index]
		var button := PromptButton.new()
		button.action = StringName(choice.get("action", &""))
		button.name = "Choice_%s" % String(choice.id)
		button.text = String(choice.label)
		button.position = Vector2(x + index * (width + 8.0), _panel.size.y - MIN_TARGET - 12.0)
		button.size = Vector2(width, MIN_TARGET)
		button.custom_minimum_size = Vector2(width, MIN_TARGET)
		button.clip_text = true
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_style_button(button)
		var choice_id: StringName = StringName(choice.id)
		button.pressed.connect(_on_choice_pressed.bind(choice_id))
		_panel.add_child(button)
		ButtonFeedback.attach(button)
		_buttons.append(button)
		_choice_ids.append(choice_id)
	for index: int in range(count):
		var button := _buttons[index]
		button.focus_neighbor_left = _buttons[maxi(index - 1, 0)].get_path()
		button.focus_neighbor_right = _buttons[mini(index + 1, count - 1)].get_path()


func _on_choice_pressed(choice_id: StringName) -> void:
	if _revealing:
		_finish_reveal_now()
		return
	AudioService.play(&"confirm")
	choice_selected.emit(choice_id)


func _build() -> void:
	_panel = Panel.new()
	_panel.name = "SpeechPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.size = PANEL_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = Color(BRASS, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	for y: float in [6.0, PANEL_SIZE.y - 7.0]:
		var rule := ColorRect.new()
		rule.name = "BrassRule"
		rule.color = BRASS
		rule.position = Vector2(16, y)
		rule.size = Vector2(PANEL_SIZE.x - 32.0, 1)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_panel.add_child(rule)
		_rules.append(rule)
	_pointer = Polygon2D.new()
	_pointer.name = "SpeakerPointer"
	_pointer.color = BRASS
	_pointer.visible = false
	_panel.add_child(_pointer)
	_cameo_frame = Panel.new()
	_cameo_frame.name = "PortraitCameo"
	_cameo_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.bg_color = CAMEO_SURFACE
	frame_style.border_color = BRASS
	frame_style.set_border_width_all(1)
	_cameo_frame.add_theme_stylebox_override("panel", frame_style)
	_panel.add_child(_cameo_frame)
	_cameo_clip = Control.new()
	_cameo_clip.name = "CameoWindow"
	_cameo_clip.position = Vector2(1, 1)
	_cameo_clip.clip_contents = true
	_cameo_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cameo_frame.add_child(_cameo_clip)
	_cameo = TextureRect.new()
	_cameo.name = "Portrait"
	_cameo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_cameo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_cameo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_cameo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cameo_clip.add_child(_cameo)
	_name_label = Label.new()
	_name_label.name = "Speaker"
	_name_label.clip_text = true
	_name_label.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_name_label.add_theme_font_size_override("font_size", Typography.CONTROL)
	_name_label.add_theme_color_override("font_color", BRASS)
	_panel.add_child(_name_label)
	_body = InputPromptLabel.new()
	_body.name = "Line"
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_override("font", Typography.UI_FONT)
	_body.add_theme_font_size_override("font_size", 15)
	_body.add_theme_constant_override("line_spacing", -2)
	_body.add_theme_color_override("font_color", IVORY)
	_panel.add_child(_body)
	_apply_layout(LAYOUTS[0], {})


static func _style_button(button: Button) -> void:
	button.add_theme_font_override("font", Typography.UI_FONT)
	button.add_theme_font_size_override("font_size", Typography.CONTROL)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", IVORY)
	button.add_theme_color_override("font_focus_color", IVORY)
	button.add_theme_color_override("font_pressed_color", BRASS)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = (
			BUTTON_HOVER
			if state == "hover"
			else (BUTTON_PRESSED if state == "pressed" else BUTTON_FILL)
		)
		style.border_color = CYAN if state == "focus" else Color(BRASS, 0.8)
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(4)
		if state == "focus":
			style.draw_center = false
		button.add_theme_stylebox_override(state, style)
