extends Control

@export var cursor : Node2D
@export var movement_cursor : AnimatedSprite2D

var cursor_scale : Vector2
var movement_cursor_scale : Vector2

var window_size : Vector2i
var window_shortest_length : int

func _ready() -> void:
	cursor_scale = cursor.scale
	movement_cursor_scale = movement_cursor.scale
	GameStatus.game_state_changed.connect(toggle_cursor_game_state)

func _process(delta: float) -> void:
	window_size = get_tree().root.content_scale_size
	window_shortest_length = min(window_size.x, window_size.y)
	var mouse_vector = InputController.mouse_vector
	
	# Set visibility based on input mode
	if InputController.current_input_mode == InputController.input_modes.MOUSE:
		cursor.visible = true
	elif InputController.current_input_mode == InputController.input_modes.CONTROLLER:
		cursor.visible = false
	
	# Position cursor to equivilant of mouse position
	movement_cursor.position.x = mouse_vector.x * window_shortest_length / 2.
	movement_cursor.position.y = mouse_vector.y * window_shortest_length / 2.
	
	movement_cursor.rotation = atan2(mouse_vector.y, mouse_vector.x) + PI / 2.
	
	var anim_count = movement_cursor.sprite_frames.get_animation_names().size()
	var anim := "Arrow_%d" % [ceili(InputController.movement_vector_mouse.length() * (anim_count - 1))]
	if movement_cursor.animation != anim:
		movement_cursor.play(anim)
	
	# Adjust opacity of cursor material to deadzone
	var alpha_start := .25
	var alpha_end := .5
	var modulate_color := Color(
		1, 1, 1,
		lerp(alpha_start, alpha_end, InputController.movement_vector_mouse.length())
	)
	
	movement_cursor.modulate = modulate_color
	
	align_cursor_with_chocomel()


func align_cursor_with_chocomel():
	var cam : = Context.camera
	var chocomel_tracker_pos := Context.chocomel.global_position + Vector3.UP * .5
	var chocomel_coords_2D := cam.camera3D.unproject_position(chocomel_tracker_pos)
	
	cursor.position = chocomel_coords_2D
	
	var min_space_x := float(min(chocomel_coords_2D.x, window_size.x - chocomel_coords_2D.x))
	var min_space_y := float(min(chocomel_coords_2D.y, window_size.y - chocomel_coords_2D.y))
	var scale_lim_x : float = clamp(min_space_x / (window_size.x/2.), .2, 1.)
	var scale_lim_y : float = clamp(min_space_y / (window_size.y/2.), .2, 1.)
	var scale_factor : float = min(scale_lim_x, scale_lim_y)
	
	cursor.scale = cursor_scale * scale_factor
	movement_cursor.scale = movement_cursor_scale * window_shortest_length / 1080.

func toggle_cursor_game_state(new_state, prev_state):
	visible = new_state in [GameStatus.game_states.GAMEPLAY, GameStatus.game_states.INTRO]
