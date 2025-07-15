extends Node3D

# These are manually picked based on the distance from the camera!
var window_width_in_local_space := 0.355
var window_height_in_local_space := 0.2

@export var material_cursor : StandardMaterial3D

func _process(delta: float) -> void:
	var window_width := InputController.window_width
	var window_height := InputController.window_height
	
	# Set visibility based on input mode
	if InputController.current_input_mode == InputController.input_modes.MOUSE:
		visible = true
	elif InputController.current_input_mode == InputController.input_modes.CONTROLLER:
		visible = false
	
	var mouse_vector = InputController.mouse_vector
	
	# Position cursor to equivilant of mouse position
	position.x = remap(
		mouse_vector.x,
		-1.0,
		1.0,
		-window_height_in_local_space,
		window_height_in_local_space
	)
	position.y = remap(
		-mouse_vector.y,
		1.0,
		-1.0,
		window_height_in_local_space,
		-window_height_in_local_space
	)
	
	# Adjust opacity of cursor material to deadzone
	var opacity_factor : float = max(
			abs(InputController.movement_vector_mouse.x),
			abs(InputController.movement_vector_mouse.y)
	)
	material_cursor.albedo_color.a = remap(
		opacity_factor,
		0,
		1,
		0.1,
		1.0
	)
	# Clamp min opcaity to not turn negative
	material_cursor.albedo_color.a = max(
		material_cursor.albedo_color.a,
		0
	)
