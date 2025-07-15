extends CollisionEntity


func _ready() -> void:
	
	var target_collision_layers : PackedInt32Array = [5]
	var target_collision_masks : PackedInt32Array = [] 
	init_collision_layers(target_collision_layers, target_collision_masks)
	self.add_to_group("TerrainSnow")
