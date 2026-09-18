extends Node

signal save_failed(error: Error)
signal load_failed(message_key: String)

var state: SaveGame
var platform: PlatformServices = LocalPlatform.new()
var slot: StringName = &"save"
var is_write_blocked: bool = false


func new_game(seed_value: int = 0) -> void:
	state = SaveGame.new()
	state.chips = Economy.STARTING_CHIPS
	state.rng_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	state.created_at = Time.get_datetime_string_from_system(true)
	is_write_blocked = false
	_apply_state()


func save() -> Error:
	if is_write_blocked:
		return ERR_UNAVAILABLE
	if state == null:
		new_game()
	state.chips = Wallet.balance
	state.debt = Economy.debt
	state.lifetime_wagered = Economy.lifetime_wagered
	state.active_contracts = Economy.contract_snapshot()
	state.contract_completions = Economy.contract_completions
	state.rng_states = RNGService.snapshot()
	state.achievements = platform.achievements.duplicate()
	var error: Error = platform.write_save(slot, JSON.stringify(state.to_dict()).to_utf8_buffer())
	if error != OK:
		save_failed.emit(error)
	return error


func load_game() -> Error:
	var bytes: PackedByteArray = platform.read_save(slot)
	if bytes.is_empty():
		if platform.has_save(slot):
			return _recover_corrupt()
		new_game()
		return OK
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or not parser.data is Dictionary:
		return _recover_corrupt()
	var data: Dictionary = parser.data
	var version: Variant = data.get("schema_version", -1)
	if not _is_integer(version) or int(version) < 0:
		return _recover_corrupt()
	version = int(version)
	if version > SaveGame.CURRENT_SCHEMA_VERSION:
		is_write_blocked = true
		load_failed.emit("SAVE_INCOMPATIBLE")
		return ERR_UNAVAILABLE
	while version < SaveGame.CURRENT_SCHEMA_VERSION:
		data = _migrate(data, int(version))
		if data.is_empty():
			return _recover_corrupt()
		version = data["schema_version"]
	if not _valid_state(data):
		return _recover_corrupt()
	state = SaveGame.from_dict(data)
	is_write_blocked = false
	_apply_state()
	return OK


func _apply_state() -> void:
	Wallet.reset(state.chips)
	Economy.debt = state.debt
	Economy.lifetime_wagered = state.lifetime_wagered
	RNGService.reset(state.rng_seed)
	RNGService.restore(state.rng_states)
	Economy.reset_contracts(state.active_contracts, state.contract_completions)
	platform.achievements = state.achievements.duplicate()
	Economy.debt_changed.emit(Economy.debt)


func _recover_corrupt() -> Error:
	var error: Error = platform.preserve_corrupt(slot)
	if error != OK:
		is_write_blocked = true
		load_failed.emit("SAVE_PRESERVE_FAILED")
		return error
	new_game()
	load_failed.emit("SAVE_CORRUPT")
	return OK


func _migrate(data: Dictionary, version: int) -> Dictionary:
	var migrated: Dictionary = data.duplicate(true)
	if version == 0:
		migrated["schema_version"] = 1
		migrated["debt"] = data.get("debt", 0)
		migrated["lifetime_wagered"] = data.get("lifetime_wagered", 0)
	elif version == 1:
		migrated["schema_version"] = 2
		migrated["active_contracts"] = []
		migrated["contract_completions"] = "0"
	else:
		return {}
	return migrated


func _valid_state(data: Dictionary) -> bool:
	for key: String in ["chips", "debt", "lifetime_wagered", "contract_completions"]:
		var value: Variant = data.get(key, -1)
		if not _is_integer(value) or int(value) < 0 or int(value) > Wallet.MAX_CHIPS:
			return false
	if not _valid_nested_state(data):
		return false
	var tier: Variant = data.get("tier_unlocked", 0)
	var seconds: Variant = data.get("played_seconds", 0.0)
	return (
		_is_integer(tier)
		and int(tier) >= 0
		and int(tier) <= 2
		and _is_integer(data.get("rng_seed", 0))
		and (seconds is float or seconds is int)
		and is_finite(float(seconds))
		and float(seconds) >= 0.0
		and data.get("created_at", "") is String
	)


func _valid_nested_state(data: Dictionary) -> bool:
	if not data.get("active_contracts", []) is Array:
		return false
	var contract_ids: Dictionary = {}
	for entry: Variant in data.get("active_contracts", []):
		if not entry is Dictionary:
			return false
		var id := StringName(entry.get("id", ""))
		var progress: Variant = entry.get("progress", -1)
		if (
			not Economy.CONTRACTS.has(id)
			or contract_ids.has(id)
			or not _is_integer(progress)
			or int(progress) < 0
		):
			return false
		contract_ids[id] = true
	if contract_ids.size() > Economy.CONTRACT_SLOTS:
		return false
	for key: String in ["cabinet_stats", "achievements", "rng_states"]:
		if not data.get(key, {}) is Dictionary:
			return false
	for stats: Variant in data.get("cabinet_stats", {}).values():
		if not stats is Dictionary:
			return false
		for key: String in ["rounds", "wagered", "returned", "best_win"]:
			var value: Variant = stats.get(key, 0)
			if not _is_integer(value) or int(value) < 0:
				return false
	for value: Variant in data.get("achievements", {}).values():
		if not value is bool:
			return false
	for value: Variant in data.get("rng_states", {}).values():
		if not _is_integer(value):
			return false
	return true


func _is_integer(value: Variant) -> bool:
	return (
		value is int
		or (value is String and value.is_valid_int() and str(int(value)) == value)
		or (value is float and is_finite(value) and floor(value) == value)
	)
