class_name DirectoryBar extends FadingControl

signal image_selected(path: String)

@export var directory_label: Label
@export var image_list_cont: Control
@export var refresh_button: Button
@export var date_sort_button: Button
@export var search_bar: LineEdit

var sort_date: bool = false:
	set(value): 
		sort_date = value
		_populate_browser(_current_image_set, false, _image_list.get_item_metadata(_image_list.get_selected_items()[0]) if _image_list.is_anything_selected() else "")
var filter: String = "":
	set(value): 
		filter = value
		_populate_browser(_current_image_set, false, _image_list.get_item_metadata(_image_list.get_selected_items()[0]) if _image_list.is_anything_selected() else "")


const _image_list_scene: String = "res://scenes/directory_bar_image_list.tscn"

var _current_image_set: Array[image_data] = []
var _current_base_directory: String = ""
var _image_list: ItemList


func _ready() -> void:
	refresh_button.pressed.connect(func(): setup_directory(_image_list.get_item_metadata(_image_list.get_selected_items()[0]) if _image_list.is_anything_selected() else _current_base_directory))
	date_sort_button.toggled.connect(func(value): sort_date = value)
	search_bar.text_changed.connect(func(value): filter = value)


func setup_directory(base_path: String) -> void:
	if !base_path.is_absolute_path():
		printerr("DirectoryBar: Argument must be an absolute path to an image or directory!")
		hide()
		return
	if _image_list: _image_list.queue_free()
	var setup_thread: Thread = Thread.new()
	_current_base_directory = base_path
	setup_thread.start(_setup_directory_threaded.bind(base_path, setup_thread))


func change_image(count: int) -> void:
	var index: int = _image_list.get_selected_items()[0] if _image_list.is_anything_selected() else -1
	index += count
	if index < 0: index += _image_list.item_count
	if index >= _image_list.item_count: index -= _image_list.item_count
	_image_list.select(index)
	_image_selected(index)


func add_image_paths_to_browser(paths: PackedStringArray) -> void:
	for path in paths:
		var image: Image = Image.load_from_file(path)
		if !image:
			printerr("Directory Browser could not load image: %s" % path)
			continue
		var img_size := image.get_size()
		@warning_ignore("integer_division")
		img_size.x = img_size.x * 48 / img_size.y
		image.resize(img_size.x, 48, Image.INTERPOLATE_NEAREST)
		var icon: Texture2D = ImageTexture.create_from_image(image)
		_current_image_set.append(image_data.new(path, FileAccess.get_modified_time(path), icon))
		_populate_browser(_current_image_set, false, _current_base_directory)


func _setup_directory_threaded(base_path: String, thread: Thread) -> void:
	_current_image_set.clear()
	_image_list = load(_image_list_scene).instantiate()
	@warning_ignore("narrowing_conversion")
	_image_list.fixed_column_width = _image_list.size.x / 2
	var directory := base_path.get_base_dir()
	directory_label.call_thread_safe("set_text", directory.right(directory.length() - directory.rfind("\\") - 1))
	directory_label.call_thread_safe("set_tooltip_text", directory)
	var dir := DirAccess.open(directory)
	var files: Array = Array(dir.get_files())
	files = files.filter(ImageView.is_valid_image_path)
	#if files.size() < 2: 
		#hide()
		#call_deferred("_setup_post_thread", thread, false)
		#return

	for file in files:
		var path: = "%s\\%s" % [directory, file]
		var image: Image = Image.load_from_file(path)
		if !image:
			printerr("Directory Browser could not load image: %s" % file)
			continue
		var img_size := image.get_size()
		@warning_ignore("integer_division")
		img_size.x = img_size.x * 48 / img_size.y
		image.resize(img_size.x, 48, Image.INTERPOLATE_NEAREST)
		var icon: Texture2D = ImageTexture.create_from_image(image)
		_current_image_set.append(image_data.new(path, FileAccess.get_modified_time(path), icon))
	
	_populate_browser(_current_image_set, false, base_path)
		
	call_deferred("_setup_post_thread", thread, true)


func _setup_post_thread(thread: Thread, success: bool) -> void:
	thread.wait_to_finish()
	if !success: return
	image_list_cont.add_child(_image_list)
	_image_list.item_selected.connect(_image_selected)
	show()


func _image_selected(index: int) -> void:
	image_selected.emit(_image_list.get_item_metadata(index))


func _add_item(path: String, icon: Texture) -> void:
	_image_list.add_item(path.get_file(), icon)
	_image_list.set_item_metadata(_image_list.item_count - 1, path)


func _populate_browser(images: Array[image_data], ignore_filters: bool = false, to_select: String = "") -> void:
	if !_image_list: return
	_image_list.clear()

	if !ignore_filters:
		if sort_date:
			images.sort_custom(func(a: image_data, b: image_data): return b.date < a.date)
		else:
			images.sort_custom(func(a: image_data, b: image_data): return a.file.naturalnocasecmp_to(b.file) < 0)
		
		if not filter.is_empty():
			images = images.filter(func(item: image_data): return item.file.to_upper().contains(filter.to_upper()))
		
	for image in images:
		_add_item(image.path, image.icon)
		if image.path == to_select:
			_image_list.select(_image_list.item_count - 1)
			
	_image_list.ensure_current_is_visible()


class image_data:
	var path: String
	var file: String:
		get: return path.get_file()
	var date: int
	var icon: Texture
	
	func _init(_path: String, _date: int, _icon: Texture) -> void:
		path = _path
		date = _date
		icon = _icon
