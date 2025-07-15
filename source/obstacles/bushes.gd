extends CollisionEntity

# For characters to check if this is not an invisible level boundary
var is_physical_object := true

var area : Area3D

var base_transform : Transform3D

var cs_base_transforms : Dictionary[CollisionShape3D, Transform3D]

var wiggle_timer : Timer
var time_elapsed : float
var frame := -1
var wiggle_direction : Vector3

var mesh_instances : Array[MeshInstance3D]

const wiggle_amount := .5
const wiggle_frequency := 4
const wiggle_duration := 1.
const wiggle_fps := 24.

func _ready() -> void:
	super._ready()
	
	var target_collision_layers : PackedInt32Array = [6]
	var target_collision_masks : PackedInt32Array = [4] 
	init_collision_layers(target_collision_layers, target_collision_masks)
	
	base_transform = global_transform
	
	area = Area3D.new()
	add_child(area)
	area.owner = self
	
	for cs in collision_shapes:
		var area_collision_shape := cs.duplicate()
		area.add_child(area_collision_shape)
		area_collision_shape.owner = area
		cs_base_transforms[cs] = cs.global_transform
	area.top_level = true
	
	area.set_collision_mask_value(1, false)
	area.set_collision_mask_value(3, true)
	area.name = 'BushArea'
	
	area.connect("body_entered", chocomel_enter)
	
	#find_mesh_instances(self)

func find_mesh_instances(node : Node):
	if node.get_class() == "MeshInstance3D":
		mesh_instances.push_back(node)
	for n in node.get_children():
		find_mesh_instances(n)

func animate_wiggle(delta):
	if wiggle_timer:
		time_elapsed += delta
		
	var prev_frame := frame
	frame = time_elapsed * wiggle_fps
	if frame == prev_frame:
		return
	 
	var wiggle_progress := 1. - wiggle_timer.time_left / wiggle_timer.wait_time
	var envelope := (1. - wiggle_progress) ** 2.
	var bloat := envelope * cos(wiggle_progress * TAU * wiggle_frequency)
	
	global_transform = base_transform.rotated((wiggle_direction.cross(Vector3.UP)), wiggle_amount * envelope * sin(wiggle_progress * TAU * wiggle_frequency))
	global_transform = global_transform.scaled(Vector3(1, 1, 1) * (bloat * .1 + 1.))
	global_position = base_transform.origin
	
	for cs in collision_shapes:
		cs.global_transform = cs_base_transforms[cs]

func chocomel_enter(body : Node3D):
	# prevent retrigger while playing
	if wiggle_timer:
		return
	
	wiggle_direction = body.velocity.normalized()
	trigger_wiggle()

func pinda_collide(collisions : KinematicCollision3D, i : int):
	# prevent retrigger while playing
	if wiggle_timer:
		return
		
	if collisions.get_travel().length() == 0.:
		return
	wiggle_direction = collisions.get_travel().normalized()
	trigger_wiggle()

func trigger_wiggle():
	WiggleManager.wiggle_entities[self] = true
	if wiggle_timer:
		global_transform = base_transform
		wiggle_timer.start()
	else:
		wiggle_timer = Timer.new()
		self.add_child(wiggle_timer)
		wiggle_timer.wait_time = wiggle_duration
		wiggle_timer.connect("timeout", end_wiggle)
		wiggle_timer.start()
		
	Context.sfx_manager.play_sound_at_position(self.global_position, SFXManager.SOUND.BUSH)
	
func end_wiggle():
	wiggle_timer.queue_free()
	WiggleManager.wiggle_entities.erase(self)
	global_transform = base_transform
	time_elapsed = 0.
	frame = -1
