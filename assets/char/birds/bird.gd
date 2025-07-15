extends Node3D

@export_category("Member Nodes")
@export var animation_player : AnimationPlayer
@export var animation_tree : AnimationTree
@export var debug_radius : MeshInstance3D

@export_category("Settings")
@export var custom_rotation := false

enum character_states {NONE, IDLE, FLYING, WAITING}
var current_character_state := character_states.NONE

const WAITING_TIME := 30.0
var waiting_timeout := WAITING_TIME:
	set(value):
		waiting_timeout = clamp(value, 0.0, WAITING_TIME)

var animation_finished := false
var current_animation : StringName
var previous_animation : StringName
var current_playing_position := 0.0
var previous_playing_position := 0.0

var flight_direction := Vector3.ZERO
var chocomel_is_nigh := false
var chocomel_one_the_horizon := false

@onready var animation_tree_playback : AnimationNodeStateMachinePlayback = animation_tree["parameters/playback"]
@onready var random_start_offset := randf_range(0.0, 1.0):
	set(value):
		random_start_offset = clamp(value, 0.0, 1.0)


func _ready() -> void:
	
	#print("random_start_offset = " + str(random_start_offset))
	
	debug_radius.visible = false
	
	if not custom_rotation:
		rotation = Vector3(0, randf_range(-PI, PI), 0)


func _physics_process(delta: float) -> void:
	
	previous_playing_position = current_playing_position
	current_playing_position = animation_tree_playback.get_current_play_position()
	
	previous_animation = current_animation
	current_animation = animation_tree_playback.get_current_node()
	
	# Make sure that animation is not misidentified as finished when it was changed
	if previous_animation != current_animation:
		previous_playing_position = -1.0
	
	if (
		current_playing_position < previous_playing_position
		or current_playing_position == animation_tree_playback.get_current_length()
	):
		animation_finished = true
	
	
	flight_direction = (global_position - Context.chocomel.global_position).normalized()
	var chocomel_distance := (Context.chocomel.global_position - global_position).length()
	chocomel_is_nigh = chocomel_distance < 4.0
	chocomel_one_the_horizon = chocomel_distance < 15.0
	
	state_logic()
	
	# Reset bools
	animation_finished = false


func state_logic() -> void:
	var delta := get_physics_process_delta_time()
	
	match current_character_state:
		character_states.NONE:
			
			init_bird_randomly()
			
		character_states.IDLE:
			
			if chocomel_is_nigh:
				fly_away()
			elif animation_finished:
				next_random_loop()
			
		character_states.FLYING:
			if animation_finished:
				hide_and_time_bird()
		
		character_states.WAITING:
			
			waiting_timeout -= delta
			
			# Reset timer if chocomel stalks the perimiter
			
			if chocomel_one_the_horizon:
				waiting_timeout = WAITING_TIME
			
			if waiting_timeout <= 0.0:
				start_bird_animations()


func init_bird_randomly() -> void:
	
	var delta := get_physics_process_delta_time()
	
	if random_start_offset > 0.0:
		random_start_offset -= delta
		return
	
	if random_start_offset == 0.0:
		start_bird_animations()


func start_bird_animations() -> void:
	
	current_character_state = character_states.IDLE
	
	visible = true
	animation_tree_playback.start("Idle Loops")
	#next_random_loop()


func next_random_loop() -> void:
	
	#animation_tree_playback.set("parameters/Idle Loops/blend_position", randf())
	
	animation_tree["parameters/Idle Loops/blend_position"] = randf()


func fly_away() -> void:
	
	set_rotation_from_vector(flight_direction)
	
	current_character_state = character_states.FLYING
	
	animation_tree_playback.start("Fly Away")
	animation_tree["parameters/Fly Away/blend_position"] = randf()


func hide_and_time_bird() -> void:
	
	current_character_state = character_states.WAITING
	visible = false


func set_rotation_from_vector(global_direction : Vector3) -> void:
	var angle := global_direction.signed_angle_to(Vector3.BACK, Vector3.UP)
	basis = Basis.IDENTITY.rotated(Vector3.UP, -angle)
