@tool # Needed so it runs in editor.
extends EditorScenePostImport

enum shape_types {SIMPLE, TRIMESH}

func _post_import(scene: Node) -> Object:
	for node in scene.get_children():
		process_node(node)
	
	return scene

func process_node(node: Node) -> void:
	
	# Custom propeties i.e "meta data" or "metas"
	var metas = node.get_meta_list()
	for meta in metas:
		var meta_val = node.get_meta(meta)
		
		if meta != "extras":
			continue
		
		# TODO: Not checking for any specific content in the meta data yet
		for property in meta_val:
			if property == "collision":
				print("Converting to collision")
				var content = meta_val.get(property)
				if content == "-concave":
					print("converting to trimesh")
					collision_mesh_conversion(node)
				elif content == "-cylinder":
					print("converting to cylinder")
					var original_name = node.name
					# Rename so there's no name conflict
					node.name = "delete"
					var new_collision_shape = CollisionShape3D.new()
					new_collision_shape.shape = CylinderShape3D.new()
					new_collision_shape.name = original_name
					new_collision_shape.position = node.position
					new_collision_shape.rotation = node.rotation
					var height_from_scale = node.scale.y * 2
					var radius_from_scale = (node.scale.x + node.scale.z) / 2
					new_collision_shape.shape.height = height_from_scale
					new_collision_shape.shape.radius = radius_from_scale
					node.add_sibling(new_collision_shape)
					# Setting the owner is vital. Otherwise it won't show up
					new_collision_shape.set_owner(node.get_parent())
					# Delete nodes
					node.queue_free()


func collision_mesh_conversion(node : MeshInstance3D, ) -> void:
	print("Converting to trimesh")
	
	# Create the new collision shape
	node.create_trimesh_collision()
	
	var original_name = node.name
	var static_body = node.get_child(0)
	var collision_shape = static_body.get_child(0)
	var trimesh_shape = collision_shape.shape.duplicate()
	# Rename so there's no name conflict
	node.name = "delete"
	var new_collision_shape = CollisionShape3D.new()
	new_collision_shape.shape = trimesh_shape
	new_collision_shape.name = original_name
	new_collision_shape.position = node.position
	new_collision_shape.scale = node.scale
	new_collision_shape.rotation = node.rotation
	node.add_sibling(new_collision_shape)
	# Setting the owner is vital. Otherwise it won't show up
	new_collision_shape.set_owner(node.get_parent())
	# Delete nodes
	collision_shape.queue_free()
	static_body.queue_free()
	node.queue_free()
