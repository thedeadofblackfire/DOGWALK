extends Area3D
class_name LightArea

@export var INVERT := false
@export var FADE_TIME := 5.0
@export var DIMMING_TARGET_FACTOR := 0.0


# Each child light. Stored as 'node : light_energy'
var child_lights := {}

# State variables
var active := false
var entered_nodes := []
var current_light_factor := 0.0:
	set(value):
		current_light_factor = clamp(value, 0.0, 1.0)

@onready var FADE_SPEED := 1/FADE_TIME

func _ready() -> void:
	
	# Collision layers
	var target_collision_layers : PackedInt32Array = [1]
	var target_collision_masks : PackedInt32Array = [3,4]
	init_collision_layers(target_collision_layers, target_collision_masks)
	
	# Connect signals
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Create list of children lights
	for child in get_children():
		if child is Light3D:
			child_lights[child] = child.light_energy
	
	set_active()
	if active:
		current_light_factor = 1.0


func _process(delta: float) -> void:
	
	set_active()
	var dim_direction := -1
	if active:
		dim_direction = 1
	
	# Factor for how much the light is dimmed
	current_light_factor += FADE_SPEED * delta * dim_direction
	
	# Fade lights
	for light in child_lights:
		fade_light_energy(light, child_lights[light])
		light.visible = light.light_energy > 0.0


## Are the lights on or not
func set_active() -> void:
	
	if INVERT:
		active = entered_nodes.size() == 0
	else:
		active = entered_nodes.size() > 0


func fade_light_energy(light : Light3D, target_energy : float) -> void:
	
	light.light_energy = lerp(
		target_energy * DIMMING_TARGET_FACTOR,
		target_energy,
		current_light_factor
	)
	
	#light.shadow_enabled = light.light_energy > 0.0


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


func _on_body_entered(body: Node3D) -> void:
	entered_nodes.append(body)


func _on_body_exited(body: Node3D) -> void:
	entered_nodes.erase(body)
