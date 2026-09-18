extends GutTest

var _original_platform: PlatformServices
var _original_slot: StringName


func before_each() -> void:
	_original_platform = SaveService.platform
	_original_slot = SaveService.slot
	SaveService.platform = LocalPlatform.new("user://tests/%s" % Time.get_ticks_usec())
	SaveService.slot = &"qa"
	SaveService.new_game(12345)


func after_each() -> void:
	SaveService.platform = _original_platform
	SaveService.slot = _original_slot
	SaveService.new_game(12345)


func test_ac010_through_ac012_wallet_atomic_signals_and_rejection() -> void:
	watch_signals(Wallet)
	assert_eq(Wallet.balance, 200)
	assert_true(Wallet.try_apply(20, 35))
	assert_eq(Wallet.balance, 215)
	assert_signal_emitted_with_parameters(Wallet, "balance_changed", [200, 215])
	assert_eq(typeof(Wallet.balance), TYPE_INT)
	assert_false(Wallet.try_apply(216, 0))
	assert_eq(Wallet.balance, 215)
	assert_signal_emitted(Wallet, "transaction_rejected")
	assert_signal_emit_count(Wallet, "balance_changed", 1)
	assert_false(Wallet.try_apply(-1, 0))
	assert_false(Wallet.try_apply(0, -1))
	assert_eq(Wallet.balance, 215)


func test_ac013_named_rng_streams_are_independent() -> void:
	RNGService.reset(9981)
	var expected := RNGService.stream(&"slot_classic").randi()
	RNGService.reset(9981)
	for index in 100:
		RNGService.stream(&"blackjack").randi()
	assert_eq(RNGService.stream(&"slot_classic").randi(), expected)
	assert_same(RNGService.stream(&"slot_classic"), RNGService.stream(&"slot_classic"))
	assert_ne(RNGService.stream(&"slot_classic").seed, RNGService.stream(&"blackjack").seed)


func test_ac015_through_ac022_save_roundtrip_and_atomic_replacement() -> void:
	Wallet.reset(721)
	Economy.debt = 100
	assert_eq(SaveService.save(), OK)
	Wallet.reset(25)
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Wallet.balance, 721)
	assert_eq(Economy.debt, 100)
	Wallet.reset(722)
	assert_eq(SaveService.save(), OK, "Replace an existing save on Windows")
	var data: Dictionary = JSON.parse_string(
		SaveService.platform.read_save(&"qa").get_string_from_utf8()
	)
	assert_eq(int(data.chips), 722)
	assert_eq(int(data.schema_version), SaveGame.CURRENT_SCHEMA_VERSION)
	assert_false(FileAccess.file_exists(SaveService.platform.base_path.path_join("qa.json.tmp")))


func test_corrupt_save_preserved_and_newer_save_never_overwritten() -> void:
	assert_eq(SaveService.platform.write_save(&"qa", "{broken".to_utf8_buffer()), OK)
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Wallet.balance, 200)
	assert_true(FileAccess.file_exists(SaveService.platform.base_path.path_join("qa.json.corrupt")))
	var newer := '{"schema_version":999,"chips":1000}'
	assert_eq(SaveService.platform.write_save(&"qa", newer.to_utf8_buffer()), OK)
	assert_eq(SaveService.load_game(), ERR_UNAVAILABLE)
	assert_ne(SaveService.save(), OK)
	assert_eq(SaveService.platform.read_save(&"qa").get_string_from_utf8(), newer)


func test_schema_zero_migrates_in_sequence() -> void:
	var old := '{"schema_version":0,"chips":321}'
	assert_eq(SaveService.platform.write_save(&"qa", old.to_utf8_buffer()), OK)
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Wallet.balance, 321)
	assert_eq(Economy.debt, 0)
	assert_eq(SaveService.save(), OK)
	var data: Dictionary = JSON.parse_string(
		SaveService.platform.read_save(&"qa").get_string_from_utf8()
	)
	assert_eq(int(data.schema_version), SaveGame.CURRENT_SCHEMA_VERSION)


func test_malformed_nested_save_recovers_without_runtime_errors() -> void:
	for invalid_stats in [{"slot_classic": 7}, {"slot_classic": {"rounds": "not a number"}}]:
		var data := SaveGame.new().to_dict()
		data.chips = "200"
		data.cabinet_stats = invalid_stats
		assert_eq(SaveService.platform.write_save(&"qa", JSON.stringify(data).to_utf8_buffer()), OK)
		assert_eq(SaveService.load_game(), OK)
		assert_eq(Wallet.balance, 200)
		assert_true(SaveService.state.cabinet_stats.is_empty())
	assert_true(FileAccess.file_exists(SaveService.platform.base_path.path_join("qa.json.corrupt")))


func test_zero_byte_existing_save_is_preserved_as_corrupt() -> void:
	assert_eq(SaveService.platform.write_save(&"qa", PackedByteArray()), OK)
	assert_eq(SaveService.load_game(), OK)
	assert_eq(Wallet.balance, 200)
	assert_true(FileAccess.file_exists(SaveService.platform.base_path.path_join("qa.json.corrupt")))
