extends Node

@export var godot_logo : TextureRect
@export var blender_logo : TextureRect
@export var animation_player : AnimationPlayer

var game_started := false

func _ready() -> void:
	animation_player.animation_finished.connect(kill)
	
func kill(anim: String = ""):
	Context.menu_ui.main_menu.enter_main_menu()
	queue_free()

func _process(delta: float) -> void:
	if Context.debug.skip_launch_logos:
		kill()
	# Make sure the animation only starts when processing starts on all nodes
	if not game_started:
		animation_player.play("logos_animated")
		game_started = true
