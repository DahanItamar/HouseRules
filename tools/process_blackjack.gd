extends SceneTree
## Crops the Higgsfield blackjack master to the game's native 16:9 stage without stretching.

const SOURCE := "res://assets/source/redesign/blackjack/blackjack_table_higgsfield.png"
const OUTPUT := "res://assets/production/blackjack/blackjack_table.png"


func _initialize() -> void:
	var image := Image.load_from_file(SOURCE)
	assert(not image.is_empty(), "Missing blackjack source master")
	var target_width := image.get_width()
	var target_height := int(target_width * 9.0 / 16.0)
	if target_height > image.get_height():
		target_height = image.get_height()
		target_width = int(target_height * 16.0 / 9.0)
	var left := (image.get_width() - target_width) / 2
	var top := (image.get_height() - target_height) / 2
	image = image.get_region(Rect2i(left, top, target_width, target_height))
	var error := image.save_png(OUTPUT)
	assert(error == OK, "Could not save blackjack runtime crop")
	print("CROPPED blackjack_table ", image.get_size())
	quit()
