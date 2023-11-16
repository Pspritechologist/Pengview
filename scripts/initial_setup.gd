extends Node

## Is exiftools installed?
var exiftool_installed: bool = true
## Is ffmpeg installed?
var ffmpeg_installed: bool = true


## The command to execute exiftool.
static var exiftool: String:
	get:
		if OS.get_name() == "Windows": return "\"%s\"" % ProjectSettings.globalize_path(_user_exiftool_path)
		else: return "exiftool"

## The command to execute ffmpeg.
static var ffmpeg: String:
	get:
		if OS.get_name() == "Windows": return "\"%s\"" % ProjectSettings.globalize_path(_user_ffmpeg_path)
		else: return "ffmpeg"


const _depends_enable_path: String = "psprite_games/pengview/check_for_depends"

# Windows vars
const _int_exiftool_path: String = "res://depends/windows/exiftool.exe"
const _user_exiftool_path: String = "user://exiftool.exe"

const _int_ffmpeg_path: String = "res://depends/windows/ffmpeg.exe"
const _user_ffmpeg_path: String = "user://ffmpeg.exe"

# Linux vars
#const _unix_install_command: String = "gzip -dc Image-ExifTool-12.65.tar.gz | tar -xf - && cd Image-ExifTool-12.65 && perl Makefile.PL && sudo make install"
#const _int_exiftool_tar: String = "res://Image-ExifTool-12.65.tar.gz"
#const _user_exiftool_tar: String = "user://Image-ExifTool-12.65.tar.gz"
#const _user_install_sh: String = "user://exif_install.sh"


func _ready() -> void:
	if !ProjectSettings.get_setting_with_override(_depends_enable_path):
		print("Skipping check for dependencies...")
		exiftool_installed = false
		ffmpeg_installed = false
		return

	# Check for exiftool.
	if OS.execute(exiftool, [], [], true) != OK:

		if OS.get_name() == "Windows": # Windows set up.
			print("Making exiftool.exe")
			var exif_bytes := FileAccess.get_file_as_bytes(_int_exiftool_path)
			var user_exe := FileAccess.open(_user_exiftool_path, FileAccess.WRITE)
			user_exe.store_buffer(exif_bytes)
		
		else: # Linux set up.
			printerr("exiftool not installed!")
			exiftool_installed = false
	
	# Check for ffmpeg.
	if OS.execute(ffmpeg, [], [], true) != OK:

		if OS.get_name() == "Windows": # Windows set up.
			print("Making ffmpeg.exe")
			var ffmpeg_bytes := FileAccess.get_file_as_bytes(_int_ffmpeg_path)
			var user_exe := FileAccess.open(_user_ffmpeg_path, FileAccess.WRITE)
			user_exe.store_buffer(ffmpeg_bytes)
		
		else: # Linux set up.
			printerr("ffmpeg not installed!")
			ffmpeg_installed = false

			#print("The .tar.gz for exiftools is located at %s. Install it by running the following command in that folder." % ProjectSettings.globalize_path(_user_exiftool_tar))
			#print(_unix_install_command)
			#print("Restart after installing.")
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

