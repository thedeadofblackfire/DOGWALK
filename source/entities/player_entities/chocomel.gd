extends CharacterBody3D

class_name Chocomel

signal has_moved(
	new_position: Vector3,
	current_velocity : Vector3,
	last_leash_point_scalar : float,
	moving_to_pinda_scalar : float,
	collar_bone_position : Vector3
)
signal has_barked()
signal tried_to_bark()
signal has_been_digging()
signal request_interaction(interaction_type : int)
signal confirmed_interaction(confirmation : bool)
signal ended_interaction()
signal entered_camera_magnet_zone(area_node : CameraMagnetZone)
signal exited_camera_magnet_zone(area_node : CameraMagnetZone)
signal set_new_petting_loop(value : float)

# For checking if the current frame is synced with the animation stepping
const FRAME_TIME := 1.0 / 24.0
var frame_time_modulo := 0.0
var on_animation_step := false

# Character states
enum character_states {IDLE, MOVING, DIG, PULLING, PUSHING, PUSHING_PINDA, INTERACTION, CINEMATIC}
enum interaction_types {LICK, REWARD, SUPERLICK, SNUGGLE, PETTING}
var barking_states := [
	character_states.IDLE,
	character_states.MOVING,
]
var current_character_state := character_states.IDLE
var previous_character_state := -1
var queued_character_state := -1
var state_was_forced := false
var current_interaction_type := interaction_types.LICK
var started_barking := false
var slippery_movement := false
var interaction_conditions_met := false

# Action variables
var interaction_confirmed := false
const BARK_TIME = 0.7 # Length of the bark animation. TODO: Set this dynamically
var bark_timeout := BARK_TIME:
	set(value):
		bark_timeout = clamp(value, 0.0, BARK_TIME)
const wake_up_recovery_time := 3.
var wake_up_progress_time := -1.
var digging_timeout := 0.0

# Movement variables
enum movement_types {WALK, TROT, RUN}
var current_movement_type := movement_types.WALK
var current_max_speed := max_speed_regular
var current_velocity := Vector3.ZERO ## The original velocity before move_and_slide()
var current_direction := self.basis.z  ## The original direction before move_and_slide()
var previous_direction := Vector3.ZERO
var current_rotation_to_target_angle_difference := 0.0
var slowdown_factor := 0.0
var previous_velocity := Vector3.ZERO
var new_velocity_direction := Vector3.ZERO
var angular_speed_factor := 0.0
var angular_speed_factor_absolute := 0.0
var angular_speed_factor_sign := 0

# Tracking of ongoing collisions instead of only the initial collision
var ongoing_touching := []
var touching_pinda : bool
var touching_actual_wall : bool

# Pinda variables
var pinda_position : Vector3
var pinda_velocity : Vector3
var pinda_direction :Vector3
var pinda_distance : float
var moving_towards_pinda_scalar : float ## How much chocomel is facing in the direction of Pinda
var pinda_needs_help := false
var pinda_started_petting := false

# Leash variables
var leash_points : PackedVector3Array
var leash_length : float
var last_leash_point : Vector3
var last_leash_point_direction : Vector3
var last_leash_point_scalar : float ## How much is Chocomel moving towards the last leash point (or kid)

# Input variables
var input_vector : Vector2

# Animation variables
var animation_state_changed : bool
var animation_state_finished : bool
var animation_started : bool
var animation_looped : bool
var current_animation_length : float
var current_animation_position : float
var previous_animation_position : float
var current_movement_speed_slice := 1
var current_rotation_slice := 1
var current_slice_rotation : float
var current_turning_slice := 1
var current_angular_velocity_slice := 1
var sitting_time := 0.0
var running_time := 0.0
var facing_same_direction_timer := 0.0
var collar_bone_global_transform : Transform3D
var petting_version_value := 0.0

# List of animation states
enum animation_states {
	IDLE,
	MOVING,
	PULLING,
	PUSHING,
	PUSHING_PINDA,
	DIGGING,
	REWARD,
	LICKING,
	SUPERLICK,
	SNUGGLE,
	SLEEPING,
	WAKING,
	LAY_DOWN,
	PETTING_LOOPS,
	STAND_UP,
}
var animation_state_names : Dictionary = {
	animation_states.IDLE 			: "Idle",
	animation_states.MOVING 		: "Moving",
	animation_states.PULLING 		: "Pulling",
	animation_states.PUSHING 		: "Pushing",
	animation_states.PUSHING_PINDA 	: "Pushing Pinda",
	animation_states.DIGGING 		: "Digging",
	animation_states.REWARD 		: "Reward",
	animation_states.LICKING 		: "Licking Pinda",
	animation_states.SUPERLICK 		: "Superlick",
	animation_states.SNUGGLE 		: "Snuggle",
	animation_states.SLEEPING		: "Sleeping",
	animation_states.WAKING			: "Wake Up",
	animation_states.LAY_DOWN 		: "Lay Down",
	animation_states.PETTING_LOOPS 	: "Petting Loops",
	animation_states.STAND_UP 		: "Stand Up",
}
var queued_animation_state : StringName = animation_state_names[animation_states.IDLE]
var current_animation_state : StringName
var previous_animation_state : StringName

enum feet {
	FRONT_LEFT,
	FRONT_RIGHT,
	BACK_LEFT,
	BACK_RIGHT
}

const foot_bones := {
	feet.FRONT_LEFT : "DEF_fore_foot-L",
	feet.FRONT_RIGHT : "DEF_fore_foot-R",
	feet.BACK_LEFT : "DEF_hind_foot-L",
	feet.BACK_RIGHT : "DEF_hind_foot-R",
}

# Member variables
@export_category("General")
@export var player : Node3D # The owner node if present
@export var model : Node3D
@export var animation_tree : AnimationTree
@export var skeleton : Skeleton3D
@export var touch_detector : ShapeCast3D
@export var terrain_detector : TerrainDetector
@export_category("ValueSlicers")
@export var RotationSlicerSlow : ValueSlicer
@export var RotationSlicerRegular : ValueSlicer
@export var RotationSlicerFast : ValueSlicer
@export var AngularVelocitySlicer : ValueSlicer
@export var TurningSlicer : ValueSlicer
@export var MovementSpeedSlicer : ValueSlicer
@export var footstep_fx : FootstepFX
@export var sound_effects: ChocomelSFX

# Identification
@onready var interactable_id = Constants.interactable_ids.CHOCOMEL

# Shared player variables
@onready var action_cancel_speed 		: float = player.action_cancel_speed
@onready var max_speed_regular			: float = player.chocomel_speed
@onready var max_speed_pushing 			: float = player.chocomel_speed_pushing
@onready var max_speed_pulling 			: float = player.chocomel_speed_pulling
@onready var rotation_speed				: float = player.chocomel_rotation_speed
@onready var speed_acceleration 		: float = player.chocomel_speed_acceleration
@onready var speed_acceleration_ice 	: float = player.chocomel_speed_acceleration_ice
@onready var rotation_acceleration		: float = player.chocomel_rotation_acceleration
@onready var maximum_leash_length 		: float = player.maxmimum_leash_length
@onready var leash_slowdown_threshold 	: float = player.leash_locking_threshold
@onready var pinda_interaction_distance	: float = player.close_interaction_distance

# Accessible variables for other nodes
@onready var origin_offset_z := model.position.z


func _ready() -> void:
	
	# Inject node link to game state so other nodes can find Chocomel
	Context.chocomel = self
	Context.interactable_nodes[interactable_id] = self
	
	has_moved.connect(_on_position_changed)
	
	# Send initial position
	send_movement_changes()
	
	
	init_animation_tree_parameters()
	
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS


func _physics_process(delta: float) -> void:
	
	terrain_state_entering()
	update_variables()
	set_animation_tree_travel()
	
	# Player Input
	if InputController.action_pressed:
		set_an_action(delta)
	
	# Pre-movement
	state_entering()
	
	# Update wakeup progress. Only move when awake
	if not Context.debug.skip_wake_up:# TODO: remove debug
		if wake_up_progress_time < wake_up_recovery_time:
			wake_up_progress_time += get_physics_process_delta_time()
		if animation_tree.get("parameters/animation states/playback").get_current_node() in ["Sleeping", "Wake Up"]:
			wake_up_progress_time = 0.
	else:
		wake_up_progress_time = wake_up_recovery_time
	
	# Barking
	if started_barking:
		bark_timeout = BARK_TIME
		has_barked.emit()
		# Start bark animations
		animation_tree[
			"parameters/Bark Adding TimeSeek/seek_request"
		] = 0.0
		animation_tree[
			"parameters/Bark Blending TimeSeek/seek_request"
		] = 0.0
	set_animation_tree_paramenters_barking()
	
	# Movement
	if current_character_state != character_states.CINEMATIC:
		movement_logic(delta)

	# Post movement
	check_ongoing_touches()
	state_logic(delta)
	
	# Update animations
	set_procedural_animations()
	
	send_movement_changes()
	
	# Reset flags for next frame
	on_animation_step = false
	interaction_confirmed = false
	pinda_needs_help = false
	started_barking = false
	state_was_forced = false
	touching_pinda = false
	touching_actual_wall = false
	pinda_started_petting = false
	
	# Tick donw timers
	bark_timeout -= delta


## Code that is executed only once upon entering a new state.
func terrain_state_entering() -> void:
	slippery_movement = terrain_detector.current_terrain_state == Constants.terrain_states.ICE

func move_and_slide_custom():
	var collision = move_and_collide(current_velocity * get_process_delta_time(), true)
	var virtual_velocity := current_velocity
	var normal := Vector3.ZERO
	
	# Throttle speed on this frame based on angular velocity
	var turning_speed := remap(
			angular_speed_factor_absolute,
			0.0,
			1.0,
			1.0,
			0.75
		)
	
	velocity = current_velocity * turning_speed
	
	# Increase friction on low input force
	if input_vector.length() <= 0.8:
		wall_min_slide_angle = deg_to_rad(25.0)
	else:
		wall_min_slide_angle = 0.0
	
	#if collision and input_vector.length() <= 0.8:
		#normal = collision.get_normal()
		#if normal.y <= .5:
			## project normal into plane
			#normal = (normal - normal.project(Vector3.UP)).normalized()
			#virtual_velocity -= velocity.project(normal)
			#
			## attenuate velocity based on collision angle
			#var collision_angle = acos((-normal).dot(velocity.normalized()))
			#var angle_min = .1
			#var angle_max = .6
			#if collision_angle < angle_min:
				#velocity = velocity.dot(normal) * normal
			#elif collision_angle < angle_max:
				#var l = (collision_angle - angle_min) / (angle_max - angle_min)
				#velocity = velocity * l**2
	
	# restrain velocity by leash if chocomel is moving away
	if virtual_velocity.dot(last_leash_point_direction) < 0.:
		leash_restrain()
	else:
		slowdown_factor = 0.0
	
	move_and_slide()
	return

## Update the most vital variables for this frame
## before any state changes, actions or movement happens.
func update_variables() -> void:

	input_vector = InputController.movement_vector
	
	# Most important variables for movement
	check_leash_length() 
	
	# Pinda variables
	var pinda_directional_vector := (pinda_position - global_position)
	pinda_distance = pinda_directional_vector.length()
	pinda_direction = pinda_directional_vector.normalized()
	var input3 := Vector3(input_vector.x, 0.0, input_vector.y)
	if input3 != Vector3.ZERO:
		moving_towards_pinda_scalar = input3.normalized().dot(pinda_direction)
	
	# Action conditionals
	interaction_conditions_met = (
			terrain_detector.current_terrain_state != Constants.terrain_states.ICE
			and pinda_distance <= pinda_interaction_distance
			and moving_towards_pinda_scalar >= 0.4
	)


## Update various variables based on the leash distances and points.
func check_leash_length() -> void:
	# TODO: This is not correct. This should use the leash points as well.
	pinda_distance = (pinda_position - global_position).length()
	
	
	if leash_points.size() > 1:
		# The second to last leash point is always the one right before chocomel
		last_leash_point = leash_points[-2]
	else:
		last_leash_point = pinda_position
	
	var input_vector3 := Vector3(input_vector.x, 0.0, input_vector.y)
	last_leash_point_direction = (last_leash_point - global_position).normalized()
	last_leash_point_direction.y = 0.0
	last_leash_point_scalar = input_vector3.normalized().dot(last_leash_point_direction)


## Checking player input to trigger actions like barking and digging.
## These are mostly state changes that are triggered, so this function should be before state_entering().
func set_an_action(_delta : float) -> void:
	
	if current_character_state == character_states.PULLING and bark_timeout <= 0.0:
		bark_timeout = BARK_TIME
		tried_to_bark.emit()
	
	if not interaction_conditions_met:
		# Just bark if possible
		if current_character_state in barking_states and bark_timeout <= 0.0:
			started_barking = true
		return
	
	# Trigger Pinda interactions if availbile
	if pinda_needs_help:
		force_next_character_state(
			character_states.DIG,
			animation_states.DIGGING
		)
		return
	
	elif Context.pinda.current_character_state == Context.pinda.character_states.GETTING_UP:
		if confirm_interaction(interaction_types.SUPERLICK):
			force_next_character_state(
				character_states.INTERACTION,
				animation_states.SUPERLICK
			)
			current_interaction_type = interaction_types.SUPERLICK
			return
	
	elif Context.pinda.current_character_state == Context.pinda.character_states.BREAK_DOWN:
		if confirm_interaction(interaction_types.PETTING):
			force_next_character_state(
				character_states.INTERACTION,
				animation_states.LAY_DOWN
			)
			current_interaction_type = interaction_types.PETTING
			return
	
	elif Context.pinda.mood < 5.0:
		if confirm_interaction(interaction_types.SNUGGLE):
			force_next_character_state(
				character_states.INTERACTION,
				animation_states.SNUGGLE
			)
			current_interaction_type = interaction_types.SNUGGLE
			return
	
	else:
		if confirm_interaction(interaction_types.LICK):
			force_next_character_state(
				character_states.INTERACTION,
				animation_states.LICKING
			)
			current_interaction_type = interaction_types.LICK
			return


## Send a signal to Pinda if licking is currently possible. If a confirmation signal is sent back,
## it meas Pinda started the action and Chocomel can continue with it as well.
## If the interaction is rejected or no singal is sent back, do not start the interaction.
func confirm_interaction(interaction_type : interaction_types) -> bool:
	request_interaction.emit(interaction_type)
	if interaction_confirmed:
		print("Confirmed interation = " + str(interaction_types.keys()[interaction_type]))
		return true
	else:
		print("Denied interation = " + str(interaction_types.keys()[interaction_type]))
		return false


## Set up Chocomels location and orientation so they are perfectly synched up 
## for an animation with Pinda together.
func set_interaction_transform() -> void:
	
	#var pinda_pivot_bone := skeleton.find_bone("Pinda")
	#var pinda_pivot_transform:= skeleton.get_bone_global_pose(pinda_pivot_bone)
	#var pinda_global_pivot_transform : Transform3D = player.pinda.global_transform * pinda_pivot_transform
	
	#global_transform = pinda_global_pivot_transform
	set_rotation_from_vector(pinda_direction)


## Code that is executed only once upon entering a new state.
func state_entering() -> void:
	
	if current_character_state != previous_character_state:
		
		# Set default values first. States can override them if needed
		current_max_speed = max_speed_regular
		
		match current_character_state:
			
			character_states.CINEMATIC:
				# Reset movement_timers
				sitting_time = 0.0
				running_time = 0.0
		
			character_states.IDLE:
				pass
			
			character_states.MOVING:
				pass
			
			character_states.DIG:
				current_max_speed = 0.0
				
				# Reset movement_timers
				digging_timeout = 0.0
				sitting_time = 0.0
				running_time = 0.0
			
			character_states.PULLING:
				current_max_speed = max_speed_pulling
			
			character_states.PUSHING:
				pass
				#current_max_speed = max_speed_pushing
			
			character_states.PUSHING_PINDA:
				current_max_speed = max_speed_pushing
			
			character_states.INTERACTION:
				
				# Reset movement_timers
				sitting_time = 0.0
				running_time = 0.0
				
				if current_interaction_type == interaction_types.LICK:
					set_interaction_transform()
				
				elif current_interaction_type == interaction_types.REWARD:
					set_interaction_transform()
				
				elif current_interaction_type == interaction_types.SUPERLICK:
					set_interaction_transform()
				
				elif current_interaction_type == interaction_types.SNUGGLE:
					set_interaction_transform()
				
				elif current_interaction_type == interaction_types.PETTING:
					set_interaction_transform()
					Context.camera.current_camera_state = Context.camera.camera_states.IDLING
					
					# A little hack to make sure the correct starting animation is played
					sitting_time = 2.0
		
		previous_character_state = current_character_state


## All movement logic with the currently set values and states.
func movement_logic(_delta) -> void:
	
	var input_vector3 := Vector3(input_vector.x, 0, input_vector.y)
	previous_velocity = current_velocity
	
	# If there is no movement or input at all, return early.
	# This helps prevent the near 0 variable calculations from eventually breaking
	var floating_point_minimum := 0.001
	if (
			previous_velocity.length() < floating_point_minimum
			and input_vector3.length() < floating_point_minimum
	):
		return
	
	# Remove player control for some states
	elif current_character_state in [character_states.DIG, character_states.INTERACTION]:
		current_velocity = Vector3.ZERO
		velocity = Vector3.ZERO
		return
	
	
	previous_direction = current_direction
	if previous_velocity != Vector3.ZERO:
		current_direction = new_velocity_direction.normalized()
	var target_direction := input_vector3.normalized()
	current_rotation_to_target_angle_difference = current_direction.signed_angle_to(
			target_direction,
			Vector3.UP
	)
	
	# A factor that can be used to slow the velocity and determine the bending of the body
	angular_speed_factor = remap(current_rotation_to_target_angle_difference, -1.2, 1.2, -1, 1)
	angular_speed_factor = clamp(angular_speed_factor, -1, 1)
	angular_speed_factor_absolute  	= abs(angular_speed_factor)
	angular_speed_factor_sign 	 	= sign(angular_speed_factor)
	
	# Rotate the character at a certain speed. More natural than lerping the direction vectors.
	var target_rotation = clamp(current_rotation_to_target_angle_difference, - rotation_speed, rotation_speed)
	target_direction = current_direction.rotated(
			Vector3.UP,
			target_rotation
	)
	
	# Set the target velocity
	var target_speed := input_vector3.length() * current_max_speed
	var target_velocity = target_direction * target_speed
	
	var new_velocity_length = lerp(
			(previous_velocity * Vector3(1,0,1)).length(),
			target_speed,
			speed_acceleration * _delta
		)
	new_velocity_direction = lerp(
			previous_direction.normalized(),
			target_direction,
			rotation_acceleration * _delta
		).normalized()
	
	# Accelerate to the new velocity
	if not slippery_movement:
		current_velocity = new_velocity_direction * new_velocity_length
	else:
		current_velocity = lerp(current_velocity, target_velocity, speed_acceleration_ice * _delta)
	current_velocity.y = 0.0
	
	# A bit of gravity to stay on the ground
	if not is_on_floor():
		current_velocity.y -= 9.8
	
	# Only move when awake
	if not Context.debug.skip_wake_up:
		current_velocity *= pow(wake_up_progress_time / wake_up_recovery_time, 0.1)
	
	move_and_slide_custom()
	
	# TODO: This function is problematic, since the result may or may not be
	# 		used and overridden by set_character_rotation_to_slice() in the state logic.
	# NOTE: These extra conditions are to prevent rotaiton snapping when waking up
	if current_velocity.length() > 0.0 and wake_up_progress_time > 0.0:
		set_rotation_from_vector(current_direction.normalized())


func leash_restrain():
	
	slowdown_factor = remap(
		leash_length,
		maximum_leash_length - leash_slowdown_threshold,
		maximum_leash_length,
		0.0,
		1.0
	)
	slowdown_factor = clamp(slowdown_factor, 0.0, 1.0)
	
	# Add counter velocity
	var spring_power := .2
	var spring_speed := (leash_length - (maximum_leash_length - leash_slowdown_threshold)) / get_process_delta_time() * spring_power
	spring_speed = max(spring_speed, 0.)
	velocity += last_leash_point_direction * slowdown_factor * spring_speed


func set_rotation_from_vector(global_direction : Vector3) -> void:
	var angle := global_direction.signed_angle_to(Vector3.BACK, Vector3.UP)
	basis = Basis.IDENTITY.rotated(Vector3.UP, -angle)


func check_ongoing_touches() -> void:
	
	touch_detector.trigger_shapecast()
	
	# Ongoing touching objects
	for node in ongoing_touching:
		if node.name == "Pinda":
			touching_pinda = true
		elif "is_physical_object" in node:
			touching_actual_wall = true
	#print("CHECKING ONGOING TOUCHES NR: " + str(Engine.get_frames_drawn()))


## Updating variables and states based on recent changes.
func state_logic(delta : float) -> void:
	
	# A minimum speed for when movement animations should kick in
	var moving_speed := 0.2
	# WARNING: This is a duplicated value in collision interaction and in the same state for Pinda
	var moving_against_pinda := moving_towards_pinda_scalar > 0.8
	var pinda_not_walking := pinda_velocity.length() <= 2.1
	# Used for pushing
	var at_moving_input := (input_vector.length() * max_speed_regular) >= moving_speed
	var at_moving_velocity := velocity.length() >= moving_speed
	
	var input_vector3 := Vector3(input_vector.x, 0.0, input_vector.y)
	var correct_direction_factor := velocity.normalized().dot(input_vector3.normalized())
	correct_direction_factor = clamp(correct_direction_factor, 0.0, 1.0)
	var scalar_velocity := velocity.length() * correct_direction_factor
	var at_pushing_velocity : bool = (scalar_velocity / max_speed_pushing) >= (input_vector.length() * 0.90)
	
	var leash_secured := Context.leash.current_leash_handle_state == Context.leash.leash_handle_states.SECURED
	
	match current_character_state:
		
		character_states.CINEMATIC:
			
			if at_moving_input and queued_animation_state == animation_state_names[animation_states.SLEEPING]:
				queue_next_character_state(
					character_states.CINEMATIC,
					animation_states.WAKING
				)
			elif current_animation_state == animation_state_names[animation_states.WAKING]:
				if animation_state_finished:
					queue_next_character_state(
						character_states.IDLE,
						animation_states.IDLE
					)
		
		character_states.IDLE:
			
			count_sitting_running_time()
			
			if at_moving_input and touching_pinda and moving_against_pinda:
				queue_next_character_state(
					character_states.PUSHING_PINDA,
					animation_states.PUSHING_PINDA
				)
			elif at_moving_input and not at_pushing_velocity and touching_actual_wall:
				queue_next_character_state(
					character_states.PUSHING,
					animation_states.PUSHING
				)
			elif at_moving_input and slowdown_factor > 0.0 and (pinda_not_walking or leash_secured):
				queue_next_character_state(
					character_states.PULLING,
					animation_states.PULLING
				)
			elif at_moving_velocity:
				queue_next_character_state(
					character_states.MOVING,
					animation_states.MOVING
				)
			
			set_character_rotation_to_slice(delta)
		
		character_states.MOVING:
			
			count_sitting_running_time()
			
			if at_moving_input and touching_pinda and moving_against_pinda:
				queue_next_character_state(
					character_states.PUSHING_PINDA,
					animation_states.PUSHING_PINDA
				)
			elif at_moving_input and not at_pushing_velocity and touching_actual_wall:
				queue_next_character_state(
					character_states.PUSHING,
					animation_states.PUSHING
				)
			elif at_moving_input and slowdown_factor > 0.0 and (pinda_not_walking or leash_secured):
				queue_next_character_state(
					character_states.PULLING,
					animation_states.PULLING
				)
			elif not at_moving_velocity:
				queue_next_character_state(
					character_states.IDLE,
					animation_states.IDLE
				)
			
			set_character_rotation_to_slice(delta)
			set_animation_tree_paramenters_moving()
		
		character_states.DIG:
			digging_timeout += delta
			
			set_rotation_from_vector(pinda_direction)
			
			if InputController.action_pressed:
				digging_timeout = 0.0
			elif digging_timeout >= 1.0:
				queue_next_character_state(
					character_states.IDLE,
					animation_states.IDLE
				)
			
			if interaction_conditions_met and pinda_needs_help:
				has_been_digging.emit()
			else:
				queue_next_character_state(
					character_states.IDLE,
					animation_states.IDLE
				)
		
		character_states.PULLING:
			
			count_sitting_running_time()
			
			if not at_moving_input:
				queue_next_character_state(
					character_states.IDLE,
					animation_states.IDLE
				)
			elif slowdown_factor <= 0.0 or not (pinda_not_walking or leash_secured):
				queue_next_character_state(
					character_states.MOVING,
					animation_states.MOVING
				)
			
			set_character_rotation_to_slice(delta)
			set_animation_tree_paramenters_pulling()
		
		character_states.PUSHING:
			
			count_sitting_running_time()
			
			if not at_moving_input:
				queue_next_character_state(
					character_states.IDLE,
					animation_states.IDLE
				)
			elif not touching_actual_wall or at_pushing_velocity:
				queue_next_character_state(
					character_states.MOVING,
					animation_states.MOVING
				)
			
			set_character_rotation_to_slice(delta)
			set_animation_tree_paramenters_pushing()
		
		character_states.PUSHING_PINDA:
			
			count_sitting_running_time()
			
			# NOTE: I'm not checking for "touching_pinda" here because it's easy to lose touch while moving
			if not at_moving_input:
				queue_next_character_state(
					character_states.IDLE,
					animation_states.IDLE
				)
			elif not moving_against_pinda or (pinda_position - global_position).length() >= 1.0:
				queue_next_character_state(
					character_states.MOVING,
					animation_states.MOVING
				)
			
			set_rotation_from_vector(pinda_direction)
			set_character_rotation_to_slice(delta)
			set_animation_tree_paramenters_pushing_pinda()
		
		character_states.INTERACTION:
			
			if current_interaction_type == interaction_types.PETTING:
				set_animation_tree_paramenters_petting()
				
				# Switch to next animation when it's done
				if current_animation_state == animation_state_names[animation_states.LAY_DOWN] and pinda_started_petting:
					queue_next_character_state(
						character_states.INTERACTION,
						animation_states.PETTING_LOOPS
					)
					return
				
				var cancelable = (
					current_animation_state == animation_state_names[animation_states.PETTING_LOOPS]
					and input_vector.length() >= action_cancel_speed
				)
				
				if cancelable:
					Context.camera.current_camera_state = Context.camera.camera_states.FOLLOW
					queue_next_character_state(
						character_states.IDLE,
						animation_states.IDLE
					)
					ended_interaction.emit()
			
			else:
				# Set the moment where the animation & action can be canceled out of early
				var cancel_time := 10.0
				if current_interaction_type == interaction_types.LICK:
					cancel_time = 0.7
				elif current_interaction_type == interaction_types.SUPERLICK:
					cancel_time = 1.0
				
				var cancelable := (
					current_animation_position >= cancel_time
					and input_vector.length() >= action_cancel_speed
				)
				if animation_state_finished or cancelable:
					force_next_character_state(
						character_states.IDLE,
						animation_states.IDLE
					)


func set_character_rotation_to_slice(delta : float) -> void:
	
	current_angular_velocity_slice = AngularVelocitySlicer.get_snapped_slice(
		abs(current_rotation_to_target_angle_difference),
		current_angular_velocity_slice
	)
	
	# Choose an active rotation slicer with more or fewer total slices.
	# This helps make rotations look better depending on the angular velocity
	var active_rotation_slicer : ValueSlicer
	
	if current_angular_velocity_slice > 3:
		active_rotation_slicer = RotationSlicerFast
	elif current_angular_velocity_slice > 0:
		active_rotation_slicer = RotationSlicerRegular
	else:
		active_rotation_slicer = RotationSlicerSlow
	
	var directional_angle := basis.z.signed_angle_to(Vector3.BACK, Vector3.UP)
	var slice_size := active_rotation_slicer._slice_size
	var rotation_slice_offset := -slice_size * 0.5
	
	# Only update the rotation slice if synced with the playing animation stepping
	if on_animation_step:
		current_rotation_slice = active_rotation_slicer.get_snapped_slice(
			directional_angle + rotation_slice_offset,
			current_rotation_slice
		)
		# Set the rotation slices
		var rotation_start_offset = PI
		current_slice_rotation = (slice_size * (current_rotation_slice+1)) + rotation_start_offset + rotation_slice_offset
	
	rotation = Vector3(0.0, -current_slice_rotation, 0.0)


## Transformation of procedural bones like the leash collar bone
func set_procedural_animations() -> void:
	
	var collar_bone_idx = skeleton.find_bone("GDT-leash_rotation")
	var collar_bone_local_transform : Transform3D = skeleton.get_bone_global_pose(collar_bone_idx)
	var new_collar_bone_transform : Transform3D = collar_bone_local_transform.looking_at(last_leash_point_direction, Vector3.UP)
	
	var local_rotation := self.basis.get_euler().y
	new_collar_bone_transform = new_collar_bone_transform.rotated_local(Vector3.UP, -local_rotation)
	
	skeleton.set_bone_global_pose(collar_bone_idx, new_collar_bone_transform)


## Check if the state machine queued the next character and animation state. 
## Then travel to the next animation state. If aniamtion state started playing,
## set the new current_character_state.
## This should happen at the end of the frame, so the first frame of the new
## character state has more pivot bone information availible.
func set_animation_tree_travel() -> void:
	var tree_playback : AnimationNodeStateMachinePlayback = animation_tree["parameters/animation states/playback"]
	# TODO: SHould the current state also be set at the end of this function?
	#		Otherwise it already traveled to a new state which is outdated in this variable.
	previous_animation_state = current_animation_state
	current_animation_state = tree_playback.get_current_node()
	previous_animation_position = current_animation_position
	current_animation_position = tree_playback.get_current_play_position()
	current_animation_length = tree_playback.get_current_length()
	
	var new_animation_is_set : bool = queued_animation_state != current_animation_state
	
	# If no character state is queued it must mean the new state should instantly start
	if new_animation_is_set and queued_character_state == -1:
		tree_playback.start(queued_animation_state)
	# But if queued, wait until animation finished.
	# TODO: This should not be spammed each frame. May lead to bugs!
	elif new_animation_is_set:
		tree_playback.travel(queued_animation_state)
	# Otherwise the switch must be done and the queue can be reset
	else:
		if queued_character_state != -1:
			current_character_state = queued_character_state
			queued_character_state = -1
	
	# Update context variables for state logic and animation parameters
	animation_state_changed = previous_animation_state != queued_animation_state
	animation_state_finished = current_animation_position == current_animation_length
	animation_started = current_animation_position < previous_animation_position
	animation_looped = animation_started and not animation_state_changed


## Set the next character state and queue the next animation state to play.
## If there is already an animation state queued, then cancel the process.
## The next character state will only switch once the queued animation state starts.
func queue_next_character_state(next_character_state : character_states, next_animation_state : animation_states) -> void:
	if queued_character_state != -1:
		return
	
	if state_was_forced:
		print("WARNING! The character state was already forced previously during this frame!")
		print("This animation state was attempted to be queued = " + str(animation_states.keys()[next_animation_state]))
		return
	
	queued_character_state = next_character_state
	queued_animation_state = animation_state_names[next_animation_state]

## Use when the character state needs to be set immediately, regardless of the animation
func force_next_character_state(new_character_state : character_states, new_animation_state : animation_states) -> void:
	# clear queue to avoid undoing change
	queued_character_state = -1
	
	current_character_state = new_character_state
	queued_animation_state = animation_state_names[new_animation_state]


## Force start the animation state instead of putting it in the queue.
func force_next_animation(anim : String) -> void:
	queued_animation_state = anim
	
	var tree_playback : AnimationNodeStateMachinePlayback = animation_tree["parameters/animation states/playback"]
	tree_playback.start(anim)


func init_animation_tree_parameters() -> void:
	
	# Skip bark animation on game start
	animation_tree[
		"parameters/Bark Adding TimeSeek/seek_request"
		] = 1.0
	animation_tree[
		"parameters/Bark Blending TimeSeek/seek_request"
		] = 1.0
	
	# Make sure that the bending is possible
	animation_tree[
		"parameters/animation states/Moving/adding_bend/add_amount"
		] = 1.0


## General function to get the a factor of how much the velocity matches the max speed.
func get_directional_speed_factor() -> float:
	
	# Avoids calucaltion and bugs
	if current_max_speed <= 0.0:
		return 0.0
	
	var directional_speed := velocity.length()
	var directional_speed_factor := remap(directional_speed, 0.0, current_max_speed, 0.0, 1.0)
	directional_speed_factor = clamp(directional_speed_factor, 0.0, 1.0)
	
	return directional_speed_factor


## Update the current_movement_type to either Walk, Trot or Run 
func set_movement_speed_type(directional_speed_factor : float) -> void:
	
	current_movement_speed_slice = MovementSpeedSlicer.get_snapped_slice(
		directional_speed_factor,
		current_movement_speed_slice
	)
	
	if current_movement_speed_slice >= 14:
		current_movement_type = movement_types.RUN
	elif current_movement_speed_slice >= 5:
		current_movement_type = movement_types.TROT
	else:
		current_movement_type = movement_types.WALK 


## Get a factor for the animation speed scale. The function returns the correct
## factor for the current character state.
func get_anim_speed_scale(directional_speed_factor : float) -> float:
	
	if current_character_state == character_states.PULLING:
		var movement_speed_in := 0.05
		var movement_speed_out := 0.5 # Pulling generally never goes further than 0.7 of the speed
		var anim_scale := remap(
				directional_speed_factor,
				movement_speed_in,
				movement_speed_out,
				0.2,
				1.0
		)
		anim_scale = clamp(anim_scale, 0.0, 1.0)
		
		return anim_scale
	
	elif (
		current_character_state == character_states.PUSHING
		or current_character_state == character_states.PUSHING_PINDA
	):
		# TODO: Doesn't work yet with using the directional_speed_factor,
		#		Needs access to an input velocity factor.
		return 1.0
	
	elif (current_character_state == character_states.MOVING):
		var anim_scale := 1.
		match current_movement_type:
			movement_types.WALK:
				anim_scale = velocity.length() / .85
		return anim_scale
	
	return 1.0


func count_sitting_running_time() -> void:
	var delta := get_physics_process_delta_time()
	
	if current_velocity.length() >= 0.1:
		sitting_time = 0.0
	else:
		sitting_time += delta
	if (velocity.length() / max_speed_regular) >= 0.8:
		running_time += delta
	else:
		running_time = 0.0


func set_animation_tree_paramenters_barking() -> void:
	var bark_positon : float = animation_tree["parameters/bark anim adding/current_position"]
	var bark_length : float = animation_tree["parameters/bark anim adding/current_length"]
	
	var bark_factor := 0.0
	if bark_positon < bark_length:
		bark_factor = 1.0
	
	animation_tree[
		"parameters/Bark Adding/add_amount"
	] = bark_factor
	animation_tree[
		"parameters/Bark Blending/blend_amount"
	] = bark_factor



func set_animation_tree_paramenters_moving() -> void:
	
	# Start with choosing the general movement animation
	var directional_speed_factor := get_directional_speed_factor()
	
	set_movement_speed_type(directional_speed_factor)
	
	var movement_speed_blend : float
	if current_movement_type == movement_types.RUN:
		movement_speed_blend = 1.0
	elif current_movement_type == movement_types.TROT:
		movement_speed_blend = 0.5
	elif current_movement_type == movement_types.WALK:
		movement_speed_blend = 0.0
		
	animation_tree[
		"parameters/animation states/Moving/movement_speed/blend_position"
		] = movement_speed_blend
	animation_tree[
		"parameters/animation states/Moving/movement_speed_scale/scale"
		] = get_anim_speed_scale(directional_speed_factor)
	
	
	var total_range := TurningSlicer._range_size
	
	# Only update the bending of chocomel if the rotation has changed
	# or a certain time has passed.
	
	# Set current turing  slice
	if on_animation_step:
		current_turning_slice = TurningSlicer.get_snapped_slice(
			angular_speed_factor_absolute,
			current_turning_slice
		)
	
	var snapped_angular_factor : float
	snapped_angular_factor = (current_turning_slice) * TurningSlicer._slice_size
	
	# NOTE: Only used while moving
	# Turning animation adding
	var left_to_right_factor := remap(-angular_speed_factor_sign, -1, 1, 0, 1)
	animation_tree[
		"parameters/animation states/Moving/is_right/blend_amount"
	] = left_to_right_factor
	animation_tree[
		"parameters/animation states/Moving/bending_factor/seek_request"
	] = snapped_angular_factor


func set_animation_tree_paramenters_pushing() -> void:
	
	var directional_speed_factor := get_directional_speed_factor()
	
	animation_tree[
		"parameters/animation states/Pushing/Time Scale/scale"
	] = get_anim_speed_scale(directional_speed_factor)


func set_animation_tree_paramenters_pushing_pinda() -> void:
	
	var directional_speed_factor := get_directional_speed_factor()
	
	animation_tree[
		"parameters/animation states/Pushing Pinda/Speed Scale/scale"
	] = get_anim_speed_scale(directional_speed_factor)


func set_animation_tree_paramenters_pulling() -> void:
	
	var directional_speed_factor := get_directional_speed_factor()
	
	animation_tree[
		"parameters/animation states/Pulling/Time Scale/scale"
	] = get_anim_speed_scale(directional_speed_factor)


func set_animation_tree_paramenters_petting() -> void:
	
	# Set Lay Down version
	var stand_sit_factor := 1.0
	if sitting_time >= 2.0:
		stand_sit_factor = 0.0
	
	animation_tree[
		"parameters/animation states/Lay Down/blend_position"
	] = stand_sit_factor
	
	# Restart petting loops and set new random petting animation
	if animation_state_finished and current_animation_state == animation_state_names[animation_states.PETTING_LOOPS]:
		animation_tree[
			"parameters/animation states/Petting Loops/TimeSeek/seek_request"
		] = 0.0
		petting_version_value = randf()
		set_new_petting_loop.emit(petting_version_value)
	
	animation_tree[
		"parameters/animation states/Petting Loops/Petting Loops BlendSpace1D/blend_position"
	] = petting_version_value


## Emit the new position and other variables
func send_movement_changes() -> void:
	
	# Send collar bone global position
	var collar_pivot_bone_idx : int = skeleton.find_bone("GDT-leash_point")
	var collar_pivot_transform : Transform3D = skeleton.get_bone_global_pose(collar_pivot_bone_idx)
	collar_pivot_transform = self.global_transform * collar_pivot_transform
	
	has_moved.emit(
		global_position,
		current_velocity,
		last_leash_point_scalar,
		moving_towards_pinda_scalar,
		collar_pivot_transform.origin
	)

func footstep(foot1 : feet, foot2 : feet = -1, foot3 : feet = -1, foot4 : feet = -1):
	if terrain_detector.current_terrain_state != Constants.terrain_states.NONE:
		return
	for f in [foot1, foot2, foot3, foot4]:
		if f == -1:
			continue
		var foot_transform := skeleton.get_bone_global_pose(skeleton.find_bone(foot_bones[f]))
		footstep_fx.add_footstep(
			(skeleton.global_transform * foot_transform).origin,
			self.current_direction
		)

# NOTE: Signal functions

func _on_position_changed(
		new_position: Vector3,
		current_velocity : Vector3,
		last_leash_point_scalar : float,
		moving_to_pinda_scalar : float,
		collar_bone_position : Vector3
	):
	RenderingServer.global_shader_parameter_set("chocomel_position", new_position)

func _on_pinda_has_moved(
		_new_position: Vector3,
		_current_velocity : Vector3,
	) -> void:
	pinda_position = _new_position
	pinda_velocity = _current_velocity


func _on_leash_changed_leash_points(points: PackedVector3Array, length: float) -> void:
	leash_points = points
	leash_length = length


## Track what Chocomel is ongoingly touching
func _on_touch_detector_body_entered(body: Node3D) -> void:
	
	#print("OLD TOUCH DETECTOR ENTERED NR: " + str(Engine.get_frames_drawn()))
	
	ongoing_touching.append(body)
	#print("Detected touch = " + str(body.name))


## Check what Chocomel is no longer touching
func _on_touch_detector_body_exited(body: Node3D) -> void:
	
	#print("OLD TOUCH DETECTOR EXITED NR: " + str(Engine.get_frames_drawn()))
	
	ongoing_touching.erase(body)
	#print("Exited touch = " + str(body.name))


func _on_pinda_call_for_help() -> void:
	pinda_needs_help = true
	

## Pinda requested an interaction. 
## Check if this is possible on Chocomel and signal back a confirmation or denial.
func _on_pinda_request_interaction(interaction: int) -> void:
	
	if interaction == Context.pinda.interaction_types.CHOCOMEL_REWARD:
		
		var conditions_met := (
			current_velocity.length() <= current_max_speed * 0.75
			and pinda_distance <= pinda_interaction_distance
		)
		
		if conditions_met:
			confirmed_interaction.emit(true)
			force_next_character_state(
				character_states.INTERACTION,
				animation_states.REWARD
			)
			current_interaction_type = interaction_types.REWARD
		else:
			confirmed_interaction.emit(false)
	
	elif interaction == Context.pinda.interaction_types.PETTING:
		
		confirmed_interaction.emit(true)
		force_next_character_state(
			character_states.INTERACTION,
			animation_states.LAY_DOWN
		)
		current_interaction_type = interaction_types.PETTING


## Pinda has confirmed or denied the interaction.
func _on_pinda_confirmed_interaction(confirmation : bool) -> void:
	interaction_confirmed = confirmation


func _on_pinda_started_petting_loops() -> void:
	pinda_started_petting = true


func _on_animation_tree_mixer_applied() -> void:
	# Check if the current_animation is on the frame step
	var prev_frame_time_modulo = frame_time_modulo
	frame_time_modulo = fmod(current_animation_position, FRAME_TIME)
	if prev_frame_time_modulo > frame_time_modulo:
		on_animation_step = true
