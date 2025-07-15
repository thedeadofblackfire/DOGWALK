extends Area3D

func reset_intersection():
	for ar in get_overlapping_areas():
		area_entered.emit(ar)
		
	for bod in get_overlapping_bodies():
		body_entered.emit(bod)
