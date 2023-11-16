class_name ImageView extends TextureRect

# Signals for main window reactions.
## Emitted when a new image is loaded.
signal image_loaded()
## Emitted when the scaling of the image changes.
signal scale_changed(new_scale: scale_mode)
## Emitted when the filtering of an image changes.
signal filter_changed(new_state: bool)


var current_path: String

var current_mode: scale_mode


## Enum for scaling options.
enum scale_mode{
	## Shrinks the image to remain within, but won't stretch it.
	FIT_CANVAS,
	## Stretches or shrinks the image to remain within.
	STRETCH_CANVAS,
	## Keeps the original image's scale.
	KEEP_ORIGINAL
}

## All file types supported by Pengview.
const supported_file_types: PackedStringArray = [
	"png",
	"jpg",
	"jpeg",
	"gif",
]

#static var scaling_tooltips: Dictionary = {
	#scale_mode.FIT_CANVAS: "Shrinks the image to remain within, but won't stretch it.",
	#scale_mode.STRETCH_CANVAS: "Stretches or shrinks the image to remain within.",
	#scale_mode.KEEP_ORIGINAL: "Keeps the original image's scale."
#}


## Temp directory.
static var _temp: String = ProjectSettings.globalize_path("user://tmp")


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
	return supported_file_types.has(ext) and (path.is_relative_path() or path.is_absolute_path())


## Loads an image from a file path, optionally resizing it.
func load_image(path: String, resize: bool = true) -> void:
	# Ensure that the file is a PNG, JPG, or WEBP
	if !ImageView.is_valid_image_path(path):
		printerr("Error: ImageView.load_image() only supports the following types: %s. Image loaded is of type: %s" % [supported_file_types, path.get_extension()])
		return

	var output = _import_image_standard(path) if path.get_extension().to_lower() != "gif" else _import_gif(path)
	if !output:
		print_debug("Error: ImageView/load_image() couldn't load %s" % path)
		return
	texture = output
	current_path = path
	
	if resize: #TODO This should happen on Main, not ImageView
		get_window().size = texture.get_size().clamp(Vector2(530, 330), DisplayServer.screen_get_size() * 0.80)
		if Vector2(get_window().size) > texture.get_size():
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


func _import_image_standard(path: String): # Can't have a return because then null is invalid
	var img_texture: ImageTexture
	# Check if the file is already cached.
	if _cached_images.has(path):
		img_texture = _cached_images[path]
	else:
		# Otherwise, load the image and cache it.
		var image = Image.new()
		if image.load(path):
			print_debug("Error: ImageView.load_image() could not load image at path: %s" % path)
			return null
		img_texture = ImageTexture.create_from_image(image)
		if !img_texture: 
			print_debug("Error: ImageView.load_image() could not create texture from image at path: %s" % path)
			return null
		_cached_images[path] = img_texture
		
	return img_texture


func _import_gif(path: String): # Can't have a return because then null is invalid
	if OS.get_name() != "Windows": return null #TODO Linux support.
	var anim_texture: AnimatedTexture
	# Check if the file is already cached.
	if _cached_images.has(path):
		anim_texture = _cached_images[path]
	else:
		# Otherwise, generate the animation and cache it.
		var tmp_path = _temp + "/" + path.get_file().get_basename()
		DirAccess.make_dir_recursive_absolute(tmp_path)
		var cmdout = []
		print("%s %s %s %s" % [InitialSetup.ffmpeg, "-i", path, tmp_path + "/output%04d.png"])
		if OS.execute(InitialSetup.ffmpeg, ["-i", path, tmp_path + "/output%04d.png"], cmdout, false, OS.has_feature("editor")) != OK:
			printerr("Error: ImageView._import_gif() had an ffmpeg error. Output is below.")
			print(cmdout)
			return null
		print_verbose(cmdout)
		var output_files = DirAccess.get_files_at(tmp_path)
		
		anim_texture = AnimatedTexture.new()
		var index: int = 0
		for file in output_files:
			var img = Image.load_from_file("%s/%s" % [tmp_path, file])
			var text = ImageTexture.create_from_image(img)
			anim_texture.set_frame_texture(index, text)
			anim_texture.set_frame_duration(index, 0.04162) #TODO Get info properly.
			DirAccess.remove_absolute("%s/%s" % [tmp_path, file])
			index += 1
		anim_texture.frames = index
		_cached_images[path] = anim_texture
		DirAccess.remove_absolute(tmp_path)
	
	return anim_texture


func _on_input(event: InputEvent) -> void: #TODO This is pretty gross, inputs should either be handled fully here, or fully on Main.
	if !Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): return
	if !event is InputEventMouseMotion: return 
	if (scale == Vector2.ONE and !Input.is_key_pressed(KEY_ALT)) or (scale != Vector2.ONE and Input.is_key_pressed(KEY_ALT)): return
	position += event.relative * scale.x
	position = position.clamp(Vector2.ZERO - size * 0.80, get_parent().size - size * 0.20)


## Keeps the image's pivot point centered.
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
