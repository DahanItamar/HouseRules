extends SceneTree
## Converts Higgsfield's exact magenta-mask masters into clean runtime alpha PNGs.

const SOURCE_DIR := "res://assets/source/redesign/slot_symbols"
const OUTPUT_DIR := "res://assets/production/slot/symbols"
const NAMES: Array[String] = ["cherry", "lemon", "bell", "bar", "seven", "diamond"]
const FRAMES: Array[String] = []
const EFFECT_SOURCE := "res://assets/source/redesign/effects/casino_win_burst_mask.png"
const EFFECT_OUTPUT := "res://assets/production/effects/casino_win_burst.png"
const AVATAR_EIGHT_SOURCE := "res://assets/source/redesign/floor_avatar_eight_direction_magenta.png"
const AVATAR_EIGHT_OUTPUT := "res://assets/production/characters/casino_guest_eight_direction.png"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for asset_name: String in NAMES:
		var image := _key_image(asset_name)
		var error := image.save_png(OUTPUT_DIR.path_join(asset_name + ".png"))
		assert(error == OK, "Could not save keyed symbol: %s" % asset_name)
		print("KEYED ", asset_name, " ", image.get_size(), " corner_alpha=", image.get_pixel(0, 0).a)
	for asset_name: String in FRAMES:
		var image := _key_image(asset_name)
		var used := image.get_used_rect()
		assert(used.has_area(), "Keyed frame is empty: %s" % asset_name)
		image = image.get_region(used)
		var error := image.save_png(OUTPUT_DIR.path_join(asset_name + ".png"))
		assert(error == OK, "Could not save keyed frame: %s" % asset_name)
		print("KEYED+CROPPED ", asset_name, " ", image.get_size())
	var effect := _key_path(EFFECT_SOURCE)
	var effect_error := effect.save_png(EFFECT_OUTPUT)
	assert(effect_error == OK, "Could not save keyed win effect")
	print("KEYED casino_win_burst ", effect.get_size())
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(AVATAR_EIGHT_OUTPUT.get_base_dir())
	)
	var eight_directions := _key_path(AVATAR_EIGHT_SOURCE)
	var eight_error := eight_directions.save_png(AVATAR_EIGHT_OUTPUT)
	assert(eight_error == OK, "Could not save keyed eight-direction avatar")
	print("KEYED casino_guest_eight_direction ", eight_directions.get_size())
	quit()


func _key_image(asset_name: String) -> Image:
	return _key_path(SOURCE_DIR.path_join(asset_name + "_mask.png"))


func _key_path(path: String) -> Image:
	var image := Image.load_from_file(path)
	assert(not image.is_empty(), "Missing magenta-mask source: %s" % path)
	image.convert(Image.FORMAT_RGBA8)
	for y: int in range(image.get_height()):
		for x: int in range(image.get_width()):
			var color := image.get_pixel(x, y)
			var magenta_dominance: float = minf(color.r, color.b) - color.g
			if color.r > 0.82 and color.b > 0.82 and color.g < 0.25:
				color.a = 0.0
			elif magenta_dominance > 0.16:
				color.a = clampf((0.52 - magenta_dominance) / 0.36, 0.0, 1.0)
				var spill: float = magenta_dominance * (1.0 - color.a)
				color.r = maxf(color.g, color.r - spill)
				color.b = maxf(color.g, color.b - spill)
			image.set_pixel(x, y, color)
	return image
