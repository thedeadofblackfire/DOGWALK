extends MultiMeshInstance3D

const MAX_N := 10000
var last_index := 0

var active := true

@export var main_interaction : Node3D
@export var single_piece : MeshInstance3D
@export var center_offset : float
@export var spread : float = .25
@export var scale_min : float = .5
@export var scale_max : float = 1.
@export var snow_spawn_rate := 20.
@export_range (0., 1.) var random_orientation := .1
@export_range (0., 1.) var random_tilt := .1
@export var gap_interval := .15
@export var gap_length := .1

var spawn_rate : float = 0 # avg pieces per second

var piece_transforms : Array[Transform3D] = []
var piece_color : Array[Color] = []

var entity : Node3D
var origin_offset_entity : Vector3

var gap_timer := Timer.new()

func _ready() -> void:
	var mesh := single_piece.mesh
	
	multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.use_colors = true
	
	multimesh.instance_count = MAX_N
	multimesh.visible_instance_count = 0
	
	entity = main_interaction.entity
	origin_offset_entity = entity.global_transform.inverse() * main_interaction.global_position
	
	self.add_child(gap_timer)
	gap_timer.timeout.connect(flip_active)
	flip_active()

func _process(delta: float) -> void:
	if main_interaction.active and active:
		spawn_rate = snow_spawn_rate * entity.velocity.length()
	else:
		spawn_rate = 0.
		return
	
	# find out how many pieces to spawn on this frame
	var n : int = 0
	if delta > 1. / spawn_rate:
		n = int(spawn_rate * delta)
	if randf() < (spawn_rate * delta) - n:
		n += 1
	
	if n == 0:
		return
	
	spawn_new_trail_pieces(n)

func spawn_new_trail_pieces(n : int):
	var start_index = multimesh.visible_instance_count
	var center_offset_axis = entity.velocity.normalized().cross(Vector3.UP)
	var origin_offset := entity.global_transform * main_interaction.position - entity.global_position
	
	for i in n:
		var off = entity.global_position
		off += Vector3((randf()-.5) * spread, .2, (randf()-.5) * spread)
		off += center_offset_axis * sign(randf()-.5) * center_offset
		off += origin_offset
		
		var tra = Transform3D.IDENTITY
		tra = tra.rotated_local(Vector3.UP, (randf()-.5) * TAU * random_orientation)
		tra = tra.rotated_local(Vector3.RIGHT, (randf()-.5) * PI * random_tilt)
		tra = tra.rotated_local(Vector3.BACK, (randf()-.5) * PI * random_tilt)
		tra.origin = off
		
		var instance_scale = lerp(scale_min, scale_max, randf())
		tra = tra.scaled_local(Vector3(instance_scale, instance_scale, instance_scale))
		
		var instance_transform = tra
		var instance_color = Color(randf(), randf(), randf(), randf())
	
		multimesh.set_instance_transform(last_index, instance_transform)
		multimesh.set_instance_color(last_index, instance_color)
		last_index += 1
		last_index = last_index % MAX_N
		
		if multimesh.visible_instance_count+1 < MAX_N:
			multimesh.visible_instance_count = last_index

func flip_active():
	if active:
		gap_timer.start(gap_length * randf())
	else:
		gap_timer.start(gap_interval)
	active = !active
