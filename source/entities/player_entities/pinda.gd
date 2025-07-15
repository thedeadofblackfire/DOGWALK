extends CharacterBody3D

class_name Pinda

signal has_moved(
	new_position : Vector3,
	current_velocity : Vector3,
	)
signal call_for_help()
signal request_interaction(interaction_type : int)
signal confirmed_interaction(confirmation : bool)
signal reached_point_of_interest(point_of_interest_interaction_id : int)
signal exiting_character_state(character_state : int)
signal entering_character_state(character_state : int)
signal started_petting_loops()
signal updated_bone_transforms()
signal updated_hand_transform(hand_transform: Transform3D)

# States depending on speed and interactions
enum character_states {
	IDLE,
	SLIDING,
	SEEKING,
	CATCHING_UP,
	WALKING_TO_CHOCOMEL,
	AT_LEASH_END,
	PULLING,
	STUCK,
	GETTING_UP,
	PUSHED,
	BREAK_DOWN,
	INTERACTION,
	CINEMATIC,
	GATE,
}
enum idle_types {
	ANNOUNCE_DISCOVERY,
	ANNOUNCE_INTERACTION,
	BARK_REACTION,
	WAITING,
	CALL_FOR_HELP,
	CATCH_A_BREATH,
}
enum break_down_types {
	CRYING,
	MOPING,
}
enum interaction_types {
	ITEM_PICKUP,
	SNOWMAN_DECORATING,
	CHOCOMEL_LICK,
	CHOCOMEL_SUPERLICK,
	SNUGGLE,
	PETTING,
	CHOCOMEL_REWARD,
	GRAB_TRAFFIC_CONE,
	}

const ROCK_BOTTOM_MOOD := 1.5
const DANGER_PULL_FACTOR := 0.8
const BREAKDOWN_ANGLE := deg_to_rad(40)
const TRAFFIC_CONE_GRAB_SPEED := 3.0
const IDLE_TOGETHER_START := 8.0

## Thesholds to dragging_distance of leash_length when pulling starts.
## Basically constants that are not meant to be edited.
var ground_pull_thresholds := {
	"road" 		: 0.7,
	"ground" 	: 0.8,
	"snow" 		: 0.9,
	"ice" 		: 0.8
}

# States and other modes
var current_character_state 	:= character_states.CATCHING_UP:
	get():
		return current_character_state
	set(new_character_state):
		if current_character_state != new_character_state:
			emit_signal("exiting_character_state", current_character_state)
			emit_signal("entering_character_state", new_character_state)
		current_character_state = new_character_state
var previous_character_state	:= character_states.CATCHING_UP
var queued_character_state 		: character_states = -1
var queued_transform 			:= Transform3D.IDENTITY # For setting the transform when entering the state
var state_was_forced := false
var current_idle_type 			:= idle_types.BARK_REACTION
var current_break_down_type		:= break_down_types.CRYING
var current_interaction_type 	:= interaction_types.ITEM_PICKUP
var previous_interaction_type 	: interaction_types = -1
var interaction_confirmed := false
var interaction_ended := false
var chocomel_did_digging := false
var colliding_with_traffic_cone := false
# When collecting the traffic cone, the reward is given once off the ice
var queued_reward := false

# Character state variables
var skip_movement : bool
var state_pull_effectiveness : float
var procedural_arm_movement : bool # If the left arm is dynamically pointing along the leash
var sliced_rotation : bool

# Terrain state variables
var current_walking_speed : float
var pull_threshold : float
var terrain_friction : float
var terrain_pull_cap : float
var maximum_pushing_speed : float
var maximum_walking_speed : float

# Timers to transition character states
const CONTINUE_SEEKING_TIMER_START = 1.0
var continue_seeking_timer := 0.0:
	set(value):
		continue_seeking_timer = clamp(value, 0.0, CONTINUE_SEEKING_TIMER_START)
const CONTINUE_REWARD_TIMER_START = 2.0
var continue_reward_timer := 0.0:
	set(value):
		continue_reward_timer = clamp(value, 0.0, CONTINUE_REWARD_TIMER_START)
const REMEMBER_REWARD_TIMER_START = 20.0
var remember_reward_timer := 0.0:
	set(value):
		remember_reward_timer = clamp(value, 0.0, REMEMBER_REWARD_TIMER_START)
const WAITING_TIMER_START = 8.0
var waiting_timer := WAITING_TIMER_START:
	set(value):
		waiting_timer = clamp(value, 0.0, WAITING_TIMER_START)
const MAX_STATIONARY_TIME := 1.0
var stationary_timer := 0.0:
	set(value):
		stationary_timer = clamp(value, 0.0, MAX_STATIONARY_TIME)


# Track movement targets
var goal_point := Vector3.ZERO # overall goal pinda is trying to move to
var goal_point_distance := 0.0
var target_point := Vector3.ZERO # next target pinda is trying to reach on their way to the goal
var movement_target_position := Vector3.ZERO # next immediate target pinda is moving towards
var prev_movement_target_position : Vector3
var movement_target_direction : Vector3
var movement_target_distance : float

# Movement variables
enum movement_types {IDLE, WALK, RUN, RUN_DRAGGED}
var current_movement_type = movement_types.IDLE
var new_velocity := Vector3.ZERO
var current_velocity := Vector3.ZERO
var previous_velocity := Vector3.ZERO
var pull_factor : float
var holding_leash : bool

# Shapecast variables for obstacle avoidance
var shapecast_collision : Node3D
var shapecast_collision_point : Vector3
var shapecast_collision_distance := 20.0 # Arbitrary high value
var shapecast_collision_normal : Vector3

# Tracking of ongoing collisions instead of only the initial collision
var ongoing_touching := []
var touching_chocomel : bool
var touching_actual_wall : bool

# Chocomel variables
var chocomel_position := Vector3.ZERO
var chocomel_velocity := Vector3.ZERO
var current_velocity_against_chocomel := Vector3.ZERO
var chocomel_direction := Vector3.ZERO
var next_leash_point_scalar := 0.0 # How much chocomel is retracting/extending the leash 
var chocomel_moving_to_pinda_scalar := 0.0

# Leash variables
var leash_length := 0.0
var leash_length_change := 0.0 # WARNING: Be careful with dependency cycles when using this for speed
var leash_limit_reached : bool
var leash_limit_just_reached := false
var leash_corner_points : PackedVector3Array
var leash_nearest_point := Vector3.ZERO

# Leash corner point target
var nearest_leash_point_position := Vector3.ZERO
var nearest_leash_point_direction := Vector3.ZERO
var nearest_leash_point_distance := 0.0

# Item and point of interest variables
var next_decoration_item : Constants.interactable_ids
var current_point_of_interest : Node3D
var previous_point_of_interest : Node3D # Eventually important for not picking the same point next
var point_of_interest_interaction_id : int
var point_of_interest_item_id : int
var point_of_interest_location := Vector3.ZERO
var reward_init_location := Vector3.ZERO

# Animation variables
const EMOTE_DURATION := 2.5

var animation_finished : bool
var animation_state_changed : bool
var animation_state_finished : bool
var animation_started : bool
var animation_looped : bool
var current_animation_position : float
var previous_animation_position : float
var current_animation_length : float
var current_rotation_slice := 1
var current_arm_rotation_slice := 1
var current_pull_blend_slice := 1
var current_walking_speed_slice := 1
var current_arm_rotation_y := 0.0
var petting_version_value := 0.0

# For checking if the current frame is synced with the animation stepping
const FRAME_TIME := 1.0 / 12.0
var frame_time_modulo := 0.0
var on_animation_step := false

# List of animation states
enum animation_states {
	REGULAR,
	ON_ICE,
	STUCK,
	GETTING_UP,
	DECORATING,
	PICK_UP,
	BARK_REACT,
	CALLING_OUT,
	WAITING,
	LICKED,
	SNUGGLE,
	SUPERLICK,
	REWARD,
	PUSHED,
	PULLING,
	CRYING,
	MOPING,
	BUILDING,
	THINKING,
	ATTACH_BRANCH,
	DETACH_POINT,
	# Gate
	INSPECTING_SPOT1,
	INSPECTING_SPOT2,
	INSPECTING_SPOT3,
	OPENING_SPOT3,
	MOVING_THROUGH_FENCE,
	FALLEN_THROUGH_FENCE,
	UNLOCKING_GATE,
	GATE_OPEN,
	# Pond
	GRAB_TRAFFIC_CONE,
	PULL_TRAFFIC_CONE,
	CATCH_A_BREATH,
	# Petting
	LAY_DOWN,
	TURN,
	PETTING_LOOPS,
	STAND_UP,
}
var animation_state_names : Dictionary = {
	animation_states.REGULAR 	: "Seeking and Catching Up",
	animation_states.ON_ICE 	: "Ice Movement",
	animation_states.STUCK 		: "Stuck",
	animation_states.GETTING_UP : "Getting Up",
	animation_states.DECORATING : "Decorating Snowman",
	animation_states.PICK_UP 	: "Pick Up",
	animation_states.BARK_REACT : "Bark React",
	animation_states.CALLING_OUT: "Calling Out",
	animation_states.WAITING 	: "Waiting",
	animation_states.LICKED 	: "Licking Pinda",
	animation_states.SNUGGLE 	: "Snuggle",
	animation_states.SUPERLICK 	: "Superlick",
	animation_states.REWARD		: "Reward",
	animation_states.PUSHED 	: "Pushed",
	animation_states.PULLING	: "Pulling",
	animation_states.CRYING		: "Crying",
	animation_states.MOPING		: "Moping",
	animation_states.BUILDING	: "Building",
	animation_states.THINKING	: "Thinking",
	animation_states.ATTACH_BRANCH	: "Attach Branch",
	animation_states.DETACH_POINT : "Detach and Point",
	# Gate
	animation_states.INSPECTING_SPOT1 	: "Check Spot 1",
	animation_states.INSPECTING_SPOT2 	: "Check Spot 2",
	animation_states.INSPECTING_SPOT3 	: "Check Spot 3",
	animation_states.OPENING_SPOT3 		: "Lift Plank",
	animation_states.MOVING_THROUGH_FENCE : "Move Through Fence",
	animation_states.FALLEN_THROUGH_FENCE : "Fallen Through Fence",
	animation_states.UNLOCKING_GATE : "Unlock Gate",
	animation_states.GATE_OPEN 		: "Open Gate",
	# Pond
	animation_states.GRAB_TRAFFIC_CONE 	: "Grab Traffic Cone",
	animation_states.PULL_TRAFFIC_CONE 	: "Pull Traffic Cone",
	animation_states.CATCH_A_BREATH 	: "Catch a Breath",
	# Petting
	animation_states.LAY_DOWN 		: "Lay Down",
	animation_states.TURN 			: "Turn",
	animation_states.PETTING_LOOPS 	: "Petting Loops",
	animation_states.STAND_UP 		: "Stand Up",
}
var queued_animation_state : StringName = animation_state_names[animation_states.REGULAR]
var current_animation_state : StringName 
var previous_animation_state : StringName

# To be changed when pikcing up or letting go of the traffic cone
var pompom_scale_down_factor  := 0.0
var lay_down_type_factor := 0.0

# Add new pick up animation states here
const pick_up_animations : Dictionary = {
	Constants.interactable_ids.BRANCH		: "Branch Pick Up",
	Constants.interactable_ids.TENNIS_BALL	: "Tennis Ball Pick Up",
	Constants.interactable_ids.TRAFFIC_CONE	: "Traffic Cone Pick Up",
	Constants.interactable_ids.SHOVEL	: "Shovel Pick Up",
}

# Info on the last collision. Used for impact on stamina.
var just_touched_chocomel := false
var collision_normal := Vector3.ZERO
var collision_angle_scalar := 0.0

# foot info
enum feet {
	LEFT,
	RIGHT
}

const foot_bones := {
	feet.LEFT : "DEF_foot-L",
	feet.RIGHT : "DEF_foot-R"
}

# Mood variables
const MAX_MOOD = 10.0
const MAX_MOOD_DEBUG = 4.0
var mood := MAX_MOOD:
	set(value):
		# Pinda is invincible while permanently in the gate challenge
		var in_gate_challenge := false
		if Context.sequence_gate == null:
			# This check is just so it doesn't access variable on null
			pass
		elif Context.sequence_gate.active_sequence:
			in_gate_challenge = true
		
		# TODO: Remove the debug value later after testing is done
		if Context.debug.always_happy or in_gate_challenge:
			mood = MAX_MOOD_DEBUG if GameStatus.debug_low_mood else MAX_MOOD
		else:
			if GameStatus.debug_low_mood:
				mood = clamp(value, 0.0, MAX_MOOD_DEBUG)
			else:
				mood = clamp(value, 0.0, MAX_MOOD)
var previous_mood := MAX_MOOD

# Stamina variables
const STAMINA_MAX = 10.0
const STAMINA_MAX_DEBUG = 4.0
var stamina := STAMINA_MAX:
	get:
		return stamina
	set(value):
		# TODO: Remove the debug value later after testing is done
		if Context.debug.always_fast:
			stamina = STAMINA_MAX_DEBUG if GameStatus.debug_low_stamina else STAMINA_MAX
		else:
			if GameStatus.debug_low_stamina:
				stamina = clamp(value, 0.0, STAMINA_MAX_DEBUG)
			else:
				stamina = clamp(value, 0.0, STAMINA_MAX)
var previous_stamina := STAMINA_MAX
var stamina_improved := false

# Other animation variables
var bone_snapping_targets : Dictionary
var left_hand_bone_global_transform : Transform3D

var tennis_ball_id = Constants.interactable_ids.TENNIS_BALL
var traffic_cone_id = Constants.interactable_ids.TRAFFIC_CONE
var shovel_id = Constants.interactable_ids.SHOVEL

# Member variables
@export var player : Node3D # The owner node if present
@export var character_asset : Node3D
@export var skeleton : Skeleton3D
@export var collision_shape : CollisionShape3D
@export var shapecast_obstacles : ShapeCast3D
@export var touch_detector : ShapeCast3D
@export var emote_bubbles : EmoteBubble
@export var item_detector : Area3D
@export var terrain_detector : TerrainDetector
@export var animation_player : AnimationPlayer
@export var animation_tree : AnimationTree
@export var character_rotation_slicer : ValueSlicer
@export var arm_rotation_slicer : ValueSlicer
@export var pull_blend_slicer : ValueSlicer
@export var walking_speed_slicer : ValueSlicer
@export var footstep_fx : FootstepFX
@export var sound_effects : PindaSFX
# This one will be created on ready
@onready var procedural_animator : ProceduralAnimator 

# Debug shapes
@export var debug_direction : Node3D
@export var debug_position : Node3D

# GameStatus Info
@onready var interactable_id := Constants.interactable_ids.PINDA

# Shared player variables
# Maximum walking speed for different terrain
@onready var speed_walk_ground 			: float = player.pinda_walk_speed_ground
@onready var speed_walk_snow 			: float = player.pinda_walk_speed_snow
@onready var speed_walk_ice 			: float = player.pinda_walk_speed_ice
# Maximum pull speed for for different terrain
@onready var pull_cap_regular 			: float = player.pinda_pull_cap_regular
@onready var pull_cap_snow 				: float = player.pinda_pull_cap_snow
@onready var pull_cap_ice 				: float = player.pinda_pull_cap_ice
# Leash and distance variables
@onready var maximum_leash_length 		: float = player.maxmimum_leash_length
@onready var dragging_distance 			: float = maximum_leash_length - player.leash_locking_threshold
@onready var catching_up_distance 		: float = player.catching_up_distance
@onready var close_interaction_distance : float = player.close_interaction_distance
# Chocomel variables
@onready var chocomel_speed 			: float = player.chocomel_speed
@onready var chocomel_pushing_speed_ground : float = player.chocomel_pushing_speed_ground
@onready var chocomel_pushing_speed_snow : float = player.chocomel_pushing_speed_snow
# Needed force to make Pinda instantly fall.
# Total velocity difference between pinda and Chocomel to make the kid fall
@onready var yank_fall_force 			: float = player.yank_fall_force
# Recovery over time
@onready var stamina_recovery_regular 	: float = player.stamina_recovery_regular
@onready var stamina_recovery_stationary: float = player.stamina_recovery_stationary
@onready var stamina_recovery_digging 	: float = player.stamina_recovery_digging
# Drain over time in snow * pull speed
@onready var stamina_drain_regular		: float = player.stamina_drain_regular
@onready var stamina_drain_snow 		: float = player.stamina_drain_snow
@onready var stamina_drain_pushing		: float = player.stamina_drain_pushing
@onready var stamina_drain_exhaustion 	: float = player.stamina_drain_exhaustion
# Drain over time against obstacles * pull speed
@onready var stamina_impact_tripping	: float = player.stamina_impact_tripping
@onready var stamina_impact_collision	: float = player.stamina_impact_collision
@onready var stamina_impact_chocomel 	: float = player.stamina_impact_chocomel
# Next allowed impact or tripping
@onready var tripping_timeout_duration 	: float = player.tripping_timeout_duration
# Mood - General
# Instant heal values
@onready var mood_heal_comfort 		: float = player.mood_heal_comfort
@onready var mood_heal_item_pickup 	: float = player.mood_heal_item_pickup
@onready var mood_heal_item_placed 	: float = player.mood_heal_item_placed
@onready var mood_heal_lick 			: float = player.mood_heal_lick
@onready var mood_heal_reward 			: float = player.mood_heal_reward
# Mood - Physical
# Instant heal values
@onready var mood_heal_help_get_up 	: float = player.mood_heal_help_get_up
# Instant impact values
@onready var mood_impact_falling 		: float = player.mood_impact_falling
# Drain over time values
@onready var mood_drain_floor_dragging : float = player.mood_drain_floor_dragging
@onready var mood_drain_stuck_in_snow 	: float = player.mood_drain_stuck_in_snow
# Timer values
@onready var mood_timeout_lick 		: float = player.mood_timeout_lick
@onready var stamina_timer_exhaustion 	: float = player.stamina_timer_exhaustion
@onready var mood_timer_floor_dragging : float = player.mood_timer_floor_dragging
@onready var mood_timer_stuck_in_snow 	: float = player.mood_timer_stuck_in_snow
# Mood - Mental
# Instant heal values
@onready var mood_heal_reached_point_of_interest : float = player.mood_heal_reached_point_of_interest
# Instant impact values
@onready var mood_impact_yanking 		: float = player.mood_impact_yanking
# Drain over time values
@onready var mood_drain_put_of_reach 	: float = player.mood_drain_out_of_reach
# Timer values
@onready var mood_timer_out_of_reach 	: float = player.mood_timer_out_of_reach
@onready var mood_timer_yanking			: float = player.mood_timer_yanking

# Timers
@onready var next_tripping_timer := 0.0:
	set(value):
		next_tripping_timer = clamp(value, 0.0, tripping_timeout_duration)
@onready var exhaustion_timer := stamina_timer_exhaustion:
	set(value):
		exhaustion_timer = clamp(value, 0.0, stamina_timer_exhaustion)

# Mood timers
@onready var next_lick_timer := 0.0:
	set(value):
		next_lick_timer = clamp(value, 0.0, mood_timeout_lick)
@onready var next_out_of_reach_timer := 0.0:
	set(value):
		next_out_of_reach_timer = clamp(value, 0.0, mood_timer_out_of_reach)
@onready var floor_dragging_timer := mood_timer_floor_dragging:
	set(value):
		floor_dragging_timer = clamp(value, 0.0, mood_timer_floor_dragging)
@onready var stuck_in_snow_timer := mood_timer_stuck_in_snow:
	set(value):
		stuck_in_snow_timer = clamp(value, 0.0, mood_timer_stuck_in_snow)


func _ready() -> void:
	# Init relationship to game state
	Context.pinda = self
	Context.interactable_nodes[interactable_id] = self
	
	# Set initial state values
	# TODO: This should be a function that is the same that is called on state entering!
	terrain_pull_cap = pull_cap_regular
	
	has_moved.connect(_on_position_changed)
	animation_tree.mixer_applied.connect(_on_animation_tree_mixer_applied)
	
	set_up_signal_bus()
	
	create_procedural_animator_node()
	set_bone_snapping_targets()
	pre_movement_updates()
	
	# Init states
	previous_character_state = -1 # Changing the previous state enum will force an update
	terrain_state_entering()
	character_state_entering()
	
	# Send initial position
	send_movement_changes()
	
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS

func _physics_process(delta: float) -> void:
	
	# Initiate the state if changed
	set_animation_tree_travel()
	terrain_state_entering()
	character_state_entering()
	
	# Update variables for this frame
	previous_mood = mood
	
	# Pre-movement
	pre_movement_updates()
	check_ongoing_touches()
	set_goal_and_target_points()
	set_movement_target_variables()
	
	# Skip movement, or use ice / ground movement logic
	if skip_movement:
		current_velocity = Vector3.ZERO
	elif terrain_detector.current_terrain_state == Constants.terrain_states.ICE:
		
		# Starting velocity
		new_velocity = velocity
		
		# Decelerate the velocity from last frame
		new_velocity = lerp(new_velocity, Vector3.ZERO, 0.1 * delta)
		
		ice_movement_pushing()
		ice_movement_pulling_and_limiting()
		conclude_movement()
		
		# Orient towards Chocomel if pulled
		if pull_factor > 0.0:
			set_rotation_from_vector(chocomel_direction)
	else:
		
		# Movement logic. Each updates the new_velocity
		set_walking_movement(delta)
		set_pulling_or_pushing_movement(delta)
		conclude_movement()
	
	set_debug_settings()
		
	# Post Movement updates and state changes
	character_state_updates(delta)
	
	# Animation
	set_character_rotation_slices()
	set_animation_tree_parameters()
	
	# Communication with other nodes
	send_movement_changes()
	
	# Reset variables for next frame
	new_velocity = Vector3.ZERO
	interaction_confirmed = false
	interaction_ended = false
	chocomel_did_digging = false
	just_touched_chocomel = false
	state_was_forced = false
	touching_chocomel = false
	touching_actual_wall = false
	animation_finished = false
	on_animation_step = false
	
	# Tick down timers
	progress_timers(delta)
	


func set_debug_settings() -> void:
	# Debug states
	if GameStatus.debug_low_stamina:
		stamina = STAMINA_MAX_DEBUG
	if GameStatus.debug_increase_stamina:
		stamina += 2.0
	if GameStatus.debug_decrease_stamina:
		stamina -= 2.0
	if GameStatus.debug_low_mood:
		mood = MAX_MOOD_DEBUG
	if GameStatus.debug_increase_mood:
		mood += 2.0
	if GameStatus.debug_decrease_mood:
		mood -= 2.0


## Code that is executed only once upon entering a new state.
func terrain_state_entering() -> void:
	
	# Set up terrain state. Only done once when state changed.
	if terrain_detector.current_terrain_state != terrain_detector.previous_terrain_state:
		
		match terrain_detector.current_terrain_state:
			Constants.terrain_states.NONE:
				# Pull variables
				terrain_pull_cap = pull_cap_regular
				pull_threshold = ground_pull_thresholds["ground"]
				terrain_friction = 0.8
				
				maximum_walking_speed = speed_walk_ground
				maximum_pushing_speed = chocomel_pushing_speed_ground
			
			Constants.terrain_states.SNOW:
				# Pull variables
				terrain_pull_cap = pull_cap_snow
				pull_threshold = ground_pull_thresholds["snow"]
				terrain_friction = 1.0
				
				maximum_walking_speed = speed_walk_snow
				maximum_pushing_speed = chocomel_pushing_speed_snow
			
			Constants.terrain_states.ICE:
				# Pull variables
				terrain_pull_cap = pull_cap_ice
				pull_threshold = ground_pull_thresholds["ice"]
				terrain_friction = 0.005
				
				maximum_walking_speed = speed_walk_ice


## Code that is executed only once upon entering a new state.
func character_state_entering() -> void:
	
	# Skip state entering if it hasn't changed
	if current_character_state != previous_character_state:
		pass
	elif (
		current_character_state == previous_character_state
		and current_interaction_type != previous_interaction_type
	):
		pass
	# WARNING: If only the idle_type has changed, then the new state won't be entered!
	else:
		return
		
	# The state is saved to compare it at the end of this function.
	var new_character_state = current_character_state
	
	# Default state variables. These can be changed by each state if needed:
	skip_movement = false
	state_pull_effectiveness = 1.0
	procedural_arm_movement = holding_leash
	sliced_rotation = true
	
	match current_character_state:
		
		character_states.CINEMATIC:
			
			skip_movement = true
			state_pull_effectiveness = 0.0
			procedural_arm_movement = false
			sliced_rotation = false
			
			set_queued_transform()
		
		character_states.GATE:
			
			skip_movement = true
			state_pull_effectiveness = 0.0
			procedural_arm_movement = false
			sliced_rotation = false
			
			set_queued_transform()
		
		character_states.IDLE:
			
			skip_movement = true
			state_pull_effectiveness = 0.0
			
			if current_idle_type == idle_types.BARK_REACTION:
				# Reset timer to pick up interest again and seek it out
				continue_seeking_timer = CONTINUE_SEEKING_TIMER_START
			
			elif current_idle_type == idle_types.WAITING:
				procedural_arm_movement = false
			
			elif current_idle_type == idle_types.ANNOUNCE_DISCOVERY:
				emote_bubbles.trigger_emote(
					emote_bubbles.emote_states.CHOCOMEL,
					EMOTE_DURATION
				)
			
			elif current_idle_type == idle_types.ANNOUNCE_INTERACTION:
				emote_bubbles.trigger_emote(
					emote_bubbles.emote_states.CHOCOMEL,
					EMOTE_DURATION
				)
			
			elif current_idle_type == idle_types.CALL_FOR_HELP:
				emote_bubbles.trigger_emote(
					emote_bubbles.emote_states.CHOCOMEL,
					EMOTE_DURATION
				)
			
			elif current_idle_type == idle_types.CATCH_A_BREATH:
				waiting_timer = 5.0
				# To prevent the negative mood impact
				reset_point_of_interest()
		
		character_states.SLIDING:
			procedural_arm_movement = false
		
		character_states.SEEKING:
			pass
		
		character_states.CATCHING_UP:
			pass
		
		character_states.WALKING_TO_CHOCOMEL:
			pass
		
		character_states.PULLING:
			state_pull_effectiveness = 0.5
			procedural_arm_movement = false
		
		character_states.AT_LEASH_END:
			state_pull_effectiveness = 0.0
		
		character_states.STUCK:
			state_pull_effectiveness = 0.5
			procedural_arm_movement = false
			
			stamina = 0.0
			
			# Rotate the character around to make the animations blend better
			if previous_character_state == character_states.PUSHED:
				set_rotation_from_vector(-chocomel_direction)
		
		character_states.GETTING_UP:
			state_pull_effectiveness = 0.0
			procedural_arm_movement = false
			
			# The request to trigger the tripping anymation might be queued.
			# This aborts it so Pinda doesn't immediately trip once back on their feet
			animation_tree[
				"parameters/AnimationStates/Seeking and Catching Up/Tripping/request"
			] = 2
			animation_tree[
				"parameters/AnimationStates/Ice Movement/Tripping/request"
			] = 2
		
		character_states.PUSHED:
			procedural_arm_movement = false
		
		character_states.BREAK_DOWN:
			state_pull_effectiveness = 0.1
			procedural_arm_movement = false
			sliced_rotation = false
			
			stamina = STAMINA_MAX
			
			# TODO: Check if this looks good. Make this a variable
			set_rotation_from_vector(Vector3.BACK.rotated(Vector3.UP, BREAKDOWN_ANGLE))
		
		character_states.INTERACTION:
			skip_movement = true
			state_pull_effectiveness = 0.0
			procedural_arm_movement = false
			sliced_rotation = false
			
			if current_interaction_type == interaction_types.ITEM_PICKUP:
				
				# When picking up the traffic cone on ice, Pinda needs to slide around.
				if terrain_detector.current_terrain_state == Constants.terrain_states.ICE:
					skip_movement = false
					sliced_rotation = true
				
				# Item effect
				GameStatus.picked_up_item(point_of_interest_item_id)
				# Pinda effect
				recover_mood(mood_heal_item_pickup, 0.1)
				# TODO: This doesn't seem to work sometimes.
				set_rotation_from_vector(Vector3.BACK)
				
			elif current_interaction_type == interaction_types.SNOWMAN_DECORATING:
				# Copy rotation of snowman to align
				var snowman_id = Constants.interactable_ids.SNOWMAN
				var snowman = Context.interactable_nodes[snowman_id]
				set_rotation_from_vector(snowman.animation_start_spot.basis.z)
				
				snowman.stop_missing_item_emotes()
				
			elif current_interaction_type == interaction_types.CHOCOMEL_LICK:
				if next_lick_timer == 0.0:
					recover_mood(mood_heal_lick)
					next_lick_timer = mood_timeout_lick
				
				if GameStatus.current_game_state == GameStatus.game_states.GAMEPLAY:
					player.leash.reset()
				
				set_interaction_transform()
			
			elif current_interaction_type == interaction_types.CHOCOMEL_SUPERLICK:
				set_interaction_transform()
				
				if GameStatus.current_game_state == GameStatus.game_states.GAMEPLAY:
					player.leash.reset()
				
				# Pinda effect
				recover_mood(mood_heal_help_get_up)
			
			elif current_interaction_type == interaction_types.SNUGGLE:
				if next_lick_timer == 0.0:
					recover_mood(mood_heal_lick * 2.0)
					next_lick_timer = mood_timeout_lick
				
				set_interaction_transform()
				
				if GameStatus.current_game_state == GameStatus.game_states.GAMEPLAY:
					player.leash.reset()
			
			elif current_interaction_type == interaction_types.PETTING:
				
				if GameStatus.current_game_state == GameStatus.game_states.GAMEPLAY:
					player.leash.reset()
				
				if previous_character_state == character_states.BREAK_DOWN:
					if previous_animation_state == animation_state_names[animation_states.MOPING]:
						lay_down_type_factor = 1.0
					elif previous_animation_state == animation_state_names[animation_states.CRYING]:
						lay_down_type_factor = -1.0
					else:
						assert(true, "Something went wrong when triggering the petting animation")
				else:
					lay_down_type_factor = 0.0
			
			elif current_interaction_type == interaction_types.CHOCOMEL_REWARD:
				set_interaction_transform()
				
				# Pinda effect
				remember_reward_timer = 0.0
				reset_point_of_interest()
				
				# Reset leash just in case for the gate sequence
				Context.leash.reset()
			
			elif current_interaction_type == interaction_types.GRAB_TRAFFIC_CONE:
				var traffic_cone : Node3D = Context.interactable_nodes[Constants.interactable_ids.TRAFFIC_CONE]
				global_transform = traffic_cone.global_transform
				rotation = Vector3.ZERO
	
	previous_character_state = current_character_state
	previous_interaction_type = current_interaction_type
	
	assert(
		current_character_state == new_character_state,
		"The character state was changed on entering the state. This will cause bugs!"
	)

# TODO: Change the default value from 1.0 to something like null
func set_walking_speed(override_walking_speed := 1.0) -> void:
	
	var delta := get_physics_process_delta_time()
	
	if override_walking_speed != 1.0:
		current_walking_speed = override_walking_speed
		return
	
	var max_speed : float
	var acceleration : float
	if maximum_walking_speed == speed_walk_ground:
		max_speed = speed_walk_ground
		acceleration = 6.0
	else:
		max_speed = speed_walk_snow
		acceleration = 3.0
	
	if maximum_walking_speed == speed_walk_ground:
		# TODO: For all lerp functions maybe? These should take delta time into account!
		var ground_acceleration := 6.0
		current_walking_speed = lerp(
			current_walking_speed,
			max_speed * get_destination_speed_factor(),
			acceleration * delta
		)


## Returns a factor based on how close Pinda is to chocomel if they are moving towards them.
## If not then this factor is 1.0, meaning no slowdown needed.
func get_destination_speed_factor() -> float:
	var is_moving_to_chocomel := target_point == chocomel_position * Vector3(1,0,1)
	var target_point_distance := (global_position - target_point).length()
	
	var destination_slowdown_factor := remap(
		target_point_distance,
		catching_up_distance,
		catching_up_distance + 0.5,
		0.0,
		1.0
	)
	if not is_moving_to_chocomel:
		destination_slowdown_factor = 1.0
	else:
		destination_slowdown_factor = clampf(destination_slowdown_factor, 0.0, 1.0)
	
	return destination_slowdown_factor


func check_ongoing_touches() -> void:
	#print("CHECKING ONGOING TOUCHES NR: " + str(Engine.get_frames_drawn()))
	
	touch_detector.trigger_shapecast()

	# Ongoing touching objects
	for node in ongoing_touching:
		if node.name == "Chocomel":
			touching_chocomel = true
		elif "is_physical_object" in node:
			touching_actual_wall = true


## Updating variables and states based on recent changes.
func character_state_updates(delta : float) -> void:
	
	# Character state logic
	match current_character_state:
		
		character_states.CINEMATIC:
			
			set_walking_speed(0.0)
			
			if current_animation_state == animation_state_names[animation_states.FALLEN_THROUGH_FENCE]:
				queue_next_character_state(
					character_states.STUCK,
					animation_states.STUCK
				)
		
		character_states.GATE:
			
			set_walking_speed(0.0)
			
			if check_leash_limit_reaction():
				pass
			elif check_pushing_from_chocomel():
				pass
		
		character_states.IDLE:
			
			set_walking_speed(0.0)
			
			# Conditional state logic and state switching
			if terrain_detector.current_terrain_state == Constants.terrain_states.ICE:
				# Skip to other state. Idle is not used for ice at the moment
				queue_next_character_state(
					character_states.CATCHING_UP,
					animation_states.REGULAR
				)
			elif check_leash_limit_reaction():
				pass
			elif check_pushing_from_chocomel():
				pass
			# Natural state transitions
			else:
				
				if current_idle_type == idle_types.WAITING:
					
					# Orient Pinda towards Chocomel
					set_rotation_from_vector(chocomel_direction)
					emote_bubbles.trigger_emote(
						emote_bubbles.emote_states.TREAT,
						0.1
					)
						
					# Waiting every frame for confirmation
					if confirm_reward_interaction():
						force_next_character_state(
							character_states.INTERACTION,
							animation_states.REWARD
						)
						current_interaction_type = interaction_types.CHOCOMEL_REWARD
					else:
						waiting_timer -= delta
						if waiting_timer <= 0.0:
							queue_next_character_state(
								character_states.CATCHING_UP,
								animation_states.REGULAR
							)
				
				elif current_idle_type == idle_types.ANNOUNCE_DISCOVERY:
					
					if animation_state_finished:
						queue_next_character_state(
							character_states.SEEKING,
							animation_states.REGULAR
						)
				
				elif current_idle_type == idle_types.ANNOUNCE_INTERACTION:
					if animation_state_finished:
						queue_next_character_state(
							character_states.IDLE,
							animation_states.WAITING
						)
						current_idle_type = idle_types.WAITING
				
				elif current_idle_type == idle_types.BARK_REACTION:
					if animation_state_finished:
						queue_next_character_state(
							character_states.CATCHING_UP,
							animation_states.REGULAR
						)
				
				elif current_idle_type == idle_types.CALL_FOR_HELP:
					if animation_state_finished:
						queue_next_character_state(
							character_states.CATCHING_UP,
							animation_states.REGULAR
						)
				
				elif current_idle_type == idle_types.CATCH_A_BREATH:
					waiting_timer -= delta
					if waiting_timer <= 0.0:
						queue_next_character_state(
							character_states.CATCHING_UP,
							animation_states.REGULAR
						)
			
			stamina_recovery(true)
		
		character_states.SLIDING:
			
			set_walking_speed(0.0)
			
			if check_falling_or_crying():
				pass
			elif check_pinda_collision_impact():
				pass
			
			if stamina <= 0.0:
				queue_next_character_state(
					character_states.STUCK,
					animation_states.STUCK
				)
			elif terrain_detector.current_terrain_state != Constants.terrain_states.ICE:
				queue_next_character_state(
					character_states.IDLE,
					animation_states.CATCH_A_BREATH
				)
				current_idle_type = idle_types.CATCH_A_BREATH
			
			# Check if Pinda can hold onto the traffic cone or fails
			check_grabbing_traffic_cone()
		
		character_states.SEEKING:
			
			set_walking_speed()
			
			if check_ice_contact():
				return
			
			# Variables and state update
			if check_leash_limit_reaction():
				pass
			elif check_pushing_from_chocomel():
				pass
			elif check_reaching_point_of_interest():
				pass
			
			stamina_recovery(false)
			
		character_states.CATCHING_UP:
			
			# Set walking speed
			set_walking_speed()
			
			if (reward_init_location - global_position).length() > 10.0:
				remember_reward_timer = 0.0
			
			if queued_reward:
				set_state_reward_chocomel()
				queued_reward = false
				return
			elif (
				continue_reward_timer > 0.0
				and continue_reward_timer < CONTINUE_REWARD_TIMER_START
				and remember_reward_timer > 0.0
				and pull_factor < 0.6
			):
				queue_next_character_state(
					character_states.IDLE,
					animation_states.WAITING
				)
				current_idle_type = idle_types.WAITING
				return
			
			if check_ice_contact():
				return
			
			check_dragged_away_from_interest()
			
			# Variables and state update
			check_pinda_exhaustion()
			check_pinda_collision_impact()
			
			if check_pushing_from_chocomel():
				pass
			elif check_falling_or_crying():
				pass
			elif check_call_for_help():
				pass
			elif check_call_or_seek():
				pass
			# Go to chocomel for petting
			elif Context.chocomel.sitting_time > IDLE_TOGETHER_START:
				queue_next_character_state(
					character_states.WALKING_TO_CHOCOMEL,
					animation_states.REGULAR
				)
			
			stamina_recovery(false)
		
		character_states.WALKING_TO_CHOCOMEL:
			
			# Set walking speed
			set_walking_speed(1.1)
			
			var chocomel_interaction_distance : float = (
					chocomel_position - global_position
				).length() + player.chocomel.origin_offset_z
			var reached_chocomel := chocomel_interaction_distance <= close_interaction_distance
			var chocomel_moved := Context.chocomel.sitting_time <= IDLE_TOGETHER_START
			
			if reached_chocomel:
				if confirm_petting_interaction():
					force_next_character_state(
						character_states.INTERACTION,
						animation_states.LAY_DOWN
					)
					current_interaction_type = interaction_types.PETTING
					
			elif chocomel_moved: 
				queue_next_character_state(
					character_states.CATCHING_UP,
					animation_states.REGULAR
				)
			
			stamina_recovery(false)
		
		character_states.PULLING:
			
			set_walking_speed(0.5)
			
			var goal_direction := (goal_point - global_position).normalized()
			var average_direction : Vector3 = lerp(goal_direction, -chocomel_direction, 0.5).normalized()
			set_rotation_from_vector(average_direction)
			
			var minimum_input := InputController.movement_vector.length() >= 0.1
			var minimum_chocomel_speed := chocomel_velocity.length() >= 0.1
			var leash_length_change_per_second := leash_length_change / delta
			
			if (
					# TODO: There is still a bit of jittereing back and forth with SEEKING
					# It's mainly because of the input and chocomel_velocity doesn't reflect the actual velocity of chocomel
					# The direction is also hard to determine.
					(minimum_input and leash_length_change_per_second < -0.2 and chocomel_moving_to_pinda_scalar > 0.5)
					or leash_length <= 3.0
				):
				force_next_character_state(
					character_states.SEEKING,
					animation_states.REGULAR
				)
			elif check_dragged_away_from_interest():
				pass
		
		character_states.AT_LEASH_END:
			
			set_walking_speed(0.0)
			
			set_rotation_from_vector(chocomel_direction)
			
			var minimum_chocomel_speed := chocomel_velocity.length() >= 1.0
			if not minimum_chocomel_speed:
				return
			
			var yanking_chocomel_speed := chocomel_velocity.length() >= 2.0
			
			if yanking_chocomel_speed and chocomel_moving_to_pinda_scalar < -0.5:
				force_next_character_state(
					character_states.CATCHING_UP,
					animation_states.REGULAR
				)

			elif (
					(minimum_chocomel_speed and chocomel_moving_to_pinda_scalar > 0.5)
					or leash_length <= 3.0
				):
				force_next_character_state(
					character_states.SEEKING,
					animation_states.REGULAR
				)
			elif check_leash_limit_reaction():
				pass
		
		character_states.STUCK:
			
			set_walking_speed(0.0)
			
			continue_seeking_timer = CONTINUE_SEEKING_TIMER_START
			
			# Skip this if the point of interest is likely the traffic cone
			if terrain_detector.current_terrain_state != Constants.terrain_states.ICE:
				check_dragged_away_from_interest()
			
			# TASK: This needs to be more contextual to the exact animation
			var push_over_anim_length := animation_player.get_animation_library("Pinda-anim_lib").get_animation("ACTN-pinda-push_over").length
			var fall_flat_anim_length := animation_player.get_animation_library("Pinda-anim_lib").get_animation("ACTN-pinda-fall_flat").length
			var fall_snow_anim_length := animation_player.get_animation_library("Pinda-anim_lib").get_animation("ACTN-pinda-fall_snow").length
			# Turns out this animation is the same length as dragging through snow. That's ok for the intented effect
			var distressed_anim_length := animation_player.get_animation_library("Pinda-anim_lib").get_animation("LOOP-pinda-fallen_dragged_panic").length
			
			var rumble_duration := 0.2
			if current_animation_length == push_over_anim_length or current_animation_length == fall_snow_anim_length:
				if current_animation_position >= 0.15:
					emote_bubbles.trigger_emote(
						emote_bubbles.emote_states.CRASH,
						EMOTE_DURATION
					)
					InputController.trigger_rumble(rumble_duration)
			elif current_animation_length == fall_flat_anim_length:
				if current_animation_position >= 0.3:
					emote_bubbles.trigger_emote(
						emote_bubbles.emote_states.CRASH,
						EMOTE_DURATION
					)
					InputController.trigger_rumble(rumble_duration)
			elif current_animation_length == distressed_anim_length:
				InputController.trigger_rumble(0.1, true)
			else:
				pass
			
			# Recover or reset to 0
			if pull_factor >= 1.0:
				stamina = 0.0
				if floor_dragging_timer == 0.0:
					reduce_mood(mood_drain_floor_dragging * delta, 0.1)

			var stuck_in_snow = terrain_detector.current_terrain_state == Constants.terrain_states.SNOW
			
			# Recover after a second or require help
			if not stuck_in_snow:
				stamina += 10.0 * delta
			else:
				call_for_help.emit()
				
				var controller_as_input := InputController.current_input_mode == InputController.input_modes.CONTROLLER
				var chocomel_nearby := (chocomel_position - global_position).length() < 3.0
				
				if chocomel_did_digging:
					stamina += stamina_recovery_digging * delta
					
					# TODO: Make these instead contextually appear based on chocomels close proximity.
					if controller_as_input:
						emote_bubbles.trigger_emote(
							emote_bubbles.emote_states.BUTTON_PRESS,
							EMOTE_DURATION
						)
					else:
						emote_bubbles.trigger_emote(
							emote_bubbles.emote_states.CLICK_PRESS,
							EMOTE_DURATION
						)
				elif chocomel_nearby:
					if controller_as_input:
						emote_bubbles.trigger_emote(
							emote_bubbles.emote_states.BUTTON_PROMPT,
							0.1
						)
					else:
						emote_bubbles.trigger_emote(
							emote_bubbles.emote_states.CLICK_PROMPT,
							0.1
						)
					#if stuck_in_snow_timer == 0.0:
						#reduce_mood(mood_drain_stuck_in_snow * delta, 0.1)
			
			# Velocity check is for the case where Pinda is on ice.
			if stamina == STAMINA_MAX and velocity.length() <= 1.0:
				force_next_character_state(
					character_states.GETTING_UP,
					animation_states.GETTING_UP
				)
				if chocomel_did_digging:
					recover_mood(mood_heal_help_get_up)
		
		character_states.GETTING_UP:
			
			set_walking_speed(0.0)
			
			continue_seeking_timer = CONTINUE_SEEKING_TIMER_START
			
			# Set stamina to 0 under conditions
			# TODO: This needs to be tought out better. Maybe depending on the snow/ground animation
			#		Pinda can be pushed to the ground after a certain amount of time?
			# 		It's too easy to push Pinda over after having dug them out.
			#if check_pushing_from_chocomel():
				#pass
			if pull_factor >= 1.0:
				stamina = 0.0
			
			# Fall back down 
			if stamina == 0.0:
				force_next_character_state(
					character_states.STUCK,
					animation_states.STUCK
				)
				#var almost_stood_up := current_animation_position >= 2.9
				#if almost_stood_up:
					#reduce_mood(mood_impact_falling)
			
			# Set next regular movement state
			if check_call_or_seek():
				pass
			elif animation_state_finished:
				queue_next_character_state(
					character_states.CATCHING_UP,
					animation_states.REGULAR
				)
		
		character_states.PUSHED:
			
			set_walking_speed(0.0)
			
			continue_seeking_timer = CONTINUE_SEEKING_TIMER_START
			continue_reward_timer = CONTINUE_REWARD_TIMER_START
			
			if check_ice_contact():
				pass
			else:
				check_dragged_away_from_interest()
			
			
			# Orient Pinda towards chocomel
			set_rotation_from_vector(chocomel_direction)
			
			var too_much_force := InputController.movement_vector.length() >= 0.9
			if too_much_force:
				stamina -= stamina_drain_pushing * delta
				if emote_bubbles.current_state != emote_bubbles.emote_states.SWEAT:
					emote_bubbles.trigger_emote(
						emote_bubbles.emote_states.SWEAT,
						0.1
					)
			
			var no_longer_pushing := (
				chocomel_moving_to_pinda_scalar < 0.8
				or chocomel_velocity.length() < 0.1
				# TODO: Ideally reaplace this with touching_chocomel once that is more reliable
				#or not touching_chocomel
				or (chocomel_position - global_position).length() >= 1.0
			)
			
			if check_falling_or_crying():
				pass
			# NOTE: This is kindof a hack to keep Pinda in the correct state in the intro.
			#		It also prevents a bug where Pinda kept giving Chocomel treats?
			elif no_longer_pushing and GameStatus.current_game_state == GameStatus.game_states.INTRO:
				queue_next_character_state(
					character_states.SEEKING,
					animation_states.REGULAR
				)
			elif no_longer_pushing:
				queue_next_character_state(
					character_states.CATCHING_UP,
					animation_states.REGULAR
				)
		
		character_states.BREAK_DOWN:
			
			set_walking_speed(0.0)
			
			continue_seeking_timer = CONTINUE_SEEKING_TIMER_START
			
			check_dragged_away_from_interest()
			
			# TODO: Check if this looks good. Make this a variable
			set_rotation_from_vector(Vector3.BACK.rotated(Vector3.UP, BREAKDOWN_ANGLE))
			
			if current_break_down_type == break_down_types.MOPING:
				emote_bubbles.trigger_emote(
					emote_bubbles.emote_states.CLOUDY,
					0.1
				)
				
				#sound_effects.play_emote_sound(EmoteBubble.emote_states.CLOUDY)
			
			stamina_recovery(true)
		
		character_states.INTERACTION:
			
			set_walking_speed(0.0)
			
			if current_interaction_type == interaction_types.ITEM_PICKUP:
				# Pinda can be yanked out of this state early (Unless it's the Traffic Cone)
				# NOTE: Commented out to make sure the animations are visible to the end. Would need more work otherwise.
				#if terrain_detector.current_terrain_state != Constants.terrain_states.ICE:
					#check_leash_limit_reaction()
				
				# TODO: All of the logic below in this section should actually only be excecuted once.
				# 		But this cannot be in the state entering function. So find a better way to trigger this just once.
				#		Or maybe it's fine to have this in the state entering function since states are now queued instead of immediately set.
				if point_of_interest_interaction_id == Constants.interactable_ids.TENNIS_BALL:
					animation_tree.animation_finished.connect(hide_tennis_ball)
				if terrain_detector.current_terrain_state == Constants.terrain_states.ICE:
					queue_next_character_state(
						character_states.SLIDING,
						animation_states.ON_ICE
					)
					queued_reward = true
					animation_tree.animation_finished.connect(scale_down_pompom)
				elif current_point_of_interest != Context.interactable_nodes[Constants.interactable_ids.BRANCH]:
					set_state_reward_chocomel()
					reset_point_of_interest()
			
			elif current_interaction_type == interaction_types.SNOWMAN_DECORATING:
				
				var snowman = Context.interactable_nodes[Constants.interactable_ids.SNOWMAN]
				var snowman_state_machine_playback : AnimationNodeStateMachinePlayback
				snowman_state_machine_playback = snowman.animation_tree.get("parameters/playback")
				
				var decorating_playback : AnimationNodeStateMachinePlayback = animation_tree["parameters/AnimationStates/Decorating Snowman/playback"]
				
				if animation_finished:
					
					print("Current decorating node = " + decorating_playback.get_current_node())
					
					# Set next held items to "PLACED"
					if next_decoration_item > 0:
						GameStatus.placed_item(next_decoration_item)
						recover_mood(mood_heal_item_placed)
					
					# Check which item is next
					if Context.interactable_nodes[tennis_ball_id].item_state == GameStatus.item_states.HELD:
						next_decoration_item = tennis_ball_id
						decorating_playback.start("attach tennis ball")
						Context.interactable_nodes[tennis_ball_id].visible = true
						print("tennis ball")
					elif Context.interactable_nodes[traffic_cone_id].item_state == GameStatus.item_states.HELD:
						next_decoration_item = traffic_cone_id
						decorating_playback.start("attach traffic cone")
						pompom_scale_down_factor = 0.0
						print("traffic cone")
					elif Context.interactable_nodes[shovel_id].item_state == GameStatus.item_states.HELD:
						next_decoration_item = shovel_id
						decorating_playback.start("attach shovel")
						# Snowman synced animation
						snowman_state_machine_playback.start("Attach Shovel")
						# Shovel synced animation
						var shovel_player : AnimationPlayer = Context.interactable_nodes[Constants.interactable_ids.SHOVEL].anim_player
						shovel_player.play("PR-shovel-anim_lib/CINE-shovel-attach_shovel")
						print("shovel")
					
					# This is the moment the proud animation finishes
					elif next_decoration_item == -1:
						reset_point_of_interest()
						# Reset this value so this next time when bringing items to the snowman works
						next_decoration_item = 0
						
						if check_ending():
							GameStatus.trigger_ending()
						else:
							next_decoration_item = -2
					# This is the moment the leash has been picked back up
					elif next_decoration_item == -2:
						# Finish Pinda effect once no more items are held
						set_state_reward_chocomel()
						force_next_character_state(
							character_states.IDLE,
							animation_states.CALLING_OUT
						)
						current_idle_type = idle_types.ANNOUNCE_INTERACTION
						
						snowman.start_missing_item_emotes()
					
					else:
						next_decoration_item = -1
						decorating_playback.start("attach proud")
						print("no item")
			
			elif current_interaction_type == interaction_types.CHOCOMEL_LICK:
				# Queue next state
				queue_next_character_state(
					character_states.CATCHING_UP,
					animation_states.REGULAR
				)
				
				# Pinda can be yanked out of this state early
				check_leash_limit_reaction()
				
				continue_seeking_timer = CONTINUE_SEEKING_TIMER_START
			
			elif current_interaction_type == interaction_types.CHOCOMEL_SUPERLICK:
				# Queue next state
				queue_next_character_state(
					character_states.CATCHING_UP,
					animation_states.REGULAR
				)
				
				# Pinda can be yanked out of this state early
				check_leash_limit_reaction()
				
				continue_seeking_timer = CONTINUE_SEEKING_TIMER_START
			
			elif current_interaction_type == interaction_types.SNUGGLE:
				queue_next_character_state(
					character_states.CATCHING_UP,
					animation_states.REGULAR
				)
				
				# Pinda can be yanked out of this state early
				check_leash_limit_reaction()
			
			elif current_interaction_type == interaction_types.PETTING:
				
				# Set next animation state when laying down
				if current_animation_state == animation_state_names[animation_states.LAY_DOWN]:
					# Go directly to petting loops
					if lay_down_type_factor == 0.0:
						queue_next_character_state(
							character_states.INTERACTION,
							animation_states.PETTING_LOOPS
						)
						set_interaction_transform()
					# First do a turn
					else:
						queue_next_character_state(
							character_states.INTERACTION,
							animation_states.TURN
						)
						# Set only distance to chocomel (Duplicate from set_interaction_transform()
						var chocomel_interaction_distance := 1.35 
						var chocomel_offset : float = player.chocomel.origin_offset_z
						var interaction_distance := chocomel_offset + chocomel_interaction_distance
						var current_heigth := global_position.y
						global_position = player.chocomel.global_position - (interaction_distance * chocomel_direction)
						global_position.y = current_heigth
				
				# Set up turn and petting transition
				elif current_animation_state == animation_state_names[animation_states.TURN]:
					queue_next_character_state(
						character_states.INTERACTION,
						animation_states.PETTING_LOOPS
					)
					
					# Turn pinda mid animation
					var turn_start_time := 0.2
					var turn_end_time := 0.7
					
					if (
						current_animation_position > turn_start_time
						and current_animation_state == animation_state_names[animation_states.TURN]
						and on_animation_step
					):
						var iterative_direction : Vector3 = lerp(basis.z, chocomel_direction, 40.0 * delta)
						set_rotation_from_vector(iterative_direction)
				
				elif current_animation_state == animation_state_names[animation_states.PETTING_LOOPS]:
					
					# Trigger this only once when this animation state started
					if previous_animation_state != animation_state_names[animation_states.PETTING_LOOPS]:
						started_petting_loops.emit()
						recover_mood(mood_heal_comfort)
					
					if interaction_ended:
						queue_next_character_state(
							character_states.CATCHING_UP,
							animation_states.REGULAR
						)
			
			elif current_interaction_type == interaction_types.CHOCOMEL_REWARD:
				# Queue next state
				queue_next_character_state(
					character_states.CATCHING_UP,
					animation_states.REGULAR
				)
				
				# Pinda can be yanked out of this state early
				check_leash_limit_reaction()
				
				if animation_state_finished:
					recover_mood(mood_heal_reward)
			
			elif current_interaction_type == interaction_types.GRAB_TRAFFIC_CONE:
				
				var chocomel_moving_away_factor := Context.chocomel.velocity.normalized().dot(chocomel_direction)
				var chocomel_pulling_force := Context.chocomel.velocity.length() * chocomel_moving_away_factor
				chocomel_pulling_force = max(chocomel_pulling_force, 0.0)
				
				if leash_limit_just_reached:
					#if chocomel_pulling_force > 4.0:
						#print("TOO MUCH FORCE with = " + str(snappedf(chocomel_pulling_force, 0.1)))
						#queue_next_character_state(
							#character_states.STUCK,
							#animation_states.STUCK
						#)
					if chocomel_pulling_force >= 4.0:
						print("ENOUGH FORCE with = " + str(snappedf(chocomel_pulling_force, 0.1)))
						
						set_state_item_pickup()
						reset_point_of_interest()
						
					else:
						print("NOT ENOUGH FORCE with = " + str(snappedf(chocomel_pulling_force, 0.1)))
						pass
			
			stamina_recovery(true)



# NOTE: Various checks for state variable updates and enventual state switching


func scale_down_pompom(anim : String) -> void:
	pompom_scale_down_factor = 1.0
	animation_tree.animation_finished.disconnect(scale_down_pompom)


func scale_up_pompom(anim : String) -> void:
	pompom_scale_down_factor = 0.0
	animation_tree.animation_finished.disconnect(scale_up_pompom)


func hide_tennis_ball(anim : String) -> void:
	Context.interactable_nodes[Constants.interactable_ids.TENNIS_BALL].visible = false
	animation_tree.animation_finished.disconnect(hide_tennis_ball)


## Force ice movement once on ice
func check_ice_contact() -> bool:
	
	if terrain_detector.current_terrain_state != Constants.terrain_states.ICE:
		return false

	queue_next_character_state(
		character_states.SLIDING,
		animation_states.ON_ICE
	)
	return true


## Check if Pinda has been exhausted.
func check_pinda_exhaustion() -> bool:
	
	if exhaustion_timer > 0.0:
		return false
	
	var delta := get_physics_process_delta_time()
	var minimum_pull_effect := maxf(pull_factor - DANGER_PULL_FACTOR, 0.0)
	if terrain_detector.current_terrain_state == Constants.terrain_states.SNOW:
		stamina -= stamina_drain_snow * delta * minimum_pull_effect
	else:
		stamina -= stamina_drain_exhaustion * delta
	
	emote_bubbles.trigger_emote(
		emote_bubbles.emote_states.SWEAT,
		0.1
	)
	
	return true

## Forget the item if dragged away too far and get mopey
func check_dragged_away_from_interest() -> bool:
	
	if point_of_interest_location == Vector3.ZERO:
		return false
	
	var dragged_away_distance := 10.0
	if (point_of_interest_location - global_position).length() < dragged_away_distance:
		return false
	
	reset_point_of_interest()
	
	if current_point_of_interest == Context.interactable_nodes[Constants.interactable_ids.TRAFFIC_CONE]:
		# Reset point of interest but no effect on mood.
		# Traffic Cone is a special case here
		return true
	
	if current_character_state == character_states.BREAK_DOWN:
		return true
	
	if mood <= ROCK_BOTTOM_MOOD:
		queue_next_character_state(
			character_states.BREAK_DOWN,
			animation_states.MOPING
		)
		current_break_down_type = break_down_types.MOPING
	else:
		reduce_mood(mood_impact_yanking, EMOTE_DURATION)
	
	return true


## Check if Pinda rammed into an obstacle.
func check_pinda_collision_impact() -> bool:
	
	if not is_on_wall():
		return false
	
	var is_phyisical_object := false
	
	var collisions := get_slide_collision(0)
	for i in collisions.get_collision_count():
		var collider := collisions.get_collider(i)
		if collider.has_method("pinda_collide"):
			collider.pinda_collide(collisions, i)
		if "is_physical_object" in collider:
			is_phyisical_object = true
	
	var conditions_met := (
		is_phyisical_object
		and next_tripping_timer <= 0.0
	)
	if not conditions_met:
		return false
	
	collision_normal = get_wall_normal()
	collision_angle_scalar = movement_target_direction.dot(collision_normal)
	
	var collision_strength := 0.0
	var on_ice := terrain_detector.current_terrain_state == Constants.terrain_states.ICE
	
	if not on_ice:
		var critical_angle := collision_angle_scalar <= -0.8
		if not critical_angle:
			return false
		
		if pull_factor < DANGER_PULL_FACTOR:
			return false
		
		collision_strength = pull_factor
		
	else:
		var minimum_speed := 5.0
		if current_velocity.length() <= minimum_speed:
			return false
		
		collision_strength = remap(current_velocity.length(), minimum_speed, 8.0, 0.0, 1.0)
		collision_strength = clamp(collision_strength, 0.0, 1.0)
		print("collision_strength = " + str(collision_strength))
	
	# Reset timer
	next_tripping_timer = tripping_timeout_duration
	
	# Update variables
	stamina -= stamina_impact_collision * collision_strength
	
	# Visual feedback
	emote_bubbles.trigger_emote(
		emote_bubbles.emote_states.SWEAT,
		EMOTE_DURATION
	)
	
	# Audio feedback
	# TODO: offset impact volume according to velocity
	sound_effects.impact_sfx.volume_db = velocity.length() + 2.5
	
	print(sound_effects.impact_sfx.volume_db)
	
	sound_effects.impact_sfx.play()
	# TODO: big oof at high velocity?
	sound_effects.ouch_sfx.play()
	
	trigger_tripping_animation()
	
	return true

## Check if Pinda should fall or even cry.
func check_falling_or_crying() -> bool:
	
	# Special case where Pinda insta-falls
	var total_pull_force := current_velocity_against_chocomel.length()
	if leash_limit_just_reached and total_pull_force >= yank_fall_force:
		stamina = 0.0
	
	# Conditions
	if stamina > 0.0:
		return false
	
	
	# Don't cry in snow since it doesn't work that well there.
	if mood <= ROCK_BOTTOM_MOOD:
		force_next_character_state(
			character_states.BREAK_DOWN,
			animation_states.CRYING
		)
		current_break_down_type = break_down_types.CRYING
		
		emote_bubbles.stop_anim()
	else:
		force_next_character_state(
			character_states.STUCK,
			animation_states.STUCK
		)
		reduce_mood(mood_impact_falling)
	
	return true


## Check if moping on the ground should happen or to catch up with Chocomel.
func check_catching_up_or_resisting() -> void:
	
	var was_yanked := current_velocity_against_chocomel.length() > (maximum_walking_speed + 1.0)
	
	if current_point_of_interest == null:
		force_next_character_state(
			character_states.CATCHING_UP,
			animation_states.REGULAR
		)
		if was_yanked:
			trigger_yanking_animation()
	
	elif mood < 2.0:
		force_next_character_state(
		character_states.PULLING,
		animation_states.PULLING
	)
	elif was_yanked:
		force_next_character_state(
			character_states.CATCHING_UP,
			animation_states.REGULAR
		)
		trigger_yanking_animation()
	else:
		force_next_character_state(
			character_states.AT_LEASH_END,
			animation_states.WAITING
		)


## Make Pinda react to a maxed out leash length.
## WARNING: Don't use this for STUCK or GETTING_UP state
func check_leash_limit_reaction() -> bool:
	
	if not leash_limit_reached:
		return false
	
	if not holding_leash:
		return false
	
	# Either make the kid fall or yank it back to you
	if check_falling_or_crying():
		pass
	else:
		check_catching_up_or_resisting()
	
	# Reset timer to pick up interest again and seek it out
	continue_seeking_timer = CONTINUE_SEEKING_TIMER_START
	continue_reward_timer = CONTINUE_REWARD_TIMER_START
	
	return true


## Switch to pushing state if needed.
func check_pushing_from_chocomel() -> bool:
	
	if not touching_chocomel:
		return false
	
	
	if chocomel_moving_to_pinda_scalar >= 0.8 and chocomel_velocity.length() >= 0.1:
		
		if current_character_state == character_states.GETTING_UP:
			stamina = 0.0
			return true
		
		force_next_character_state(
			character_states.PUSHED,
			animation_states.PUSHED
		)
	return true


## Check if there's need or if it's time to call for help.
func check_call_for_help() -> bool:
	var delta := get_process_delta_time()
	
	# Check if Pinda must be stuck on some collision
	if velocity.length() <= 0.1 and leash_length > catching_up_distance + 0.5:
		stationary_timer += delta
	else:
		stationary_timer = 0.0
	
	if stationary_timer < MAX_STATIONARY_TIME:
		return false
	
	stationary_timer = 0.0
	queue_next_character_state(
		character_states.IDLE,
		animation_states.CALLING_OUT
	)
	current_idle_type = idle_types.CALL_FOR_HELP
	
	return true


## Check if Pinda still remembers a Point of Interest and seek it out.
func check_call_or_seek() -> bool:
	
	# Base condition
	var conditions_met := (
		current_point_of_interest != null
		and point_of_interest_location != Vector3.ZERO
		and continue_seeking_timer <= 0.0
	)
	
	if not conditions_met:
		return false
	
	# Emote trigger is manually done in the intro.
	if GameStatus.current_game_state != GameStatus.game_states.INTRO:
		emote_bubbles.trigger_emote(
			emote_bubbles.emote_states.EXCLAMATION,
			EMOTE_DURATION
		)
		
		#sound_effects.play_emote_sound(EmoteBubble.emote_states.EXCLAMATION)
		
		
	
	# Queue seeking by default
	queue_next_character_state(
		character_states.SEEKING,
		animation_states.REGULAR
	)
	
	# Check if Chocomel is following Pinda to the point of interest.
	# Only if not, then instead queue the calling out animation and state first.
	var chocomel_movement_direction := chocomel_velocity.normalized()
	var point_of_interest_direction := (point_of_interest_location - global_position).normalized()
	var chocomel_moving_to_interest_scalar := chocomel_movement_direction.dot(point_of_interest_direction)
	var chocomel_in_direction_to_interest_scalar := chocomel_direction.dot(point_of_interest_direction)
	
	# First check if chocomel is in eyesight of the point of interest
	if chocomel_in_direction_to_interest_scalar > 0.0:
		return true
	# Then check if chocomel is going in the direction of the point of interest
	if chocomel_moving_to_interest_scalar > 0.25:
		return true
		
	queue_next_character_state(
		character_states.IDLE,
		animation_states.CALLING_OUT
	)
	current_idle_type = idle_types.ANNOUNCE_DISCOVERY
	
	return true


## Check if Pinda is near the traffic cone and can grab it / trips over it,
func check_grabbing_traffic_cone() -> bool:
	
	var traffic_cone_node : Node3D = Context.interactable_nodes[Constants.interactable_ids.TRAFFIC_CONE]
	var distance_to_traffic_cone := (traffic_cone_node.global_position - global_position).length()
	var MIN_DISTANCE := 0.45
	
	if distance_to_traffic_cone > MIN_DISTANCE:
		colliding_with_traffic_cone = false
		return false
	elif colliding_with_traffic_cone:
		return false
	else:
		colliding_with_traffic_cone = true
	
	# Don't continue if traffic cone is no longer on the pond
	var current_traffic_cone_state : GameStatus.item_states = Context.interactable_nodes[traffic_cone_id].item_state
	if current_traffic_cone_state != GameStatus.item_states.NONE:
		return false
	
	if velocity.length() <= TRAFFIC_CONE_GRAB_SPEED:
		force_next_character_state(
			character_states.INTERACTION,
			animation_states.GRAB_TRAFFIC_CONE
		)
		current_interaction_type = interaction_types.GRAB_TRAFFIC_CONE
		print("GRABBED at = " + str(snappedf(velocity.length(), 0.1)))
	elif next_tripping_timer <= 0.0:
		stamina -= stamina_impact_tripping
		emote_bubbles.trigger_emote(
			emote_bubbles.emote_states.SWEAT,
			EMOTE_DURATION
		)
		trigger_tripping_animation()
		next_tripping_timer = tripping_timeout_duration
		print("TOO FAST at = " + str(snappedf(velocity.length(), 0.1)))
	else:
		return false
	
	print("CORRECT DISTANCE at = " + str(snappedf(distance_to_traffic_cone, 0.01)))
	return true


## Recover stamina over time based on the state
func stamina_recovery(fast_recovery : bool) -> void:
	
	var delta := get_physics_process_delta_time()
	
	# No recovery yet :D
	if pull_factor > 0.0:
		return
	
	if fast_recovery:
		stamina += stamina_recovery_stationary * delta
	else:
		stamina += stamina_recovery_regular * delta


## Send a signal to Pinda if licking is currently possible. If a confirmation signal is sent back,
## it meas Pinda started the action and Chocomel can continue with it as well.
## If the interaction is rejected or no singal is sent back, do not start the interaction.
func confirm_reward_interaction() -> bool:
	
	request_interaction.emit(interaction_types.CHOCOMEL_REWARD)
	if interaction_confirmed:
		return true
	else:
		return false


func confirm_petting_interaction() -> bool:
	
	request_interaction.emit(interaction_types.PETTING)
	if interaction_confirmed:
		return true
	else:
		return false


## Update various important variables between the characters and the leash that might have changed.
func pre_movement_updates() -> void:
	
	var delta := get_physics_process_delta_time()
	
	previous_velocity = velocity

	chocomel_direction = (chocomel_position - global_position).normalized() * Vector3(1,0,1)
	
	# The kid reaches the leash limit a bit sooner for a bit of wiggle room.
	# Also check the first moment the leash is maxed out to trigger animations
	var already_check_leash_limit_reaction := leash_limit_reached
	# NOTE: The drag distance is a bit lowered here to absolutely make sure this is triggere more reliably.
	#		The springyness of the leash can make it hard to actually reach the dragging_distance reliably.
	leash_limit_reached = leash_length >= dragging_distance - 0.25
	if leash_limit_reached and not already_check_leash_limit_reaction:
		leash_limit_just_reached = true
	else:
		leash_limit_just_reached = false
	
	# Update the nearest leash point for the movement target and procedural arm movement
	var no_leash_collisions := leash_corner_points.size() <= 2
	if no_leash_collisions:
		nearest_leash_point_position = chocomel_position * Vector3(1,0,1)
	else:
		nearest_leash_point_position = leash_corner_points[1] * Vector3(1,0,1)
	nearest_leash_point_direction = (nearest_leash_point_position - global_position).normalized()
	nearest_leash_point_distance = (nearest_leash_point_position - global_position).length()
	
	if leash_length_change > 0.0:
		current_velocity_against_chocomel = (
			nearest_leash_point_direction.normalized() * (leash_length_change / delta)
		)
	
	# Factor of how much Pinda is being pulled by Chocomel
	holding_leash = player.leash.current_leash_handle_state == player.leash.leash_handle_states.HELD
	if holding_leash:
		var leash_length_factor := leash_length/dragging_distance
		pull_factor = remap(leash_length_factor, pull_threshold, 1.0, 0.0, 1.0)
		pull_factor = max(pull_factor, 0.0)
	else:
		pull_factor = 0.0
	
	if stamina > previous_stamina:
		stamina_improved = true
	else:
		stamina_improved = false
	previous_stamina = stamina


func set_goal_and_target_points() -> void:
	
	var delta := get_process_delta_time()
	var previous_target_point = target_point
	
	if current_character_state in [character_states.CATCHING_UP, character_states.WALKING_TO_CHOCOMEL]:
		
		goal_point = chocomel_position * Vector3(1,0,1)
		
		if holding_leash:
			target_point = nearest_leash_point_position * Vector3(1,0,1)
		else:
			target_point = goal_point
		
		var target_point_distance := (chocomel_position - (global_position * Vector3(1,0,1))).length()
		
	elif current_character_state == character_states.SEEKING:
		
		goal_point = point_of_interest_location * Vector3(1,0,1)
		target_point = goal_point
	
	elif current_character_state == character_states.PULLING:
		
		goal_point = point_of_interest_location * Vector3(1,0,1)
		
		var global_plane_position := global_position * Vector3(1,0,1)
		
		# Viable target along the leash halfway between chocomel and the goal
		var pinda_to_goal_distance := (goal_point - global_plane_position).length()
		var goal_to_leash_direction := (nearest_leash_point_position - goal_point).normalized()
		var in_between_target = goal_point + (goal_to_leash_direction * pinda_to_goal_distance)
		
		target_point = in_between_target
	
	else:
		# Using the looking direction when idle is a nice starting point for when Pinda moves again
		target_point = global_position + (basis.z * 10.0)
		return



## Set movement target position, distance and direction
## for the movement logic to use, among other variables.
func set_movement_target_variables() -> void:
	
	prev_movement_target_position = movement_target_position
	
	var delta := get_process_delta_time()
	
	# More reliable than movement_target_distance to check if Pinda reached their goal
	goal_point_distance = ((goal_point*Vector3(1,0,1)) - (global_position*Vector3(1,0,1))).length()
	
	# Start calculating the movement target
	movement_target_position = target_point
	set_movement_obstacle_avoidance()
	
	# Lerp movement target for smooth movement and avoiding jittering
	var movement_target_smoothing := 5.0 * delta
	movement_target_position = lerp(
		prev_movement_target_position,
		movement_target_position,
		movement_target_smoothing
	)
	
	movement_target_direction = (movement_target_position - global_position) * Vector3(1,0,1)
	movement_target_direction = movement_target_direction.normalized()
	
	movement_target_distance = (movement_target_position - (global_position * Vector3(1,0,1))).length()
	
	debug_position.global_position = movement_target_position


## Adjust the movement_target_position variable to avoid obstacles
func set_movement_obstacle_avoidance() -> void:
	var target_direction := ((target_point - global_position) * Vector3(1,0,1)).normalized()
	
	# Always reset distance far off on every frame, to start finding the closest one again
	shapecast_collision_distance = 20.0
	
	if not shapecast_obstacles.is_colliding():
		shapecast_collision = null
		return 
	
	# Loop over the collisions to find the closest one
	for idx in shapecast_obstacles.get_collision_count():
		# TODO: This can cause flickiering between multiple shapes frame by frame.
		#		Try to find averaged values between multiple collisions instead.
		var collision_point := shapecast_obstacles.get_collision_point(idx)
		var collision_distance : float = (collision_point - global_position).length()
		var collision_normal := shapecast_obstacles.get_collision_normal(idx)
		
		# Ignore if it might be the floor or a ceiling of a collision object.
		# Only look for walls.
		if abs(collision_normal.y) > 0.5:
			continue
		
		# Ignore collisions that are facing the same direction as the character.
		# This removes the chance to pick up on back-faces once getting too close to objects.
		# Also doesn't consider objects that are behind the character.
		if target_direction.dot(collision_normal) > 0.0:
			continue
		
		# Update collison variables
		shapecast_collision = shapecast_obstacles.get_collider(idx)
		shapecast_collision_point = collision_point
		shapecast_collision_distance = collision_distance
		shapecast_collision_normal = collision_normal
	
	# Don't repell Pinda if the target is closer than the avoided wall
	var target_distance = (target_point - global_position).length()
	if shapecast_collision_distance >= target_distance:
		return
	
	# Strength factor for avoidance based on distance to collision point.
	# Avoids flickering and makes movement a bit more natural.
	var touching_radius : float = collision_shape.shape.radius * 2
	var detection_radius : float = shapecast_obstacles.shape.radius
	var collision_proximity_factor := remap(
		shapecast_collision_distance,
		detection_radius,
		touching_radius,
		0.0,
		abs(pull_factor - 1) # If Pinda is pulled, they can collide with obstacles easier.
	)
	collision_proximity_factor = clamp(collision_proximity_factor, 0.0, 1.0)
	var target_proximity_factor := remap(
		target_distance,
		1.0,
		2.0,
		0.0,
		1.0
	)
	target_proximity_factor = clamp(target_proximity_factor, 0.0, 1.0)
	
	# Calculate the avoidance direction.
	var avoidance_direction := shapecast_collision_normal
	# Remove y direction so it's locked to the ground plane
	#avoidance_direction.y = 0.0
	#avoidance_direction = avoidance_direction.normalized()
	
	var sliding_direction = (avoidance_direction.rotated(Vector3.UP, PI/2))
	var side = sign(sliding_direction.dot(target_direction))
	sliding_direction = sliding_direction * side
	#if collision_proximity_factor >= 0.5:
		#avoidance_direction = sliding_direction
	avoidance_direction = sliding_direction
	
	# Change movement_target_position to collision avoidance
	var avoidance_strength := 6.0
	var avoidance_position := shapecast_collision_point + (avoidance_direction * avoidance_strength)
	movement_target_position = lerp(
		target_point,
		avoidance_position,
		collision_proximity_factor * target_proximity_factor
	)
	
	
	# Debug
	debug_direction.global_rotation = Transform3D.IDENTITY.looking_at(avoidance_direction).basis.get_euler()


# Update targets transforms to snap props to
func set_bone_snapping_targets() -> void:
	
	# Find bones
	var bone_idx_item_spot_generic 		:= skeleton.find_bone('PRP-tennis_ball')
	var bone_idx_item_spot_tennis_ball 	:= skeleton.find_bone('PRP-tennis_ball')
	var bone_idx_item_spot_traffic_cone:= skeleton.find_bone('PRP-traffic_cone')
	var bone_idx_item_spot_shovel 		:= skeleton.find_bone('PRP-shovel')
	# TODO: Replace this with the shoes
	var bone_idx_item_spot_ear_muffs 	:= skeleton.find_bone('PRP-tennis_ball')
	var bone_idx_item_spot_branch 	:= skeleton.find_bone('PRP-branch')

	# Get global transforms for each bone 
	var item_spot_generic 		:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_generic)
	var item_spot_tennis_ball 	:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_tennis_ball)
	var item_spot_traffic_cone 	:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_traffic_cone)
	var item_spot_shovel 		:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_shovel)
	var item_spot_ear_muffs 	:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_ear_muffs)
	var item_spot_branch 	:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_branch)
	
	# Item IDs
	var item_id_generic 		:= Constants.interactable_ids.ITEM_GENERIC
	var item_id_traffic_cone	:= Constants.interactable_ids.TRAFFIC_CONE
	var item_id_tennis_ball 	:= Constants.interactable_ids.TENNIS_BALL
	var item_id_shovel 			:= Constants.interactable_ids.SHOVEL
	var item_id_ear_muffs 		:= Constants.interactable_ids.EAR_MUFFS
	var item_id_branch 		:= Constants.interactable_ids.BRANCH
	
	
	# Set dictionary enties
	bone_snapping_targets = {
		item_id_generic 		: item_spot_generic,
		item_id_traffic_cone 	: item_spot_traffic_cone,
		item_id_tennis_ball 	: item_spot_tennis_ball,
		item_id_shovel 			: item_spot_shovel,
		item_id_ear_muffs 		: item_spot_ear_muffs,
		item_id_branch 		: item_spot_branch,
	}


## Pushing force from Chocomel applied on Pinda
func ice_movement_pushing() -> void:
	var delta := get_physics_process_delta_time()
	
	if not touching_chocomel:
		return
	
	var chocomel_movement_direction := Context.chocomel.current_velocity.normalized()
	var chocomel_movement_speed : float = Context.chocomel.velocity.length()
	
	var pushing_direction := (-chocomel_direction).normalized()
	var pushing_factor := chocomel_movement_direction.dot(pushing_direction)
	pushing_factor = maxf(pushing_factor, 0.0)
	var pushing_speed := chocomel_movement_speed * pushing_factor
	var pushing_acceleration := 3.0 * delta
	new_velocity = new_velocity + (pushing_direction * pushing_speed * pushing_acceleration)


## Reflecting the velocity based on the nearest leash point. 
## Makes sure the velcoity slingshoots around and the max leash length is preserved.
func ice_movement_pulling_and_limiting() -> void:
	var delta := get_physics_process_delta_time()

	var distance_to_nearest_leash_point := (global_position - nearest_leash_point_position).length()
	
	# Check if the leash is near its maximum length
	var leash_stretch_factor : float = (leash_length - dragging_distance) / player.leash_locking_threshold
	leash_stretch_factor = clamp(leash_stretch_factor, 0.0, 1.0)
	
	var nearest_leash_point_velocity := (Context.chocomel.current_velocity).length() * nearest_leash_point_direction
	var relative_velocity_to_chocomel := new_velocity - nearest_leash_point_velocity
	var leash_direction_speed := nearest_leash_point_direction.dot(relative_velocity_to_chocomel)
	var leash_velocity := leash_direction_speed * nearest_leash_point_direction
	var tangental_velocity = relative_velocity_to_chocomel - (leash_velocity * leash_stretch_factor)
	
	new_velocity = tangental_velocity + nearest_leash_point_velocity
	
	# Limit the maximum sliding speed
	var max_sliding_speed := 8.0
	if current_character_state == character_states.BREAK_DOWN:
		max_sliding_speed = 3.0
	var clamped_speed := minf(new_velocity.length(), max_sliding_speed)
	new_velocity = new_velocity.normalized() * clamped_speed
	
	# Position correction when leash is stretched too far or when it should get shorter  
	var position_correction := nearest_leash_point_direction * maxf(leash_length - maximum_leash_length, 0.0)
	global_position += position_correction


## Set the base walking speed that Pinda contributes to the velocity.
func set_walking_movement(delta : float) -> void:
	
	if movement_target_distance < (current_walking_speed * delta):
		# Apply only enought speed to catch up with Chocomel minimum distance (prevent overshoot)
		new_velocity = movement_target_direction * movement_target_distance/delta
	
	else:
		# Regular speed
		new_velocity = movement_target_direction * current_walking_speed


## Apply additional pull or push speed from Chocomel.
func set_pulling_or_pushing_movement(delta : float) -> void:
	
	if current_character_state == character_states.PUSHED:
		
		var pushing_speed : float = min(chocomel_velocity.length(), maximum_pushing_speed)
		var pushing_direction := -chocomel_direction
		new_velocity = pushing_direction * pushing_speed
		return
	
	if pull_factor <= 0.0:
		return
	
	# TODO: I'm using the pure chocomel velocity instead of the actual one to avoid a dependency cycle
	# 		Needs a lot of cleanup
	# WARNING: Using the input instead of the actual Chocomel speed is good but would break if
	#			both characters would ever be stuck against a wall.
	#			Chocomel wouldn't move and still pull Pinda.
	var input_vector3 := Vector3(InputController.movement_vector.x, 0.0, InputController.movement_vector.y)
	var chocomel_target_speed := input_vector3 * chocomel_speed
	var chocomel_pinda_speed_difference : float = chocomel_target_speed.length() - current_walking_speed
	chocomel_pinda_speed_difference = max(chocomel_pinda_speed_difference, 0.0)
	
	# Don't pull if chocomel is moving towards the leash, shortening it.
	if sign(next_leash_point_scalar) > 0.0:
		chocomel_pinda_speed_difference = 0.0
	
	var current_pull_cap : float = (terrain_pull_cap * state_pull_effectiveness)
	var current_pull_speed = min(chocomel_pinda_speed_difference * pull_factor, current_pull_cap)
	
	new_velocity += nearest_leash_point_direction * current_pull_speed
	
	# Friction causing additional velocity acceleration and especially deceleration
	# TODO: Apply delta time correctly for lerping
	# TODO: Maybe remove this? Terrain friction does basially nothing on snow/ground
	#		This was made for ice movement
	var slowing_down : bool = new_velocity.length() < current_velocity.length()
	if slowing_down:
		new_velocity = lerp(current_velocity, new_velocity, terrain_friction)
	else:
		new_velocity = lerp(current_velocity, new_velocity, 0.2)


func conclude_movement() -> void:
	
	# A bit of gravity to stay on the ground
	if not is_on_floor():
		new_velocity.y -= 9.8
	
	# Apply velocity and move
	if new_velocity.length() > 0.0:
		current_velocity = new_velocity
		velocity = current_velocity
		move_and_slide()
		if current_velocity.length() > 0.1:
			set_rotation_from_vector(current_velocity.normalized())
	else:
		velocity = Vector3.ZERO
		current_velocity = Vector3.ZERO


## If any transform override has been queued with the character state, it will be applied and reset now
func set_queued_transform() -> void:
	if queued_transform != Transform3D.IDENTITY:
		global_transform = queued_transform
	queued_transform = Transform3D.IDENTITY


func set_rotation_from_vector(global_direction : Vector3) -> void:
	var angle := global_direction.signed_angle_to(Vector3.BACK, Vector3.UP)
	basis = Basis.IDENTITY.rotated(Vector3.UP, -angle)


## Emit the new position and bone transforms of the characters
func send_movement_changes() -> void:
	has_moved.emit(global_position, current_velocity)


func progress_timers(delta) -> void:
	
	# General timers
	next_tripping_timer -= delta
	
	if pull_factor <= 0.0:
		continue_seeking_timer -= delta
		continue_reward_timer -= delta
	
	remember_reward_timer -= delta
	
	# Mood timeouts after event
	next_lick_timer -= delta
	next_out_of_reach_timer -= delta
	
	# Progressive timers to begin mood drain
	var prologned_tired_dragging := (
		not stamina_improved
		and stamina <= (STAMINA_MAX * 0.5)
	)
	var prologned_snow_dragging := (
		terrain_detector.current_terrain_state == Constants.terrain_states.SNOW
		and current_movement_type ==movement_types.RUN_DRAGGED
	)
	if prologned_tired_dragging or prologned_snow_dragging:
		exhaustion_timer -= delta
	else:
		exhaustion_timer = stamina_timer_exhaustion
	
	if current_character_state == character_states.STUCK and pull_factor >= 1.0:
		floor_dragging_timer -= delta
	else:
		floor_dragging_timer = mood_timer_floor_dragging
	
	var stuck_in_snow : bool = (
		current_character_state == character_states.STUCK
		and terrain_detector.current_terrain_state == Constants.terrain_states.SNOW
	)
	if stuck_in_snow:
		stuck_in_snow_timer -= delta
	else:
		stuck_in_snow_timer = mood_timer_stuck_in_snow


# TODO: This is a complete copy of chocomels code. Maybe de-duplicate this.
## Set character rotation, animation tree variables and other procedural animations.
func set_character_rotation_slices() -> void:
	
	# Rotation in slices. Only do this in non-interactions to align characters properly.
	if not sliced_rotation:
		pass
	else:
		var directional_angle := basis.z.signed_angle_to(Vector3.BACK, Vector3.UP)
		var slice_size := character_rotation_slicer._slice_size
		var slize_number := character_rotation_slicer._slice_numbers
		
		var rotation_slice_offset := -slice_size * 0.5
		
		current_rotation_slice = character_rotation_slicer.get_snapped_slice(
			directional_angle + rotation_slice_offset,
			current_rotation_slice
		)
		
		# Set the rotation slices
		var rotation_start_offset := -PI
		var slice_rotation = (slice_size * (current_rotation_slice+1)) + rotation_start_offset + rotation_slice_offset 
		rotation = Vector3(0.0, -slice_rotation, 0.0)


## Check if the state machine queued the next character and animation state. 
## Then travel to the next animation state. If aniamtion state started playing,
## set the new current_character_state.
## This should happen at the end of the frame, so the first frame of the new
## character state has more pivot bone information availible.
func set_animation_tree_travel() -> void:
	var tree_playback : AnimationNodeStateMachinePlayback = animation_tree["parameters/AnimationStates/playback"]
	# TODO: SHould the current state also be set at the end of this function?
	#		Otherwise it already traveled to a new state which is outdated in this variable.
	previous_animation_state = current_animation_state
	current_animation_state = tree_playback.get_current_node()
	previous_animation_position = current_animation_position
	current_animation_position = tree_playback.get_current_play_position()
	current_animation_length = tree_playback.get_current_length()
	
	var new_animation_is_set := queued_animation_state != current_animation_state
	
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


## Force start the character and animation state instead of putting it in the queue.
func force_next_character_state(next_character_state : character_states, next_animation_state : animation_states) -> void:
	current_character_state = next_character_state
	queued_animation_state = animation_state_names[next_animation_state]
	queued_character_state = -1
	
	state_was_forced = true


## Force start the animation state instead of putting it in the queue.
func force_next_animation(anim_state : String) -> void:
	queued_animation_state = anim_state
	
	var tree_playback : AnimationNodeStateMachinePlayback = animation_tree["parameters/AnimationStates/playback"]
	tree_playback.start(anim_state)


## Angling the arm towards the next leash point in specific states.
## ...
func set_procedural_arm_rotation() -> void:
	
	if not procedural_arm_movement:
		update_leash_handle_position(Transform3D.IDENTITY)
		return
		
	# Rotations that will affect the arm rotations
	# NOTE: A looking_at() could be more accurate but this is only needed for core gameplay animations
	var pinda_rotation_y = basis.get_euler().y
	var leash_target_rotation_y := Basis(
		nearest_leash_point_direction.cross(Vector3.UP),
		Vector3.UP,
		nearest_leash_point_direction).orthonormalized().get_euler().y
	
	# Get the bone idx and transforms for the chain I'm editing
	var shoulder_bone_idx 			:= skeleton.find_bone("shoulder-L")
	# As this is the highest hierarchy bone here, it's gonna be the global pose.
	# The rest are local poses that will be added on top of this one.
	var shoulder_bone_transform 	:= skeleton.get_bone_global_pose(shoulder_bone_idx)
	var arm_bone_idx 				:= skeleton.find_bone("arm_master-L")
	var arm_bone_transform_local 	:= skeleton.get_bone_pose(arm_bone_idx)
	
	var global_leash_target_rotation_y = wrapf(
		leash_target_rotation_y - pinda_rotation_y,
		-PI,
		PI
	)
	
	# Only update the target arm rotation if not in angles that intersect with the body
	var in_arm_rotation_range := (
		global_leash_target_rotation_y > -1.5
		and global_leash_target_rotation_y < 2.0
	)
	if in_arm_rotation_range:
		current_arm_rotation_y = global_leash_target_rotation_y
		
		current_arm_rotation_slice = arm_rotation_slicer.get_snapped_slice(
			current_arm_rotation_y,
			current_arm_rotation_slice
		)
		
		# Convert the rotation slice to 
		var slice_number := arm_rotation_slicer._slice_numbers
		current_arm_rotation_y = remap(
			current_arm_rotation_slice +1,
			1,
			slice_number,
			-PI,
			PI
		)
		
		# Adjust start rotation look down instead of right
		current_arm_rotation_y = wrapf(current_arm_rotation_y + TAU, -PI, PI)

	# Amount of applied rotation for each bone
	var shoulder_rotate_factor := 0.2
	var arm_rotate_factor := 0.6
	
	# Apply rotation to bones
	var new_shoulder_bone_transform := shoulder_bone_transform.rotated(
		Vector3.UP,
		current_arm_rotation_y * shoulder_rotate_factor
	)
	var original_arm_bone_origin := arm_bone_transform_local.origin
	var new_arm_bone_transform_local := arm_bone_transform_local.rotated(
		Vector3.BACK,
		current_arm_rotation_y * arm_rotate_factor
	)
	new_arm_bone_transform_local.origin = original_arm_bone_origin
	# Apply shoulder pose to local arm pose to get global arm pose 
	#new_arm_bone_transform_local = shoulder_bone_transform * new_arm_bone_transform_local
	
	# Send transforms to be overridden for the render frame
	procedural_animator._on_bone_has_been_transformed(shoulder_bone_idx, new_shoulder_bone_transform)
	procedural_animator._on_bone_has_been_transformed_local(arm_bone_idx, new_arm_bone_transform_local)

	update_leash_handle_position(new_shoulder_bone_transform * new_arm_bone_transform_local)


## Regular stumbling animation while moving
func trigger_tripping_animation() -> void:
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Tripping/request"
	] = 1
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Tripping Type/blend_amount"
	] = -1
	
	if terrain_detector.current_terrain_state == Constants.terrain_states.ICE:
		animation_tree[
			"parameters/AnimationStates/Ice Movement/Tripping/request"
		] = 1
	
	InputController.trigger_rumble()


## Stumble and rolling for tripping over terrain assets.
func trigger_rolling_animation() -> void:
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Tripping/request"
	] = 1
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Tripping Type/blend_amount"
	] = 0
	
	InputController.trigger_rumble()


## Stumble and rolling for tripping over terrain assets.
func trigger_yanking_animation() -> void:
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Tripping/request"
	] = 1
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Tripping Type/blend_amount"
	] = 1
	
	InputController.trigger_rumble()


## Update the position that needs to be sent out to the leash to place the handle.
func update_leash_handle_position(
	arm_bone_transform : Transform3D
) -> void:
	
	if not procedural_arm_movement:
		# Only take the pure leash handle pivot transform
		var leash_handle_bone_idx 				:= skeleton.find_bone("leash_handle")
		var leash_handle_bone_transform_local 	:= skeleton.get_bone_global_pose(leash_handle_bone_idx)
		left_hand_bone_global_transform = skeleton.global_transform * leash_handle_bone_transform_local
	else:
		# Here on out I calculate the target position of the leash handle to signal to the leash
		
		# Get the rest of the hierarchy between the arm bone and leash target bone
		var arm_bone_idx 	:= skeleton.find_bone("arm_master-L")
		var grab_bone_idx 	:= skeleton.find_bone("P-grab-L")
		
		if arm_bone_transform == Transform3D.IDENTITY:
			arm_bone_transform 	= skeleton.get_bone_global_pose(arm_bone_idx)
		
		var relative_transform_arm_grab := skeleton.get_bone_global_pose(arm_bone_idx).inverse() * skeleton.get_bone_global_pose(grab_bone_idx)
		
		var handle_bone_transform_global := (
			arm_bone_transform
			* relative_transform_arm_grab
		)
		
		# Update handle target bone to signal out later
		left_hand_bone_global_transform = skeleton.global_transform * handle_bone_transform_global
	
	updated_hand_transform.emit(left_hand_bone_global_transform)


## Angling the mouth towards the view angle and flipping the mouth UVs and rotation when needed.
func set_procedural_mouth_rotation() -> void:
	var pinda_rotation_y = basis.get_euler().y
	var head_bone_idx := skeleton.find_bone("head")
	var head_rotation_y := skeleton.get_bone_global_pose(head_bone_idx).basis.get_euler().y
	var combined_rotation_y : float = pinda_rotation_y + head_rotation_y
	
	# This Euler ommits PI from the Y axis to make later remapping and clamping easier (range doesn't wrap on PI but on 0)
	var new_mouth_rotation := Quaternion.from_euler(Vector3(-PI/2, -combined_rotation_y, 0.0))
	
	var new_mouth_rotation_euler : Vector3 = new_mouth_rotation.get_euler()
	# Dampen how much the mouth is rotated exactly to the camera.
	# This way the character needs to rotate even further for the mouth to reach the sides.
	var rotation_dampen_factor := 0.5
	new_mouth_rotation_euler.y = remap(
		new_mouth_rotation_euler.y,
		-PI,
		PI,
		-PI * rotation_dampen_factor,
		PI * rotation_dampen_factor
	)
	
	# Limit mouth rotations to left & right
	var mouth_rotation_limit := 0.675
	new_mouth_rotation_euler.y = clamp(
		new_mouth_rotation_euler.y,
		-mouth_rotation_limit,
		mouth_rotation_limit
	)
	
	# Flip mouth when crossing the middle
	var flipped_mouth := false
	if sign(new_mouth_rotation_euler.y) > 0.0:
		flipped_mouth = true
	
	# Rotate the mouth
	var gdt_mouth_bone_idx : int = skeleton.find_bone("GDT-mouth")
	var mouth_transform := skeleton.get_bone_rest(gdt_mouth_bone_idx)
	
	mouth_transform = mouth_transform.rotated_local(mouth_transform.basis.y, new_mouth_rotation_euler.y)
	
	# Flip the mouth
	if flipped_mouth:
		mouth_transform = mouth_transform.scaled_local(Vector3(-1.0, 1.0, 1.0))
	# TODO: Quick hack to hace the mouth shading look ok when flipped. Find a better way.
	for bone in skeleton.get_children():
		if bone is BoneAttachment3D and bone.name.contains("GEO-mouth-"):
			for mesh in bone.get_children():
				if mesh is MeshInstance3D and mesh.name.contains("GEO-mouth-"):
					var mesh_data = mesh.get("mesh")
					var material = mesh_data.get("surface_0/material")
					material.set("shader_parameter/flip_normals", flipped_mouth)
					material.set("shader_parameter/backface_color", flipped_mouth)
	
	procedural_animator._on_bone_has_been_transformed_local(gdt_mouth_bone_idx, mouth_transform)


## Update the current_movement_type 
func set_movement_speed_type() -> void:
	
	# Walking speed slice to get a result with a threshold
	current_walking_speed_slice = walking_speed_slicer.get_snapped_slice(
		velocity.length(),
		current_walking_speed_slice
	)
	
	if (
		(
			(current_walking_speed_slice > 2 and pull_factor > DANGER_PULL_FACTOR)
			or pull_factor >= 1.0
		)
		and current_character_state != character_states.SEEKING
	):
		current_movement_type = movement_types.RUN_DRAGGED
	elif current_walking_speed_slice >= 3:
		current_movement_type = movement_types.RUN
	elif velocity.length() >= maximum_walking_speed * 0.1:
		current_movement_type = movement_types.WALK
	else:
		current_movement_type = movement_types.IDLE


func get_speed_factor() -> float:
	
	if current_movement_type == movement_types.WALK:
		return 0.16
	elif current_movement_type == movement_types.RUN:
		return 0.51
	elif current_movement_type == movement_types.RUN_DRAGGED:
		return 1.0
	else:
		return 0.0


func set_animation_tree_parameters() -> void:
	
	animation_tree[
		"parameters/pompom small/add_amount"
	] = pompom_scale_down_factor
	
	set_movement_speed_type()
	
	var pulled_on_ice := 0.0
	if (
		terrain_detector.current_terrain_state == Constants.terrain_states.ICE
		and pull_factor > 0.0
	):
		pulled_on_ice = 1.0
	animation_tree[
		"parameters/AnimationStates/Ice Movement/Idle - Moving/blend_amount"
	] = pulled_on_ice
	
	var excited_face_factor := 0.0
	if (
		(point_of_interest_location - global_position).length() < 3.0
		and velocity.length() <= TRAFFIC_CONE_GRAB_SPEED
		and current_character_state == character_states.SLIDING
	):
		excited_face_factor = 1.0
		emote_bubbles.trigger_emote(
			emote_bubbles.emote_states.EXCLAMATION,
			0.1
		)
	animation_tree[
		"parameters/AnimationStates/Ice Movement/Excited Face/blend_amount"
	] = excited_face_factor
	
	# Set movement parameters
	var speed_factor := get_speed_factor()
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Moving 1D Regular/blend_position"
	] = speed_factor
	
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Moving 1D Tired/blend_position"
	] = speed_factor
	
	# Use the leashless run animation if there's no leash held
	var without_leash_factor := 1.0
	if holding_leash:
		without_leash_factor = 0.0
	
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Without Leash/blend_amount"
	] = without_leash_factor
	
	# Either idle or use movement
	var movement_factor : float
	if speed_factor == 0.0:
		movement_factor = 0.0
	else:
		movement_factor = 1.0
	
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Idle - Moving Factor/blend_amount"
	] = movement_factor
	
	# Push against chocomel
	var low_speed : bool = current_movement_type in [movement_types.WALK, movement_types.IDLE]
	var target_direction := (target_point - global_position).normalized()
	var chocomel_in_the_way := (
		target_direction.dot(chocomel_direction) >= 0.8
		and current_character_state != character_states.CATCHING_UP
	)
	
	var pushing_factor := 0.0
	if low_speed and touching_chocomel and chocomel_in_the_way:
		pushing_factor = 1.0
	
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Pushing Chocomel/blend_amount"
	] = pushing_factor
	
	# Set correct walk speed playback factor
	var speed_walk_factor := 1.0
	if current_movement_type == movement_types.WALK:
		# Adjust animation speed scale for walking
		var maximum_walking_speed := 1.8 # TODO: Calculate this value in case things change.
		speed_walk_factor = remap(current_velocity.length(), 0.0, maximum_walking_speed, 0.0, 1.0)
		speed_walk_factor = clamp(speed_walk_factor, 0.0, 1.0)
	
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Walking Speed Factor/scale"
	] = speed_walk_factor
	
	var stamina_factor : float
	# Don't use stamina animations in the intro since they are designed with the leash and dragging in mind
	if stamina <= 5.0 and GameStatus.current_game_state != GameStatus.game_states.INTRO:
		stamina_factor = 0.0
	else:
		stamina_factor = 1.0
		
	
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Stamina Movement/blend_amount"
	] = stamina_factor
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Stamina Idle/blend_amount"
	] = stamina_factor
	
	# Mood variables
	var mood_factor : float
	if mood <= 5.0:
		mood_factor = 0.0
	else:
		mood_factor = 1.0
	
	# Set calling out variant
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Sad Face/blend_amount"
	] = abs(mood_factor - 1)
	animation_tree[
		"parameters/AnimationStates/Seeking and Catching Up/Sad Idle/blend_amount"
	] = abs(mood_factor - 1)
	
	# Use the correct animation when getting stuck
	var snow_or_ground_factor := 1.0
	if terrain_detector.current_terrain_state == Constants.terrain_states.SNOW:
		snow_or_ground_factor = 0.0
	
	current_pull_blend_slice = pull_blend_slicer.get_snapped_slice(
		pull_factor,
		current_pull_blend_slice
	)
	
	# Most other animation states
	var current_pull_blend_factor : float = (current_pull_blend_slice+1) / 5.0
	animation_tree[
		"parameters/AnimationStates/Stuck/Fallen/blend_position"
	] = Vector2(snow_or_ground_factor, current_pull_blend_factor)
	animation_tree[
		"parameters/AnimationStates/Stuck/Falling/blend_position"
	] = snow_or_ground_factor
	animation_tree[
		"parameters/AnimationStates/Getting Up/blend_position"
	] = snow_or_ground_factor
	
	# Set correct lay down animation for starting petting
	animation_tree[
		"parameters/AnimationStates/Lay Down/blend_position"
	] = lay_down_type_factor
	
	# Restart petting loops and set new random petting animation
	if animation_state_finished and current_animation_state == animation_state_names[animation_states.PETTING_LOOPS]:
		animation_tree[
			"parameters/AnimationStates/Petting Loops/TimeSeek/seek_request"
		] = 0.0
	
	animation_tree[
		"parameters/AnimationStates/Petting Loops/Petting_BlendSpace1D/blend_position"
	] = petting_version_value


## Check what the spotted node is and update variables.
func spotted_point_of_interest(node : Node3D) -> void:
	
	var spotted_id : Constants.interactable_ids
	
	if "interactable_id" in node:
		spotted_id = node.interactable_id
	elif "interactable_id" in node.get_parent():
		spotted_id = node.get_parent().interactable_id
	else:
		assert(true, "The spotted point of interest has not id!")
	
	# Check if Pinda can interact with the interest point already.
	# If yes, store type of interest and seek it out
	if spotted_id in Constants.item_ids:
		point_of_interest_item_id = node.item_id
		point_of_interest_location = node.global_position
		point_of_interest_location.y = 0.0
	
	elif spotted_id == Constants.interactable_ids.SNOWMAN:
		# Check if Pinda is holding an item for the snowman
		var is_holding_item := false
		for item_id in GameStatus.items_status:
			if Context.interactable_nodes[item_id].item_state == GameStatus.item_states.HELD:
				is_holding_item = true
				continue
		if not is_holding_item:
			return
		
		point_of_interest_location = node.animation_start_spot.origin
		point_of_interest_location.y = 0.0
	
	elif spotted_id == Constants.interactable_ids.GATE:
		point_of_interest_location = node.global_position
		point_of_interest_location.y = 0.0
	
	current_point_of_interest = node
	point_of_interest_interaction_id = spotted_id
	


func reset_point_of_interest() -> void:
	
	previous_point_of_interest = current_point_of_interest
	current_point_of_interest = null
	point_of_interest_location = Vector3.ZERO


## Set the appropriate interaction when reaching a point of interest.
func check_reaching_point_of_interest() -> bool:
	
	# Close enough to the goal point
	if goal_point_distance > 0.1:
		return false
	
	# Snap to the goal point
	global_position.x = goal_point.x
	global_position.z = goal_point.z
	
	if point_of_interest_interaction_id in Constants.item_ids:
		set_state_item_pickup()
	elif point_of_interest_interaction_id == Constants.interactable_ids.SNOWMAN:
		set_state_snowman_decorating()
	
	reached_point_of_interest.emit(point_of_interest_interaction_id)
	return true
	
	# TODO: Use recover_mood(mood_heal_check_reaching_point_of_interest) for other interactions


## Set up Pindas location and orientation so they are perfectly synched up 
## for an animation with chocomel together. 
func set_interaction_transform() -> void:
	
	# Pivot bone info
	# TODO: Always taking this fixed distance instead of the actual bone.
	#		Because I couldn't always trust the aniation to have the bone on the right spot
	var chocomel_interaction_distance := 1.35 
	#var chocomel_pivot_bone := skeleton.find_bone("Chocomel")
	#var chocomel_pivot_transform:= skeleton.get_bone_global_pose(chocomel_pivot_bone)
	
	# Determine needed interaction distance for animation
	var chocomel_offset : float = player.chocomel.origin_offset_z
	var chocomel_offset_vector : Vector3 = Vector3(0.0, 0.0, chocomel_offset)
	#var interaction_distance := chocomel_offset + chocomel_pivot_transform.origin.z
	var interaction_distance := chocomel_offset + chocomel_interaction_distance
	
	# Set position distance and orientation
	var current_heigth := global_position.y
	global_position = player.chocomel.global_position - (interaction_distance * chocomel_direction)
	global_position.y = current_heigth
	set_rotation_from_vector(chocomel_direction)


## Function for character state changes
func set_state_item_pickup() -> void:
	
	queue_next_character_state(
		character_states.INTERACTION,
		animation_states.PICK_UP
	)
	current_interaction_type = interaction_types.ITEM_PICKUP
	
	var pick_up_tree_playback : AnimationNodeStateMachinePlayback = animation_tree["parameters/AnimationStates/Pick Up/playback"]
	if point_of_interest_item_id in pick_up_animations:
		pick_up_tree_playback.travel(pick_up_animations[point_of_interest_item_id])
	else:
		pick_up_tree_playback.travel("Generic Pick Up")


## Function for character state changes
func set_state_snowman_decorating() -> void:
	
	queue_next_character_state(
		character_states.INTERACTION,
		animation_states.DECORATING
	)
	current_interaction_type = interaction_types.SNOWMAN_DECORATING


## Call Chocomel over for a celebretory moment together.
func set_state_reward_chocomel() -> void:
	
	remember_reward_timer = REMEMBER_REWARD_TIMER_START
	reward_init_location = global_position
	
	queue_next_character_state(
		character_states.IDLE,
		animation_states.CALLING_OUT
	)
	current_idle_type = idle_types.ANNOUNCE_INTERACTION


## React to bark appropriately
func set_state_react_to_bark() -> void:
	return #TODO: improve and use again
	
	# Only switch if Pinda is seeking something out
	if current_character_state != character_states.SEEKING:
		return
	
	force_next_character_state(
		character_states.IDLE,
		animation_states.BARK_REACT
	)
	current_idle_type = idle_types.BARK_REACTION


func recover_mood(value : float, emote_duration := EMOTE_DURATION) -> void:
	mood += value
	
	emote_bubbles.trigger_emote(
		emote_bubbles.emote_states.HEARTS,
		emote_duration
	)
	
	#sound_effects.play_emote_sound(EmoteBubble.emote_states.HEARTS, 0.35)
	#sound_effects.play_sound(PindaSFX.SOUNDS.RECOVER_MOOD, 0.35)


func reduce_mood(value : float, emote_duration := EMOTE_DURATION) -> void:
	mood -= value
	
	# For falling the emote is triggered a bit later in the state logic
	if value != mood_impact_falling:
		emote_bubbles.trigger_emote(
			emote_bubbles.emote_states.DOOM_SPIRAL,
			emote_duration
		)


func check_ending() -> bool:
	return GameStatus.ready_for_ending


## On ready, create a procedural ani
func create_procedural_animator_node() -> void:
	procedural_animator = ProceduralAnimator.new()
	skeleton.add_child(procedural_animator)
	procedural_animator.owner = owner


func set_up_signal_bus():
	SignalBus.connect("pinda_tripping_hazard", _on_tripping_hazard)


func footstep(foot1 : feet, foot2 : feet = -1):
	if terrain_detector.current_terrain_state != Constants.terrain_states.NONE:
		return
	for f in [foot1, foot2]:
		if f == -1:
			continue
		var foot_transform := skeleton.get_bone_global_pose(skeleton.find_bone(foot_bones[f]))
		footstep_fx.add_footstep(
			(skeleton.global_transform * foot_transform).origin,
			current_velocity.normalized()
		)
		
	if terrain_detector.current_terrain_state == Constants.terrain_states.SNOW:
		sound_effects.footstep_snow_lift_sfx.play()

# NOTE: SIGNAL FUNCTIONS


func _on_position_changed(new_position : Vector3, current_velocity : Vector3):
	RenderingServer.global_shader_parameter_set("pinda_position", new_position)


func _on_tripping_hazard():
	# Only if Pinda is pulled, have terrain elements effect stamina
	var is_pulled := pull_factor >= DANGER_PULL_FACTOR
	if not is_pulled:
		return
	
	if current_character_state != character_states.CATCHING_UP:
		return
	
	if next_tripping_timer > 0.0:
		return
		
	stamina -= stamina_impact_tripping
	emote_bubbles.trigger_emote(
		emote_bubbles.emote_states.SWEAT,
		EMOTE_DURATION
	)
	next_tripping_timer = tripping_timeout_duration
	trigger_rolling_animation()


func _on_leash_changed_leash_points(points: PackedVector3Array, length : float) -> void:
	leash_corner_points = points
	leash_length_change = length - leash_length
	leash_length = length


func _on_chocomel_has_moved(
		new_position: Vector3,
		new_velocity : Vector3,
		leash_scalar : float,
		moving_to_pinda_scalar : float,
		collar_pivot_position : Vector3
) -> void:
	chocomel_position = new_position
	chocomel_velocity = new_velocity
	next_leash_point_scalar = leash_scalar
	chocomel_moving_to_pinda_scalar = moving_to_pinda_scalar


func _on_chocomel_has_barked() -> void:
	set_state_react_to_bark()


func _on_interest_detector_area_entered(area: Area3D) -> void:
	if current_point_of_interest != null:
		return
	spotted_point_of_interest(area)


func _on_interest_detector_body_entered(body: Node3D) -> void:
	if current_point_of_interest != null:
		return
	spotted_point_of_interest(body)


func _on_chocomel_has_been_digging() -> void:
	chocomel_did_digging = true


## Chocomel requested an interaction. 
## Check if this is possible on Pinda and signal back a confirmation or denial.
func _on_chocomel_request_interaction(interaction: int) -> void:
	
	var chocomel_interactions = Context.chocomel.interaction_types
	
	# Check if the gate challege is present and active. Don't allow licks.
	# Pinda might be on the other side of the fence
	var gate_sequence_active := false
	if Context.sequence_gate == null:
		pass
	elif Context.sequence_gate.active_sequence:
		gate_sequence_active = true
	
	if gate_sequence_active:
		confirmed_interaction.emit(false)
		return
	
	if interaction == chocomel_interactions.LICK:
		
		var conditions_met := (
			terrain_detector.current_terrain_state != Constants.terrain_states.ICE
			and current_character_state == character_states.CATCHING_UP
		)
		if not conditions_met:
			confirmed_interaction.emit(false)
			return
		
		confirmed_interaction.emit(true)
		force_next_character_state(
			character_states.INTERACTION,
			animation_states.LICKED
		)
		current_interaction_type = interaction_types.CHOCOMEL_LICK
	
	elif interaction == chocomel_interactions.SNUGGLE:
		
		var conditions_met := (
			terrain_detector.current_terrain_state != Constants.terrain_states.ICE
			and current_character_state == character_states.CATCHING_UP
			and mood < 5.0
		)
		if not conditions_met:
			confirmed_interaction.emit(false)
			return
		
		confirmed_interaction.emit(true)
		force_next_character_state(
			character_states.INTERACTION,
			animation_states.SNUGGLE
		)
		current_interaction_type = interaction_types.SNUGGLE
	
	elif interaction == chocomel_interactions.SUPERLICK:
		
		var conditions_met := (
			terrain_detector.current_terrain_state == Constants.terrain_states.NONE
			and current_character_state == character_states.GETTING_UP
			and current_animation_position < 3.0
		)
		if not conditions_met:
			confirmed_interaction.emit(false)
			return
		
		confirmed_interaction.emit(true)
		force_next_character_state(
			character_states.INTERACTION,
			animation_states.SUPERLICK
			)
		current_interaction_type = interaction_types.CHOCOMEL_SUPERLICK
	
	elif interaction == chocomel_interactions.PETTING:
		confirmed_interaction.emit(true)
		
		force_next_character_state(
			character_states.INTERACTION,
			animation_states.LAY_DOWN
			)
		current_interaction_type = interaction_types.PETTING
	
	else:
		confirmed_interaction.emit(false)


## Pinda has confirmed or denied the interaction.
func _on_chocomel_confirmed_interaction(confirmation : bool) -> void:
	interaction_confirmed = confirmation


## Track what Chocomel is ongoingly touching
func _on_touch_detector_body_entered(body: Node3D) -> void:
	#print("TOUCH DETECTOR ENTERED NR: " + str(Engine.get_frames_drawn()))
	
	ongoing_touching.append(body)
	#print("Detected touch = " + str(body.name))
	
	if body.name == "Chocomel":
		just_touched_chocomel = true


## Check what Chocomel is no longer touching
func _on_touch_detector_body_exited(body: Node3D) -> void:
	#print("TOUCH DETECTOR EXITED NR: " + str(Engine.get_frames_drawn()))
	
	ongoing_touching.erase(body)
	#print("Exited touch = " + str(body.name))

## SAVE AND LOAD

func save_state():
	var save_dict := {
		"node" : get_path(),
		"mood" : mood,
		"stamina" : stamina,
		"current_character_state" : current_character_state,
		"pompom_scale_down_factor" : pompom_scale_down_factor,
	}
	return save_dict


func _on_chocomel_ended_interaction() -> void:
	interaction_ended = true


func _on_chocomel_set_new_petting_loop(value: float) -> void:
	petting_version_value = value
	animation_state_finished = true


## The bone snapping targets are only set once the animation is actionally applied near the end of the process
func _on_animation_tree_mixer_applied() -> void:
	set_bone_snapping_targets()
	
	set_procedural_mouth_rotation()
	set_procedural_arm_rotation()
	
	updated_bone_transforms.emit()
	
	# Check if the current_animation is on the frame step
	var prev_frame_time_modulo = frame_time_modulo
	frame_time_modulo = fmod(current_animation_position, FRAME_TIME)
	if prev_frame_time_modulo > frame_time_modulo:
		on_animation_step = true
	
	# Update context variables for state logic and animation parameters
	animation_state_changed = previous_animation_state != queued_animation_state
	animation_state_finished = current_animation_position == current_animation_length
	animation_started = current_animation_position < previous_animation_position
	animation_looped = animation_started and not animation_state_changed


func _on_animation_tree_animation_finished(anim_name: StringName) -> void:
	animation_finished = true
