extends GutTest
## Elven Court: the slot owns its theme, cabinet art, reel icons and HUD.

const SLOT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/slot_classic.tres")
const BLACKJACK_DEFINITION: CabinetDefinition = preload("res://data/cabinets/blackjack.tres")
const VAULT_DEFINITION: CabinetDefinition = preload("res://data/cabinets/minefield_vault.tres")
const REEL_WINDOW := Rect2(166, 151, 628, 234)
const TV_SAFE := Rect2(48, 27, 864, 486)

var _starting_balance: int
var _starting_test_mode: bool


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


func _open(definition: CabinetDefinition) -> CabinetPanel:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(definition)
	return session.cabinet.panel


func test_elven_bezel_is_a_sharp_4k_master_with_an_exact_reel_aperture() -> void:
	var bezel: Texture2D = CabinetPanel.SLOT_BODY
	assert_eq(bezel.resource_path, "res://assets/production/slot/elven/elven_court_bezel.png")
	assert_eq(bezel.get_size(), Vector2(3840, 2160))
	var image := bezel.get_image()
	var scale := 4.0
	# Inside the reel window: true transparency (the runtime reels show through).
	for sample: Vector2 in [
		REEL_WINDOW.position + Vector2(2, 2),
		REEL_WINDOW.get_center(),
		REEL_WINDOW.end - Vector2(3, 3),
	]:
		assert_lt(image.get_pixelv(Vector2i(sample * scale)).a, 0.05, "aperture at %s" % sample)
	# Just outside it: the opaque carved frame.
	for sample: Vector2 in [
		REEL_WINDOW.position - Vector2(6, 6),
		REEL_WINDOW.end + Vector2(6, 6),
		Vector2(480, 120),
	]:
		assert_eq(image.get_pixelv(Vector2i(sample * scale)).a, 1.0, "frame at %s" % sample)
	var panel := _open(SLOT_DEFINITION)
	var art: Sprite2D = panel.find_child("SlotCabinetArt", true, false)
	assert_not_null(art)
	assert_eq(art.position, Vector2.ZERO, "Bezel fills the whole 960x540 canvas")
	assert_almost_eq(art.texture.get_width() * art.scale.x, 960.0, 0.01)


func test_elven_symbols_are_transparent_unique_masters_with_classic_semantics() -> void:
	var paths: Dictionary = {}
	assert_eq(SlotSymbol.TEXTURES.size(), SlotMachineMath.Symbol.size())
	for index: int in range(SlotSymbol.TEXTURES.size()):
		var texture: Texture2D = SlotSymbol.TEXTURES[index]
		var path := texture.resource_path
		assert_string_starts_with(path, "res://assets/production/slot/elven/symbol_")
		assert_false(paths.has(path), "%s is used once" % path)
		paths[path] = true
		assert_eq(texture.get_size(), Vector2(1024, 1024))
		var image := texture.get_image()
		var used := Rect2(image.get_used_rect())
		assert_true(
			SlotSymbol.SUBJECT_RECTS[index].grow(4).encloses(used),
			"%s subject rect %s covers alpha %s" % [path, SlotSymbol.SUBJECT_RECTS[index], used]
		)
		for corner: Vector2i in [
			Vector2i.ZERO, Vector2i(1023, 0), Vector2i(0, 1023), Vector2i(1023, 1023)
		]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner %s" % [path, corner])
	# Seven stays a seven and bar stays a bar: math indices are unchanged.
	assert_string_contains(SlotSymbol.TEXTURES[SlotMachineMath.Symbol.SEVEN].resource_path, "seven")
	assert_string_contains(SlotSymbol.TEXTURES[SlotMachineMath.Symbol.BAR].resource_path, "bar")


func test_every_symbol_fits_inside_its_reel_cell() -> void:
	var symbol := SlotSymbol.new()
	symbol.size = Vector2(190, 74)
	add_child_autofree(symbol)
	for index: int in range(SlotSymbol.TEXTURES.size()):
		var subject: Rect2 = SlotSymbol.SUBJECT_RECTS[index]
		var fit := (
			Vector2(minf(190.0, 74.0 * SlotSymbol.MAX_SUBJECT_ASPECT), 74.0) * SlotSymbol.CELL_FILL
		)
		var scale := minf(fit.x / subject.size.x, fit.y / subject.size.y)
		var drawn := subject.size * scale
		assert_lte(drawn.x, 190.0)
		assert_lte(drawn.y, 74.0)
		assert_gte(maxf(drawn.x, drawn.y), 60.0, "symbol %d stays readable" % index)


func test_slot_hud_is_themed_and_does_not_leak_into_other_games() -> void:
	var panel := _open(SLOT_DEFINITION)
	assert_eq(panel._title.text, tr("SLOT_THEME_TITLE"))
	for node_name: String in ["SlotCreditsMeter", "SlotBetTray", "SlotResultMeter"]:
		var inlay: Panel = panel.find_child(node_name, true, false)
		assert_not_null(inlay, node_name)
		var style: StyleBoxFlat = inlay.get_theme_stylebox("panel")
		assert_eq(style.bg_color, CabinetPanel.SLOT_ELVEN_PANEL, "%s flat emerald fill" % node_name)
		assert_eq(style.border_color, CabinetPanel.SLOT_ELVEN_GOLD)
		assert_ne(
			style.corner_radius_top_left,
			style.corner_radius_top_right,
			"%s leaf-cut corners" % node_name
		)
		# Inlays share the deck band every cabinet uses (y 430-524); horizontally
		# they stay inside TV-safe bounds.
		var rect := inlay.get_rect()
		assert_gte(rect.position.x, TV_SAFE.position.x, "%s TV-safe left" % node_name)
		assert_lte(rect.end.x, TV_SAFE.end.x, "%s TV-safe right" % node_name)
		assert_lte(rect.end.y, 524.0, "%s stays on the deck band" % node_name)
		assert_not_null(inlay.find_child("ElvenInlayLine", false, false))
	var selector: StakeSelector = panel._stake_selector
	var tray: Control = panel.find_child("SlotBetTray", true, false)
	assert_true(
		tray.get_rect().encloses(selector.get_rect()), "Bet chips sit inside the tray inlay"
	)
	for button: Button in selector._buttons:
		assert_gte(button.size.x, 44.0, "%s keeps a 44 px target" % button.name)
		assert_gte(button.size.y, 44.0)
		var plate := button.get_node_or_null("KitPlate") as KitPlate
		assert_not_null(plate, "%s wears the Elven Court plate" % button.name)
		assert_eq(plate.texture, UiKit.texture(&"slot_classic", "button"))
		var global_rect := Rect2(selector.position + button.position, button.size)
		assert_true(TV_SAFE.encloses(global_rect), "%s chip is TV-safe" % button.name)
		var focus: StyleBoxFlat = button.get_theme_stylebox("focus")
		assert_eq(focus.border_color, Color("48c5d5"), "Focus stays the shared cyan border")
	# Blackjack and Vault keep their own console styling.
	for definition: CabinetDefinition in [BLACKJACK_DEFINITION, VAULT_DEFINITION]:
		var other := _open(definition)
		assert_null(other.find_child("SlotCreditsMeter", true, false))
		assert_null(other.find_child("ElvenInlayLine", true, false))
		for button: Button in other._stake_selector._buttons:
			var other_plate := button.get_node_or_null("KitPlate") as KitPlate
			assert_ne(
				other_plate.texture,
				UiKit.texture(&"slot_classic", "button"),
				"Elven plates stay in the Elven Court"
			)
		assert_ne(other._title.text, tr("SLOT_THEME_TITLE"))


func test_lever_sits_in_the_painted_mount_and_stays_tv_safe() -> void:
	var panel := _open(SLOT_DEFINITION)
	var lever: SlotLever = panel._slot_lever
	assert_eq(lever.position, CabinetPanel.SLOT_LEVER_PIVOT)
	var target: Button = lever.get_node("LeverHitTarget")
	var rect := Rect2(lever.position + target.position, target.size)
	assert_gte(rect.size.x, 44.0)
	assert_true(TV_SAFE.encloses(rect), "Lever target %s stays TV-safe" % rect)
	assert_false(rect.intersects(REEL_WINDOW))
	var image := CabinetPanel.SLOT_BODY.get_image()
	# The carved mount below the pivot is painted, opaque cabinet art.
	assert_eq(image.get_pixelv(Vector2i((lever.position + Vector2(0, 30)) * 4.0)).a, 1.0)


func test_result_status_uses_plaque_colors() -> void:
	var panel := _open(SLOT_DEFINITION)
	var win := RoundResult.create(10, 30, RoundResult.Outcome.WIN, {"symbols": [0, 0, 0]})
	panel.show_result(win)
	assert_eq(panel._status.get_theme_color("font_color"), CabinetPanel.SLOT_ELVEN_GOLD_BRIGHT)
	var loss := RoundResult.create(10, 0, RoundResult.Outcome.LOSS, {"symbols": [0, 1, 2]})
	panel.show_result(loss)
	assert_eq(panel._status.get_theme_color("font_color"), CabinetPanel.SLOT_ELVEN_SILVER)
