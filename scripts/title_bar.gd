extends Control

func _ready() -> void:
	self.resized.connect(_on_resized)


func _on_resized() -> void:
	pass
