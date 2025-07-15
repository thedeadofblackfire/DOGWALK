extends Area3D
class_name CollectableItem

signal item_state_changed(new_state : GameStatus.item_states, previous_state : GameStatus.item_states)

var item_state := GameStatus.item_states.NONE:
	get():
		return GameStatus.items_status[item_id]
	set(value):
		item_state_changed.emit(value, item_state)
		GameStatus.items_status[item_id] = value
		if camera_magnet_zone:
			if value in [GameStatus.item_states.NONE, -1]:
				camera_magnet_zone.disabled = false
				if camera_magnet_zone.zone_deactivated.is_connected(disable_cam_zone):
					camera_magnet_zone.zone_deactivated.disconnect(disable_cam_zone)
			else:
				if camera_magnet_zone.active:
					camera_magnet_zone.zone_deactivated.connect(disable_cam_zone)
				else:
					camera_magnet_zone.disabled = true
var can_be_picked_up := true:
	get():
		return can_be_picked_up
	set(value):
		collision_shape.disabled = !value
		can_be_picked_up = value


@export var item_id : Constants.interactable_ids
@export var collision_shape : CollisionShape3D
@export var skeleton : Skeleton3D
@export var camera_magnet_zone : CameraMagnetZone
@export var anim_player : AnimationPlayer

@onready var interactable_id := item_id
@onready var player = null
@onready var snowman = null


# add new state pose animations here
const item_world_anim : Dictionary = {
	Constants.interactable_ids.BRANCH		: "PR-branch-anim_lib/POSE-branch-pick_up_branch",
	Constants.interactable_ids.SHOVEL 		: "PR-shovel-anim_lib/POSE-shovel-world",
	Constants.interactable_ids.TENNIS_BALL : "PR-tennis_ball-anim_lib/POSE-tennis_ball-world",
	Constants.interactable_ids.TRAFFIC_CONE : "PR-traffic_cone-anim_lib/POSE-cone-world",
}
const item_held_anim : Dictionary = {
	Constants.interactable_ids.SHOVEL 		: "PR-shovel-anim_lib/POSE-shovel-zero",
	Constants.interactable_ids.TENNIS_BALL 	: "PR-tennis_ball-anim_lib/POSE-tennis_ball-zero",
	Constants.interactable_ids.TRAFFIC_CONE : "PR-traffic_cone-anim_lib/POSE-cone-zero",
}
const item_snowman_anim : Dictionary = {
	Constants.interactable_ids.SHOVEL 		: "PR-shovel-anim_lib/POSE-shovel-snowman",
	Constants.interactable_ids.TENNIS_BALL 	: "PR-tennis_ball-anim_lib/POSE-tennis_ball-zero",
	Constants.interactable_ids.TRAFFIC_CONE : "PR-traffic_cone-anim_lib/POSE-cone-zero",
}

func _ready() -> void:
	# Init relationship to game state
	Context.interactable_nodes[interactable_id] = self
	
	# The item transforms are only set after the animations are applied near the end of the process.
	anim_player.mixer_applied.connect(set_item_transform)
	
	# Find specific nodes in the tree
	player = get_tree().get_nodes_in_group("Player")
	for node in player:
		if node.name == "Player":
			player = node
			continue
	snowman = get_tree().get_nodes_in_group("Snowman")
	for node in snowman:
		if node.get_parent().name == "PR-snowman":
			snowman = node
			continue
	# Check if variables were set
	assert(player.name == "Player", "Player node wasn't found by item!")
	assert(snowman.get_parent().name == "PR-snowman", "Snowman node wasn't found by item!")
	
	skeleton.modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_PHYSICS
	
	# Set collision layer to 8 and leave all other layers and masks off
	for layer in range(1, 32):
		if layer == 8:
			set_collision_layer_value(layer, true)
			set_collision_mask_value(layer, false)
		else:
			set_collision_layer_value(layer, false)
			set_collision_mask_value(layer, false)
	
	# Steal the rotation of the parent. This is needed because the 
	# parent is placed and rotated in the level. To make prop interactions work well,
	# there can't be any added rotations on the prop.
	
	var parent_transform = get_parent().global_transform
	get_parent().global_transform = Transform3D.IDENTITY
	global_transform = parent_transform
	
	if skeleton != null:
		skeleton.reset_bone_poses()
	
	# Set initial pose and connect signal for future chagnes
	set_item_pose(-1, GameStatus.item_states.NONE)
	self.item_state_changed.connect(set_item_pose)
	
	item_state = GameStatus.item_states.NONE


func _process(delta: float) -> void:
	item_state_logic()
	set_item_transform()


## Snap item to correct target depending on current state
func item_state_logic() -> void:
	item_state = GameStatus.items_status[item_id]
	can_be_picked_up = GameStatus.items_status[item_id] == GameStatus.item_states.NONE


func set_item_transform():
	var pinda_pivots : Dictionary = player.pinda.bone_snapping_targets
	
	match item_state:
		GameStatus.item_states.NONE:
			return
		GameStatus.item_states.HELD:
			if item_id in pinda_pivots:
				global_transform = pinda_pivots[item_id]
		GameStatus.item_states.PLACED:
			if item_id in snowman.item_snapping_targets:
				global_transform = snowman.item_snapping_targets[item_id]
			else:
				global_transform = Transform3D.IDENTITY


func set_item_pose(new_state : GameStatus.item_states, prev_state : GameStatus.item_states):
	if not anim_player:
		return
	if new_state == prev_state:
		return
	match new_state:
		GameStatus.item_states.NONE:
			play_pose_from_dict(item_world_anim)
		GameStatus.item_states.HELD:
			play_pose_from_dict(item_held_anim)
		GameStatus.item_states.PLACED:
			play_pose_from_dict(item_snowman_anim)


func play_pose_from_dict(dict : Dictionary):
	if item_id not in dict:
		if anim_player.has_animation("RESET"):
			anim_player.play("RESET")
		else:
			skeleton.reset_bone_poses()
		return
	anim_player.play(dict[item_id])
	
func disable_cam_zone():
	camera_magnet_zone.zone_deactivated.disconnect(disable_cam_zone)
	print("DISABLE")
	camera_magnet_zone.disabled = true
