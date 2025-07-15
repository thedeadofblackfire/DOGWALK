extends SubViewportContainer

class_name MenuUI

@export var support_button : Control

@export var main_menu : Control
@export var pause_menu : Control
var settings_menu : Control:
	get():
		return find_child("SettingsMenu")

func _ready() -> void:
	Context.menu_ui = self

func _process(delta: float) -> void:
	var ratio_x : float = get_tree().root.content_scale_size.x / 3840.
	var ratio_y : float = get_tree().root.content_scale_size.y / 2160.
	
	support_button.visible = main_menu.state == main_menu.menu_states.MAIN
	
	scale = Vector2(min(ratio_x, ratio_y), min(ratio_x, ratio_y))
