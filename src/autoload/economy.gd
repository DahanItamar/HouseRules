extends Node
## M1 starting state and cashier recovery; contract rotation is a later milestone.

signal debt_changed(current: int)

const STARTING_CHIPS: int = 200
const SOLVENCY_FLOOR: int = 20
const MARKER_STIPEND: int = 100
var debt: int = 0
var lifetime_wagered: int = 0


func is_below_solvency_floor() -> bool:
	return Wallet.balance < SOLVENCY_FLOOR


func take_marker() -> bool:
	if not is_below_solvency_floor() or debt > Wallet.MAX_CHIPS - MARKER_STIPEND:
		return false
	debt += MARKER_STIPEND
	if not Wallet.try_apply(0, MARKER_STIPEND):
		debt -= MARKER_STIPEND
		return false
	debt_changed.emit(debt)
	SaveService.save()
	return true


func repay_debt(amount: int) -> bool:
	var repaid: int = mini(amount, mini(Wallet.balance, debt))
	if repaid <= 0:
		return false
	debt -= repaid
	if not Wallet.try_apply(repaid, 0):
		debt += repaid
		return false
	debt_changed.emit(debt)
	SaveService.save()
	return true
