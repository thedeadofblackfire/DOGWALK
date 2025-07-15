extends Node3D

class_name FootstepFX

const N_MAX := 1000 # maximum number of footsteps visible at once
const N_COLL := 20 # maximum number of last created footsteps considered for collision avoidance
const fps := 1.5 # framerate for disappearing footsteps
const diappearing_frames := 2 # frames used for disappearing
const life_duration := 12. # total lifetime of a footstep in seconds
const y_offset := .05 # offset off the ground in y direction

var swizzle_index := 0 # index of the next footstep to be added

@export var entity : Node3D
@export var size := .5
@export var aspect := 1.
@export var material : Material
@export var footstep_instances : MultiMeshInstance3D

var multimesh : MultiMesh
var instance_ages : PackedFloat32Array

func _ready() -> void:
	multimesh = footstep_instances.multimesh
	
	multimesh.instance_count = N_MAX
	multimesh.visible_instance_count = 0
	multimesh.mesh.surface_set_material(0, material)
	multimesh.mesh.size = Vector2(aspect * size, size)
	
	instance_ages.resize(N_MAX)

func _process(delta: float) -> void:
	animate_footsteps()

func animate_footsteps():
	for i in multimesh.visible_instance_count:
		var instance_transform = multimesh.get_instance_transform(i)
		if instance_transform.basis.get_scale().length() == 0.:
			continue
		var instance_age = instance_ages[i]
		var delta = get_process_delta_time()
		instance_ages[i] += delta
		
		var life_progress = instance_age / life_duration
		
		if life_progress >= 1:
			multimesh.set_instance_transform(i, Transform3D.IDENTITY.scaled(Vector3.ZERO))
			continue
			
		if life_progress >= 1. - diappearing_frames / (fps * life_duration):
			if fmod(instance_age * fps, 1) - (delta * fps) < 0:
				var down_scale_factor : float = remap(life_progress, .8, 1., 1., 0.)
				down_scale_factor = clamp(down_scale_factor, 0., 1.)
				var alpha_factor := down_scale_factor
				down_scale_factor = pow(down_scale_factor, .2)
				multimesh.set_instance_transform(i, multimesh.get_instance_transform(i).scaled_local(Vector3(down_scale_factor, down_scale_factor, down_scale_factor)))
				var r = randf()
				alpha_factor = pow(alpha_factor, 0.9)
				multimesh.set_instance_color(i, Color(r,r,r,alpha_factor))

func add_footstep(pos : Vector3, dir : Vector3):
	if check_intersection(pos):
		return
	
	if multimesh.visible_instance_count < multimesh.instance_count:
		multimesh.visible_instance_count += 1
	
	instance_ages[swizzle_index] = 0.
	
	var instance_transform := Transform3D.IDENTITY.looking_at(dir)#.rotated_local(Vector3.DOWN, PI/2.)
	instance_transform = instance_transform.translated(pos)
	instance_transform = instance_transform.translated(Vector3.UP * y_offset)
	
	multimesh.set_instance_transform(swizzle_index, instance_transform)
	var r = randf()
	multimesh.set_instance_color(swizzle_index, Color(r,r,r,1.))
	swizzle_index = (swizzle_index + 1) % N_MAX
	
func check_intersection(pos : Vector3):
	var idx : int
	for i in N_COLL:
		idx = (swizzle_index - i - 1 + N_MAX) % N_MAX
		
		if idx >= multimesh.visible_instance_count:
			return false
		
		var instance_transform := multimesh.get_instance_transform(idx)
		if instance_transform.basis.get_scale().length() <= .1:
			return false
		
		if ((instance_transform.origin - pos) * Vector3(1,0,1)).length() < size / 2.:
			return true
	
	return false
