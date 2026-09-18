class_name RoundResult
extends RefCounted

enum Outcome { WIN, LOSS, PUSH, CASHED_OUT, ABANDONED }

var stake: int = 0
var payout: int = 0
var outcome: Outcome = Outcome.LOSS
var detail: Dictionary = {}


static func create(
	risked: int, returned: int, kind: Outcome, display: Dictionary = {}
) -> RoundResult:
	var result: RoundResult = RoundResult.new()
	result.stake = risked
	result.payout = returned
	result.outcome = kind
	result.detail = display
	return result
