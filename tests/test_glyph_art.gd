extends GutTest
## The painted input glyphs and the two shared plaques: that the masters are real
## transparent art at a usable resolution, that every piece a nine-patch or a
## three-slice stretches is genuinely flat there, and that each device family
## resolves to its own art.
##
## Built by tools/art/build_glyph_kit.py from assets/source/layered_v2/ui_kit.

## No master may be smaller than this on its short side: the glyphs are drawn at
## 18-28 px but the kit has to stay sharp when the canvas is scaled to 4K.
const MIN_SHORT_SIDE: int = 400


func _image(texture: Texture2D) -> Image:
	var image := texture.get_image()
	assert_not_null(image, "%s decodes" % texture.resource_path)
	image.decompress()
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	return image


func _every_texture() -> Dictionary:
	var textures: Dictionary = {
		"bumper": GlyphKit.BUMPER,
		"keycap": GlyphKit.KEYCAP,
		"dpad": GlyphKit.DPAD,
		"ps_face": GlyphKit.PS_FACE,
	}
	for letter: String in GlyphKit.XBOX_FACES:
		textures["xbox_" + letter.to_lower()] = GlyphKit.XBOX_FACES[letter]
	textures["result_banner"] = UiKit.texture(UiKit.SHARED, "result_banner")
	textures["score_badge"] = UiKit.texture(UiKit.SHARED, "score_badge")
	return textures


func test_every_master_is_sharp_transparent_art() -> void:
	var paths: Array[String] = []
	for name: String in _every_texture():
		var texture: Texture2D = _every_texture()[name]
		assert_not_null(texture, "%s is bundled" % name)
		var size := texture.get_size()
		assert_gte(int(minf(size.x, size.y)), MIN_SHORT_SIDE, "%s is a large master" % name)
		var image := _image(texture)
		# Real alpha, not a matte: every corner of the padded canvas is clear.
		for corner: Vector2i in [
			Vector2i(0, 0),
			Vector2i(image.get_width() - 1, 0),
			Vector2i(0, image.get_height() - 1),
			Vector2i(image.get_width() - 1, image.get_height() - 1)
		]:
			assert_eq(image.get_pixelv(corner).a, 0.0, "%s corner %s is clear" % [name, corner])
		assert_gt(
			image.get_pixel(image.get_width() / 2, image.get_height() / 2).a,
			0.99,
			"%s is opaque where it is painted" % name
		)
		assert_false(paths.has(texture.resource_path), "%s has its own file" % name)
		paths.append(texture.resource_path)


func test_the_four_xbox_gems_are_four_different_pictures() -> void:
	var seen: Array[String] = []
	for letter: String in ["A", "B", "X", "Y"]:
		var texture: Texture2D = GlyphKit.XBOX_FACES[letter]
		assert_false(seen.has(texture.resource_path), "%s is its own gem" % letter)
		seen.append(texture.resource_path)
	assert_eq(seen.size(), 4)


func test_the_sliced_pieces_are_flat_where_they_stretch() -> void:
	# A three-slice only stretches the band between the painted caps, so every
	# column in that band must be identical or the stretch would smear the paint.
	for entry: Array in [
		[GlyphKit.BUMPER, GlyphKit.BUMPER_CAPS], [GlyphKit.KEYCAP, GlyphKit.KEYCAP_CAPS]
	]:
		var image := _image(entry[0] as Texture2D)
		var caps: Vector2 = entry[1]
		var left := int(caps.x)
		var right := image.get_width() - int(caps.y) - 1
		assert_gt(right, left, "%s has a band to stretch" % (entry[0] as Texture2D).resource_path)
		var middle := (left + right) / 2
		for row: int in [
			image.get_height() / 4, image.get_height() / 2, image.get_height() * 3 / 4
		]:
			var reference := image.get_pixel(left, row)
			for column: int in [middle, right]:
				assert_eq(
					image.get_pixel(column, row),
					reference,
					(
						"%s row %d is uniform across the band"
						% [(entry[0] as Texture2D).resource_path, row]
					)
				)


func test_the_shared_plaques_have_a_flat_centre_inside_valid_margins() -> void:
	for part: String in ["result_banner", "score_badge"]:
		var texture := UiKit.texture(UiKit.SHARED, part)
		var margin := UiKit.margin(UiKit.SHARED, part)
		var image := _image(texture)
		assert_gt(margin, 0, "%s records a patch margin" % part)
		assert_lt(
			margin * 2,
			mini(image.get_width(), image.get_height()),
			"%s margins fit inside the texture" % part
		)
		# The centre patch is the only part a nine-patch stretches in both axes.
		var reference := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
		for at: Vector2i in [
			Vector2i(margin, margin),
			Vector2i(image.get_width() - margin - 1, margin),
			Vector2i(margin, image.get_height() - margin - 1),
			Vector2i(image.get_width() - margin - 1, image.get_height() - margin - 1)
		]:
			assert_eq(image.get_pixelv(at), reference, "%s centre patch is flat at %s" % [part, at])


func test_each_device_family_resolves_to_its_own_painted_button() -> void:
	var pad := InputRouter.Device.GAMEPAD
	var xbox := InputRouter.GamepadFamily.XBOX
	var sony := InputRouter.GamepadFamily.PLAYSTATION
	var nintendo := InputRouter.GamepadFamily.NINTENDO
	var gem := GlyphKit.face_texture(InputRouter.glyph_spec(&"interact", pad, xbox))
	assert_eq(gem, GlyphKit.XBOX_FACES["A"], "Xbox A is the green gem")
	assert_eq(
		GlyphKit.face_texture(InputRouter.glyph_spec(&"back", pad, xbox)),
		GlyphKit.XBOX_FACES["B"],
		"Xbox B is the red gem"
	)
	# PlayStation and Nintendo print their own symbol or letter on the blank button.
	assert_eq(
		GlyphKit.face_texture(InputRouter.glyph_spec(&"interact", pad, sony)), GlyphKit.PS_FACE
	)
	assert_eq(
		GlyphKit.face_texture(InputRouter.glyph_spec(&"interact", pad, nintendo)), GlyphKit.PS_FACE
	)
	assert_ne(gem, GlyphKit.PS_FACE, "An Xbox prompt never shows the PlayStation button")


func test_glyphs_keep_their_painted_aspect_and_grow_for_a_long_legend() -> void:
	var height := 20.0
	var pill := InputGlyph.measure({"kind": InputRouter.GlyphKind.SHOULDER, "label": "LB"}, height)
	assert_almost_eq(pill, height * GlyphKit.BUMPER_ASPECT, 0.5, "A short legend keeps the pill")
	var long_pill := InputGlyph.measure(
		{"kind": InputRouter.GlyphKind.TRIGGER, "label": "Options"}, height
	)
	assert_gt(long_pill, pill, "A long legend widens the pill instead of overflowing it")
	var key := InputGlyph.measure({"kind": InputRouter.GlyphKind.KEYCAP, "label": "Q"}, height)
	assert_almost_eq(
		key, height * GlyphKit.KEYCAP_ASPECT, 0.5, "One letter keeps the keycap square"
	)
	assert_gt(
		InputGlyph.measure({"kind": InputRouter.GlyphKind.KEYCAP, "label": "Enter"}, height),
		key,
		"A word widens the keycap"
	)
	var face := InputGlyph.measure(
		{"kind": InputRouter.GlyphKind.FACE, "label": "A", "color": Color.GREEN}, height
	)
	assert_eq(face, height, "A face button stays round")
