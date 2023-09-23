class_name ImageView extends TextureRect

## Enum for scaling options.
enum scale_mode{
	FIT_CANVAS,
	STRETCH_CANVAS,
	KEEP_ORIGINAL
}


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Loads an image from a file path, optionally setting the directory to be used.
func load_image(path: String, _set_dir: bool = true) -> void:
	# Ensure that the file is a PNG, JPG, or WEBP
	if !ImageView.is_valid_image_path(path):
		printerr("Error: ImageView.set_image() only supports PNG, JPG, and WEBP files. Image loaded is of type: %s" % [path.get_extension()])
		return
	var image = Image.new()
	if image.load(path):
		printerr("Error: ImageView.set_image() could not load image at path: %s" % path)
		return
	var img_texture = ImageTexture.create_from_image(image)
	if !img_texture: 
		printerr("Error: ImageView.set_image() could not create texture from image at path: %s" % path)
		return

	texture = img_texture
	get_window().size = img_texture.get_size().clamp(Vector2(300, 200), DisplayServer.screen_get_size() * 0.80)
	get_window().move_to_center()


## Set the scaling mode of the image.
func set_scale_mode(mode: scale_mode) -> void:
	match mode:
		scale_mode.KEEP_ORIGINAL:
			expand_mode = TextureRect.EXPAND_KEEP_SIZE
			stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		scale_mode.FIT_CANVAS:
			expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		scale_mode.STRETCH_CANVAS:
			expand_mode = TextureRect.EXPAND_KEEP_SIZE
			stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


## Sets whether the image should be filtered.
func set_filter(filter: bool) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if filter else CanvasItem.TEXTURE_FILTER_NEAREST


## Checks if the given string is a valid image file.
static func is_valid_image_path(path: String) -> bool:
	var ext = path.get_extension().to_lower()
	return (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp") and (path.is_relative_path() or path.is_absolute_path())


## Keeps the image's pivot point centered based on .
func _on_item_rect_changed() -> void:
	pass # Replace with function body.
