extends StaticBody3D


const PINDA_RETURN_DISTANCE := 6.0

var pinda_is_near := true

# For characters to check if this is not an invisible level boundary
var is_physical_object := true

# Member variables
@export var skeleton : Skeleton3D
@export var animation_tree : AnimationTree
@export var emote_bubble_hat : EmoteBubble
@export var emote_bubble_nose : EmoteBubble
@export var emote_bubble_cane : EmoteBubble

var animation_start_spot : Transform3D
var handle_rest_spot : Transform3D

# Dictionary of pivot point positions
var item_snapping_targets : Dictionary

@onready var interactable_id := Constants.interactable_ids.SNOWMAN


func _ready() -> void:
	
	# Steal the rotation of the parent. This is needed because the 
	# parent is placed and rotated in the level. To make prop interactions work well,
	# there can't be any added rotations on the prop.
	var parent_transform = get_parent().global_transform
	get_parent().global_transform = Transform3D.IDENTITY
	global_transform = parent_transform
	
	# Init relationship to game state
	Context.interactable_nodes[interactable_id] = self
	
	set_bone_targets()


func _physics_process(delta: float) -> void:
	
	#  Check if pinda just returned or left to show emotes
	var pinda_distance := (Context.pinda.global_position - global_position).length()
	var previous_pinda_is_near := pinda_is_near
	pinda_is_near = pinda_distance <= PINDA_RETURN_DISTANCE
	var pinda_just_returned := pinda_is_near and pinda_is_near != previous_pinda_is_near
	
	if pinda_just_returned and GameStatus.current_game_state == GameStatus.game_states.GAMEPLAY:
		start_missing_item_emotes()
	elif not pinda_is_near :
		stop_missing_item_emotes()


func start_missing_item_emotes() -> void:
	# Signify missing hat
	if GameStatus.items_status[Constants.interactable_ids.TRAFFIC_CONE] == GameStatus.item_states.NONE:
		emote_bubble_hat.trigger_emote(emote_bubble_hat.emote_states.MISSING_HAT)
	# Signify missing nose
	if GameStatus.items_status[Constants.interactable_ids.TENNIS_BALL] == GameStatus.item_states.NONE:
		emote_bubble_nose.trigger_emote(emote_bubble_hat.emote_states.MISSING_NOSE)
	# Signify missing cane
	if GameStatus.items_status[Constants.interactable_ids.SHOVEL] == GameStatus.item_states.NONE:
		emote_bubble_cane.trigger_emote(emote_bubble_hat.emote_states.MISSING_CANE)


func stop_missing_item_emotes() -> void:
	emote_bubble_hat.trigger_emote(emote_bubble_hat.emote_states.NONE)
	emote_bubble_nose.trigger_emote(emote_bubble_hat.emote_states.NONE)
	emote_bubble_cane.trigger_emote(emote_bubble_hat.emote_states.NONE)


func set_bone_targets() -> void:

	var bone_idx_animation_start_spot 	:= skeleton.find_bone('Pinda')
	animation_start_spot = global_transform * skeleton.get_bone_global_pose(bone_idx_animation_start_spot)
	
	var bone_idx_handle_rest_spot 	:= skeleton.find_bone('Branch-arm')
	handle_rest_spot = global_transform * skeleton.get_bone_global_pose(bone_idx_handle_rest_spot)
	
	# Find bones
	var bone_idx_item_spot_generic 		:= skeleton.find_bone('Arm_Right-4')
	var bone_idx_item_spot_traffic_cone:= skeleton.find_bone('PRP-Traffic_cone')
	var bone_idx_item_spot_tennis_ball 	:= skeleton.find_bone('PRP-Tennis_ball')
	var bone_idx_item_spot_shovel 		:= skeleton.find_bone('PRP-Shovel')
	# TODO: Replace this with the shoes
	var bone_idx_item_spot_ear_muffs 	:= skeleton.find_bone('Arm_Right-4')

	# Get global transforms for each bone 
	var item_spot_generic 		:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_generic)
	var item_spot_traffic_cone 	:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_traffic_cone)
	var item_spot_tennis_ball 	:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_tennis_ball)
	var item_spot_shovel 		:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_shovel)
	var item_spot_ear_muffs 	:= global_transform * skeleton.get_bone_global_pose(bone_idx_item_spot_ear_muffs)
	
	# Item IDs
	var item_id_generic 		:= Constants.interactable_ids.ITEM_GENERIC
	var item_id_traffic_cone	:= Constants.interactable_ids.TRAFFIC_CONE
	var item_id_tennis_ball 	:= Constants.interactable_ids.TENNIS_BALL
	var item_id_shovel 			:= Constants.interactable_ids.SHOVEL
	var item_id_ear_muffs 		:= Constants.interactable_ids.EAR_MUFFS
	
	# Set up dictionary with bones
	item_snapping_targets = {
		item_id_generic 		: item_spot_generic,
		item_id_traffic_cone 	: item_spot_traffic_cone,
		item_id_tennis_ball 	: item_spot_tennis_ball,
		item_id_shovel 			: item_spot_shovel,
		item_id_ear_muffs 		: item_spot_ear_muffs,
	}
	
