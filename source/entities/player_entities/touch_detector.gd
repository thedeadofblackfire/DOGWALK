extends ShapeCast3D

signal body_entered(body: Node3D)
signal body_exited(body: Node3D)

var colliders : Array[Node3D]

func _ready() -> void:
	return
	body_entered.connect(func(body):
		print("ENTER")
		print(body))
	body_exited.connect(func(body):
		print("EXIT")
		print(body))


func trigger_shapecast() -> void:
	#print("NEW TOUCH DETECTOR NR: " + str(Engine.get_frames_drawn()))
	
	force_shapecast_update()
	
	if not is_colliding():
		for c in colliders:
			body_exited.emit(c)
		colliders.clear()
		return
	
	var previous_colliders := colliders.duplicate()
	colliders.clear()
	
	for i in get_collision_count():
		var collider = get_collider(i)
		if collider not in previous_colliders:
			body_entered.emit(collider)
		colliders.push_back(collider)
	
	for c in previous_colliders:
		if c not in colliders:
			body_exited.emit(c)
	
