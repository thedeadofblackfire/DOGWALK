extends Node3D

@export var skeleton : Skeleton3D
@export var cursor_pivot : Node3D

const scramble_strength := .5
const letter_bone_names := [
	"letter_D",
	"letter_O",
	"letter_G",
	"letter_W",
	"letter_A",
	"letter_L",
	"letter_K",
]
var letter_nodes : Dictionary[String, Node3D]
var previous_mouse_position : Vector2

var animation_clock := 0.

var hovered_control : Control

func _ready() -> void:
	for bone_name in letter_bone_names:
		letter_nodes[bone_name] = skeleton.find_child("GEO-logo-%s" % [bone_name])
	
	get_viewport().gui_focus_changed.connect(scramble_force)

func _physics_process(delta: float) -> void:
	mouse_interaction()
	hover_interaction()
	
	animation_clock += delta * randf()
	
	var root_idx := skeleton.find_bone("root")
	skeleton.set_bone_pose_position(root_idx, Vector3.RIGHT * sin(animation_clock * 4) * 1. * delta)
	skeleton.rotate(Vector3.UP, sin(animation_clock * 2) * .001)

func hover_interaction():
	if not get_viewport():
		return
	if hovered_control == get_viewport().gui_get_hovered_control():
		return
	hovered_control = get_viewport().gui_get_hovered_control()
	if not hovered_control:
		return
	if hovered_control.get_class() not in ["OptionButton", "Button", "HSlider", "CheckButton", "TabBar"]:
		return
	scramble_force(hovered_control)

func mouse_interaction():
	
	var mouse_position := get_viewport().get_mouse_position()
	if not previous_mouse_position: previous_mouse_position = mouse_position
	var mouse_point_direction := Context.camera.camera3D.project_local_ray_normal(mouse_position)
	var camera_dir_transform := Context.camera.camera3D.global_transform
	camera_dir_transform.origin = Vector3.ZERO
	var mouse_velocity := (mouse_position - previous_mouse_position) / get_physics_process_delta_time() / InputController.window_size.y
	var mouse_move := camera_dir_transform * Vector3(mouse_velocity.x, mouse_velocity.y, 0.)
	(func(): previous_mouse_position = mouse_position).call_deferred()
	
	for bone_name in letter_bone_names:
		var bone_idx := skeleton.find_bone(bone_name)
		var bone_rest := skeleton.get_bone_global_rest(bone_idx)
		
		var letter_position := Context.camera.camera3D.unproject_position(letter_nodes[bone_name].global_position)
		var mouse_distance = (mouse_position - letter_position).length()
		
		var influence = clamp((100. - mouse_distance) / 100., 0., 1.)
		
		skeleton.set_bone_global_pose(bone_idx, bone_rest.translated((mouse_move) * influence * .01))

func scramble_force(node: Control):
	var delta = get_physics_process_delta_time()
	for bone_name in letter_bone_names:
		var bone_idx := skeleton.find_bone(bone_name)
		var bone_pose := skeleton.get_bone_global_pose(bone_idx)
		
		skeleton.set_bone_global_pose(bone_idx, bone_pose.translated(.001 / delta * scramble_strength * Vector3(randf()-.5, randf()-.5, randf()-.5)))
