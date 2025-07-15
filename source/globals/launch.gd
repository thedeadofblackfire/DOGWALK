extends Node

func _ready() -> void:
	get_tree().current_scene.add_child(preload("res://source/user_interface/launch_logos.tscn").instantiate())
