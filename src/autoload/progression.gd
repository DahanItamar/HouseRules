extends Node
## The player's standing with the House, and the records behind it.
##
## Standing is a *view* of `Economy.lifetime_wagered`: this service stores no
## second currency and hands no chips out. It watches settled rounds so it can
## announce a new tier, keep the win streak, and count the time played, then
## writes those three records into the save beside the numbers the cabinets
## already record.
##
## It must never touch `Wallet`, a paytable or an RNG stream. The one chip
## movement it owns is the player's own purchase of the deed, which spends the
## bank through the Wallet's ordinary boundary and returns nothing.

signal tier_reached(tier_index: int)
signal standing_changed
signal house_purchased

## Time is banked in whole seconds so a save is never dirtied by a frame.
const PLAYTIME_FLUSH_SECONDS: float = 5.0

var current_streak: int = 0
var longest_streak: int = 0
var house_owned: bool = false
## The highest tier the player has been told about, so a reload is quiet.
var acknowledged_tier: int = 0
var _played_seconds: float = 0.0
var _unbanked: float = 0.0
var _counting: bool = false


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if not _counting:
		return
	_played_seconds += delta
	_unbanked += delta
	if _unbanked >= PLAYTIME_FLUSH_SECONDS:
		_unbanked = 0.0
		if SaveService.state != null:
			SaveService.state.played_seconds = _played_seconds


## The floor starts the clock and the title menu stops it, so idle time on the
## menu is not sold to the player as time played.
func set_counting_time(counting: bool) -> void:
	_counting = counting


func played_seconds() -> float:
	return _played_seconds


# --- Standing -----------------------------------------------------------------------


func wagered() -> int:
	return maxi(Economy.lifetime_wagered, 0)


func tier_index() -> int:
	return HouseLevel.tier_index(wagered())


func level() -> int:
	return HouseLevel.level(wagered())


func tier() -> Dictionary:
	return HouseLevel.tier(wagered())


func tier_ratio() -> float:
	return HouseLevel.tier_ratio(wagered())


func ownership_ratio() -> float:
	return HouseLevel.ownership_ratio(wagered())


func next_target() -> int:
	return HouseLevel.next_target(wagered())


func is_max_tier() -> bool:
	return HouseLevel.is_max_tier(wagered())


func stats() -> PlayerStats:
	return PlayerStats.from_save(SaveService.state)


func can_buy_house() -> bool:
	return HouseLevel.can_buy_house(wagered(), Wallet.balance, house_owned)


## The Manager's sale. The price leaves the bank through the Wallet's own
## boundary; nothing is paid back, and no paytable, stake or result is touched.
func buy_house() -> bool:
	if not can_buy_house():
		return false
	if not Wallet.try_apply(HouseLevel.DEED_PRICE, 0):
		return false
	house_owned = true
	_write_records()
	SaveService.save()
	house_purchased.emit()
	standing_changed.emit()
	return true


# --- Records ------------------------------------------------------------------------


## Called once per settled round, after the wallet has already moved. A
## progression record can never change what that round paid.
func record_round(result: RoundResult) -> void:
	if result == null or result.outcome == RoundResult.Outcome.ABANDONED:
		return
	if result.payout > result.stake:
		current_streak += 1
		longest_streak = maxi(longest_streak, current_streak)
	else:
		current_streak = 0
	_write_records()
	var reached := tier_index()
	standing_changed.emit()
	if reached > acknowledged_tier:
		acknowledged_tier = reached
		_write_records()
		tier_reached.emit(reached)


## Re-reads standing after something outside a settled round moved the
## lifetime wagered total - today only the developer menu. `announce` raises
## the tier card, which is how a new rung is captured without grinding to it.
func refresh_standing(announce: bool = false) -> void:
	var reached := tier_index()
	if announce and reached != acknowledged_tier:
		acknowledged_tier = reached
		_write_records()
		standing_changed.emit()
		tier_reached.emit(reached)
		return
	acknowledged_tier = maxi(acknowledged_tier, reached)
	_write_records()
	standing_changed.emit()


## Re-reads the loaded profile. `SaveService` calls this after every load.
func apply_state(state: SaveGame) -> void:
	if state == null:
		return
	current_streak = maxi(state.current_win_streak, 0)
	longest_streak = maxi(state.longest_win_streak, current_streak)
	house_owned = state.house_owned
	_played_seconds = maxf(state.played_seconds, 0.0)
	_unbanked = 0.0
	# A profile loaded below its own standing is caught up silently, so a save
	# made before this ladder existed does not fire five level-up cards at once.
	acknowledged_tier = maxi(state.acknowledged_tier, tier_index())
	standing_changed.emit()


## Writes this service's three records into the loaded profile. The caller
## decides when the profile itself is written to disk.
func write_state(state: SaveGame) -> void:
	if state == null:
		return
	state.current_win_streak = current_streak
	state.longest_win_streak = longest_streak
	state.acknowledged_tier = acknowledged_tier
	state.house_owned = house_owned
	state.played_seconds = _played_seconds


func _write_records() -> void:
	write_state(SaveService.state)
