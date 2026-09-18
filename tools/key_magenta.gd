extends SceneTree
## Converts Higgsfield's exact magenta-mask masters into clean runtime alpha PNGs.

const SOURCE_DIR := "res://assets/source/redesign/slot_symbols"
const OUTPUT_DIR := "res://assets/production/slot/symbols"
const NAMES: Array[String] = ["cherry", "lemon", "bell", "bar", "seven", "diamond"]


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	for asset_name: String in NAMES:
		var image := Image.load_from_file(SOURCE_DIR.path_join(asset_name + "_mask.png"))
		assert(not image.is_empty(), "Missing magenta-mask source: %s" % asset_name)
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
		var error := image.save_png(OUTPUT_DIR.path_join(asset_name + ".png"))
		assert(error == OK, "Could not save keyed symbol: %s" % asset_name)
		print("KEYED ", asset_name, " ", image.get_size(), " corner_alpha=", image.get_pixel(0, 0).a)
	quit()
