extends Control

@export var support_button : TextureButton


func _on_support_button_pressed() -> void:
	OS.shell_open("https://studio.blender.org/")
	
	# This is to make sure that the player is aware that a web-tab just opened
	# TODO: Find a way to switch active window isntead of default browser?
	Settings.apply("window_mode", "WINDOWED", true)
