extends GutTest
## Hexbound Vault: its own person, tiles, backdrop and HUD language. Presentation
## only; the minefield math is untouched.

const VAULT_DEFINITION := "res://data/cabinets/minefield_vault.tres"
const OTHER_DEFINITIONS: Array[String] = [
	"res://data/cabinets/slot_classic.tres",
	"res://data/cabinets/blackjack.tres",
]
const GRID := Rect2(342, 122, 296, 296)
const TV_SAFE := Rect2(48, 27, 864, 486)
const FOCUS_CYAN := Color("48c5d5")
var _starting_test_mode: bool
var _starting_balance: int


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.set_test_mode(false)
	_starting_balance = Wallet.balance
	Wallet.reset(500)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.set_test_mode(false)
	Wallet.reset(_starting_balance)
	Wallet.set_test_mode(_starting_test_mode)


func _open(definition_path: String) -> CabinetPanel:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(load(definition_path))
	return session.cabinet.panel


func _host_paths(panel: CabinetPanel) -> Array[String]:
	var host: CabinetHost
	match panel.cabinet.context.definition.id:
		&"slot_classic":
			host = panel._slot_hostess
		&"blackjack":
			host = panel._blackjack_dealer_presenter.host()
		&"minefield_vault":
			host = panel._vault_attendant
	var paths: Array[String] = []
	if host == null:
		return paths
	for id: StringName in host.pose_ids():
		paths.append(host.pose_texture(id).resource_path)
	return paths


func test_sorceress_masters_are_unique_sharp_and_cleanly_cut() -> void:
	var panel := _open(VAULT_DEFINITION)
	var paths := _host_paths(panel)
	assert_eq(paths.size(), 4, "indicate, idle, cash-out and warning poses")
	for path: String in paths:
		assert_true(
			path.begins_with("res://assets/production/characters/hosts/vault_witcher_sorceress"),
			"%s is the Hexbound Vault sorceress" % path
		)
		var image := (load(path) as Texture2D).get_image()
		assert_gte(image.get_width(), 1024, path)
		assert_gte(image.get_height(), 1536, path)
		assert_ne(image.detect_alpha(), Image.ALPHA_NONE, "%s has real alpha" % path)
		var last := Vector2i(image.get_width() - 1, image.get_height() - 1)
		for corner: Vector2i in [Vector2i.ZERO, Vector2i(last.x, 0), Vector2i(0, last.y), last]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner %s is clear" % [path, corner])
	for other: String in OTHER_DEFINITIONS:
		for path: String in _host_paths(_open(other)):
			assert_false(paths.has(path), "%s is not shared with the vault" % path)


func test_every_pose_keeps_one_planted_stature() -> void:
	var host: CabinetHost = _open(VAULT_DEFINITION)._vault_attendant
	var master := host.pose_bounds(host.master_pose)
	for id: StringName in host.pose_ids():
		var bounds := host.pose_bounds(id)
		assert_almost_eq(bounds.position.y, master.position.y, 2.0, "%s head height" % id)
		assert_almost_eq(bounds.end.y, master.end.y, 2.0, "%s boots on one sole line" % id)
		assert_false(bounds.intersects(GRID), "%s never stands over the tiles" % id)
		assert_true(TV_SAFE.encloses(bounds), "%s stays inside TV-safe bounds" % id)


func test_tiles_and_backdrop_use_the_witcher_masters() -> void:
	var expected := [
		"res://assets/production/vault/witcher/tile_sealed.png",
		"res://assets/production/vault/witcher/tile_safe_coins.png",
		"res://assets/production/vault/witcher/tile_cursed_rune.png",
	]
	for index: int in range(expected.size()):
		assert_eq(VaultTile.FACE_TEXTURES[index].resource_path, expected[index])
	var panel := _open(VAULT_DEFINITION)
	var backdrop := panel.find_child("VaultBackdropArt", true, false) as Sprite2D
	assert_not_null(backdrop)
	assert_eq(
		backdrop.texture.resource_path,
		"res://assets/production/vault/witcher/witcher_vault_backdrop.png"
	)
	assert_eq(backdrop.texture.get_size(), Vector2(3840, 2160), "Native 4K crypt master")
	var bed := panel.find_child("VaultGridBed", true, false) as Control
	assert_not_null(bed, "A slate bed seats the tile grid")
	assert_true(Rect2(bed.position, bed.size).encloses(GRID))


func test_vault_hud_is_its_own_carved_stone_language() -> void:
	var panel := _open(VAULT_DEFINITION)
	assert_eq(panel._title.text, tr("VAULT_WITCHER_TITLE"))
	assert_true(panel.find_child("VaultStatusPanel", true, false) is VaultRuneFrame)
	assert_true(panel.find_child("VaultControlDeck", true, false) is VaultRuneFrame)
	assert_false(panel._ambient.visible, "No sci-fi scan/ring attract over the crypt")
	for button: Button in [panel._vault_open, panel._vault_cash_out]:
		var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
		var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
		assert_eq(normal.corner_radius_top_left, VaultRuneFrame.CORNER_RADIUS, "Squared, carved")
		assert_eq(normal.shadow_size, 0, "Flat: no soft shadow or glow")
		assert_ne(normal.border_color, FOCUS_CYAN, "Cyan is reserved for focus")
		assert_eq(focus.border_color, FOCUS_CYAN, "Keyboard/controller focus stays cyan")
		assert_gte(button.size.y, 44.0, "44 px minimum target")
		assert_true(TV_SAFE.encloses(Rect2(button.position, button.size)))
	await get_tree().process_frame
	# The quick-bet keys are shared, so the vault says "vault" through its own
	# painted kit plate rather than through a different set of controls.
	for chip: Button in panel._stake_selector._buttons:
		var plate := chip.get_node_or_null("KitPlate") as KitPlate
		assert_not_null(plate, "%s wears the vault's painted plate" % chip.name)
		assert_eq(plate.texture, UiKit.texture(&"minefield_vault", "button"))
		var focus: StyleBoxFlat = chip.get_theme_stylebox("focus")
		assert_eq(focus.border_color, FOCUS_CYAN, "Cyan stays reserved for focus")


func test_other_games_keep_their_own_stake_chips() -> void:
	var slot := _open(OTHER_DEFINITIONS[0])
	for chip: Button in slot._stake_selector._buttons:
		var plate := chip.get_node_or_null("KitPlate") as KitPlate
		assert_not_null(plate)
		assert_ne(
			plate.texture,
			UiKit.texture(&"minefield_vault", "button"),
			"The vault's plate never leaks into the Slot HUD"
		)


func test_meter_ready_state_uses_candle_amber_not_green() -> void:
	assert_eq(VaultCashoutMeter.READY_COLOR, VaultRuneFrame.AMBER)
	assert_ne(VaultCashoutMeter.READY_COLOR, VaultCashoutMeter.DISABLED_COLOR)
