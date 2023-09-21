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

@onready var imageview: ImageView = %ImageView # The big cheese.

var current_path: String = ""

var meta_window: Window # The window for displaying metadata. Starts hidden.

var titlebar_in_use: bool = false
var last_mouse_pos: Vector2i

## Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Input.use_accumulated_input = false
	# Connect all Nodes.
	hidebutton.pressed.connect(_title_button_pressed.bind(0))
	minmaxbutton.pressed.connect(_title_button_pressed.bind(1))
	quitbutton.pressed.connect(_title_button_pressed.bind(2))
	for child in borders.get_children():
		child.gui_input.connect(_scale_input.bind(child.name))
	backgroundoptions.item_selected.connect(_on_background_selected)
	scaleoptions.item_selected.connect(_on_scale_selected)
	filtertoggle.toggled.connect(_on_filter_toggled)
	#self.gui_input.connect(_move_input)
	#self.gui_input.connect(_on_input)
	
	# Handle args.
	var args: PackedStringArray = OS.get_cmdline_args()
	for arg in args:
		if ImageView.is_valid_image_path(arg):
			current_path = arg
			break
	if current_path:
		print("Loading image: %s" % current_path)
		imageview.load_image(current_path)
	
	# Setup meta window.
	var meta_thread: Thread = Thread.new()
	meta_thread.start(_setup_meta.bind(meta_thread))
	
	# Set title.
	titlelabel.add_image(preload("res://icons/icon.tres"), %Titlebar.size.y, %Titlebar.size.y)
	titlelabel.add_text(" Pengview")

	# Set background options.
	for i in range(0, background.get_tab_count()):
		backgroundoptions.add_item(background.get_tab_title(i).capitalize())

	# Set scaling options.
	for option in ImageView.scale_mode:
		scaleoptions.add_item(option.capitalize())


## Handles fading the title var.
func _process(delta: float) -> void:
	titlebar_in_use = titlebar.get_global_rect().has_point(titlebar.get_global_mouse_position())
	titlebar.modulate.a = lerpf(titlebar.modulate.a, 1 if titlebar_in_use else 0, 6 * delta)


## Handles sizing the window.
func _scale_input(event: InputEvent, side: String) -> void:
	var pos: Vector2i = DisplayServer.mouse_get_position()
	var window: Window = get_window()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: 
		last_mouse_pos = pos
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN: 
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			get_window().move_to_center()
		var movement: Vector2i = (pos - last_mouse_pos)
		match side:
			# Edges
			"BL":
				window.size.x += -movement.x
				window.position.x += movement.x
			"BT": 
				window.size.y += -movement.y
				window.position.y += movement.y
			"BR": window.size.x += movement.x
			"BB": window.size.y += movement.y
			# Corners
			"CTL": 
				window.size += Vector2i(-movement.x, -movement.y)
				window.position += Vector2i(movement.x, movement.y)
			"CTR": 
				window.size += Vector2i(movement.x, -movement.y)
				window.position += Vector2i(0, movement.y)
			"CBR": window.size += Vector2i(movement.x, movement.y)
			"CBL": 
				window.size += Vector2i(-movement.x, movement.y)
				window.position += Vector2i(movement.x, 0)
				
		last_mouse_pos = pos


# Handles moving the window.
func _move_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT: 
		last_mouse_pos = DisplayServer.mouse_get_position()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):

		var oldpos = get_window().position

		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN: 
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			get_window().move_to_center()
		get_window().position += ((DisplayServer.mouse_get_position() - last_mouse_pos) * 2)

		#if bip: 
			#print("Old window: %s, New window: %s, Old mouse: %s, New mouse: %s, Window diff: %s, Mouse diff: %s" %
				#[oldpos, get_window().position, last_mouse_pos, DisplayServer.mouse_get_position(), get_window().position - oldpos, DisplayServer.mouse_get_position() - last_mouse_pos])
			#bip = false
		#else: 
			#printerr("Old window: %s, New window: %s, Old mouse: %s, New mouse: %s, Window diff: %s, Mouse diff: %s" %
				#[oldpos, get_window().position, last_mouse_pos, DisplayServer.mouse_get_position(), get_window().position - oldpos, DisplayServer.mouse_get_position() - last_mouse_pos])
			#bip = true

		last_mouse_pos = DisplayServer.mouse_get_position()

#func _move_input(event: InputEvent) -> void:
	#if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		#var oldpos = get_window().position
		#get_window().position += event.relative as Vector2i
		#print("Old window: %s, New window: %s, Old mouse: %s, New mouse: %s, Window diff: %s, Mouse diff: %s" % [oldpos, get_window().position, last_mouse_pos, DisplayServer.mouse_get_position(), get_window().position - oldpos, event.relative])


## Handles all the title bar buttons.
func _title_button_pressed(type: int) -> void:
	match type:
		0: # Minimize
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MINIMIZED)
		1: # Maximize
			if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			else:
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		2: # Quit
			get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event == InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		var cont := _generate_context_menu()
		#cont.position = get_global_mouse_position()
		cont.popup_on_parent(get_viewport_rect())


func _generate_context_menu() -> PopupMenu:
	var menu := PopupMenu.new()
	menu.add_icon_item(load("res://icons/quit.tres"), "Quit", 0)
	menu.set_item_metadata(menu.get_item_index(0), _title_button_pressed.bind(2))
	
	menu.index_pressed.connect(func(index): menu.get_item_metadata(index).call())
	return menu


func _setup_meta(thread: Thread = null) -> void:
	if !InitialSetup.exiftool_installed or !ImageView.is_valid_image_path(current_path):
		return
	var data := MetaParser.read_meta(current_path)

	var meta_inst = load("res://scenes/meta_panel.tscn").instantiate()
	meta_inst.items = data
	meta_inst.update_list()
	call_deferred("_add_meta_children", meta_inst, thread)

func _add_meta_children(meta, thread: Thread) -> void:
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
	$MetaButton.pressed.connect(func(): meta_window.visible = true) # TODO: Make this a proper UI element.


## Handles changing the background.
func _on_background_selected(tab: int) -> void:
	background.current_tab = tab


## Handles changing the scale.
func _on_scale_selected(tab: int) -> void:
	imageview.set_scale_mode(ImageView.scale_mode.values()[tab])


## Handles toggling the filter.
func _on_filter_toggled(toggled: bool) -> void:
	imageview.set_filter(toggled)
