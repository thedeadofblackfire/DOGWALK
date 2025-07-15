extends Node

var toppled_entities : Dictionary[ToppleEntity, bool]

func _process(delta: float) -> void:
	for te in toppled_entities.keys():
		if not te:
			toppled_entities.clear()
			break
		te.procedural_topple_anim(delta)
