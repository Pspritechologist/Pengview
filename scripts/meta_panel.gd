extends Control

const item_scene: PackedScene = preload("res://scenes/meta_item.tscn")

var items: Dictionary


func update_list() -> void:
	for key in items:
		var inst = item_scene.instantiate()
		inst.key = str(key)
		inst.value = str(items[key])
		$%ItemContainer.add_child(inst)
