class_name ContextMenu extends PopupMenu

var main: Main

var scale_factor: float:
	set(value): 
		ProjectSettings.set_setting("display/window/stretch/scale", value)
		main.get_window().content_scale_factor = value
	get: return ProjectSettings.get_setting_with_override("display/window/stretch/scale")


func _init(main_window: Main) -> void:
	main = main_window
	
	add_check_item("Fullscreen")
	set_item_metadata(item_count - 1, func(): main.toggle_fullscreen())
	set_item_checked(item_count - 1, main._fullscreened)
	
	add_multistate_item("Zoom Level", 5)
	
	add_item("Reset Image")
	set_item_metadata(item_count - 1, func(): main.imageview.reset())
	
	add_item("Show Image Metadata")
	set_item_metadata(item_count - 1, func(): main.meta_window.show())
	
	add_multistate_item("Scale: %sx" % scale_factor, 5)
	set_item_metadata(item_count - 1, _on_scaling_pressed.bind(item_count - 1))
	
	add_item("Quit")
	set_item_metadata(item_count - 1, func(): main.quit())

	index_pressed.connect(func(index): get_item_metadata(index).call())


func _on_scaling_pressed(index: int) -> void:
	scale_factor = 1.0 if scale_factor < 1 else\
		1.5 if scale_factor < 1.5 else\
		2.0 if scale_factor < 2.0 else\
		2.5 if scale_factor < 2.5 else\
		3.0 if scale_factor < 3.0 else\
		1.0
	set_item_text(index, "Scale: %sx" % scale_factor)
