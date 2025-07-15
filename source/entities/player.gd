extends Node3D

class_name Player

@export_category("Player Entity Values")
@export_subgroup("Input Values")
@export var action_cancel_speed := 0.8
@export_subgroup("Distance Values")
@export var maxmimum_leash_length := 6.5 ## The maximum length that the the characters can be from each other.
@export var leash_locking_threshold := 0.5 ## Threshold towards the maximum leash length that triggers Pinda to be dragged or pulled
@export var catching_up_distance := 2.5 ## Ideal distance between Pinda and Chocomel to interact. Pinda will prefer to move to this distance.
@export var close_interaction_distance := 1.35

@export_subgroup("Chocomel Values")
@export var chocomel_speed := 5.5 ## Maximum speed of Chocomel in meters per second.
@export var chocomel_speed_pushing := 2.0 ## Maximum speed of Chocomel in meters per second.
@export var chocomel_speed_pulling := 3.0 ## Maximum speed of Chocomel in meters per second.
@export var chocomel_rotation_speed := 1.5 ## Lowering this makes the rotation less snappy, but can also cause issues when the input is faster than the rotation.
@export var chocomel_acceleration := 6.0
@export var chocomel_rotation_acceleration := 15.0 ## The acceleration & deceleration of only the angular velocity.
@export var chocomel_speed_acceleration := 4.8 ## The acceleration & deceleration of only the directional velocity.
@export var chocomel_speed_acceleration_ice := 1.0
@export var chocomel_pushing_speed_ground := 1.5 ## Speed in meters per second in maximum psuhing speed against Pinda.
@export var chocomel_pushing_speed_snow := 0.8 ## Speed in meters per second in maximum psuhing speed against Pinda.

@export_subgroup("Pinda Values")

@export var pinda_walk_speed_ground := 3.0 ## The maximum speed that Pinda can contribute to their speed via waling and running. In meters per second
@export var pinda_walk_speed_snow := 2.0 ## The maximum speed that Pinda can contribute to their speed via waling and running. In meters per second.
@export var pinda_walk_speed_ice := 0.0 ## The maximum speed that Pinda can contribute to their speed via waling and running. In meters per second.
@export var pinda_pull_cap_regular := 4.0 ## The max meters per second that Chocomel can add to Pindas speed while pulling them. Only so much speed to catch up with Chocomels current speed will be applied.
@export var pinda_pull_cap_snow := 1.5 ## The max meters per second that Chocomel can add to Pindas speed while pulling them. Only so much speed to catch up with Chocomels current speed will be applied.
@export var pinda_pull_cap_ice := 10.0 ## The max meters per second that Chocomel can add to Pindas speed while pulling them. Only so much speed to catch up with Chocomels current speed will be applied.

@export_subgroup("Pinda Stamina")
# Needed force to make Pinda instantly fall.
@export var yank_fall_force = 5.5 ## Total velocity difference between pinda and Chocomel to make the kid fall
# Recovery over time values
@export var stamina_recovery_regular := 0.5 ## Recovery per second while in motion.
@export var stamina_recovery_stationary := 1.5 ## Recovery per second while stationary.
@export var stamina_recovery_digging := 3.0 ## Recovery per second while digging the kid out.
# Drain over time values
@export var stamina_drain_regular := 0.0 ## Stamina drain per second multiplied with the pull force excerted on Pinda. Used when the leash is nearing or at maximum length.
@export var stamina_drain_snow  := 3.0 ## Stamina drain per second multiplied with the pull force excerted on Pinda. Used when the leash is nearing or at maximum length.
@export var stamina_drain_pushing := 3.0 ## Stamina drain per second based on input vector when pushing
@export var stamina_drain_exhaustion = 0.5
# Instant impact values
@export var stamina_impact_tripping := 4.0 ## Instantly subtraced stamina when tripping over roots, rocks, shrubs and other pass-through obstacles. Only triggered when Pinda is being pulled by Chocomel.
@export var stamina_impact_collision: = 5.0 ## Instantly subtraced stamina when colliding with static obstacles like trees and rocks. The angle of the collision is used as a factor so only direct collisions are an instant fall. The pull strength is also a factor.
@export var stamina_impact_chocomel := 5.0 ## Instantly subtraced stamina when running into Pinda too hard.
# Timer values
@export var tripping_timeout_duration := 2.0 ## Cooldown in seconds before the next collision can occur. The animation length is also considered for this value.

@export_subgroup("Mood Values - General")
# Instant heal values
@export var mood_heal_comfort = 10.0
@export var mood_heal_item_pickup = 6.0
@export var mood_heal_item_placed = 6.0
@export var mood_heal_lick = 1.0
@export var mood_heal_reward = 2.0

@export_subgroup("Mood Values - Physical")
# Instant heal values
@export var mood_heal_help_get_up = 1.0
# Instant impact values
@export var mood_impact_falling = 2.0
# Drain over time values
@export var mood_drain_floor_dragging = 0.5
@export var mood_drain_stuck_in_snow = 0.5
# Timer values
@export var mood_timeout_lick = 10.0
@export var stamina_timer_exhaustion = 5.0
@export var mood_timer_floor_dragging = 5.0
@export var mood_timer_stuck_in_snow = 6.0

@export_subgroup("Mood Values - Mental")
# Instant heal values
@export var mood_heal_reached_point_of_interest = 3.0
# Instant impact values
@export var mood_impact_yanking = 6.0
# Drain over time values
@export var mood_drain_out_of_reach = 0.5
# Timer values
@export var mood_timer_out_of_reach = 4.0
@export var mood_timer_yanking = 6.0

@export_category("Member variables")
@export var camera : Node3D
@export var chocomel : CharacterBody3D
@export var pinda : CharacterBody3D
@export var leash : Leash


func _ready() -> void:
	# Init relationship to game state
	Context.player = self
	add_to_group("Persist")

func save_state():
	var save_dict := {
		"node" : get_path(),
		"pinda_pos_x" : pinda.position.x,
		"pinda_pos_y" : pinda.position.y,
		"pinda_pos_z" : pinda.position.z,
	}
	return save_dict

func load_state(node_data):
	pinda.position.x = node_data["pinda_pos_x"]
	pinda.position.y = node_data["pinda_pos_y"]
	pinda.position.z = node_data["pinda_pos_z"]
	chocomel.position.x = node_data["pinda_pos_x"]
	chocomel.position.y = node_data["pinda_pos_y"]
	chocomel.position.z = node_data["pinda_pos_z"]
	
	leash.reset()
