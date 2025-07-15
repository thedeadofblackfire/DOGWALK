extends CollisionEntity

class_name ToppleEntity

var toppled := false
const untopple_time := 0.4
var topple_timer : Timer

var topple_shape_cast : ShapeCast3D

const topple_rate := 5.
const untopple_rate := 3.
const topple_fraction := .85
const topple_offset := .1
var topple_progress = 0.
var topple_direction := 1.

var active := false

func _ready() -> void:
	super._ready()
	
	var target_collision_layers : PackedInt32Array = [5]
	var target_collision_masks : PackedInt32Array = [3,4]
	init_collision_layers(target_collision_layers, target_collision_masks)
	self.body_entered.connect(topple)

func procedural_topple_anim(delta: float):
	if not toppled:
		if topple_progress == 0.:
			return
		elif topple_progress < 0.:
			active = false
			ToppleManager.toppled_entities.erase(self)
			topple_progress = 0.
			set_topple_transform()
		else:
			topple_progress -= delta * untopple_rate
	else:
		if is_colliding():
			topple_timer.start()
			
		if topple_progress == 1.:
			return
		elif topple_progress > 1.:
			topple_progress = 1.
			set_topple_transform()
		else:
			topple_progress += delta * (pow(topple_progress, 2.) * 2. + 1.) * topple_rate
	set_topple_transform()
	
func set_topple_transform():
	rotation.x = topple_progress * - PI / 2. * topple_fraction * topple_direction
	scale.z = max(.01, 1. - topple_progress)
	position.y = topple_offset * topple_progress
	
func is_colliding():
	if not topple_shape_cast:
		return false
	
	var collisions := topple_shape_cast.collision_result
	return !collisions.is_empty()

func topple(body : Node3D):
	ToppleManager.toppled_entities[self] = true
	active = true
	if toppled:
		topple_timer.start()
		return
		
	topple_direction = sign((global_transform.inverse() * body.global_position).z)
	#print("topple: "+str(body))
	toppled = true
	
	## set up timer
	topple_timer = Timer.new()
	topple_timer.wait_time = untopple_time
	self.add_child(topple_timer)
	topple_timer.owner = self
	topple_timer.timeout.connect(untopple)
	topple_timer.start()
	
	## set up shapecast
	topple_shape_cast = ShapeCast3D.new()
	self.get_parent().add_child(topple_shape_cast)
	topple_shape_cast.owner = self.get_parent()
	topple_shape_cast.shape = collision_shapes[0].shape
	topple_shape_cast.target_position = Vector3.ZERO
	topple_shape_cast.global_transform = collision_shapes[0].global_transform
	
	for i in 32:
		topple_shape_cast.set_collision_mask_value(i+1, get_collision_mask_value(i+1))
		
	Context.audio_manager.sfx_manager.play_sound_at_position(self.global_position, SFXManager.SOUND.TOPPLE)

func untopple():
	#print("untopple")
	toppled = false
	topple_timer.queue_free()
	topple_shape_cast.queue_free()
	Context.sfx_manager.play_sound_at_position(self.global_position, SFXManager.SOUND.UNTOPPLE)
