class_name CabinetStats
extends RefCounted

var rounds: int = 0
var wagered: int = 0
var returned: int = 0
var best_win: int = 0


func record(result: RoundResult) -> void:
	rounds += 1
	wagered += result.stake
	returned += result.payout
	best_win = maxi(best_win, result.payout)


func to_dict() -> Dictionary:
	return {
		"rounds": str(rounds),
		"wagered": str(wagered),
		"returned": str(returned),
		"best_win": str(best_win)
	}


static func from_dict(data: Dictionary) -> CabinetStats:
	var result: CabinetStats = CabinetStats.new()
	result.rounds = int(data.get("rounds", 0))
	result.wagered = int(data.get("wagered", 0))
	result.returned = int(data.get("returned", 0))
	result.best_win = int(data.get("best_win", 0))
	return result
