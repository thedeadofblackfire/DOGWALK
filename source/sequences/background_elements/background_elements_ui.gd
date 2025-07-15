extends Control
class_name BackgroundElementsUI

@export var making_of : Control
@export var pause : Control
@export var settings : Control
@export var video_container : AspectRatioContainer

func _ready() -> void:
	Context.background_elements_ui = self
	making_of.hide()
	pause.hide()
	settings.hide()
	
	get_window().size_changed.connect(adjust_settings_background)
	adjust_settings_background()

func adjust_settings_background():
	var ratio_x : float = get_tree().root.content_scale_size.x / 1920.
	var ratio_y : float = get_tree().root.content_scale_size.y / 1080.
	
	find_child("SettingsBackground").scale = Vector2(min(ratio_x, ratio_y), min(ratio_x, ratio_y))
