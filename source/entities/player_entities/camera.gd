extends Node3D

class_name GameCamera

# How far the characters need to be apart for zooming to take effect
const ZOOM_OUT_THRESHOLD = 2.0
const CAMERA_SMOOTHING = 3.0 ## Acceleration for zooming and panning
# How much the position is blended between Pinda to Chocomel
const CLOSE_POSITION_SHARING = 0.4
const FAR_POSITION_SHARING = 1.2
const FAR_POSITION_SHARING_ICE = 0.9

const DOF_near := 5.0
const DOF_far := 7.5

const PAN_LIMIT := .1

# Camera near distance preset
var camera_near_position_z = 0.0
var camera_near_scale = Vector3(0.8, 0.8, 0.8)
var camera_near_rotation_x = deg_to_rad(-40.0)
var camera_near_fov = 42.0
# Camera far distance preset
var camera_far_position_Z = 0.0
var camera_far_scale = Vector3(1.2, 1.2, 1.2)
var camera_far_rotation_x = deg_to_rad(-52.0)
var camera_far_fov = 38.0
# Camera petting distance preset
var camera_petting_position_z = -0.5
var camera_petting_scale = Vector3(0.6, 0.6, 0.6)
var camera_petting_rotation_x = deg_to_rad(-36.0)
var camera_petting_fov = 42.0

var zoom_factor := 0.0
var petting_zoom_factor := 0.0:
	set(value):
		petting_zoom_factor = clamp(value, 0.0, 1.0)
var camera_base_transform : Transform3D

# camera interaction
enum camera_states {FREE, FOLLOW, DIRECTED, IDLING}
var current_camera_state := camera_states.FOLLOW:
	get():
		return current_camera_state
	set(new_state):
		if new_state == camera_states.DIRECTED:
			global_transform = camera3D.global_transform
		current_camera_state = new_state
var target_zoom_factor : float
var target_position : Vector3
var target_camera_fov : float

var camera_pan_input : Vector2 = Vector2.ZERO

# Interest zone state
var inside_camera_interst_zone := false
var camera_magnet_zone : CameraMagnetZone
var camera_interest_target_position : Vector3

# Character variables
var pinda_position : Vector3
var chocomel_position : Vector3



@export_category("Member Variables")
@export var player : Node3D # The owner node if present
@export var camera_pivot : Node3D
@export var camera3D : Camera3D

# Shared player variables. These are fallback values to be replaced on _ready()
@onready var maximum_leash_length := 8.0



func _ready() -> void:
	
	# Init relationship to game state
	Context.camera = self
	
	camera_base_transform = camera3D.transform
	
	# Get variables from player if one is present
	if player != null:
		maximum_leash_length = player.maxmimum_leash_length
	
	SignalBus.chocomel_entered_camera_magnet_zone.connect(_on_chocomel_entered_camera_magnet_zone)
	SignalBus.chocomel_exited_camera_magnet_zone.connect(_on_chocomel_exited_camera_magnet_zone)


func _process(delta: float) -> void:
	camera_pan_input = lerp(camera_pan_input, Input.get_vector("Pan Left", "Pan Right", "Pan Up", "Pan Down"), delta)
	
	var character_distance = (pinda_position - chocomel_position).length()
	var character_distance_factor = remap(
		character_distance,
		ZOOM_OUT_THRESHOLD,
		maximum_leash_length,
		0.0,
		1.0
		)
	character_distance_factor = clamp(character_distance_factor, 0.0, 1.0)
	
	var ice_factor : int = Context.pinda.terrain_detector.current_terrain_state == Constants.terrain_states.ICE
	var actual_far_position_sharing : float = lerp(FAR_POSITION_SHARING, FAR_POSITION_SHARING_ICE, ice_factor)
	
	var character_position_sharing_factor = lerp(
			CLOSE_POSITION_SHARING,
			actual_far_position_sharing,
			character_distance_factor
	)
	var character_target_position : Vector3 = lerp(
		pinda_position,
		chocomel_position,
		character_position_sharing_factor
	)
	
	# Start out with character values
	target_zoom_factor = character_distance_factor
	target_position = character_target_position
	
	if camera_magnet_zone != null:
		
		var magnet_zone_center := camera_magnet_zone.global_position
		magnet_zone_center.y = 0.0
		var magnet_zone_distance := (magnet_zone_center - chocomel_position).length()
		var magnet_zone_distance_factor := magnet_zone_distance / camera_magnet_zone.radius
		var camera_magnet_factor : float = remap(
			magnet_zone_distance_factor,
			1.0,
			0.75,
			0.0,
			0.8
		)
		camera_magnet_factor = clamp(camera_magnet_factor, 0.0, 0.8)
		
		target_zoom_factor = lerp(
			target_zoom_factor,
			camera_magnet_factor,
			camera_magnet_zone.magnet_zoom_override,
		)
		target_position = lerp(
			target_position,
			camera_interest_target_position,
			camera_magnet_factor * camera_magnet_zone.magnet_position_override
		)
	
	# only actually approach target when following 
	if current_camera_state != camera_states.DIRECTED:
		zoom_factor = lerp(zoom_factor, target_zoom_factor, CAMERA_SMOOTHING * delta)
		global_position = lerp(global_position, target_position, CAMERA_SMOOTHING * delta)
		global_transform.basis = Basis(lerp(global_basis.get_rotation_quaternion(), Quaternion.IDENTITY, CAMERA_SMOOTHING * delta))
		camera3D.fov = lerp(camera3D.fov, target_camera_fov, CAMERA_SMOOTHING * delta)
	
	var camera_pivot_transform := Transform3D.IDENTITY
	var pivot_scale : Vector3 = lerp(camera_near_scale, camera_far_scale, zoom_factor)
	var pivot_rotation_x : float = lerp(camera_near_rotation_x, camera_far_rotation_x, zoom_factor)
	var pivot_position_z : float = lerp(camera_near_position_z, camera_far_position_Z, zoom_factor)
	
	# Take over camera zoom slowly when idling
	if current_camera_state == camera_states.IDLING:
		petting_zoom_factor = lerp(petting_zoom_factor, 1.0, 0.1 * delta)
	else:
		petting_zoom_factor = lerp(petting_zoom_factor, 0.0, 1.0 * delta)
	
	pivot_scale = lerp(pivot_scale, camera_petting_scale, petting_zoom_factor)
	pivot_rotation_x = lerp(pivot_rotation_x, camera_petting_rotation_x, petting_zoom_factor)
	pivot_position_z = lerp(pivot_position_z, camera_petting_position_z, petting_zoom_factor)
	
	camera_pivot_transform = camera_pivot_transform.basis.scaled(pivot_scale)
	camera_pivot_transform = camera_pivot_transform.rotated(Vector3.RIGHT, pivot_rotation_x)
	camera_pivot_transform.origin.z = pivot_position_z
	
	# kill and reapproach pivot and cam3d transforms depending on state
	if current_camera_state == camera_states.FOLLOW or current_camera_state == camera_states.IDLING:
		camera_pivot.transform = lerp(camera_pivot.transform, camera_pivot_transform, CAMERA_SMOOTHING * delta)
		camera3D.transform = lerp(camera3D.transform, camera_base_transform, CAMERA_SMOOTHING * delta)
		#camera3D.rotate_x(-camera_pan_input.y * .01)
		#camera3D.rotate_y(-camera_pan_input.x * .01)
		
		var pan_dir_y := (Vector3(0., -1., 2.)).normalized()
		camera_pivot.translate((Vector3.RIGHT * camera_pan_input.x + pan_dir_y * camera_pan_input.y) * PAN_LIMIT)
		
	elif current_camera_state == camera_states.DIRECTED:
		camera_pivot.transform = Transform3D.IDENTITY
		camera3D.transform = Transform3D.IDENTITY
	
	target_camera_fov = lerp(camera_near_fov, camera_far_fov, zoom_factor)
	
	set_dof_blur()


func set_dof_blur() -> void:
	
	var average_character_position : Vector3 = lerp(pinda_position, chocomel_position, 0.5)
	var distance_to_camera := (camera3D.global_position - average_character_position).length()
	
	var dof_blur_factor := remap(
		distance_to_camera,
		6.0,
		12.0,
		0.0,
		1.0
	)
	camera3D.attributes.dof_blur_near_distance = lerpf(5.25, 8.5, dof_blur_factor)


# NOTE: Signal functions

func _on_chocomel_has_moved(
		new_position: Vector3,
		new_velocity : Vector3,
		leash_scalar : float,
		moving_to_pinda_scalar : float,
		collar_pivot_position : Vector3
) -> void:
	chocomel_position = new_position


func _on_pinda_has_moved(
		new_position : Vector3,
		new_velocity : Vector3,
	) -> void:
	pinda_position = new_position


func _on_chocomel_entered_camera_magnet_zone(area_node: CameraMagnetZone) -> void:
	camera_magnet_zone = area_node
	camera_interest_target_position = area_node.interest_point.global_position
	
	if not camera_magnet_zone.disabled:
		inside_camera_interst_zone = true
		camera_magnet_zone.active = true
		
	camera_magnet_zone.zone_enabled.connect(_on_current_camera_magnet_zone_enable)
	camera_magnet_zone.zone_disabled.connect(_on_chocomel_exited_camera_magnet_zone)

func _on_current_camera_magnet_zone_enable():
	inside_camera_interst_zone = true
	camera_magnet_zone.active = true

func _on_chocomel_exited_camera_magnet_zone(area_node: CameraMagnetZone) -> void:
	if camera_magnet_zone:
		camera_magnet_zone.zone_enabled.disconnect(_on_current_camera_magnet_zone_enable)
		camera_magnet_zone.zone_disabled.disconnect(_on_chocomel_exited_camera_magnet_zone)
		camera_magnet_zone.active = false
	
	inside_camera_interst_zone = false
	camera_magnet_zone = null
	camera_interest_target_position = Vector3.ZERO
