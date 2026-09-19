extends GutTest

const DEFINITIONS: Array[String] = [
	"res://data/cabinets/slot_classic.tres",
	"res://data/cabinets/blackjack.tres",
	"res://data/cabinets/minefield_vault.tres",
]
var _starting_test_mode: bool
var _starting_balance: int


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	_starting_balance = Wallet.balance
	Wallet.test_mode_enabled = false
	Wallet.reset(500)
	MotionPolicy.set_reduced_motion_for_tests(false)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.test_mode_enabled = _starting_test_mode
	Wallet.reset(_starting_balance)


func test_each_game_has_a_unique_sharp_adult_host_asset() -> void:
	var paths: Dictionary = {}
	for definition_path: String in DEFINITIONS:
		var session := CabinetSession.new()
		add_child_autofree(session)
		session.begin(load(definition_path))
		var panel: CabinetPanel = session.cabinet.panel
		var texture: Texture2D
		match panel.cabinet.context.definition.id:
			&"slot_classic":
				texture = panel._slot_hostess.portrait_texture()
			&"blackjack":
				texture = panel._blackjack_dealer_presenter._sprite.texture
			&"minefield_vault":
				texture = panel._vault_attendant.portrait_texture()
		paths[texture.resource_path] = true
		assert_gte(texture.get_width(), 1024)
		assert_gte(texture.get_height(), 1024)
		var image := texture.get_image()
		assert_ne(image.detect_alpha(), Image.ALPHA_NONE)
		assert_eq(image.get_pixel(0, 0).a, 0.0)
		assert_eq(image.get_pixel(image.get_width() - 1, image.get_height() - 1).a, 0.0)
		session.queue_free()
		await get_tree().process_frame
	assert_eq(paths.size(), 3, "Every cabinet has its own authored person")


func test_slot_and_vault_hosts_stay_inside_protected_side_lanes() -> void:
	var slot_session := CabinetSession.new()
	add_child_autofree(slot_session)
	slot_session.begin(load(DEFINITIONS[0]))
	var slot_host: Control = slot_session.cabinet.panel._slot_hostess
	assert_false(slot_host.visual_bounds().intersects(Rect2(166, 151, 628, 234)))
	assert_lte(slot_host.visual_bounds().end.y, 430.0)

	var vault_session := CabinetSession.new()
	add_child_autofree(vault_session)
	vault_session.begin(load(DEFINITIONS[2]))
	var vault_host: Control = vault_session.cabinet.panel._vault_attendant
	assert_false(vault_host.visual_bounds().intersects(Rect2(342, 122, 296, 296)))
	assert_lte(vault_host.visual_bounds().end.x, 912.0)
	assert_lte(vault_host.visual_bounds().end.y, 258.0)


func test_host_idle_is_bounded_and_reduced_motion_has_an_exact_rest_pose() -> void:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(load(DEFINITIONS[0]))
	var host: Control = session.cabinet.panel._slot_hostess
	host._process(1.0)
	assert_between(host._portrait.position.y, -1.0, 1.0)
	MotionPolicy.set_reduced_motion_for_tests(true)
	assert_false(host.is_processing())
	assert_eq(host._portrait.position, Vector2.ZERO)
