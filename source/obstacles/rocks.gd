extends CollisionEntity

# For characters to check if this is not an invisible level boundary
var is_physical_object := true


func _ready() -> void:
	
	var target_collision_layers : PackedInt32Array = [5]
	var target_collision_masks : PackedInt32Array = [4] 
	init_collision_layers(target_collision_layers, target_collision_masks)
