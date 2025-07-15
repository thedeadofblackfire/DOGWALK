extends RayCast3D

class_name TerrainDetector

signal terrain_state_changed(new_state, previous_state)

# TODO: These states should be set onready to get the correct ground
var current_terrain_state	: Constants.terrain_states = Constants.terrain_states.NONE
var previous_terrain_state	: Constants.terrain_states = -1

var entered_snow_areas := 0
var entered_ice_areas := 0

func _ready() -> void:
	pass


func _process(delta: float) -> void:
	#print("%s \t%s" % [get_parent().name, Constants.terrain_states.keys()[current_terrain_state]])
	
	var detected_state := Constants.terrain_states.NONE
	
	if is_colliding():
		var terrain = get_collider()
		var terrain_groups : Array = terrain.get_groups()
		
		# Check ground terrain types
		if terrain_groups.find("TerrainIce") != -1:
			detected_state = Constants.terrain_states.ICE
		elif terrain_groups.find("TerrainSnow") != -1:
			detected_state = Constants.terrain_states.SNOW
	
	set_current_terrain_state(detected_state)


## Check which terrain areas are currently entered and set terrain state accordingly.
func set_current_terrain_state(detected_state : Constants.terrain_states) -> void:
	if detected_state == current_terrain_state:
		return
	
	previous_terrain_state = current_terrain_state
	current_terrain_state = detected_state
	
	emit_signal("terrain_state_changed", current_terrain_state, previous_terrain_state)
