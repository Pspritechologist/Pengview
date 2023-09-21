extends HBoxContainer

var key: String:
	set(input): $Label.text = input
	get: return $Label.text

var value: String:
	set(input): $LineEdit.text = input
	get: return $LineEdit.text
