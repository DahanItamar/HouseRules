extends GutTest
## House standing and the ledger: the tier ladder's maths, the records the save
## keeps, versioned migration from an older profile, painted bars that stay
## inside 0..1 and respect reduced motion, the Manager's compact panel, the
## deed, and the guarantee that none of it touches settlement or RTP.

const TV_SAFE := Rect2(48, 27, 864, 486)
## HUD plates and controls the standing plate must never cover.
const HUD_RECTS: Dictionary = {
	"bank plate": Rect2(48, 27, 168, 40),
	"message plate": Rect2(220, 104, 520, 40),
	"cabinet control deck": Rect2(48, 426, 864, 102),
	"floor prompt band": Rect2(56, 454, 848, 54),
	"developer widget": Rect2(2, 480, 44, 44),
}
## A schema-2 profile, exactly as the shipped game wrote them before standing.
const OLD_SAVE: Dictionary = {
	"schema_version": 2,
	"chips": "1750",
	"debt": "0",
	"lifetime_wagered": "7400",
	"active_contracts": [{"id": "slot_rounds", "progress": 3}],
	"contract_completions": "2",
	"tier_unlocked": 0,
	"cabinet_stats":
	{
		"slot_classic": {"rounds": "40", "wagered": "5000", "returned": "4100", "best_win": "600"},
		"blackjack": {"rounds": "12", "wagered": "2400", "returned": "2600", "best_win": "400"},
	},
	"achievements": {},
	"rng_seed": "20260919",
	"rng_states": {},
	"played_seconds": 930.0,
	"created_at": "2026-09-01T10:00:00",
	"tutorial_state": "done",
	"wing_invitations": ["high_roller"],
	"contract_log": [],
}

var _original_platform: PlatformServices
var _original_test_mode: bool
var _original_wagered: int


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_test_mode = Wallet.test_mode_enabled
	_original_wagered = Economy.lifetime_wagered
	Wallet.set_test_mode(false)
	SaveService.platform = LocalPlatform.new("user://tests/progression_%s" % Time.get_ticks_usec())
	SaveService.new_game(20260919)
	MotionPolicy.set_reduced_motion_for_tests(true)


func after_each() -> void:
	MotionPolicy.clear_test_override()
	SaveService.platform = _original_platform
	Wallet.set_test_mode(_original_test_mode)
	Economy.lifetime_wagered = _original_wagered
	SaveService.new_game(20260919)


func _round(stake: int, payout: int) -> RoundResult:
	var outcome := RoundResult.Outcome.WIN if payout > stake else RoundResult.Outcome.LOSS
	return RoundResult.create(stake, payout, outcome)


func _meter(width: float = 200.0, height: float = 14.0) -> ProgressMeter:
	var meter := ProgressMeter.new()
	meter.size = Vector2(width, height)
	add_child_autofree(meter)
	return meter


# --- The ladder ---------------------------------------------------------------------


func test_the_ladder_rises_and_keeps_the_shipped_wing_thresholds() -> void:
	var targets: Array[int] = []
	for tier: Dictionary in HouseLevel.TIERS:
		targets.append(int(tier.target))
	assert_eq(targets[0], 0, "The ladder starts at nothing wagered")
	for index: int in range(1, targets.size()):
		assert_gt(targets[index], targets[index - 1], "Rung %d rises" % index)
	assert_eq(
		targets[2],
		int(FloorController.WING_THRESHOLDS[FloorController.HIGH_ROLLER]),
		"High Roller is the wing's own shipped threshold"
	)
	assert_eq(
		targets[3],
		int(FloorController.WING_THRESHOLDS[FloorController.VIP]),
		"Whale is the VIP wing's own shipped threshold"
	)
	assert_eq(
		HouseLevel.OWNERSHIP_TARGET,
		targets[targets.size() - 1],
		"Owning the House is the last rung, not a number beside it"
	)


func test_tier_index_level_and_ratio_at_every_boundary() -> void:
	assert_eq(HouseLevel.tier_index(-500), 0, "A negative total cannot fall off the ladder")
	assert_eq(HouseLevel.level(0), 1, "The first rung reads as level 1, never level 0")
	for index: int in range(HouseLevel.TIERS.size()):
		var target: int = int(HouseLevel.TIERS[index].target)
		assert_eq(HouseLevel.tier_index(target), index, "Exactly on rung %d" % index)
		if index > 0:
			assert_eq(
				HouseLevel.tier_index(target - 1), index - 1, "One chip short of rung %d" % index
			)
		assert_almost_eq(HouseLevel.tier_ratio(target), 0.0 if index < 5 else 1.0, 0.001)
	var half: int = int(HouseLevel.TIERS[1].target) / 2
	assert_almost_eq(HouseLevel.tier_ratio(half), 0.5, 0.001, "Halfway to the second rung")
	assert_true(HouseLevel.is_max_tier(HouseLevel.OWNERSHIP_TARGET * 4))
	assert_almost_eq(HouseLevel.tier_ratio(HouseLevel.OWNERSHIP_TARGET * 4), 1.0, 0.001)
	assert_almost_eq(HouseLevel.ownership_ratio(HouseLevel.OWNERSHIP_TARGET / 4), 0.25, 0.001)
	assert_almost_eq(HouseLevel.ownership_ratio(-10), 0.0, 0.001)
	assert_almost_eq(HouseLevel.ownership_ratio(HouseLevel.OWNERSHIP_TARGET * 9), 1.0, 0.001)


func test_short_chips_reads_the_way_the_bars_label_it() -> void:
	assert_eq(HouseLevel.short_chips(0), "0")
	assert_eq(HouseLevel.short_chips(950), "950")
	assert_eq(HouseLevel.short_chips(5_000), "5K")
	assert_eq(HouseLevel.short_chips(1_500), "1.5K")
	assert_eq(HouseLevel.short_chips(100_000), "100K")
	assert_eq(HouseLevel.short_chips(1_200_000), "1.2M")
	assert_eq(HouseLevel.short_chips(1_000_000), "1M")
	assert_eq(HouseLevel.short_chips(-2_500), "-2.5K")
	assert_eq(HouseLevel.grouped(0), "0")
	assert_eq(HouseLevel.grouped(999), "999")
	assert_eq(HouseLevel.grouped(1_000), "1,000")
	assert_eq(HouseLevel.grouped(250_000), "250,000")
	assert_eq(HouseLevel.grouped(-1_234_567), "-1,234,567")


func test_every_rung_names_a_tier_an_initial_and_what_it_opens() -> void:
	var seen: Dictionary = {}
	for tier: Dictionary in HouseLevel.TIERS:
		for key: String in ["name_key", "initial_key", "unlock_key"]:
			var value := String(tier[key])
			assert_ne(tr(value), value, "%s has English text" % value)
		assert_false(seen.has(tier.name_key), "%s is named once" % tier.name_key)
		seen[tier.name_key] = true
		assert_eq(tr(String(tier.initial_key)).length(), 1, "The HUD initial is one letter")
	assert_eq(seen.size(), ProgressionArt.RANK_MEDALLIONS.size(), "Every rung has a medallion")


# --- Records ------------------------------------------------------------------------


func test_streaks_and_standing_follow_settled_rounds_only() -> void:
	Progression.apply_state(SaveService.state)
	Progression.record_round(_round(10, 30))
	Progression.record_round(_round(10, 30))
	assert_eq(Progression.current_streak, 2)
	assert_eq(Progression.longest_streak, 2)
	Progression.record_round(_round(10, 0))
	assert_eq(Progression.current_streak, 0, "A losing round breaks the run")
	assert_eq(Progression.longest_streak, 2, "The longest run is remembered")
	Progression.record_round(_round(10, 10))
	assert_eq(Progression.current_streak, 0, "Getting the stake back is not a win")
	var abandoned := RoundResult.create(10, 0, RoundResult.Outcome.ABANDONED)
	Progression.longest_streak = 2
	Progression.current_streak = 1
	Progression.record_round(abandoned)
	assert_eq(Progression.current_streak, 1, "An abandoned round is not a record")


func test_a_new_rung_is_announced_once() -> void:
	Economy.lifetime_wagered = 0
	Progression.apply_state(SaveService.state)
	var announced: Array[int] = []
	Progression.tier_reached.connect(func(index: int) -> void: announced.append(index))
	Economy.lifetime_wagered = int(HouseLevel.TIERS[1].target)
	Progression.record_round(_round(10, 0))
	assert_eq(announced, [1] as Array[int], "Reaching the rung announces it")
	Progression.record_round(_round(10, 0))
	assert_eq(announced.size(), 1, "The same rung is never announced twice")


func test_the_ledger_reads_only_what_the_cabinets_recorded() -> void:
	SaveService.state.cabinet_stats[&"slot_classic"] = CabinetStats.from_dict(
		{"rounds": "30", "wagered": "3000", "returned": "2100", "best_win": "450"}
	)
	SaveService.state.cabinet_stats[&"blackjack"] = CabinetStats.from_dict(
		{"rounds": "8", "wagered": "800", "returned": "1200", "best_win": "300"}
	)
	SaveService.state.longest_win_streak = 5
	SaveService.state.played_seconds = 3_930.0
	var stats := PlayerStats.from_save(SaveService.state)
	assert_eq(stats.rounds, 38)
	assert_eq(stats.staked, 3800)
	assert_eq(stats.returned, 3300)
	assert_eq(stats.net(), -500, "Net is returned minus staked, and it is allowed to be negative")
	assert_eq(stats.best_win, 450)
	assert_eq(stats.longest_streak, 5)
	assert_eq(stats.favourite_id, &"slot_classic", "Most rounds, not most chips")
	assert_eq(stats.played_text(), "1h 05m")
	assert_eq(stats.rows.size(), 2)
	assert_eq(stats.rows[0].id, &"slot_classic", "Richest row first")
	assert_eq(int(stats.rows[1].net), 400)
	assert_true(PlayerStats.from_save(null).has_history() == false, "No profile, no claims")


# --- Save and migration -------------------------------------------------------------


func test_an_old_profile_loads_and_keeps_the_standing_it_earned() -> void:
	SaveService.platform.write_save(SaveService.slot, JSON.stringify(OLD_SAVE).to_utf8_buffer())
	assert_eq(SaveService.load_game(), OK, "A schema 2 profile still loads")
	assert_eq(SaveService.state.schema_version, SaveGame.CURRENT_SCHEMA_VERSION)
	assert_eq(Economy.lifetime_wagered, 7400)
	assert_eq(Wallet.balance, 1750, "Chips survive the migration")
	assert_eq(Progression.tier_index(), 2, "7,400 wagered already stands at High Roller")
	assert_eq(Progression.longest_streak, 0, "A streak that was never recorded backfills to zero")
	assert_eq(Progression.current_streak, 0)
	assert_false(Progression.house_owned)
	assert_eq(
		Progression.acknowledged_tier, 2, "An old profile is caught up quietly, not celebrated"
	)
	var stats := Progression.stats()
	assert_eq(stats.rounds, 52, "The cabinet records it already had are read as they are")
	assert_eq(stats.net(), -700)
	assert_eq(SaveService.save(), OK)
	assert_eq(SaveService.load_game(), OK, "The migrated profile round-trips")
	assert_eq(Progression.tier_index(), 2)


func test_standing_records_survive_save_and_load() -> void:
	Progression.apply_state(SaveService.state)
	Progression.record_round(_round(10, 40))
	Progression.record_round(_round(10, 40))
	Progression.record_round(_round(10, 40))
	assert_eq(SaveService.save(), OK)
	Progression.longest_streak = 0
	Progression.current_streak = 0
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Progression.longest_streak, 3, "The longest run is in the profile")
	assert_eq(Progression.current_streak, 3)


func test_a_profile_with_impossible_records_is_refused() -> void:
	var broken := OLD_SAVE.duplicate(true)
	broken["schema_version"] = SaveGame.CURRENT_SCHEMA_VERSION
	broken["longest_win_streak"] = "-4"
	SaveService.platform.write_save(SaveService.slot, JSON.stringify(broken).to_utf8_buffer())
	assert_eq(SaveService.load_game(), OK, "A corrupt profile is preserved and replaced")
	assert_eq(Economy.lifetime_wagered, 0, "The replacement is a fresh profile")


# --- Bars -----------------------------------------------------------------------------


func test_a_bar_is_always_inside_zero_and_one() -> void:
	var meter := _meter()
	for request: float in [-3.0, -0.001, 0.0, 0.25, 1.0, 1.4, 900.0]:
		meter.set_ratio(request, false)
		assert_between(meter.shown_ratio(), 0.0, 1.0, "set_ratio(%f) is clamped" % request)
		assert_between(
			meter.fill_width(), 0.0, meter.channel_width() + 0.5, "The fill stays in the channel"
		)
	meter.set_ratio(1.0, false)
	assert_almost_eq(meter.fill_width(), meter.channel_width(), 0.5, "A full bar fills the channel")
	meter.set_ratio(0.0, false)
	assert_eq(meter.fill_width(), 0.0, "An empty bar shows no brass at all")
	meter.set_ratio(0.5, false)
	assert_almost_eq(meter.fill_width(), meter.channel_width() * 0.5, 0.5, "Half reads as half")


func test_reduced_motion_lands_on_the_final_width_at_once() -> void:
	assert_true(ProgressMeter.is_instant(true, true, true, false), "Reduced motion is instant")
	assert_false(ProgressMeter.is_instant(true, false, true, false), "Otherwise the bar fills")
	assert_true(ProgressMeter.is_instant(false, false, true, false), "A caller can ask for instant")
	assert_true(ProgressMeter.is_instant(true, false, false, false), "Nothing off screen animates")
	assert_true(ProgressMeter.is_instant(true, false, true, true), "A headless run never animates")
	MotionPolicy.set_reduced_motion_for_tests(true)
	var meter := _meter()
	meter.set_ratio(0.75)
	assert_almost_eq(meter.shown_ratio(), 0.75, 0.0001, "No tween is left running")


func test_the_painted_bar_art_is_transparent_and_sharp() -> void:
	for texture: Texture2D in [ProgressMeter.TRACK, ProgressMeter.FILL, ProgressionArt.PANEL]:
		var image := texture.get_image()
		assert_gte(image.get_width(), 800, "The master is oversampled for UHD")
		for corner: Vector2i in [
			Vector2i.ZERO,
			Vector2i(image.get_width() - 1, 0),
			Vector2i(0, image.get_height() - 1),
			Vector2i(image.get_width() - 1, image.get_height() - 1),
		]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "No matte is left in a corner")
	for medallion: Texture2D in ProgressionArt.RANK_MEDALLIONS:
		assert_eq(medallion.get_size(), Vector2(256, 256), "Every rank draws at one size")
	for icon_id: StringName in ProgressionArt.ICONS:
		assert_eq((ProgressionArt.ICONS[icon_id] as Texture2D).get_size(), Vector2(128, 128))


## A TextureRect given its texture before its expand mode is clamped up to the
## master's own size, which once drew a 256 px medallion over the whole HUD.
func test_an_icon_draws_at_the_size_it_was_asked_for() -> void:
	var icon := ProgressionArt.icon_rect(&"coin", Vector2(10, 10), 26.0)
	add_child_autofree(icon)
	assert_eq(icon.size, Vector2(26, 26), "The icon keeps the size it was given")
	assert_eq(icon.custom_minimum_size, Vector2.ZERO, "The master never sets a floor")
	var ledger := StatsPanel.new()
	add_child_autofree(ledger)
	ledger.open()
	for rect: TextureRect in ledger.find_children("*", "TextureRect", true, false):
		assert_lte(rect.size.x, 40.0, "%s is a row icon, not a poster" % rect.name)
	var card := DeedCard.new()
	add_child_autofree(card)
	card.present(HouseLevel.DEED_PRICE, HouseLevel.OWNERSHIP_TARGET)
	var art: TextureRect = card.get_node("DeedArt")
	assert_true(card.panel_rect().encloses(Rect2(art.position, art.size)), "The deed art is framed")


## The rows, the tabs and the close button share one panel and must not overlap.
func test_the_ledger_rows_do_not_run_under_the_close_button() -> void:
	var ledger := StatsPanel.new()
	add_child_autofree(ledger)
	SaveService.state.cabinet_stats[&"slot_classic"] = CabinetStats.from_dict(
		{"rounds": "9", "wagered": "90", "returned": "40", "best_win": "20"}
	)
	ledger.open()
	var close_top := ledger.close_button.position.y
	for index: int in range(StatsPanel.MAX_ROWS):
		var label: Label = ledger.get_node("LedgerRowLabel%d" % index)
		assert_lte(label.position.y + label.size.y, close_top, "Row %d clears the button" % index)
		assert_gte(
			label.position.y,
			ledger.tabs[0].position.y + ledger.tabs[0].size.y,
			"Row %d clears the tabs" % index
		)
	assert_eq(ledger.row_data().size(), 8, "The overview fills every row it has")


# --- The HUD plate ----------------------------------------------------------------------


func test_the_standing_plate_is_tv_safe_and_clears_the_hud() -> void:
	var hud := HouseLevelHud.new()
	hud.position = Vector2(224, 27)
	add_child_autofree(hud)
	var rect := Rect2(hud.position, hud.size)
	assert_true(TV_SAFE.encloses(rect), "The plate is inside TV-safe bounds")
	for label: String in HUD_RECTS:
		assert_false(rect.intersects(HUD_RECTS[label]), "The plate clears the %s" % label)
	assert_eq(hud.mouse_filter, Control.MOUSE_FILTER_IGNORE, "It never swallows a click")
	assert_false(hud.card_visible(), "The tier card starts down")
	Economy.lifetime_wagered = int(HouseLevel.TIERS[2].target)
	hud.refresh()
	assert_eq(hud.meter.shown_ratio(), 0.0, "Standing exactly on a rung starts the next bar empty")
	assert_string_contains(hud.tooltip_text, tr("TIER_HIGH_ROLLER"))


func test_the_tier_card_names_the_rung_and_what_it_opened() -> void:
	var hud := HouseLevelHud.new()
	hud.position = Vector2(224, 27)
	add_child_autofree(hud)
	Economy.lifetime_wagered = int(HouseLevel.TIERS[3].target)
	hud.celebrate(3)
	assert_true(hud.card_visible(), "A new rung raises the card")
	var title: Label = hud.card.get_node("CardTitle")
	var note: Label = hud.card.get_node("CardNote")
	assert_string_contains(title.text, tr("TIER_WHALE"))
	assert_eq(note.text, tr("TIER_UNLOCK_WHALE"))
	assert_true(
		TV_SAFE.encloses(Rect2(hud.position + hud.card.position, hud.card.size)),
		"The card stays inside TV-safe bounds"
	)
	hud.dismiss_card()
	assert_false(hud.card_visible())


# --- The ledger and the Manager's panel ---------------------------------------------------


func test_the_ledger_states_net_plainly_and_never_celebrates_a_loss() -> void:
	SaveService.state.cabinet_stats[&"slot_classic"] = CabinetStats.from_dict(
		{"rounds": "20", "wagered": "2000", "returned": "1200", "best_win": "300"}
	)
	var ledger := StatsPanel.new()
	add_child_autofree(ledger)
	ledger.open()
	assert_true(ledger.is_open())
	assert_true(TV_SAFE.encloses(ledger.panel_rect()), "The ledger is inside TV-safe bounds")
	assert_gte(ledger.close_button.size.y, 44.0, "44 px close target")
	for tab: Button in ledger.tabs:
		assert_gte(tab.size.y, 44.0, "44 px tab target")
	var rows := ledger.row_data()
	assert_eq(rows[0].label, tr("LEDGER_NET"))
	assert_eq(
		rows[0].value, tr("LEDGER_CHIPS") % HouseLevel.grouped(-800), "A loss is stated as a loss"
	)
	var net_label: Label = ledger.get_node("LedgerRowValue0")
	assert_eq(
		net_label.get_theme_color("font_color"),
		ProgressionArt.DOWN,
		"A negative net is muted red, never brass"
	)
	ledger.select_view(StatsPanel.View.CABINETS)
	var cabinet_rows := ledger.row_data()
	assert_eq(cabinet_rows.size(), 1)
	assert_string_contains(cabinet_rows[0].label, tr("CABINET_SLOT_CLASSIC_NAME"))
	ledger.close()
	assert_false(ledger.is_open())


func test_an_empty_ledger_says_so_rather_than_showing_zeroes() -> void:
	var ledger := StatsPanel.new()
	add_child_autofree(ledger)
	ledger.open()
	assert_eq(ledger.row_data().size(), 0)
	var empty: Label = ledger.get_node("LedgerEmpty")
	assert_true(empty.visible)
	assert_eq(empty.text, tr("LEDGER_EMPTY"))


func test_the_managers_panel_shows_the_rung_and_the_whole_arc() -> void:
	Economy.lifetime_wagered = 1_200_000
	Progression.apply_state(SaveService.state)
	var panel := ManagerStandingPanel.new()
	add_child_autofree(panel)
	panel.show_standing()
	assert_true(TV_SAFE.encloses(panel.panel_rect()), "The Manager's panel is TV-safe")
	assert_almost_eq(panel.meter.shown_ratio(), 1.0, 0.001, "The ladder is finished")
	assert_almost_eq(panel.ownership_meter.shown_ratio(), 1.0, 0.001)
	var numbers: Label = panel.get_node("StandingPanel/OwnershipNumbers")
	assert_eq(numbers.text, "1.2M / 1M", "Short-form chips, with the M suffix")
	Economy.lifetime_wagered = 5_000
	panel.refresh()
	var rung: Label = panel.get_node("StandingPanel/StandingNumbers")
	assert_eq(rung.text, "5K / 100K")
	assert_string_contains(
		(panel.get_node("StandingPanel/StandingNext") as Label).text, tr("TIER_WHALE")
	)


# --- The deed ---------------------------------------------------------------------------


func test_the_deed_needs_the_standing_and_the_chips_and_is_paid_once() -> void:
	Economy.lifetime_wagered = 0
	Wallet.reset(HouseLevel.DEED_PRICE)
	Progression.apply_state(SaveService.state)
	assert_false(Progression.can_buy_house(), "Chips alone do not buy the House")
	Economy.lifetime_wagered = HouseLevel.OWNERSHIP_TARGET
	Wallet.reset(HouseLevel.DEED_PRICE - 1)
	assert_false(Progression.can_buy_house(), "Standing alone does not buy the House")
	Wallet.reset(HouseLevel.DEED_PRICE + 500)
	assert_true(Progression.can_buy_house())
	assert_true(Progression.buy_house())
	assert_eq(Wallet.balance, 500, "Exactly the stated price left the bank")
	assert_true(Progression.house_owned)
	assert_false(Progression.can_buy_house(), "The House is sold once")
	assert_eq(SaveService.load_game(), OK)
	assert_true(Progression.house_owned, "Ownership is in the profile")


func test_the_deed_card_states_the_price_that_was_actually_paid() -> void:
	var card := DeedCard.new()
	add_child_autofree(card)
	card.present(HouseLevel.DEED_PRICE, 1_200_000)
	assert_true(card.is_open())
	assert_true(TV_SAFE.encloses(card.panel_rect()))
	assert_gte(card.close_button.size.y, 44.0)
	var line: Label = card.get_node("DeedLine")
	assert_string_contains(line.text, HouseLevel.grouped(HouseLevel.DEED_PRICE))
	assert_string_contains(line.text, "1.2M")
	card.close()
	assert_false(card.is_open())


# --- Nothing here may move money -----------------------------------------------------------


func test_no_standing_path_changes_a_settlement() -> void:
	Economy.lifetime_wagered = 0
	Wallet.reset(500)
	Progression.apply_state(SaveService.state)
	var balance := Wallet.balance
	for step: int in range(12):
		Progression.record_round(_round(10, 30))
	assert_eq(Wallet.balance, balance, "Recording a round never moves a chip")
	Economy.lifetime_wagered = HouseLevel.OWNERSHIP_TARGET
	Progression.refresh_standing(true)
	assert_eq(Wallet.balance, balance, "Walking the whole ladder never moves a chip")
	var stats := Progression.stats()
	assert_eq(stats.rounds, 0, "Standing records are not cabinet records")


func test_the_marker_stipend_only_rises_above_whale() -> void:
	for index: int in range(3):
		Economy.lifetime_wagered = int(HouseLevel.TIERS[index].target)
		assert_eq(
			Economy.marker_stipend(),
			Economy.MARKER_STIPEND,
			"%s keeps the shipped 100-chip marker" % tr(String(HouseLevel.TIERS[index].name_key))
		)
	var previous := Economy.MARKER_STIPEND
	for index: int in range(3, HouseLevel.TIERS.size()):
		Economy.lifetime_wagered = int(HouseLevel.TIERS[index].target)
		assert_gte(
			Economy.marker_stipend(), previous, "A higher rung never writes a smaller marker"
		)
		previous = Economy.marker_stipend()
	Economy.lifetime_wagered = int(HouseLevel.TIERS[4].target)
	Wallet.reset(0)
	var stipend := Economy.marker_stipend()
	assert_true(Economy.take_marker())
	assert_eq(Wallet.balance, stipend, "The marker pays exactly what it says")
	assert_eq(Economy.debt, stipend, "And it is owed in full")


func test_contract_bars_read_the_contract_and_nothing_else() -> void:
	var board := ContractsBoard.new()
	add_child_autofree(board)
	board.open()
	var rows := board.row_data()
	var economy_rows := Economy.contract_rows()
	assert_eq(rows.size(), economy_rows.size())
	for index: int in range(rows.size()):
		var expected: Dictionary = economy_rows[index]
		var ratio := float(expected.progress) / maxf(float(expected.target), 1.0)
		assert_almost_eq(
			float(rows[index].fill), ratio, 0.001, "Row %d fills to its own progress" % index
		)
		assert_between(float(rows[index].fill), 0.0, 1.0)
	Economy.active_contracts[0] = {"id": &"slot_rounds", "progress": 12}
	Economy.contracts_changed.emit()
	assert_almost_eq(float(board.row_data()[0].fill), 12.0 / 25.0, 0.001)
	board.close()
