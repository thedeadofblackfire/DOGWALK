extends CollisionObject3D
## Various functions that can be used by any script in the project.
class_name CollisionEntity

var collision_shapes : Array[CollisionShape3D]

func _ready() -> void:
	for node in get_children():
		if node.get_class() == "CollisionShape3D":
			collision_shapes.push_back(node)
	if not collision_shapes:
		push_warning("No collision shapes found on node: "+str(self))

## Set collion layers and masks for initializing.
func init_collision_layers(target_layers : PackedInt32Array, target_masks : PackedInt32Array) -> void:
	
	for layer in range(1, 32):
		if layer in target_layers:
			set_collision_layer_value(layer, true)
		else:
			set_collision_layer_value(layer, false)
	for mask in range(1, 32):
		if mask in target_masks:
			set_collision_mask_value(mask, true)
		else:
			set_collision_mask_value(mask, false)
