class_name FadingControl extends Control

var _fading_in_use: bool = false


func _process(delta: float) -> void:
	_fading_in_use = self.get_global_rect().has_point(self.get_global_mouse_position())
	self.modulate.a = lerpf(self.modulate.a, 1 if _fading_in_use else 0, 6 * delta)
