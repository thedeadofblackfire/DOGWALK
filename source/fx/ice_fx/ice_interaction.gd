extends Node3D

const MAX_N := 1000

@export var entity : Node3D
@export var line_3d : Line3D

var point_birth : Array[int] = []

func _ready() -> void:
	line_3d.points.clear()
	Time.get_ticks_msec()

func _process(delta: float) -> void:
	if entity.terrain_detector.current_terrain_state != Constants.terrain_states.ICE and line_3d.points.size() == 0:
		return
	
	var time = Time.get_ticks_msec()
	
	if entity.terrain_detector.current_terrain_state == Constants.terrain_states.ICE:
		line_3d.points.insert(0, entity.global_position + .05 * Vector3.UP)
		point_birth.insert(0, Time.get_ticks_msec())
	
	while line_3d.points.size() > MAX_N:
		line_3d.points.remove_at(line_3d.points.size()-1)
		point_birth.pop_back()
	
	while time - point_birth[-1] > 2000:
		line_3d.points.remove_at(line_3d.points.size()-1)
		point_birth.pop_back()
		if line_3d.points.size() == 0:
			break
			
	line_3d.rebuild()
