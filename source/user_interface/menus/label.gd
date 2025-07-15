@tool

extends Label

@export var font_scale := 1.

func _ready() -> void:
	var default_font_size = get_theme_default_font_size()
	remove_theme_font_size_override("font_size")
	add_theme_font_size_override("font_size", font_scale * default_font_size)

func _process(delta: float) -> void:
	if not Engine.is_editor_hint():
		return
	var default_font_size = get_theme_default_font_size()
	remove_theme_font_size_override("font_size")
	add_theme_font_size_override("font_size", font_scale * default_font_size)
