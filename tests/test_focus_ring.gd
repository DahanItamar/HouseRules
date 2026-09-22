extends GutTest
## One selection language across the whole house.
##
## Every cabinet used to draw its own focus cue - a differently sized rectangle,
## sometimes filled with the key's own face colour so focusing a selected key hid
## that it was selected. These tests hold every key in every cabinet to the shared
## FocusRing: the mandated cyan, hollow, one stroke weight, contained by the key
## instead of becoming a second box outside it, and following its painted corner.

const CABINETS: Array[String] = [
	"res://data/cabinets/baccarat.tres",
	"res://data/cabinets/blackjack.tres",
	"res://data/cabinets/core_overclock.tres",
	"res://data/cabinets/match_point.tres",
	"res://data/cabinets/minefield_vault.tres",
	"res://data/cabinets/poker.tres",
	"res://data/cabinets/roulette.tres",
	"res://data/cabinets/slot_classic.tres",
	"res://data/cabinets/upgrade_cluster.tres",
]
## The UI design system reserves this colour for keyboard and controller focus.
const MANDATED_CYAN := Color("48c5d5")

var _starting_balance: int
var _starting_test_mode: bool


func before_each() -> void:
	_starting_test_mode = Wallet.test_mode_enabled
	Wallet.set_test_mode(false)
	_starting_balance = Wallet.balance
	Wallet.reset(500)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	Wallet.set_test_mode(false)
	Wallet.reset(_starting_balance)
	Wallet.set_test_mode(_starting_test_mode)


func _open(path: String) -> CabinetSession:
	var session := CabinetSession.new()
	add_child_autofree(session)
	session.begin(load(path))
	return session


## Every key in `root` that wears a stylebox for focus, paired with its plate.
func _ringed_keys(root: Node) -> Array[Button]:
	var keys: Array[Button] = []
	for node: Node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.has_theme_stylebox_override("focus"):
			keys.append(button)
	return keys


func test_the_focus_colour_has_one_home() -> void:
	assert_eq(FocusRing.COLOR, MANDATED_CYAN, "The ring is the mandated cyan")
	var ring := FocusRing.style(6.0)
	assert_eq(ring.border_color, MANDATED_CYAN)
	assert_false(ring.draw_center, "A ring never fills the key it rings")
	assert_eq(ring.bg_color.a, 0.0, "Nothing behind the ring either")
	assert_eq(ring.shadow_size, 0, "Flat: a focus cue is not a glow")
	assert_eq(ring.expand_margin_top, 0.0, "It stays inside the component")
	assert_eq(
		ring.corner_radius_top_left,
		int(6.0 + FocusRing.OUTSET),
		"The contained ring follows the component corner"
	)


func test_every_cabinet_rings_its_keys_the_same_way() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var checked := 0
	for path: String in CABINETS:
		var session := _open(path)
		var panel: CabinetPanel = session.cabinet.panel
		var keys := _ringed_keys(panel)
		assert_gt(keys.size(), 0, "%s has keys to ring" % path)
		for button: Button in keys:
			var box := button.get_theme_stylebox("focus")
			if box is StyleBoxEmpty:
				# Round keys (the bet medallions, the spin disc) paint their own
				# ring around the art instead of boxing it.
				continue
			var ring := box as StyleBoxFlat
			var who := "%s/%s" % [path.get_file(), button.name]
			assert_not_null(ring, "%s rings with a flat stylebox" % who)
			assert_eq(ring.border_color, MANDATED_CYAN, "%s rings in cyan" % who)
			assert_false(ring.draw_center, "%s does not cover its own face" % who)
			assert_eq(ring.border_width_top, FocusRing.WIDTH, "%s shares one weight" % who)
			assert_eq(ring.expand_margin_top, 0.0, "%s contains its focus ring" % who)
			assert_eq(ring.shadow_size, 0, "%s casts no shadow" % who)
			checked += 1
	assert_gt(checked, 20, "The whole house was walked, not one cabinet")


func test_a_painted_key_is_ringed_on_the_corner_its_art_paints() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var painted := 0
	for path: String in CABINETS:
		var session := _open(path)
		var panel: CabinetPanel = session.cabinet.panel
		for button: Button in _ringed_keys(panel):
			var plate := button.get_node_or_null("KitPlate") as KitPlate
			var ring := button.get_theme_stylebox("focus") as StyleBoxFlat
			if plate == null or ring == null:
				continue
			var who := "%s/%s" % [path.get_file(), button.name]
			var radius := FocusRing.plate_radius(plate)
			assert_gt(radius, 0.0, "%s measures a painted corner" % who)
			assert_lte(
				radius,
				plate.border() + 0.001,
				"%s cannot round further than the nine-slice corner it stretches" % who
			)
			assert_eq(
				ring.corner_radius_top_left,
				int(roundf(radius + FocusRing.OUTSET)),
				"%s follows the plate rather than a fixed rectangle" % who
			)
			painted += 1
	assert_gt(painted, 10, "Painted keys were actually reached")


func test_every_painted_kit_declares_the_corner_it_paints() -> void:
	for theme_id: StringName in FocusRing.PAINTED_RADIUS:
		assert_true(UiKit.has_part(theme_id, "button"), "%s is a real kit" % theme_id)
		var measured := float(FocusRing.PAINTED_RADIUS[theme_id])
		assert_gt(measured, 0.0, "%s records a measured radius" % theme_id)
		var source: Rect2 = UiKit.region(theme_id, "button")
		assert_lte(
			measured, minf(source.size.x, source.size.y) * 0.5, "%s stays inside its art" % theme_id
		)


func test_a_selected_key_lights_its_plate_and_a_held_one_sinks() -> void:
	MotionPolicy.set_reduced_motion_for_tests(true)
	var style := DeckStyle.for_theme(&"blackjack")
	var button := Button.new()
	button.focus_mode = Control.FOCUS_ALL
	button.size = Vector2(120, 56)
	add_child_autofree(button)
	style.skin_button(button, style.primary_face, style.primary_edge, true)
	var plate := button.get_node_or_null("KitPlate") as KitPlate
	assert_not_null(plate, "The blackjack key is painted")
	plate.fit(Rect2(Vector2.ZERO, button.size))

	plate.set_state(DeckStyle.plate_state(button))
	var resting := plate.position.y
	assert_eq(DeckStyle.plate_state(button), KitPlate.State.NORMAL)

	button.grab_focus()
	assert_true(button.has_focus(), "The key took focus")
	assert_eq(
		DeckStyle.plate_state(button),
		KitPlate.State.FOCUSED,
		"A selected key lights its plate, so reduced motion loses nothing"
	)
	plate.set_state(KitPlate.State.FOCUSED)
	var lit := plate.modulate
	assert_eq(lit.r, 1.0, "Focus stays inside SDR instead of bleaching the plate")
	assert_gt(lit.r, lit.b, "Warm gold, not a cyan wash over the art")
	assert_eq(plate.position.y, resting, "Selecting a key does not move it")

	plate.set_state(KitPlate.State.PRESSED)
	assert_eq(plate.position.y, resting + KitPlate.PRESS_SHIFT, "A held key sinks into the cabinet")
	assert_lt(plate.modulate.r, 1.0, "And darkens while it is held")
	plate.set_state(KitPlate.State.NORMAL)
	assert_eq(plate.position.y, resting, "Releasing it brings the plate back up")


func test_hover_still_outranks_focus_so_the_pointer_key_is_the_brightest() -> void:
	var focused: Color = KitPlate.STATE_TINTS[KitPlate.State.FOCUSED]
	var hovered: Color = KitPlate.STATE_TINTS[KitPlate.State.HOVER]
	assert_gt(hovered.b, focused.b, "Hover reads brighter than the resting selection")
	assert_gt(focused.r, focused.g, "The selected key keeps a visible warm tint")
