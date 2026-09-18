extends Node
## The only mutation boundary for integer chips.

signal balance_changed(previous: int, current: int)
signal transaction_rejected(stake: int, payout: int)

const MAX_CHIPS: int = 9007199254740991
var balance: int = 200


func try_apply(stake: int, payout: int) -> bool:
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
	var previous: int = balance
	balance = chips
	if previous != balance:
		balance_changed.emit(previous, balance)
