class_name Main extends Control

@onready var hidebutton: Button = %HideButton
@onready var minmaxbutton: Button = %MinMaxButton
@onready var quitbutton: Button = %QuitButton
@onready var borders: Control = %Borders
@onready var titlebar: Control = %Titlebar
@onready var titlelabel: RichTextLabel = %TitleLabel
@onready var background: TabContainer = %Background
@onready var backgroundoptions: OptionButton = %BackgroundOptions
@onready var scaleoptions: OptionButton = %ScaleOptions
@onready var filtertoggle: CheckButton = %FilterToggle

@onready var imageview_container: Control = %ImageViewCont # The big cheese's container.

var current_path: String = ""

var imageview: ImageView # The big cheese.

var meta_window: Window # The window for displaying metadata. Starts hidden.

const _window_title_base: String = "Pengview: "
const _window_title_tags: String = "[color=white][outline_color=black][outline_size=4][font_size=24]"
const _meta_window_scene: String = "res://scenes/meta_panel.tscn"

var _titlebar_in_use: bool = false
var _fullscreened: bool = false
var _last_mouse_pos: Vector2i
var _drag_moving: bool = false
var _drag_resizing: bool = false
var _drag_resize_side: String = ""


## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.use_accumulated_input = false
	# Connect all Nodes.
	hidebutton.pressed.connect(_title_button_pressed.bind(0)) # Connect the hide button, 
	minmaxbutton.pressed.connect(_title_button_pressed.bind(1)) # Connect the maximize button, 
	quitbutton.pressed.connect(_title_button_pressed.bind(2)) # Connect and the quit button from the titlebar.
	backgroundoptions.item_selected.connect(func(tab: int): background.current_tab = tab) # Connect the background select button.
	scaleoptions.item_selected.connect(func(tab: int): imageview.set_scale_mode(ImageView.scale_mode.values()[tab])) # Set up the scaling options.
	filtertoggle.toggled.connect(func(state: bool): imageview.set_filter(state)) # Set up the AA toggle.
	for child in borders.get_children(): # Connect inputs from all the individual borders...
		child.gui_input.connect(_border_input.bind(child.name)) # Take a moment to appreciate how clean this solution is :).
	titlebar.gui_input.connect(_main_input.bind(true)) # Connect inputs from the titlerbar to mimic the main UI, indicated as the titlebar.
	self.gui_input.connect(_main_input.bind(false)) # Connect inputs from the main UI, indicated as the main UI.

	# Set background options.
	for i in range(0, background.get_tab_count()):
		backgroundoptions.add_item(background.get_tab_title(i).capitalize())

	# Set scaling options.
	for option in ImageView.scale_mode:
		scaleoptions.add_item(option.capitalize())
	
	# Handle args.
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg in args:
		if ImageView.is_valid_image_path(arg):
			current_path = arg
			break
	if current_path:
		print("Loading image: %s" % current_path)
		imageview = ImageView.new()
		imageview_container.add_child(imageview)
		imageview.image_loaded.connect(set_window_title)
		imageview.filter_changed.connect(_on_filter_changed)
		imageview.scale_changed.connect(_on_scale_changed)
		imageview.load_image(current_path)
	
	# Setup meta window.
	if InitialSetup.exiftool_installed:
		var meta_thread: Thread = Thread.new()
		meta_thread.start(_setup_meta_threaded.bind(meta_thread))


## Handles fading the title var, and resizing consistently.
func _process(delta: float) -> void:
	_titlebar_in_use = titlebar.get_global_rect().has_point(titlebar.get_global_mouse_position())
	titlebar.modulate.a = lerpf(titlebar.modulate.a, 1 if _titlebar_in_use else 0, 6 * delta)
	
	if _drag_moving: _handle_move()
	if _drag_resizing: _handle_resize()


## Handles main UI inputs.
func _main_input(event: InputEvent, _title: bool) -> void:
	if not event is InputEventMouseButton: return
	event = event as InputEventMouseButton

	if event.button_index == MOUSE_BUTTON_LEFT:
		if (imageview.scale == Vector2.ONE and !event.alt_pressed) or (imageview.scale != Vector2.ONE and event.alt_pressed): 
			_drag_moving = event.pressed
			_last_mouse_pos = DisplayServer.mouse_get_position()

	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		toggle_fullscreen()

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var menu := ContextMenu.new(self)
		add_child(menu)
		var mouse := DisplayServer.mouse_get_position()
		menu.position = Vector2(mouse.x - menu.size.x * 0.35, mouse.y - 20)
		menu.show()
		
	if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		var percent: float = 5
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: percent *= -1
		if event.ctrl_pressed: percent *= 5
		imageview.zoom(percent)


## Handles border inputs.
func _border_input(event: InputEvent, side: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: 
		_drag_resizing = event.pressed
		_last_mouse_pos = DisplayServer.mouse_get_position()
		_drag_resize_side = side


# Handles moving the window.
func _handle_move() -> void:
	var pos: Vector2i = DisplayServer.mouse_get_position()
	if !pos - _last_mouse_pos: return
	var window: Window = get_window()
	
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN: 
		toggle_fullscreen()
		window.position = pos - window.size / 2
	window.position += ((pos - _last_mouse_pos))

	_last_mouse_pos = pos


## Handles sizing the window.
func _handle_resize() -> void:
	var side = _drag_resize_side
	
	var pos: Vector2i = DisplayServer.mouse_get_position()
	var window: Window = get_window()
	
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN: 
		var full_size = window.size
		toggle_fullscreen()
		window.size = full_size
		window.move_to_center()
	var movement: Vector2i = (pos - _last_mouse_pos)
	match side:
		# Edges
		&"BL":
			window.size.x += -movement.x
			window.position.x += movement.x
		&"BT": 
			window.size.y += -movement.y
			window.position.y += movement.y
		&"BR": window.size.x += movement.x
		&"BB": window.size.y += movement.y
		# Corners
		&"CTL": 
			window.size += Vector2i(-movement.x, -movement.y)
			window.position += Vector2i(movement.x, movement.y)
		&"CTR": 
			window.size += Vector2i(movement.x, -movement.y)
			window.position += Vector2i(0, movement.y)
		&"CBR": window.size += Vector2i(movement.x, movement.y)
		&"CBL": 
			window.size += Vector2i(-movement.x, movement.y)
			window.position += Vector2i(movement.x, 0)
		
	_last_mouse_pos = pos


## Handles all the title bar buttons.
func _title_button_pressed(type: int) -> void:
	match type:
		0: # Minimize
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		1: # Maximize
			toggle_fullscreen()
		2: # Quit
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
			get_tree().quit()


func _setup_meta_threaded(thread: Thread = null) -> void:
	if !InitialSetup.exiftool_installed or !ImageView.is_valid_image_path(current_path):
		return
	var data := MetaParser.read_meta(current_path)

	var meta_inst = load(_meta_window_scene).instantiate()
	meta_inst.items = data
	meta_inst.update_list()
	call_deferred("_setup_meta_post_thread", meta_inst, thread)

func _setup_meta_post_thread(meta, thread: Thread) -> void:
	if thread: thread.wait_to_finish()
	
	meta_window = Window.new()
	meta_window.visible = false
	#meta_window.unresizable = true
	meta_window.title = "Image Metadata"
	meta_window.min_size = Vector2i(240, 240)
	meta_window.size = Vector2i(280, 550)
	meta_window.transient = true
	meta_window.add_child(meta)
	add_child(meta_window)
	meta_window.move_to_center() # Causes a thread-related error?? Seems to be fine.
	
	meta_window.close_requested.connect(func(): meta_window.visible = false)


func _on_scale_changed(mode: ImageView.scale_mode):
	scaleoptions.select(mode)


func _on_filter_changed(filter: bool):
	filtertoggle.set_pressed_no_signal(filter)


func _exit_tree() -> void:
	#if OS.has_feature("editor"): return
	ProjectSettings.save_custom(ProjectSettings.get_setting("application/config/project_settings_override"))
	print(ProjectSettings.get_setting("application/config/project_settings_override"))


## Sets the title for the window.
func set_window_title() -> void:
	titlelabel.text = ""
	@warning_ignore("narrowing_conversion")
	titlelabel.add_image(preload("res://icons/icon.tres"), titlebar.size.y, titlebar.size.y)
	titlelabel.append_text(_window_title_tags + _window_title_base)
	if current_path: titlelabel.add_text(current_path.get_basename().get_file())
	var window_title: String = _window_title_base
	if current_path: window_title += current_path.get_basename().get_file()
	DisplayServer.window_set_title(window_title)


func toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN: 
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_fullscreened = false
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_fullscreened = true
