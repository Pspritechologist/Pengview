class_name ImageView extends TextureRect

# Signals for main window reactions.
## Emitted when a new image is loaded.
signal image_loaded()
## Emitted when the scaling of the image changes.
signal scale_changed(new_scale: scale_mode)
## Emitted when the filtering of an image changes.
signal filter_changed(new_state: bool)

## Enum for scaling options.
enum scale_mode{
	FIT_CANVAS,
	STRETCH_CANVAS,
	KEEP_ORIGINAL
}


func _init() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	item_rect_changed.connect(_on_item_rect_changed)
	gui_input.connect(_on_input)


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
	get_window().size = img_texture.get_size().clamp(Vector2(530, 330), DisplayServer.screen_get_size() * 0.80)
	if Vector2(get_window().size) > img_texture.get_size():
		set_filter(false)
		set_scale_mode(scale_mode.KEEP_ORIGINAL)
	get_window().move_to_center()
	image_loaded.emit()


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
	scale_changed.emit(mode)


## Sets whether the image should be filtered.
func set_filter(filter: bool) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if filter else CanvasItem.TEXTURE_FILTER_NEAREST
	filter_changed.emit(filter)


func zoom(percent: float) -> void:
	scale += Vector2(percent / 100, percent / 100)
	scale = scale.clamp(Vector2(0.5, 0.5), Vector2(100, 100))


func reset() -> void:
	scale = Vector2.ONE
	position = Vector2.ZERO


## Checks if the given string is a valid image file.
static func is_valid_image_path(path: String) -> bool:
	var ext = path.get_extension().to_lower()
	return (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp") and (path.is_relative_path() or path.is_absolute_path())


func _on_input(event: InputEvent) -> void:
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return
	if !event is InputEventMouseMotion: return 
	if (scale == Vector2.ONE and !Input.is_key_pressed(KEY_ALT)) or (scale != Vector2.ONE and Input.is_key_pressed(KEY_ALT)): return
	position += event.relative * scale.x
	position = position.clamp(Vector2.ZERO - size * 0.80, get_parent().size - size * 0.20)


## Keeps the image's pivot point centered based on .
func _on_item_rect_changed() -> void:
	pivot_offset = size / 2
