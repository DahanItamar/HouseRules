extends Node
## Persistent contract income plus cashier recovery.

signal debt_changed(current: int)
signal contracts_changed
signal contract_completed(title_key: String, reward: int)

const STARTING_CHIPS: int = 200
const SOLVENCY_FLOOR: int = 20
const MARKER_STIPEND: int = 100
const CONTRACT_SLOTS: int = 3
const CONTRACTS: Dictionary = {
	&"slot_rounds": {"title_key": "CONTRACT_SLOT_ROUNDS", "target": 25, "reward": 300},
	&"slot_three_kind": {"title_key": "CONTRACT_SLOT_THREE_KIND", "target": 1, "reward": 500},
	&"slot_diamonds": {"title_key": "CONTRACT_SLOT_DIAMONDS", "target": 1, "reward": 2000},
	&"blackjack_wins": {"title_key": "CONTRACT_BLACKJACK_WINS", "target": 5, "reward": 400},
	&"blackjack_natural": {"title_key": "CONTRACT_BLACKJACK_NATURAL", "target": 1, "reward": 700},
	&"blackjack_double": {"title_key": "CONTRACT_BLACKJACK_DOUBLE", "target": 1, "reward": 600},
	&"vault_safe_eight": {"title_key": "CONTRACT_VAULT_SAFE_EIGHT", "target": 1, "reward": 600},
	&"vault_ten_x": {"title_key": "CONTRACT_VAULT_TEN_X", "target": 1, "reward": 900},
	&"vault_ten_mines": {"title_key": "CONTRACT_VAULT_TEN_MINES", "target": 1, "reward": 800},
	&"all_cabinets": {"title_key": "CONTRACT_ALL_CABINETS", "target": 7, "reward": 400},
}
const INITIAL_CONTRACTS: Array[StringName] = [
	&"slot_rounds", &"blackjack_wins", &"vault_safe_eight"
]
var debt: int = 0
var _persistent_debt: int = 0
var lifetime_wagered: int = 0
var active_contracts: Array[Dictionary] = []
var contract_completions: int = 0
## Newest first, capped at SaveGame.CONTRACT_LOG_SIZE: {"title_key", "reward"}.
var completion_log: Array[Dictionary] = []


func _ready() -> void:
	Wallet.test_mode_changed.connect(_on_test_mode_changed)


func is_below_solvency_floor() -> bool:
	return Wallet.balance < SOLVENCY_FLOOR


## Chips the Manager writes on one marker. `MARKER_STIPEND` is the base every
## profile starts on; House standing raises it, and only above Whale, so the
## shipped marker rules are unchanged until 100,000 chips have been turned over.
func marker_stipend() -> int:
	return maxi(HouseLevel.marker_stipend(lifetime_wagered), MARKER_STIPEND)


func can_take_marker() -> bool:
	return (
		debt <= Wallet.MAX_CHIPS - marker_stipend()
		and (is_below_solvency_floor() or Wallet.test_mode_enabled)
	)


func repayment_limit() -> int:
	return debt if Wallet.test_mode_enabled else mini(Wallet.balance, debt)


func persistent_debt() -> int:
	return _persistent_debt if Wallet.test_mode_enabled else debt


func load_debt(amount: int) -> void:
	_persistent_debt = maxi(amount, 0)
	if not Wallet.test_mode_enabled:
		debt = _persistent_debt
	debt_changed.emit(debt)


func reset_contracts(saved: Array = [], completed: int = 0) -> void:
	active_contracts.clear()
	contract_completions = maxi(completed, 0)
	for entry: Variant in saved:
		if entry is Dictionary:
			var id := StringName(entry.get("id", ""))
			if CONTRACTS.has(id) and not _has_contract(id):
				active_contracts.append(
					{"id": id, "progress": maxi(int(entry.get("progress", 0)), 0)}
				)
	for id: StringName in INITIAL_CONTRACTS:
		if active_contracts.size() >= CONTRACT_SLOTS:
			break
		if not _has_contract(id):
			active_contracts.append({"id": id, "progress": 0})
	_fill_contract_slots()
	contracts_changed.emit()


func contract_snapshot() -> Array[Dictionary]:
	return active_contracts.duplicate(true)


## One row per active contract with display-ready progress, used by the
## reception board and by `contract_lines`.
func contract_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for entry: Dictionary in active_contracts:
		var definition: Dictionary = CONTRACTS[entry.id]
		var progress: int = int(entry.progress)
		var target: int = int(definition.target)
		if entry.id == &"all_cabinets":
			progress = _bit_count(progress)
			target = 3
		(
			rows
			. append(
				{
					"id": entry.id,
					"title_key": String(definition.title_key),
					"progress": mini(progress, target),
					"target": target,
					"reward": int(definition.reward),
				}
			)
		)
	return rows


func contract_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for row: Dictionary in contract_rows():
		lines.append(
			tr("CONTRACT_LINE") % [tr(row.title_key), row.progress, row.target, row.reward]
		)
	return lines


func completion_log_snapshot() -> Array[Dictionary]:
	return completion_log.duplicate(true)


func load_completion_log(saved: Array) -> void:
	completion_log = SaveGame.sanitize_contract_log(saved)
	contracts_changed.emit()


func record_round(cabinet_id: StringName, result: RoundResult) -> void:
	if result == null or result.outcome == RoundResult.Outcome.ABANDONED:
		return
	var completed_indices: Array[int] = []
	for index: int in range(active_contracts.size()):
		var entry: Dictionary = active_contracts[index]
		entry.progress = _progress_for(entry.id, int(entry.progress), cabinet_id, result)
		active_contracts[index] = entry
		var target: int = int(CONTRACTS[entry.id].target)
		if int(entry.progress) >= target:
			completed_indices.push_front(index)
	for index: int in completed_indices:
		var entry: Dictionary = active_contracts[index]
		var definition: Dictionary = CONTRACTS[entry.id]
		var reward: int = int(definition.reward)
		if Wallet.try_apply(0, reward):
			active_contracts.remove_at(index)
			contract_completions += 1
			completion_log.push_front({"title_key": String(definition.title_key), "reward": reward})
			if completion_log.size() > SaveGame.CONTRACT_LOG_SIZE:
				completion_log.resize(SaveGame.CONTRACT_LOG_SIZE)
			contract_completed.emit(String(definition.title_key), reward)
	_fill_contract_slots()
	contracts_changed.emit()


func take_marker() -> bool:
	if not can_take_marker():
		return false
	var stipend := marker_stipend()
	debt += stipend
	if not Wallet.try_apply(0, stipend):
		debt -= stipend
		return false
	debt_changed.emit(debt)
	if not Wallet.test_mode_enabled:
		_persistent_debt = debt
		SaveService.save()
	return true


func repay_debt(amount: int) -> bool:
	var repaid: int = mini(amount, repayment_limit())
	if repaid <= 0:
		return false
	debt -= repaid
	if not Wallet.try_apply(repaid, 0):
		debt += repaid
		return false
	debt_changed.emit(debt)
	if not Wallet.test_mode_enabled:
		_persistent_debt = debt
		SaveService.save()
	return true


func _on_test_mode_changed(enabled: bool) -> void:
	if enabled:
		_persistent_debt = debt
		debt = 0
	else:
		debt = _persistent_debt
	debt_changed.emit(debt)


func _progress_for(
	id: StringName, progress: int, cabinet_id: StringName, result: RoundResult
) -> int:
	if id == &"slot_rounds" and cabinet_id == &"slot_classic":
		return progress + 1
	if id == &"slot_three_kind" and cabinet_id == &"slot_classic":
		var symbols: Array = result.detail.get("symbols", [])
		var matches: bool = (
			symbols.size() == 3 and symbols[0] == symbols[1] and symbols[1] == symbols[2]
		)
		return progress + int(matches)
	if id == &"slot_diamonds" and cabinet_id == &"slot_classic":
		return (
			progress
			+ int(result.detail.get("symbols", []).count(SlotMachineMath.Symbol.DIAMOND) == 3)
		)
	if id == &"blackjack_wins" and cabinet_id == &"blackjack":
		return progress + int(result.outcome == RoundResult.Outcome.WIN)
	if id == &"blackjack_natural" and cabinet_id == &"blackjack":
		var player: Array = result.detail.get("player", [])
		return progress + int(player.size() == 2 and BlackjackMath.hand_value(player) == 21)
	if id == &"blackjack_double" and cabinet_id == &"blackjack":
		var doubled_win: bool = (
			result.outcome == RoundResult.Outcome.WIN and result.detail.get("doubled", false)
		)
		return progress + int(doubled_win)
	if id == &"vault_safe_eight" and cabinet_id == &"minefield_vault":
		return progress + int(int(result.detail.get("safe_reveals", 0)) >= 8)
	if id == &"vault_ten_x" and cabinet_id == &"minefield_vault":
		return progress + int(result.payout >= result.stake * 10)
	if id == &"vault_ten_mines" and cabinet_id == &"minefield_vault":
		return (
			progress
			+ int(
				(
					result.outcome == RoundResult.Outcome.CASHED_OUT
					and result.detail.get("mines", []).size() >= 10
				)
			)
		)
	if id == &"all_cabinets":
		var bit: int = {&"slot_classic": 1, &"blackjack": 2, &"minefield_vault": 4}.get(
			cabinet_id, 0
		)
		return progress | bit
	return progress


func _fill_contract_slots() -> void:
	var available: Array[StringName] = []
	for id: StringName in CONTRACTS:
		if not _has_contract(id):
			available.append(id)
	while active_contracts.size() < CONTRACT_SLOTS and not available.is_empty():
		var pick: int = RNGService.stream(&"contracts").randi_range(0, available.size() - 1)
		active_contracts.append({"id": available[pick], "progress": 0})
		available.remove_at(pick)


func _has_contract(id: StringName) -> bool:
	for entry: Dictionary in active_contracts:
		if entry.id == id:
			return true
	return false


func _bit_count(value: int) -> int:
	var count: int = 0
	while value > 0:
		count += value & 1
		value >>= 1
	return count
