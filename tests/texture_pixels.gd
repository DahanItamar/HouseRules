class_name TexturePixels
extends RefCounted
## Test helper: CPU-readable copy of a texture, even when it is VRAM-compressed.


static func readable(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	return image
