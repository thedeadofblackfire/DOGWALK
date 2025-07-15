extends Node

var wiggle_entities : Dictionary[Node, bool]

func _process(delta: float) -> void:
	for we in wiggle_entities.keys():
		if not we:
			wiggle_entities.clear()
			break
		we.animate_wiggle(delta)
