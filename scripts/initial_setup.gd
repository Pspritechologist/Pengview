extends Node

var exiftool_installed: bool = true

# Windows vars
const _int_exiftool_path: String = "res://exiftool.exe"
const _user_exiftool_path: String = "user://exiftool.exe"

# Linux vars
const _unix_install_command: String = "gzip -dc Image-ExifTool-12.65.tar.gz | tar -xf - && cd Image-ExifTool-12.65 && perl Makefile.PL && sudo make install"
const _int_exiftool_tar: String = "res://Image-ExifTool-12.65.tar.gz"
const _user_exiftool_tar: String = "user://Image-ExifTool-12.65.tar.gz"
const _user_install_sh: String = "user://exif_install.sh"


func _ready() -> void:
	if OS.get_name() == "Windows":
		# Windows set up
		if OS.execute(ProjectSettings.globalize_path(_user_exiftool_path), [], [], true) != OK: # Check for exiftool.exe.
			print("Making exiftool.exe")
			var exif_bytes := FileAccess.get_file_as_bytes(_int_exiftool_path)
			var user_exe := FileAccess.open(_user_exiftool_path, FileAccess.WRITE)
			user_exe.store_buffer(exif_bytes)
			
	elif OS.get_name() == "Linux":
		# Linux set up
		if OS.execute("exiftool", [], [], true) != OK:
			printerr("exiftool not installed!")
			print("The .tar.gz for exiftools is located at %s. Install it by running the following command in that folder." % ProjectSettings.globalize_path(_user_exiftool_tar))
			print(_unix_install_command)
			print("Restart after installing.")
			exiftool_installed = false
			#print("Attempting automatic install...")
#
			#var exif_bytes := FileAccess.get_file_as_bytes(_int_exiftool_tar)
			#var user_tar := FileAccess.open(_user_exiftool_tar, FileAccess.WRITE)
			#user_tar.store_buffer(exif_bytes)
			#user_tar.close()
			#var file_exif_install := FileAccess.open(_user_install_sh, FileAccess.WRITE)
			#file_exif_install.store_string(_unix_install_command)
			#file_exif_install.close()
			#OS.execute("chmod", ["777", ProjectSettings.globalize_path(_user_install_sh)])
			##await get_tree().create_timer(1).timeout
			#OS.execute("sh", [ProjectSettings.globalize_path(_user_install_sh)])
			##OS.shell_open(file_exif_install.get_path_absolute())
			#while OS.execute("exiftool", [], [], true) != OK:
				#print("exiftool installation not done...")
				#await get_tree().create_timer(4).timeout
			#print("exiftool installation done! Cleaning up...")
			#DirAccess.remove_absolute(ProjectSettings.globalize_path(_user_exiftool_tar))
			#DirAccess.remove_absolute(ProjectSettings.globalize_path(_user_install_sh))

