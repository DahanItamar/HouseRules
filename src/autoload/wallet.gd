extends Node
## The only mutation boundary for integer chips.

signal balance_changed(previous: int, current: int)
signal transaction_rejected(stake: int, payout: int)
signal test_mode_changed(enabled: bool)

const MAX_CHIPS: int = 9007199254740991
const TEST_BANKROLL: int = 999_999_999
var balance: int = 200
var test_mode_enabled: bool = false
var _persistent_balance: int = 200


func try_apply(stake: int, payout: int) -> bool:
	if test_mode_enabled:
		if stake < 0 or payout < 0:
			transaction_rejected.emit(stake, payout)
			return false
		return true
	if stake < 0 or payout < 0 or stake > balance or payout > MAX_CHIPS - (balance - stake):
		transaction_rejected.emit(stake, payout)
		return false
	var previous: int = balance
	balance = balance - stake + payout
	if previous != balance:
		balance_changed.emit(previous, balance)
	return true


func reset(chips: int = 200) -> void:
	assert(chips >= 0 and chips <= MAX_CHIPS)
	_persistent_balance = chips
	if test_mode_enabled:
		return
	var previous: int = balance
	balance = chips
	if previous != balance:
		balance_changed.emit(previous, balance)


func set_test_mode(enabled: bool) -> void:
	if enabled == test_mode_enabled:
		return
	var previous: int = balance
	if enabled:
		_persistent_balance = balance
		balance = TEST_BANKROLL
	else:
		balance = _persistent_balance
	test_mode_enabled = enabled
	if previous != balance:
		balance_changed.emit(previous, balance)
	test_mode_changed.emit(enabled)


func persistent_balance() -> int:
	return _persistent_balance if test_mode_enabled else balance
