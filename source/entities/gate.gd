extends CollisionEntity
class_name Gate

var is_physical_object := true

@export_category("Member Variables")
@export var animation_tree : AnimationTree
@export var animation_player : AnimationPlayer
@export var skeleton : Skeleton3D
@export var closed_gate_collision : CollisionShape3D
@export var open_gate_collision : CollisionShape3D

@export_category("Test Pinda Positions")
@export var gate_inspection_spot : Area3D
@export var fence_inspection_spot : Area3D
@export var plank_inspection_spot : Area3D
@export var other_side_spot : Area3D
@export var open_gate_spot : Area3D

@export_category("Timers")
@export var process_timer : Timer
# List of interest points for easier access
@onready var interest_points := [
	gate_inspection_spot,
	fence_inspection_spot,
	plank_inspection_spot,
	other_side_spot,
	open_gate_spot,
]

@onready var interactable_id := Constants.interactable_ids.GATE


func _ready() -> void:
	
	Context.gate = self
	Context.interactable_nodes[Constants.interactable_ids.GATE] = self
