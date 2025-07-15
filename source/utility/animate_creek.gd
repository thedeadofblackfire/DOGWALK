extends Node
var creek_mat: StandardMaterial3D = preload("res://assets/sets/world/creek_water_surface.tres")
var timer = 0
const INTERVAL = 0.1
const FLOW_SPEED = 0.7


func _process(delta: float):
	var uv_offset = creek_mat.get_uv1_offset()
	timer += delta
	if timer > INTERVAL:
		uv_offset.y += delta * FLOW_SPEED
		timer = 0
		
	creek_mat.set_uv1_offset(uv_offset)
	return
