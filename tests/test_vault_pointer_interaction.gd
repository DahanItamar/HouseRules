extends GutTest

const VAULT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/minefield_vault.tres")

var _original_platform: PlatformServices
var _original_motion_persistence: bool


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_motion_persistence = MotionPolicy.persistence_enabled
	MotionPolicy.persistence_enabled = false
	MotionPolicy.set_reduced_motion_for_tests(false)
	SaveService.platform = LocalPlatform.new(
		"user://tests/vault_pointer_%s" % Time.get_ticks_usec()
	)
	SaveService.new_game(20260919)


func after_each() -> void:
	SaveService.platform = _original_platform
	MotionPolicy.persistence_enabled = _original_motion_persistence
	MotionPolicy.clear_test_override()
	SaveService.new_game(20260919)


func test_pointer_hover_synchronizes_snap_cursor_and_visual_selection() -> void:
	var game := _make_vault_game()
	assert_true(game.start_round(10))
	var tile: VaultTile = game.panel._vault_tiles[7]

	tile.mouse_entered.emit()

	assert_eq(_cursor(game).index, 7, "Pointer hover owns the same snap cursor as keys and gamepad")
	assert_true(tile.is_selected, "Hovered tile receives the shared visual selection")
	assert_false(game.panel._vault_tiles[0].is_selected)
	await wait_seconds(0.12)
	assert_eq(
		game.panel._vault_cursor.position,
		(
			CabinetPanel.VAULT_GRID_ORIGIN
			- Vector2(2, 2)
			+ Vector2(2, 1) * CabinetPanel.VAULT_GRID_PITCH
		),
		"The visible cursor settles over the pointer-selected tile"
	)


func test_pointer_click_uses_authoritative_open_request() -> void:
	var game := _make_vault_game()
	assert_true(game.start_round(10))
	var tile: VaultTile = game.panel._vault_tiles[6]

	_emit_left_click(tile)

	assert_eq(_cursor(game).index, 6, "Click synchronizes selection before requesting the reveal")
	assert_true(_math(game).revealed.has(6), "Click reaches the same authoritative reveal state")
	assert_true(game.panel._vault_revealed.has(6), "Authoritative state is reflected by the board")


func test_pointer_input_is_gated_while_help_or_result_is_pending() -> void:
	var game := _make_vault_game()
	assert_true(game.start_round(10))
	var initial_cursor: int = _cursor(game).index

	game.panel.set_help_open(true)
	game.panel._vault_tiles[4].mouse_entered.emit()
	_emit_left_click(game.panel._vault_tiles[4])
	assert_eq(_cursor(game).index, initial_cursor, "Help modal keeps pointer focus off the board")
	assert_false(_math(game).revealed.has(4), "Help modal blocks pointer activation")
	game.panel.set_help_open(false)

	game.is_result_pending = true
	game.panel.refresh()
	game.panel._vault_tiles[9].mouse_entered.emit()
	_emit_left_click(game.panel._vault_tiles[9])
	assert_eq(_cursor(game).index, initial_cursor, "Pending result freezes board selection")
	assert_false(_math(game).revealed.has(9), "Pending result blocks a second reveal")


func test_pointer_input_is_gated_after_round_result() -> void:
	var game := _make_vault_game()
	assert_true(game.start_round(10))
	game.is_round_active = false
	game.panel.refresh()
	var balance_before: int = game.context.balance

	game.panel._vault_tiles[11].mouse_entered.emit()
	_emit_left_click(game.panel._vault_tiles[11])

	assert_false(
		game.is_round_active, "Clicking the result board cannot silently start another wager"
	)
	assert_eq(game.context.balance, balance_before)
	assert_false(_math(game).revealed.has(11))


func test_keyboard_and_gamepad_cursor_remain_valid_after_pointer_use() -> void:
	var game := _make_vault_game()
	assert_true(game.start_round(10))
	game.panel._vault_tiles[12].mouse_entered.emit()
	assert_eq(_cursor(game).index, 12)

	var key_move := InputEventAction.new()
	key_move.action = &"move_right"
	key_move.pressed = true
	game._unhandled_input(key_move)
	assert_eq(_cursor(game).index, 13, "Keyboard continues from the pointer-selected cell")
	assert_true(game.panel._vault_tiles[13].is_selected)

	var pad_move := InputEventJoypadButton.new()
	pad_move.button_index = JOY_BUTTON_DPAD_DOWN
	pad_move.pressed = true
	game._unhandled_input(pad_move)
	assert_eq(_cursor(game).index, 18, "Gamepad continues from the keyboard-selected cell")
	assert_true(game.panel._vault_tiles[18].is_selected)


func test_reduced_motion_pointer_selection_reaches_exact_rest_immediately() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var game := _make_vault_game()
	assert_true(game.start_round(10))
	var tile: VaultTile = game.panel._vault_tiles[23]
	var rest_position := tile.position

	tile.mouse_entered.emit()

	assert_eq(_cursor(game).index, 23)
	assert_eq(tile.position, rest_position)
	assert_eq(tile.scale, Vector2.ONE)
	assert_eq(tile.modulate, Color.WHITE)
	assert_eq(
		game.panel._vault_cursor.position,
		(
			CabinetPanel.VAULT_GRID_ORIGIN
			- Vector2(2, 2)
			+ Vector2(3, 4) * CabinetPanel.VAULT_GRID_PITCH
		),
		"Reduced motion snaps the visual cursor to its exact rest state"
	)


func _make_vault_game() -> MiniGame:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(VAULT_DEFINITION)
	return session.cabinet


func _cursor(game: MiniGame) -> SnapCursor:
	return game.get("snap_cursor") as SnapCursor


func _math(game: MiniGame) -> MinefieldMath:
	return game.get("math") as MinefieldMath


func _emit_left_click(tile: VaultTile) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = tile.size * 0.5
	tile.gui_input.emit(click)
