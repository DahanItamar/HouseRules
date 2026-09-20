extends Node

const CASHIER_MOTION_DIRECTOR_SCRIPT := preload("res://src/ui/cashier_motion_director.gd")
const HUD_DEBT_SEPARATOR := "  /  "

var _guard := InstanceGuard.new()
var _floor: FloorController
var _menu: CanvasLayer
var _hud_layer: CanvasLayer
var _bank_panel: Panel
var _standing: HouseLevelHud
var _chip_icon: CreditChipIcon
var _hud: AnimatedNumberLabel
var _credit_caption: Label
var _message_panel: Panel
var _message: Label
var _is_playing: bool = false
var _message_serial: int = 0
var _menu_transitioning: bool = false
var _menu_background: TextureRect
var _menu_badge: TextureRect
## The menu's own rows, in the order the player walks them.
var _menu_rows: Array[Button] = []
var _menu_selector: TextureRect
## The version ticker and the notice band, in the order they settle.
var _menu_chrome: Array[Control] = []
var _menu_prompt_panel: Panel
var _menu_prompt: Label
var _menu_motion_button: Button
var _cashier_motion_director: Node
var _menu_reveal_tween: Tween
var _menu_attract_tween: Tween
var _menu_attract_elapsed: float = 0.0
var _menu_first_breath: bool = true
var _message_tween: Tween
var _bank_feedback_tween: Tween


func _ready() -> void:
	Engine.max_fps = 60
	get_window().min_size = Vector2i(1280, 720)
	get_tree().auto_accept_quit = false
	if not _guard.acquire():
		get_tree().quit()
		return
	SaveService.load_failed.connect(_show_message)
	SaveService.save_failed.connect(func(_error: Error) -> void: _show_message("SAVE_FAILED"))
	SceneRouter.menu_requested.connect(_show_menu)
	_build_hud()
	add_child(DisconnectPauseOverlay.new())
	var error: Error = SaveService.load_game()
	Wallet.set_test_mode(
		bool(ProjectSettings.get_setting("house_rules/testing/unlimited_bankroll", false))
	)
	_build_menu()
	MotionPolicy.motion_preference_changed.connect(_on_motion_preference_changed)
	if error != OK:
		_present_message(tr("SAVE_INCOMPATIBLE"))
	Wallet.balance_changed.connect(_on_balance_changed)
	Economy.debt_changed.connect(func(_debt: int) -> void: _refresh_hud())
	Economy.contract_completed.connect(_show_contract_completed)
	SceneRouter.session_changed.connect(_refresh_hud)
	InputRouter.active_device_changed.connect(func(_device: int) -> void: _refresh_menu())
	_refresh_hud()
	_refresh_menu()
	if (
		DisplayServer.get_name() != "headless"
		and bool(ProjectSettings.get_setting("house_rules/testing/start_on_floor", false))
	):
		_start_playing.call_deferred()


func _process(delta: float) -> void:
	if (
		_menu == null
		or not _menu.visible
		or not MotionPolicy.allows_continuous_motion()
		or _menu_prompt_panel == null
	):
		return
	_menu_attract_elapsed += delta
	var cadence := 2.0 if _menu_first_breath else 6.0
	if _menu_attract_elapsed < cadence:
		return
	_menu_attract_elapsed = 0.0
	_menu_first_breath = false
	_play_menu_breath()


func _build_hud() -> void:
	_hud_layer = CanvasLayer.new()
	_hud_layer.layer = 10
	add_child(_hud_layer)
	# The bank plate is its own opaque surface inside the TV-safe corner; the floor
	# draws no full-width header band behind it.
	_bank_panel = _panel(Vector2(48, 27), Vector2(168, 40), Color("17161a"), Color("c8a34b"))
	_bank_panel.pivot_offset = _bank_panel.size * 0.5
	_hud_layer.add_child(_bank_panel)
	_chip_icon = CreditChipIcon.new()
	_chip_icon.position = Vector2(56, 31)
	# Drawn at 32 px so the plate stays 40 px tall and clears the dialogue lane.
	_chip_icon.scale = Vector2(0.8, 0.8)
	_hud_layer.add_child(_chip_icon)
	_credit_caption = Label.new()
	_credit_caption.add_theme_font_override("font", Typography.UI_FONT)
	_credit_caption.position = Vector2(96, 27)
	_credit_caption.text = tr("HUD_TEST_BANK") if Wallet.test_mode_enabled else tr("HUD_CREDITS")
	_credit_caption.add_theme_font_size_override("font_size", Typography.BODY_MIN)
	_credit_caption.add_theme_color_override("font_color", Color("b8ad9c"))
	_hud_layer.add_child(_credit_caption)
	_hud = AnimatedNumberLabel.new()
	_hud.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_hud.position = Vector2(96, 40)
	_hud.size = Vector2(112, 26)
	_hud.add_theme_font_size_override("font_size", 22)
	_hud.add_theme_color_override("font_color", Color("f2c84b"))
	_hud_layer.add_child(_hud)
	_message_panel = _panel(Vector2(220, 104), Vector2(520, 40), Color("17161a"), Color("c8a34b"))
	_message_panel.visible = false
	_hud_layer.add_child(_message_panel)
	_message = Label.new()
	_message.add_theme_font_override("font", Typography.UI_FONT)
	_message.position = Vector2(236, 111)
	_message.size = Vector2(488, 26)
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_message.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_message.add_theme_font_size_override("font_size", Typography.BODY_MIN)
	_message.add_theme_color_override("font_color", Color("f1e8d8"))
	_message.visible = false
	_hud_layer.add_child(_message)
	# House standing sits beside the bank plate, inside the same TV-safe corner:
	# the rank, a slim fill toward the next rung, and the card a new rung raises.
	_standing = HouseLevelHud.new()
	_standing.position = Vector2(224, 27)
	_hud_layer.add_child(_standing)
	# House Contracts live on the reception board in the Manager's Office; the
	# HUD only toasts a completion (see _show_contract_completed).


func _build_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 6
	add_child(_menu)
	_menu_background = TextureRect.new()
	_menu_background.name = "CasinoHallArt"
	# `expand_mode` is set BEFORE the texture: a TextureRect adopts its texture's
	# size as its minimum the moment the texture is assigned, and setting the mode
	# afterwards does not take that back. With a 3840 px master the node grew to
	# 3840 wide and the menu showed the empty left margin of the plate blown up
	# across the whole screen.
	_menu_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# The branded plate: the hall with the three of them held to the right, so the
	# whole left column is free for the badge and the keys.
	_menu_background.texture = preload(
		"res://assets/production/environments/casino_menu_hall_v2.png"
	)
	_menu_background.size = Vector2(960, 540)
	_menu_background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_menu.add_child(_menu_background)
	var lighting := CasinoLighting.new()
	lighting.name = "MenuLighting"
	lighting.size = Vector2(960, 540)
	lighting.mode = CasinoLighting.Mode.MENU
	_menu.add_child(lighting)
	var menu_ambient := CasinoAmbient.new()
	menu_ambient.name = "MenuAmbient"
	menu_ambient.position = Vector2(548, 18)
	menu_ambient.size = Vector2(392, 86)
	menu_ambient.mode = CasinoAmbient.Mode.LOBBY
	menu_ambient.accent = Color("f2c84b")
	_menu.add_child(menu_ambient)
	# The left column has to be dark enough to read the badge and the keys against,
	# but a flat panel over half the screen drew a hard vertical seam down the
	# middle of the menu and cut the room in two. A gradient does the same job and
	# lets the hall carry on behind the type instead of stopping at an edge.
	var readability := TextureRect.new()
	readability.name = "MenuReadability"
	readability.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	readability.stretch_mode = TextureRect.STRETCH_SCALE
	readability.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shade := GradientTexture2D.new()
	shade.fill = GradientTexture2D.FILL_LINEAR
	shade.fill_from = Vector2.ZERO
	shade.fill_to = Vector2(1.0, 0.0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color("0c0b0de8"))
	ramp.set_color(1, Color("0c0b0d00"))
	ramp.add_point(0.52, Color("0c0b0dc4"))
	shade.gradient = ramp
	readability.texture = shade
	readability.size = Vector2(760, 540)
	_menu.add_child(readability)
	_menu_badge = TextureRect.new()
	_menu_badge.name = "TitleBadge"
	_menu_badge.texture = preload("res://assets/branding/house_rules_logo.png")
	_menu_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_menu_badge.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_menu_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_badge.position = MENU_BADGE_POSITION
	_menu_badge.size = Vector2(380, 152)
	_menu.add_child(_menu_badge)
	_menu_prompt_panel = _panel(
		Vector2(70, 320), Vector2(360, 104), Color("17161af2"), Color("c8a34b")
	)
	_menu_prompt_panel.name = "PromptPanel"
	_menu.add_child(_menu_prompt_panel)
	_menu_prompt = Label.new()
	_menu_prompt.add_theme_font_override("font", Typography.DISPLAY_FONT)
	_menu_prompt.name = "Prompt"
	_menu_prompt.position = Vector2(92, 339)
	_menu_prompt.size = Vector2(316, 70)
	_menu_prompt.add_theme_font_size_override("font_size", Typography.PROMINENT)
	_menu_prompt.add_theme_color_override("font_color", Color("f1e8d8"))
	_menu.add_child(_menu_prompt)
	_build_motion_preference_button()
	_build_menu_rows()
	_build_menu_chrome()
	_play_menu_reveal()


## The menu as a list the player walks, instead of a wall of key prompts.
##
## Each row is a painted chevron that lights when it is the one you are standing
## on, with a gold arrowhead beside it. The old prompt panel and the settings key
## stay as nodes because the reveal animation drives them and the suite measures
## them; they are simply no longer what the player uses.
const MENU_ROW_RECT := Rect2(56, 300, 330, 46)
const MENU_ROW_STEP: float = 56.0
## Where the painted badge sits, and how far it drops in over the reveal.
const MENU_BADGE_POSITION := Vector2(56, 64)
const MENU_BADGE_RISE: float = 8.0
## How far each row slides in from the left as it arrives.
const MENU_ROW_SLIDE: float = 18.0


func _build_menu_rows() -> void:
	for typeset: Control in [_menu_prompt_panel, _menu_prompt, _menu_motion_button]:
		typeset.visible = false
	# A hidden Control can still hold focus, and a focus owner nobody can see is
	# a menu with no ring drawn anywhere on it. The retired key leaves the ring.
	_menu_motion_button.focus_mode = Control.FOCUS_NONE
	_menu_selector = TextureRect.new()
	_menu_selector.name = "MenuSelector"
	_menu_selector.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_menu_selector.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_menu_selector.texture = UiKit.texture(&"menu_row", "medallion")
	_menu_selector.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_selector.size = Vector2(26, 26)
	_menu_selector.z_index = 3
	_menu.add_child(_menu_selector)
	var actions: Array[Callable] = [_start_playing, _toggle_motion_preference, _quit_game]
	for index: int in range(actions.size()):
		var row := Button.new()
		row.name = "MenuRow%d" % index
		row.position = MENU_ROW_RECT.position + Vector2(0.0, MENU_ROW_STEP * float(index))
		row.size = MENU_ROW_RECT.size
		row.focus_mode = Control.FOCUS_ALL
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_constant_override("h_separation", 0)
		row.add_theme_font_override("font", Typography.DISPLAY_FONT)
		row.add_theme_font_size_override("font_size", 21)
		for state: String in ["font_color", "font_hover_color", "font_focus_color"]:
			row.add_theme_color_override(state, Color("f6eed8"))
		row.add_theme_color_override("font_pressed_color", Color("fff6dc"))
		row.add_theme_stylebox_override(
			"focus", _menu_button_style(Color(0, 0, 0, 0), Color("48c5d5"), 3)
		)
		var act := actions[index]
		row.pressed.connect(func() -> void: act.call())
		row.focus_entered.connect(_place_menu_selector.bind(row))
		row.mouse_entered.connect(row.grab_focus)
		ButtonFeedback.attach(row)
		_menu.add_child(row)
		UiKit.paint_button(row, &"menu_row", index == 0, 11.0)
		_menu_rows.append(row)
	for index: int in range(_menu_rows.size()):
		var row := _menu_rows[index]
		row.focus_neighbor_top = row.get_path_to(_menu_rows[posmod(index - 1, _menu_rows.size())])
		row.focus_neighbor_bottom = row.get_path_to(
			_menu_rows[posmod(index + 1, _menu_rows.size())]
		)
	_refresh_menu_rows()
	_menu_rows[0].grab_focus.call_deferred()


## The version ticker and the play-money notice: the two things a splash screen
## owes the person looking at it.
func _build_menu_chrome() -> void:
	var version := Label.new()
	version.name = "VersionTicker"
	version.add_theme_font_override("font", Typography.UI_FONT)
	version.add_theme_font_size_override("font_size", 13)
	version.add_theme_color_override("font_color", Color("9a8f7f"))
	version.position = Vector2(760, 26)
	version.size = Vector2(152, 20)
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.mouse_filter = Control.MOUSE_FILTER_IGNORE
	version.text = (
		tr("MENU_VERSION") % ProjectSettings.get_setting("application/config/version", "0.0.0")
	)
	_menu.add_child(version)
	_menu_chrome.append(version)
	var band := ColorRect.new()
	band.name = "MenuNotice"
	band.position = Vector2(0, 494)
	band.size = Vector2(960, 46)
	band.color = Color("0a0809b4")
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(band)
	_menu_chrome.append(band)
	var notice := Label.new()
	notice.name = "MenuNoticeText"
	notice.add_theme_font_override("font", Typography.UI_FONT)
	notice.add_theme_font_size_override("font_size", 14)
	notice.add_theme_color_override("font_color", Color("b8ad9c"))
	notice.position = Vector2(48, 504)
	notice.size = Vector2(864, 26)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notice.text = tr("MENU_NOTICE")
	_menu.add_child(notice)
	_menu_chrome.append(notice)


## Puts the arrowhead beside whichever row has focus.
func _place_menu_selector(row: Button) -> void:
	if _menu_selector == null:
		return
	_menu_selector.position = Vector2(
		row.position.x - 32.0, row.position.y + row.size.y * 0.5 - 13.0
	)
	_menu_selector.visible = true


func _refresh_menu_rows() -> void:
	if _menu_rows.size() < 3:
		return
	# The reduced-motion row carries its shortcut glyph, because the shortcut
	# works from anywhere on the menu and is otherwise undiscoverable.
	var motion := (
		tr("MENU_ROW_MOTION")
		% (tr("SETTING_ON") if MotionPolicy.is_reduced() else tr("SETTING_OFF"))
	)
	_menu_rows[0].text = "  " + tr("MENU_ROW_PLAY")
	_menu_rows[1].text = "  " + motion + "   " + InputRouter.glyph("secondary")
	_menu_rows[2].text = "  " + tr("MENU_ROW_QUIT")
	for row: Button in _menu_rows:
		row.accessibility_name = row.text.strip_edges()


func _build_motion_preference_button() -> void:
	_menu_motion_button = Button.new()
	_menu_motion_button.name = "ReducedMotionToggle"
	_menu_motion_button.position = Vector2(70, 444)
	_menu_motion_button.size = Vector2(360, 56)
	_menu_motion_button.toggle_mode = true
	_menu_motion_button.focus_mode = Control.FOCUS_ALL
	_menu_motion_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_menu_motion_button.add_theme_font_override("font", Typography.UI_FONT)
	_menu_motion_button.add_theme_font_size_override("font_size", 18)
	_menu_motion_button.add_theme_color_override("font_color", Color("f1e8d8"))
	_menu_motion_button.add_theme_color_override("font_hover_color", Color("fff4d8"))
	_menu_motion_button.add_theme_color_override("font_focus_color", Color("fff4d8"))
	_menu_motion_button.add_theme_color_override("font_pressed_color", Color("f2c84b"))
	_menu_motion_button.add_theme_stylebox_override(
		"normal", _menu_button_style(Color("17161ae8"), Color("6e5225"), 1)
	)
	_menu_motion_button.add_theme_stylebox_override(
		"hover", _menu_button_style(Color("242027f2"), Color("c8a34b"), 1)
	)
	_menu_motion_button.add_theme_stylebox_override(
		"pressed", _menu_button_style(Color("302719f2"), Color("f2c84b"), 2)
	)
	_menu_motion_button.add_theme_stylebox_override(
		"focus", _menu_button_style(Color("00000000"), Color("f2c84b"), 3)
	)
	UiKit.paint_button(_menu_motion_button, &"menu", false, 15.0)
	_menu_motion_button.tooltip_text = tr("MENU_REDUCED_MOTION_HELP")
	_menu_motion_button.pressed.connect(_toggle_motion_preference)
	ButtonFeedback.attach(_menu_motion_button)
	_menu.add_child(_menu_motion_button)
	_refresh_motion_preference_button()


func _menu_button_style(fill: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(6)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	return style


func _panel(at: Vector2, dimensions: Vector2, fill: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = at
	panel.size = dimensions
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.shadow_color = Color("05040570")
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4)
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _refresh_menu() -> void:
	_menu_prompt.text = (
		tr("MENU_CONTROLS") % [InputRouter.glyph("interact"), InputRouter.glyph("back")]
	)
	_refresh_motion_preference_button()
	_refresh_menu_rows()


func _refresh_motion_preference_button() -> void:
	if _menu_motion_button == null:
		return
	var state_key := "SETTING_ON" if MotionPolicy.is_reduced() else "SETTING_OFF"
	_menu_motion_button.text = (
		tr("MENU_REDUCED_MOTION") % [InputRouter.glyph("secondary"), tr(state_key)]
	)
	_menu_motion_button.button_pressed = MotionPolicy.is_reduced()
	_menu_motion_button.accessibility_name = tr("MENU_REDUCED_MOTION_ACCESSIBLE") % tr(state_key)


func _toggle_motion_preference() -> void:
	MotionPolicy.set_reduced_motion(not MotionPolicy.is_reduced())
	AudioService.play(&"confirm")


func _play_menu_reveal() -> void:
	_menu_attract_elapsed = 0.0
	_menu_first_breath = true
	if _menu_reveal_tween != null:
		_menu_reveal_tween.kill()
	if MotionPolicy.is_reduced():
		_apply_menu_final_state()
		return
	_menu_background.modulate.a = 0.0
	_menu_badge.modulate.a = 0.0
	_menu_badge.position.y = MENU_BADGE_POSITION.y + MENU_BADGE_RISE
	for chrome: Control in _menu_chrome:
		chrome.modulate.a = 0.0
	for row: Button in _menu_rows:
		row.modulate.a = 0.0
		row.position.x = MENU_ROW_RECT.position.x - MENU_ROW_SLIDE
	_menu_reveal_tween = create_tween().set_parallel(true)
	_menu_reveal_tween.tween_property(_menu_background, "modulate:a", 1.0, 0.24)
	_menu_reveal_tween.tween_property(_menu_badge, "modulate:a", 1.0, 0.18).set_delay(0.04)
	(
		_menu_reveal_tween
		. tween_property(_menu_badge, "position:y", MENU_BADGE_POSITION.y, 0.20)
		. set_delay(0.04)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	# The rows arrive one after the other, so the reveal walks the eye down the
	# list in the order the player will walk it.
	for index: int in range(_menu_rows.size()):
		var row := _menu_rows[index]
		var delay := 0.14 + 0.05 * float(index)
		_menu_reveal_tween.tween_property(row, "modulate:a", 1.0, 0.16).set_delay(delay)
		(
			_menu_reveal_tween
			. tween_property(row, "position:x", MENU_ROW_RECT.position.x, 0.20)
			. set_delay(delay)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	for chrome: Control in _menu_chrome:
		_menu_reveal_tween.tween_property(chrome, "modulate:a", 1.0, 0.18).set_delay(0.32)


func _play_menu_breath() -> void:
	if _menu_attract_tween != null and _menu_attract_tween.is_valid():
		_menu_attract_tween.kill()
	var row := _focused_menu_row()
	if row == null:
		return
	# Scaling from the middle, so the row swells in place instead of growing
	# out of its top-left corner and shouldering the arrowhead aside.
	row.pivot_offset = row.size * 0.5
	_menu_attract_tween = create_tween().set_parallel(true)
	(
		_menu_attract_tween
		. tween_property(row, "scale", Vector2(1.018, 1.018), 0.16)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_menu_attract_tween.tween_property(row, "modulate", Color("fff4d8"), 0.16)
	_menu_attract_tween.chain().set_parallel(true)
	(
		_menu_attract_tween
		. tween_property(row, "scale", Vector2.ONE, 0.24)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN_OUT)
	)
	_menu_attract_tween.tween_property(row, "modulate", Color.WHITE, 0.24)


## Whichever row the player is standing on, or the first one before they move.
func _focused_menu_row() -> Button:
	if _menu_rows.is_empty():
		return null
	for row: Button in _menu_rows:
		if row.has_focus():
			return row
	return _menu_rows[0]


func _apply_menu_final_state() -> void:
	if _menu_background == null:
		return
	_menu_background.modulate.a = 1.0
	_menu_badge.modulate = Color.WHITE
	_menu_badge.position = MENU_BADGE_POSITION
	for chrome: Control in _menu_chrome:
		chrome.modulate = Color.WHITE
	for index: int in range(_menu_rows.size()):
		var row := _menu_rows[index]
		row.modulate = Color.WHITE
		row.scale = Vector2.ONE
		row.position = MENU_ROW_RECT.position + Vector2(0.0, MENU_ROW_STEP * float(index))


func _on_motion_preference_changed(reduced: bool) -> void:
	_refresh_motion_preference_button()
	if reduced:
		if _menu_reveal_tween != null:
			_menu_reveal_tween.kill()
		if _menu_attract_tween != null:
			_menu_attract_tween.kill()
		_apply_menu_final_state()
		if _message_tween != null:
			_message_tween.kill()
		_apply_message_final_state()
		if _bank_feedback_tween != null:
			_bank_feedback_tween.kill()
		_bank_panel.scale = Vector2.ONE
		_hud.modulate = Color.WHITE
	elif _menu != null and _menu.visible:
		_play_menu_reveal()


func _refresh_hud() -> void:
	if Wallet.test_mode_enabled:
		_hud.set_infinity()
	else:
		var balance_format := "%d"
		if Economy.debt > 0:
			balance_format += HUD_DEBT_SEPARATOR + str(Economy.debt)
		_hud.set_number(Wallet.balance, balance_format)
	_credit_caption.text = tr("HUD_TEST_BANK") if Wallet.test_mode_enabled else tr("HUD_CREDITS")
	if Wallet.test_mode_enabled and Economy.debt > 0:
		_hud.text += HUD_DEBT_SEPARATOR + str(Economy.debt)
	var on_floor: bool = (
		_is_playing and SceneRouter.session == null and (_floor == null or not _floor._cashier_open)
	)
	_bank_panel.visible = on_floor
	_chip_icon.visible = on_floor
	_credit_caption.visible = on_floor
	_hud.visible = on_floor
	if _standing != null:
		_standing.visible = on_floor
		if not on_floor:
			_standing.dismiss_card()
	# Time played is counted only while the player is actually at the tables.
	Progression.set_counting_time(_is_playing)


func _on_balance_changed(old_balance: int, new_balance: int) -> void:
	_refresh_hud()
	_chip_icon.play_transaction(new_balance - old_balance)
	if _bank_feedback_tween != null:
		_bank_feedback_tween.kill()
	_bank_panel.scale = Vector2.ONE
	_hud.modulate = Color.WHITE
	if MotionPolicy.is_reduced():
		return
	_bank_feedback_tween = create_tween().set_parallel(true)
	(
		_bank_feedback_tween
		. tween_property(_bank_panel, "scale", Vector2(1.035, 1.035), 0.10)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	_bank_feedback_tween.tween_property(_hud, "modulate", Color("fff0a0"), 0.10)
	(
		_bank_feedback_tween
		. chain()
		. tween_property(_bank_panel, "scale", Vector2.ONE, 0.16)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	_bank_feedback_tween.parallel().tween_property(_hud, "modulate", Color.WHITE, 0.16)


func _start_playing() -> void:
	if SaveService.is_write_blocked or _menu_transitioning:
		return
	if DisplayServer.get_name() == "headless":
		_show_floor_now()
		return
	_menu_transitioning = true
	_start_playing_animated()


func _start_playing_animated() -> void:
	await ScreenTransition.cover()
	_show_floor_now()
	await ScreenTransition.reveal()
	_menu_transitioning = false


func _show_floor_now() -> void:
	if _floor == null:
		_floor = preload("res://src/floor/floor.tscn").instantiate() as FloorController
		add_child(_floor)
		_cashier_motion_director = CASHIER_MOTION_DIRECTOR_SCRIPT.new()
		_cashier_motion_director.name = "CashierMotionDirector"
		add_child(_cashier_motion_director)
		_cashier_motion_director.bind(_floor)
		_floor.cashier_visibility_changed.connect(func(_is_open: bool) -> void: _refresh_hud())
	_floor.show()
	_floor.set_physics_process(true)
	_floor.set_process_unhandled_input(true)
	_menu.hide()
	_is_playing = true
	_refresh_hud()
	AudioService.play_ambient()
	AudioService.play(&"confirm")
	# The secretary's tour greets a new save. Test rigs and capture tools host
	# this scene under their own root and start the tour themselves.
	if get_tree().current_scene == self:
		_floor.begin_first_run_tutorial.call_deferred()


func _show_menu() -> void:
	if _menu_transitioning:
		return
	if _floor != null:
		_floor.set_physics_process(false)
		_floor.set_process_unhandled_input(false)
	if DisplayServer.get_name() == "headless":
		_show_menu_now()
		return
	_menu_transitioning = true
	_show_menu_animated()


func _show_menu_animated() -> void:
	await ScreenTransition.cover()
	_show_menu_now()
	await ScreenTransition.reveal()
	_menu_transitioning = false


func _show_menu_now() -> void:
	_is_playing = false
	if _floor != null:
		_floor.hide()
		_floor.set_physics_process(false)
		_floor.set_process_unhandled_input(false)
	_menu.show()
	_play_menu_reveal()
	AudioService.stop_ambient()
	_refresh_hud()


func _show_message(key: String) -> void:
	if _message != null:
		_present_message(tr(key))


func _show_contract_completed(title_key: String, reward: int) -> void:
	_message_serial += 1
	var serial := _message_serial
	_present_message(tr("CONTRACT_COMPLETE") % [tr(title_key), reward])
	await get_tree().create_timer(3.2).timeout
	if serial == _message_serial:
		_dismiss_message()


func _present_message(text_value: String) -> void:
	if _message_tween != null:
		_message_tween.kill()
	_message.text = text_value
	if text_value.is_empty():
		_message_panel.hide()
		_message.hide()
		return
	_message_panel.show()
	_message.show()
	_apply_message_final_state()
	if MotionPolicy.is_reduced():
		return
	_message_panel.modulate.a = 0.0
	_message.modulate.a = 0.0
	_message_panel.position.y = 98.0
	_message.position.y = 105.0
	_message_tween = create_tween().set_parallel(true)
	_message_tween.tween_property(_message_panel, "modulate:a", 1.0, 0.15)
	_message_tween.tween_property(_message, "modulate:a", 1.0, 0.15)
	(
		_message_tween
		. tween_property(_message_panel, "position:y", 104.0, 0.17)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	(
		_message_tween
		. tween_property(_message, "position:y", 111.0, 0.17)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)


func _dismiss_message() -> void:
	if _message_tween != null:
		_message_tween.kill()
	if MotionPolicy.is_reduced() or DisplayServer.get_name() == "headless":
		_message.text = ""
		_message_panel.hide()
		_message.hide()
		_apply_message_final_state()
		return
	_message_tween = create_tween().set_parallel(true)
	_message_tween.tween_property(_message_panel, "modulate:a", 0.0, 0.14)
	_message_tween.tween_property(_message, "modulate:a", 0.0, 0.14)
	(
		_message_tween
		. tween_property(_message_panel, "position:y", 98.0, 0.14)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	(
		_message_tween
		. tween_property(_message, "position:y", 105.0, 0.14)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_IN)
	)
	_message_tween.finished.connect(
		func() -> void:
			_message.text = ""
			_message_panel.hide()
			_message.hide()
			_apply_message_final_state()
	)


func _apply_message_final_state() -> void:
	if _message_panel == null or _message == null:
		return
	_message_panel.modulate = Color.WHITE
	_message.modulate = Color.WHITE
	_message_panel.position.y = 104.0
	_message.position.y = 111.0


func _unhandled_input(event: InputEvent) -> void:
	if not _is_playing:
		if event.is_action_pressed("interact"):
			_start_playing()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("secondary"):
			_toggle_motion_preference()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("back"):
			_quit_game()
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()


func _quit_game() -> void:
	if SceneRouter.session != null:
		SceneRouter.return_to_floor()
	elif SaveService.state != null:
		SaveService.save()
	_guard.release()
	get_tree().quit()


func _exit_tree() -> void:
	_guard.release()
