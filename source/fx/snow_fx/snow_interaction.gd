extends Node3D

@export var entity : Node3D
@export var trail : MultiMeshInstance3D
@export var particles : GPUParticles3D

var active := false

var terrain_detector : TerrainDetector
var raycast : RayCast3D

var particle_snow_terrain_spawn_rate := 100.

func _ready() -> void:
	
	terrain_detector = entity.terrain_detector
	
	terrain_detector.connect("terrain_state_changed", update_snow_interaction)
	
	raycast = RayCast3D.new()
	
func _process(delta: float) -> void:
	process_particles(delta)

func process_particles(delta: float):
	if active:
		particles.amount_ratio = pow(entity.velocity.length() / Context.player.chocomel_speed, 2.)
		particles.emitting = particles.amount_ratio != 0.
	if entity is not Chocomel:
		return
	particles.emitting = entity.current_animation_state == "Digging" or (particles.emitting and active)
	if entity.current_animation_state == "Digging": particles.amount_ratio = 1

func enable_interaction():
	active = true
	particles.emitting = true

func disable_interaction():
	active = false
	particles.emitting = false

func update_snow_interaction(new_terrain, previous_terrain):
	if new_terrain == Constants.terrain_states.SNOW:
		enable_interaction()
	else:
		disable_interaction()
