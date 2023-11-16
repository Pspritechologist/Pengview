class_name MetaParser extends Node


static func read_meta(filepath: String) -> Dictionary:
	var output: Array = []
	OS.execute(InitialSetup.exiftool, ["-json", filepath], output) # Get the results of exiftool's json output
	var dict: Dictionary = JSON.parse_string(output[0])[0] # Parse the first element in the output Array, which is the JSON array, and take the first element of that, which is the meta Dictionary.
	return dict


#static func write_meta(filepath: String, meta: Dictionary):
	#pass
