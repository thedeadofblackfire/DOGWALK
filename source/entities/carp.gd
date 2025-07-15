extends Node3D

@export var path_follow : PathFollow3D

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	$Path/PathFollow3D/fish/AnimationPlayer.play("fish-anim_lib/LOOP-fish-swim")
	path_follow.progress -= delta * 0.2
	
