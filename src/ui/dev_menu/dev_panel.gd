class_name DevPanel
extends Panel
## The developer menu's slide-out panel: four sections (Rooms, Games, Test,
## Info) of 44px rows on a flat near-black card with brass rules.
##
## Every row is a real Button, so the mouse works everywhere. Keyboard and
## controller navigation is driven by DevOverlay through `handle_navigation`:
## up/down walk the rows, left/right switch sections, confirm presses the
## focused row. The cyan focus ring only appears for that navigation.

signal close_requested
signal section_changed(section: int)

enum Section { ROOMS, GAMES, TEST, INFO }

const SECTION_NAMES: Array[String] = ["ROOMS", "GAMES", "TEST", "INFO"]
const PANEL_SIZE := Vector2(304, 508)
const ROW_HEIGHT: float = 44.0
const INNER_WIDTH: float = 272.0
const INFO_REFRESH_SECONDS: float = 0.25
const NAVIGATION_HINT := "Arrows or D-pad move  ·  Enter selects  ·  Esc closes"
const SURFACE := Color("0e0c0e")
const ROW := Color("181316")
const ROW_HOVER := Color("241c20")
const ROW_PRESSED := Color("0a080a")
const TAB_ACTIVE := Color("3a2c16")
const BRASS := Color("c8a34b")
const BRASS_DIM := Color("5e4a28")
const IVORY := Color("f1e8d8")
const MUTED := Color("a99e90")
const DISABLED_TEXT := Color("6d655c")
const CYAN := Color("48c5d5")

var actions: DevActions
## The overlay that owns this panel; provides the FPS readout toggle.
var overlay: Node
var section: int = Section.ROOMS
var tabs: Array[Button] = []
var close_button: Button
## Focusable rows of the current section, top to bottom.
var items: Array[Button] = []
var _rows: Array[Dictionary] = []
var _list: VBoxContainer
var _scroll: ScrollContainer
var _status: Label
var _info_labels: Array[Label] = []
var _refresh_elapsed: float = 0.0


func _init() -> void:
	name = "DevPanel"
	size = PANEL_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	var style := StyleBoxFlat.new()
	style.bg_color = SURFACE
	style.border_color = BRASS
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)


func build(owner_actions: DevActions, owner_overlay: Node) -> void:
	actions = owner_actions
	overlay = owner_overlay
	actions.status_changed.connect(_on_status)
	_label("DEVELOPER", Vector2(16, 8), Vector2(190, 26), Typography.DISPLAY_FONT, 20, IVORY)
	_label(
		"DEBUG BUILDS ONLY  ·  F10 OR `",
		Vector2(16, 34),
		Vector2(200, 18),
		Typography.UI_FONT,
		Typography.CAPTION,
		MUTED
	)
	close_button = _button("CLOSE", Vector2(PANEL_SIZE.x - 16 - 72, 8), Vector2(72, ROW_HEIGHT))
	close_button.name = "DevClose"
	close_button.pressed.connect(func() -> void: close_requested.emit())
	add_child(close_button)
	_rule(58.0)
	var tab_width := (INNER_WIDTH - 3.0 * 4.0) / 4.0
	for index: int in range(SECTION_NAMES.size()):
		var tab := _button(
			SECTION_NAMES[index],
			Vector2(16 + index * (tab_width + 4.0), 64),
			Vector2(tab_width, ROW_HEIGHT)
		)
		tab.name = "DevTab_%s" % SECTION_NAMES[index]
		tab.alignment = HORIZONTAL_ALIGNMENT_CENTER
		tab.pressed.connect(select_section.bind(index))
		add_child(tab)
		tabs.append(tab)
	_rule(114.0)
	_scroll = ScrollContainer.new()
	_scroll.name = "DevSectionScroll"
	_scroll.position = Vector2(12, 120)
	_scroll.size = Vector2(INNER_WIDTH + 12, 330)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.follow_focus = true
	add_child(_scroll)
	_style_scrollbar(_scroll.get_v_scroll_bar())
	_list = VBoxContainer.new()
	_list.name = "DevSectionRows"
	_list.custom_minimum_size = Vector2(INNER_WIDTH, 0)
	_list.add_theme_constant_override("separation", 4)
	_scroll.add_child(_list)
	_rule(456.0)
	_status = _label(
		"",
		Vector2(16, 460),
		Vector2(INNER_WIDTH, 40),
		Typography.UI_FONT,
		Typography.CAPTION,
		MUTED
	)
	_status.name = "DevStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_on_status(NAVIGATION_HINT)
	select_section(Section.ROOMS)


func select_section(index: int) -> void:
	section = posmod(index, SECTION_NAMES.size())
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	items.clear()
	_rows.clear()
	_info_labels.clear()
	match section:
		Section.ROOMS:
			_build_rooms()
		Section.GAMES:
			_build_games()
		Section.TEST:
			_build_test()
		Section.INFO:
			_build_info()
	for tab_index: int in range(tabs.size()):
		_style_tab(tabs[tab_index], tab_index == section)
	_scroll.scroll_vertical = 0
	refresh()
	section_changed.emit(section)


## Re-reads every toggle's state and every row's availability.
func refresh() -> void:
	for row: Dictionary in _rows:
		var button: Button = row.button
		if row.has("enabled"):
			button.disabled = not bool((row.enabled as Callable).call())
		if row.has("state"):
			var state_label: Label = row.state_label
			state_label.text = String((row.state as Callable).call())
	if section == Section.INFO:
		_refresh_info()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_refresh_elapsed += delta
	if _refresh_elapsed >= INFO_REFRESH_SECONDS:
		_refresh_elapsed = 0.0
		refresh()


# --- Keyboard / controller navigation -----------------------------------------


## The focus ring's walk order: Close, the active tab, then the section's rows.
func focus_order() -> Array[Button]:
	var order: Array[Button] = [close_button, tabs[section]]
	order.append_array(items)
	return order


func focus_first() -> void:
	var target: Button = items[0] if not items.is_empty() else tabs[section]
	target.grab_focus()


func focused_button() -> Button:
	var focused := get_viewport().gui_get_focus_owner() as Button
	return focused if focused != null and is_ancestor_of(focused) else null


## Handles one navigation event; returns true when it was one.
func handle_navigation(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return false
	if _pressed(event, [&"ui_up", &"move_up"]):
		move_focus(-1)
	elif _pressed(event, [&"ui_down", &"move_down"]):
		move_focus(1)
	elif _pressed(event, [&"ui_left", &"move_left"]):
		select_section(section - 1)
		tabs[section].grab_focus()
	elif _pressed(event, [&"ui_right", &"move_right"]):
		select_section(section + 1)
		tabs[section].grab_focus()
	elif _pressed(event, [&"ui_accept", &"interact"], false):
		activate_focused()
	else:
		return false
	AudioService.play(&"move")
	return true


func move_focus(step: int) -> void:
	var order := focus_order()
	var current := order.find(focused_button())
	if current < 0:
		focus_first()
		return
	var next := clampi(current + step, 0, order.size() - 1)
	order[next].grab_focus()
	if items.has(order[next]):
		_scroll.ensure_control_visible(order[next])


func activate_focused() -> void:
	var button := focused_button()
	if button == null:
		focus_first()
		return
	if not button.disabled:
		button.pressed.emit()


static func _pressed(event: InputEvent, names: Array, echo: bool = true) -> bool:
	for action: StringName in names:
		if InputMap.has_action(action) and event.is_action_pressed(action, echo):
			return true
	return false


# --- Sections -------------------------------------------------------------------


func _build_rooms() -> void:
	_header("GO TO ROOM")
	for room_id: StringName in FloorController.ROOM_IDS:
		_row(
			"DevRoom_%s" % room_id,
			DevActions.room_label(room_id),
			func() -> void: actions.go_to_room(room_id),
			{"closes": true, "enabled": actions.is_playing}
		)
	var current_room := &""
	for spot: Dictionary in DevActions.destinations():
		if spot.room != current_room:
			current_room = spot.room
			_header("%s SPOTS" % DevActions.room_label(current_room).to_upper())
		var room_id: StringName = spot.room
		var anchor_id: StringName = spot.anchor
		_row(
			"DevSpot_%s_%s" % [room_id, anchor_id],
			String(spot.label),
			func() -> void: actions.go_to_destination(room_id, anchor_id),
			{"closes": true, "enabled": actions.is_playing}
		)


func _build_games() -> void:
	_header("OPEN A TABLE  ·  WORKS FROM ANY TABLE")
	for cabinet_id: StringName in DevActions.cabinets():
		var room_id := DevActions.cabinet_room(cabinet_id)
		# A table still being built into a room has no join inlay yet.
		var room_name := "no room yet" if room_id == &"" else DevActions.room_label(room_id)
		_row(
			"DevGame_%s" % cabinet_id,
			DevActions.cabinet_name(cabinet_id),
			func() -> void: actions.open_cabinet(cabinet_id),
			{
				"closes": true,
				"enabled": actions.is_playing,
				"state": func() -> String: return room_name
			}
		)


func _build_test() -> void:
	_header("TOGGLES")
	_row(
		"DevToggle_collision",
		"Collision overlay (F2)",
		actions.toggle_collision_overlay,
		{"enabled": actions.can_toggle_collision, "state": _state_of(actions.collision_overlay_on)}
	)
	_row(
		"DevToggle_reduced_motion",
		"Reduced motion",
		actions.toggle_reduced_motion,
		{"state": _state_of(MotionPolicy.is_reduced)}
	)
	_row(
		"DevToggle_test_bank",
		"Unlimited test bank",
		actions.toggle_test_bank,
		{
			"enabled": actions.can_change_bank,
			"state": _state_of(func() -> bool: return Wallet.test_mode_enabled)
		}
	)
	_row(
		"DevToggle_glyphs",
		"Input glyphs" if actions.glyph_family_supported() else "Input glyphs (not exposed)",
		actions.cycle_glyph_family,
		{"enabled": actions.glyph_family_supported, "state": actions.glyph_family_label}
	)
	_row(
		"DevToggle_fps",
		"FPS / frame time",
		func() -> void: overlay.call("toggle_fps"),
		{"state": _state_of(func() -> bool: return bool(overlay.call("fps_visible")))}
	)
	_row(
		"DevToggle_wings",
		"Unlock both wings (session)",
		actions.toggle_wings,
		{"enabled": actions.is_playing, "state": _state_of(actions.wings_unlocked)}
	)
	_header("ACTIONS")
	_row(
		"DevAction_grant",
		"DEV  +%d chips" % DevActions.DEV_GRANT,
		actions.grant_chips,
		{
			"enabled":
			func() -> bool: return actions.can_change_bank() and not Wallet.test_mode_enabled
		}
	)
	_row(
		"DevAction_low_bank",
		"DEV  Set chips to %d (markers)" % DevActions.LOW_BANK,
		actions.set_low_bank,
		{"enabled": actions.can_change_bank}
	)
	_row(
		"DevAction_replay_tour",
		"Replay the tour",
		actions.replay_tutorial,
		{"closes": true, "enabled": actions.is_playing}
	)
	_row("DevAction_reset_tour", "Reset the tour to first-run", actions.reset_tutorial, {})
	_row(
		"DevAction_standing",
		"DEV  Next House standing",
		actions.cycle_standing,
		{"enabled": actions.can_change_bank, "state": actions.standing_label}
	)


func _build_info() -> void:
	_header("RUNNING GAME")
	for index: int in range(actions.info_lines().size()):
		var line := Label.new()
		line.name = "DevInfo_%d" % index
		line.custom_minimum_size = Vector2(INNER_WIDTH, 24)
		line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		line.add_theme_font_override("font", Typography.UI_FONT)
		line.add_theme_font_size_override("font_size", Typography.SUPPORTING)
		line.add_theme_color_override("font_color", IVORY)
		_list.add_child(line)
		_info_labels.append(line)
	_refresh_info()


func _refresh_info() -> void:
	var lines := actions.info_lines()
	for index: int in range(mini(lines.size(), _info_labels.size())):
		_info_labels[index].text = lines[index]


static func _state_of(getter: Callable) -> Callable:
	return func() -> String: return "ON" if bool(getter.call()) else "OFF"


# --- Rows and styling -------------------------------------------------------------


## One 44px row. `options`: "closes" (close the panel first), "enabled"
## (Callable -> bool) and "state" (Callable -> String shown at the right).
func _row(node_name: String, text_value: String, action: Callable, options: Dictionary) -> Button:
	var button := _button(text_value, Vector2.ZERO, Vector2(INNER_WIDTH, ROW_HEIGHT))
	button.name = node_name
	button.custom_minimum_size = Vector2(INNER_WIDTH, ROW_HEIGHT)
	var row := options.duplicate()
	row["button"] = button
	if options.has("state"):
		var state_label := Label.new()
		state_label.name = "State"
		state_label.anchor_left = 1.0
		state_label.anchor_right = 1.0
		state_label.anchor_bottom = 1.0
		state_label.offset_left = -118.0
		state_label.offset_right = -12.0
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		state_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		state_label.add_theme_font_override("font", Typography.DISPLAY_FONT)
		state_label.add_theme_font_size_override("font_size", Typography.CAPTION)
		state_label.add_theme_color_override("font_color", BRASS)
		button.add_child(state_label)
		row["state_label"] = state_label
	button.pressed.connect(_run_row.bind(action, bool(options.get("closes", false))))
	_list.add_child(button)
	items.append(button)
	_rows.append(row)
	return button


func _run_row(action: Callable, closes: bool) -> void:
	if closes:
		close_requested.emit()
	await action.call()
	if is_inside_tree():
		refresh()


func _header(text_value: String) -> void:
	var header := Label.new()
	header.text = text_value
	header.custom_minimum_size = Vector2(INNER_WIDTH, 26)
	header.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	header.add_theme_font_override("font", Typography.DISPLAY_FONT)
	header.add_theme_font_size_override("font_size", Typography.CAPTION)
	header.add_theme_color_override("font_color", BRASS)
	_list.add_child(header)


func _button(text_value: String, at: Vector2, dimensions: Vector2) -> Button:
	var button := Button.new()
	button.text = text_value
	button.position = at
	button.size = dimensions
	button.clip_text = true
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", Typography.UI_FONT)
	button.add_theme_font_size_override("font_size", Typography.SUPPORTING)
	button.add_theme_color_override("font_color", IVORY)
	button.add_theme_color_override("font_hover_color", IVORY)
	button.add_theme_color_override("font_focus_color", IVORY)
	button.add_theme_color_override("font_pressed_color", BRASS)
	button.add_theme_color_override("font_disabled_color", DISABLED_TEXT)
	button.add_theme_stylebox_override("normal", _style(ROW, BRASS_DIM, 1))
	button.add_theme_stylebox_override("hover", _style(ROW_HOVER, BRASS, 1))
	button.add_theme_stylebox_override("pressed", _style(ROW_PRESSED, BRASS, 1))
	button.add_theme_stylebox_override("disabled", _style(ROW, Color("2e2826"), 1))
	var focus := _style(Color.TRANSPARENT, CYAN, 2)
	focus.draw_center = false
	button.add_theme_stylebox_override("focus", focus)
	# A mouse click leaves no focus ring behind: cyan is for keyboard/controller.
	button.gui_input.connect(
		func(event: InputEvent) -> void:
			var mouse := event as InputEventMouseButton
			if mouse != null and not mouse.pressed:
				button.release_focus.call_deferred()
	)
	return button


func _style_scrollbar(bar: VScrollBar) -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = ROW
	track.set_corner_radius_all(3)
	track.content_margin_left = 3.0
	track.content_margin_right = 3.0
	bar.add_theme_stylebox_override("scroll", track)
	bar.add_theme_stylebox_override("scroll_focus", track)
	for state: String in ["grabber", "grabber_highlight", "grabber_pressed"]:
		var grabber := StyleBoxFlat.new()
		grabber.bg_color = BRASS_DIM if state == "grabber" else BRASS
		grabber.set_corner_radius_all(3)
		bar.add_theme_stylebox_override(state, grabber)


func _style_tab(tab: Button, active: bool) -> void:
	var style := _style(TAB_ACTIVE, BRASS, 1) if active else _style(ROW, BRASS_DIM, 1)
	tab.add_theme_stylebox_override("normal", style)
	tab.add_theme_color_override("font_color", IVORY if active else MUTED)


static func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	return style


func _label(
	text_value: String, at: Vector2, dimensions: Vector2, font: Font, font_size: int, color: Color
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = dimensions
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label


func _rule(y: float) -> void:
	var rule := ColorRect.new()
	rule.position = Vector2(16, y)
	rule.size = Vector2(INNER_WIDTH, 1)
	rule.color = Color(BRASS, 0.7)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)


func _on_status(text_value: String) -> void:
	_status.text = text_value
