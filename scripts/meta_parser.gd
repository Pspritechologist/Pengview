class_name MetaParser extends Node

static var exiftool: String = ProjectSettings.globalize_path(InitialSetup._user_exiftool_path) if OS.get_name() == "Windows" else "exiftool"


static func read_meta(filepath: String) -> Dictionary:
	var output: Array = []
	OS.execute(exiftool, ["-json", filepath], output) # Get the results of exiftool's json output
	var dict: Dictionary = JSON.parse_string(output[0])[0] # Parse the first element in the output Array, which is the JSON array, and take the first element of that, which is the meta Dictionary.
	return dict


static func write_meta(filepath: String, meta: Dictionary):
	pass
