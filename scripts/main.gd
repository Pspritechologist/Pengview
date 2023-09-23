extends Control

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

var _titlebar_in_use: bool = false
var _fullscreened: bool = false
var _last_mouse_pos: Vector2i
var _drag_moving: bool = false
var _drag_resizing: bool = false
var _drag_resize_side: String = ""

var _context_items: Array[_context_item_base] = [
	_context_item_check.new("Fullscreen", func(_menu: PopupMenu, _index: int): 
		_toggle_fullscreen(),
		"_fullscreened"),
	_context_item_multi.new("Zoom level", func(): pass, "zoom", 5, func(x: int) -> int: return x + 1 if x < 5 else 0),
	_context_item_base.new("Show Image Meta", func(_menu, _index): meta_window.show()),
	_context_item_base.new("Quit", func(): get_tree().quit()),
]

## Base class for context menu items.
class _context_item_base:
	var title: String
	var icon: Texture2D
	var callback: Callable

	func _init(_title: String,
		_callback: Callable = func(menu: PopupMenu, index: int): pass,
		_icon: Texture2D = null
	) -> void:
		self.title = _title
		self.callback = _callback
		self.icon = _icon

## Class for context menu items with two states.
class _context_item_check extends _context_item_base:
	var default_state_var: NodePath
	var default_state_func: Callable

	func _init(_title: String,
		_callback: Callable,
		_default_state_var: NodePath,
		_icon: Texture2D = null,
		_default_state_func: Callable = func(x: bool) -> bool: return x
	) -> void:
		super._init(_title, _callback, _icon)
		self.default_state_var = _default_state_var
		self.default_state_func = _default_state_func

## Class for context menu items with multiple states.
class _context_item_multi extends _context_item_check:
	var max_states: int

	func _init(_title: String,
		_callback: Callable,
		_default_state_var: NodePath,
		_max_states: int,
		_default_state_func: Callable = func(x: int) -> int: return x
	) -> void:
		super._init(_title, _callback, _default_state_var, null, _default_state_func)
		self.max_states = _max_states


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
		imageview.load_image(current_path)
	
	# Setup meta window.
	var meta_thread: Thread = Thread.new()
	meta_thread.start(_setup_meta_threaded.bind(meta_thread))
	
	# Set title.
	titlelabel.add_image(preload("res://icons/icon.tres"), %Titlebar.size.y, %Titlebar.size.y)
	titlelabel.add_text(" Pengview")

	# Set background options.
	for i in range(0, background.get_tab_count()):
		backgroundoptions.add_item(background.get_tab_title(i).capitalize())

	# Set scaling options.
	for option in ImageView.scale_mode:
		scaleoptions.add_item(option.capitalize())


## Handles fading the title var, and resizing consistently.
func _process(delta: float) -> void:
	_titlebar_in_use = titlebar.get_global_rect().has_point(titlebar.get_global_mouse_position())
	titlebar.modulate.a = lerpf(titlebar.modulate.a, 1 if _titlebar_in_use else 0, 6 * delta)
	
	if _drag_moving: _handle_move()
	if _drag_resizing: _handle_resize()


## Handles main UI inputs.
func _main_input(event: InputEvent, _title: bool) -> void:
	if not event is InputEventMouseButton: return

	if event.button_index == MOUSE_BUTTON_LEFT:
		_drag_moving = event.pressed
		_last_mouse_pos = DisplayServer.mouse_get_position()

	if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		_toggle_fullscreen()

	if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var menu := _generate_context_menu()
		add_child(menu)
		var mouse := DisplayServer.mouse_get_position()
		menu.position = Vector2(mouse.x - menu.size.x, mouse.y - 20)
		menu.show()


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
		_toggle_fullscreen()
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
		_toggle_fullscreen()
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


func _generate_context_menu() -> PopupMenu:
	var menu: PopupMenu = PopupMenu.new()
	for item in _context_items:
		# Add the item to the menu
		if item is _context_item_multi: menu.add_multistate_item(item.title, item.max_states) if !item.icon else push_error("Cannot create multistate items with icons") # Adds a multistate item, without an icon.
		elif item is _context_item_check: menu.add_check_item(item.title) if !item.icon else menu.add_icon_check_item(item.icon, item.title) # Adds a check item, with or without an icon.
		elif item is _context_item_base: menu.add_item(item.title) if !item.icon else menu.add_icon_item(item.icon, item.title) # Adds a standard item, with or without an icon.
		# Set the callback
		var index: int = menu.get_item_count() - 1
		menu.set_item_metadata(index, item.callback)
		# Set the default state if the item is a check item
		if item is _context_item_check:
			menu.set_item_checked(index, item.default_state_func.call(get_indexed(item.default_state_var)))
		# Set the default state if the item is a multistate item
		if item is _context_item_multi:
			menu.set_item_multistate(index, item.default_state_func.call(get_indexed(item.default_state_var)))
	
	menu.index_pressed.connect(func(index): menu.get_item_metadata(index).call(menu, index))
	return menu


## Handles all the title bar buttons.
func _title_button_pressed(type: int) -> void:
	match type:
		0: # Minimize
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		1: # Maximize
			_toggle_fullscreen()
		2: # Quit
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
			get_tree().quit()


func _setup_meta_threaded(thread: Thread = null) -> void:
	if !InitialSetup.exiftool_installed or !ImageView.is_valid_image_path(current_path):
		return
	var data := MetaParser.read_meta(current_path)

	var meta_inst = load("res://scenes/meta_panel.tscn").instantiate()
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


func _toggle_fullscreen() -> void:
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN: 
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		_fullscreened = false
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		_fullscreened = true
