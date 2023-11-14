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
	## Shrinks the image to remain within, but won't stretch it.
	FIT_CANVAS,
	## Stretches or shrinks the image to remain within.
	STRETCH_CANVAS,
	## Keeps the original image's scale.
	KEEP_ORIGINAL
}

#static var scaling_tooltips: Dictionary = {
	#scale_mode.FIT_CANVAS: "Shrinks the image to remain within, but won't stretch it.",
	#scale_mode.STRETCH_CANVAS: "Stretches or shrinks the image to remain within.",
	#scale_mode.KEEP_ORIGINAL: "Keeps the original image's scale."
#}

var current_path: String

var current_mode: scale_mode


var _cached_images: Dictionary = {}


func _init() -> void:
	set_scale_mode(scale_mode.FIT_CANVAS)
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	item_rect_changed.connect(_on_item_rect_changed)
	gui_input.connect(_on_input)


## Checks if the given string is a valid image file.
static func is_valid_image_path(path: String) -> bool:
	var ext = path.get_extension().to_lower()
	return (ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp") and (path.is_relative_path() or path.is_absolute_path())


## Loads an image from a file path, optionally setting the directory to be used.
func load_image(path: String, resize: bool = true) -> void:
	# Ensure that the file is a PNG, JPG, or WEBP
	if !ImageView.is_valid_image_path(path):
		printerr("Error: ImageView.set_image() only supports PNG, JPG, and WEBP files. Image loaded is of type: %s" % [path.get_extension()])
		return
	var img_texture: ImageTexture
	# Check if the file is already cached.
	if _cached_images.has(path):
		img_texture = _cached_images[path]
	else:
		# Otherwise, load the image and cache it.
		var image = Image.new()
		if image.load(path):
			printerr("Error: ImageView.set_image() could not load image at path: %s" % path)
			return
		img_texture = ImageTexture.create_from_image(image)
		if !img_texture: 
			printerr("Error: ImageView.set_image() could not create texture from image at path: %s" % path)
			return
		_cached_images[path] = img_texture

	texture = img_texture
	current_path = path
	if resize:
		get_window().size = img_texture.get_size().clamp(Vector2(530, 330), DisplayServer.screen_get_size() * 0.80)
		if Vector2(get_window().size) > img_texture.get_size():
			set_filter(false)
			set_scale_mode(scale_mode.KEEP_ORIGINAL)
		get_window().move_to_center()
	_handle_fit_scale()
		
	image_loaded.emit()


## Set the scaling mode of the image.
func set_scale_mode(mode: scale_mode) -> void:
	current_mode = mode
	match mode:
		scale_mode.KEEP_ORIGINAL: # Keeps the original scale.
			expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		scale_mode.STRETCH_CANVAS: # Stretches or shrinks to fill the rect.
			expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		scale_mode.FIT_CANVAS: # Handled in code. Shrinks to stay within, but won't stretch.
			expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			_handle_fit_scale()
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


func _on_input(event: InputEvent) -> void:
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return
	if !event is InputEventMouseMotion: return 
	if (scale == Vector2.ONE and !Input.is_key_pressed(KEY_ALT)) or (scale != Vector2.ONE and Input.is_key_pressed(KEY_ALT)): return
	position += event.relative * scale.x
	position = position.clamp(Vector2.ZERO - size * 0.80, get_parent().size - size * 0.20)


## Keeps the image's pivot point centered based on .
func _on_item_rect_changed() -> void:
	pivot_offset = size / 2
	_handle_fit_scale()
	
	
func _handle_fit_scale() -> void:
	if current_mode != scale_mode.FIT_CANVAS: return
	if !texture: return
	if size.x < texture.get_size().x or size.y < texture.get_size().y: 
		stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	else: 
		stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
