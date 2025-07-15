extends Node


func _ready() -> void:
	return
	#assign_particle_collision()
	
func assign_particle_collision():
	mark_visual_instance_layer(get_tree().current_scene)

func mark_visual_instance_layer(node: Node, flag:=false):
	# mark assets that are snow terrain
	flag = flag or "TerrainSnow" in node.get_groups()
	
	# mark assets that are ground collision
	if node.has_method("get_collision_layer_value"):
		flag = flag or node.get_collision_layer_value(10)
	
	flag = flag or node.name.contains('ground')
	
	for child in node.get_children():
		mark_visual_instance_layer(child, flag)
	
	if node.get_class() != "MeshInstance3D":
		return
	
	if flag:
		node.set_layer_mask_value(2, true)
