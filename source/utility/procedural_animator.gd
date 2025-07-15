@tool

class_name ProceduralAnimator
extends SkeletonModifier3D


# List of bone idx and their transforms that should be overridden for this frame
var bone_edits_global_transforms : Dictionary = { }
var bone_edits_transforms : Dictionary = { }
var bone_edits_local_rotations : Dictionary = {}

@onready var skeleton : Skeleton3D

func _ready() -> void:
	skeleton = get_skeleton()


func _process_modification() -> void:
	
	if skeleton == null:
		return
	
	# Apply all bone transforms in dictionary
	for idx in bone_edits_global_transforms:
		skeleton.set_bone_global_pose(idx, bone_edits_global_transforms[idx])
	for idx in bone_edits_transforms:
		skeleton.set_bone_pose(idx, bone_edits_transforms[idx])
	for idx in bone_edits_local_rotations:
		skeleton.set_bone_pose_rotation(idx, bone_edits_local_rotations[idx])


func _process(delta: float) -> void:
	
	# Clear dictionary for next frame
	call_deferred("clear_bone_overrides")


func clear_bone_overrides() -> void:
	# Clear dictionary for next frame
	bone_edits_global_transforms.clear()
	bone_edits_transforms.clear()
	bone_edits_local_rotations.clear()


## Overwrite global transform of a bone.
func _on_bone_has_been_transformed(bone_idx : int, bone_transform : Transform3D) -> void:
	bone_edits_global_transforms[bone_idx] = bone_transform


## Overwrite local transform of a bone.
func _on_bone_has_been_transformed_local(bone_idx : int, bone_transform : Transform3D) -> void:
	bone_edits_transforms[bone_idx] = bone_transform

## Overwrite local rotations of a bone.
func _on_bone_has_been_rotated(bone_idx : int, bone_rotation : Quaternion) -> void:
	bone_edits_local_rotations[bone_idx] = bone_rotation
