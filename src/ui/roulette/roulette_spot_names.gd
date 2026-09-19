class_name RouletteSpotNames
extends RefCounted
## Player-facing names for layout spots ("SPLIT 17-20", "1ST DOZEN").


static func describe(spot: Dictionary, translator: Object) -> String:
	var numbers: Array = spot.numbers
	var joined := "-".join(numbers.map(func(number: int) -> String: return str(number)))
	match int(spot.kind):
		RouletteMath.BetKind.STRAIGHT:
			return translator.tr("ROULETTE_KIND_STRAIGHT") % joined
		RouletteMath.BetKind.SPLIT:
			return translator.tr("ROULETTE_KIND_SPLIT") % joined
		RouletteMath.BetKind.STREET:
			return translator.tr("ROULETTE_KIND_STREET") % joined
		RouletteMath.BetKind.CORNER:
			return translator.tr("ROULETTE_KIND_CORNER") % joined
		RouletteMath.BetKind.SIX_LINE:
			return translator.tr("ROULETTE_KIND_SIX_LINE") % [numbers[0], numbers[-1]]
	return translator.tr(name_key(String(spot.id)))


static func name_key(id: String) -> String:
	return "ROULETTE_NAME_" + id.replace(":", "_").to_upper()


static func face_key(id: String) -> String:
	return "ROULETTE_SPOT_" + id.replace(":", "_").to_upper()
