class_name DirectoryBar extends FadingControl

signal image_selected(path: String)

@export var directory_label: Label
@export var image_list_cont: Control
@export var date_sort_button: Button

const image_list_scene: String = "res://scenes/directory_bar_image_list.tscn"

var image_list: ItemList
var sort_date: bool = false


func _ready() -> void:
	date_sort_button.toggled.connect(set_sort_by_date)


func setup_directory(base_path: String) -> void:
	if !base_path.is_absolute_path():
		printerr("DirectoryBar: Argument must be an absolute path to an image or directory!")
		hide()
		return
	if image_list: image_list.queue_free()
	var setup_thread: Thread = Thread.new()
	setup_thread.start(_setup_directory_threaded.bind(base_path, setup_thread))


func change_image(count: int) -> void:
	if !image_list.is_anything_selected(): return
	var index: int = image_list.get_selected_items()[0]
	index += count
	if index < 0: index += image_list.item_count
	if index >= image_list.item_count: index -= image_list.item_count
	image_list.select(index)
	_image_selected(index)


# Get all the items in the image_list, and organize them by last date modified
func set_sort_by_date(date: bool) -> void:
	if sort_date == date: return
	sort_date = date
	if image_list and image_list.is_anything_selected():
		setup_directory(image_list.get_item_metadata(image_list.get_selected_items()[0]))


func _setup_directory_threaded(base_path: String, thread: Thread) -> void:
	image_list = load(image_list_scene).instantiate()
	@warning_ignore("narrowing_conversion")
	image_list.fixed_column_width = image_list.size.x / 2
	var directory = base_path.get_base_dir()
	directory_label.call_thread_safe("set_text", directory.right(directory.length() - directory.rfind("\\") - 1))
	directory_label.call_thread_safe("set_tooltip_text", directory)
	var dir := DirAccess.open(directory)
	var files: Array = Array(dir.get_files())
	files = files.filter(func(item): return ImageView.is_valid_image_path(item))
	if files.size() < 2: 
		hide()
		call_deferred("_setup_post_thread", thread, false)
		return
	if sort_date:
		files.sort_custom(func(a, b): return FileAccess.get_modified_time("%s\\%s" % [directory, b]) < FileAccess.get_modified_time("%s\\%s" % [directory, a]))
	for file in files:
		var image: Image = Image.load_from_file("%s\\%s" % [directory, file])
		if !image:
			printerr("Could not load image! %s" % file)
			continue
		var img_size := image.get_size()
		@warning_ignore("integer_division")
		img_size.x = img_size.x * 48 / img_size.y
		image.resize(img_size.x, 48, Image.INTERPOLATE_NEAREST)
		var icon: Texture2D = ImageTexture.create_from_image(image)
		image_list.add_item(file, icon)
		image_list.set_item_metadata(image_list.item_count - 1, "%s\\%s" % [directory, file])
		if file == base_path.get_file(): image_list.select(image_list.item_count - 1)
		
	call_deferred("_setup_post_thread", thread, true)

func _setup_post_thread(thread: Thread, success: bool) -> void:
	thread.wait_to_finish()
	if !success: return
	image_list_cont.add_child(image_list)
	image_list.item_selected.connect(_image_selected)
	show()


func _image_selected(index: int) -> void:
	image_selected.emit(image_list.get_item_metadata(index))
