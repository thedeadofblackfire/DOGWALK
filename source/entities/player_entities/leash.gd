extends Node3D
class_name Leash

signal changed_leash_points(points : PackedVector3Array, length : float)

var PivotTree = preload("res://source/utility/pivot_grid.gd")
var prev_time

const FIXED_HEIGHT = 0.5

const avoid_leash_explode := true # avoids adding points when leash segment would be drastically lengthened (reset in extreme cases)
const avoid_unclear_side_snapping := true # add threshold to propagate previous side when it's unclear (delays snapping)
const avoid_stuck_snapped := true # allow unsnapping when leashangle is around 180deg

# Target state
enum leash_handle_states {HELD, SECURED}
var current_leash_handle_state := leash_handle_states.HELD
var pivot_position := Vector3.ZERO
var pivot_transform_visual := Transform3D.IDENTITY

# Member variables
@export var line_3d : Line3D
@export var visual_leash_line : Line3D
@export var pivots_changed := true
@export var leash_handle : Node3D
@export var leash_handle_skeleton : Skeleton3D
@export var leash_limit_sound : AudioStreamPlayer3D
@export var leash_bounce_sound : AudioStreamPlayer3D

var PIVOTS = [] # link to real pivot objects, populate on scene load
var pivot_grid = PivotTree.new()
var PIVOT_POSITIONS = []
var PIVOT_INDICES_COLLISION = []
var RELATIONS = []
var SNAPPED : Array[int] = [-1] # Leash Point index : PIVOTS index
var CELL_COORDS = []

# Dog and Kid positions
var chocomel_position := Vector3.ZERO
var chocomel_collar_position : Vector3
var pinda_position := Vector3.ZERO
var pinda_hand_transform : Transform3D
var snowman_leash_position : Vector3
var snowman_leash_handle_transform : Transform3D

var start_prev := Vector3.ZERO
var end_prev := Vector3.ZERO

@onready var snowman : Node3D

# dynamics

var prev_total_length := 0.
var wobble_timer := 0.

enum SIDE {
	LEFT,
	RIGHT,
	UNCLEAR
}


# NOTE: I added this to populate the pivots array
func _ready() -> void:
	
	# Init relationship to game state
	Context.leash = self
	
	# Add all pivots from the scene (TODO: Should be more optimized later on)
	var pivot_collection = get_tree().get_nodes_in_group("LeashPivots")
	for pivot in pivot_collection:
		PIVOTS.append(pivot)
	assert(PIVOTS.size() > 0, "Player node is made ready before the set! Reorder the Player node to be lower in the scene tree.")
	
	# Get snowman pivots
	# TODO: This needs to be deffered to avoid breaking in some cases
	var snowman = Context.interactable_nodes[Constants.interactable_ids.SNOWMAN]
	snowman_leash_handle_transform = snowman.handle_rest_spot * snowman.global_transform
	# TODO: Split this off into the physics positon and the visual position
	snowman_leash_position = snowman_leash_handle_transform.origin
	
	Context.pinda.updated_bone_transforms.connect(update_visual_leash_line)
	Context.pinda.updated_hand_transform.connect(_on_pinda_hand_updated)
	
	# Initialize pivot points
	update_pivot_positions()


func _physics_process(delta: float) -> void:
	
	if current_leash_handle_state == leash_handle_states.SECURED:
		pivot_position = snowman_leash_position
	else:
		pivot_position = pinda_position
		
	update_entire_leash()
	
	signal_new_leash_info()

func _process(delta: float) -> void:
	update_visual_leash_line()

func update_entire_leash() -> void:
	
	if pivot_position == chocomel_position:
		line_3d.points[0] = pivot_position
		line_3d.points[-1] = chocomel_position
		line_3d.rebuild()
		return
	
	var max_jump : float = max((start_prev-pivot_position).length(), (end_prev-chocomel_position).length())
	var n_steps : int = min(int(1. + max_jump / .2), 20)
	
	if max_jump == 0.0:
		return
	
	#print("%f, %f" % [(start_prev - pivot_position).length(), (end_prev - chocomel_position).length()])
	#print("%f, %d" % [max_jump, n_steps])
	
	if pivots_changed:
		update_pivot_positions()
	
	for step in n_steps:
		line_3d.points[0] = lerp(start_prev, pivot_position, float(step + 1) / n_steps)
		line_3d.points[-1] = lerp(end_prev, chocomel_position, float(step + 1) / n_steps)
		
		#print("%d %v" % [step+1, line_3d.points[0]])
		
		find_collision_pivots()
		
		recalc_relations()
		recalc_snapping()
	
	start_prev = pivot_position
	end_prev = chocomel_position
	line_3d.rebuild()


func reset():
	RELATIONS.clear()
	SNAPPED = [-1]
	
	line_3d.points.resize(2)
	while line_3d.points.size() > 2:
		line_3d.points.remove_at(1)
	line_3d.rebuild()


func update_pivot_positions():
	var NEW_PIVOT_POSITIONS = []
	for i in PIVOTS.size():
		NEW_PIVOT_POSITIONS.push_back(PIVOTS[i].get_global_position())
	
	for i in SNAPPED.size()-1:
		var segment_index = i + 1
		set_point_position(segment_index, NEW_PIVOT_POSITIONS[SNAPPED[segment_index]])
	
	PIVOT_POSITIONS = NEW_PIVOT_POSITIONS
	print(str(PIVOT_POSITIONS.size())+' leash collision pivots found')
	
	# serialize pivot positions
	pivot_grid.initialize_grid(.25, NEW_PIVOT_POSITIONS)
	
	pivots_changed = false


func signal_new_leash_info() -> void:
	
	var leash_length := 0.0
	var leash_points := line_3d.points.size()
	for i in range(1, leash_points):
		leash_length += line_3d.points[i - 1].distance_to(line_3d.points[i])
	
	changed_leash_points.emit(line_3d.points, leash_length)

func find_collision_pivots():
	var newCellCoords = pivot_grid.cells_along_point_sequence(line_3d.points)
	if CELL_COORDS == newCellCoords:
		return
	CELL_COORDS = newCellCoords
	PIVOT_INDICES_COLLISION = pivot_grid.pivots_around_cells(CELL_COORDS, 2)
	cleanup_relations()

func cleanup_relations():
	for i in RELATIONS.size():
		for k in RELATIONS[i].keys():
			if k in PIVOT_INDICES_COLLISION:
				continue
			if k == SNAPPED[i]:
				continue
			RELATIONS[i].erase(k)

func recalc_relations():
	mark_time()
	var collision_points = PIVOT_INDICES_COLLISION
	
	var newPoints = []
	var range := range(0, get_point_count()-1)
	var end_points := [range.front(), range.back()]
	if end_points.front() == end_points.back():
		end_points.remove_at(1)
	else:
		end_points.insert(1, range.back()-1)
	
	for collisionPivotIndex in collision_points.size():
		# Only pick the first and last points to update regularly. Performance saving measure.
		for segmentIndex in end_points:
			var pivotIndex = collision_points[collisionPivotIndex]
			var point = PIVOT_POSITIONS[pivotIndex]
			var start = line_3d.points[segmentIndex]
			var end = line_3d.points[segmentIndex+1]
			
			# if segment snapped to pivot, skip
			if SNAPPED[segmentIndex] == pivotIndex:
				continue
			elif segmentIndex + 1 < SNAPPED.size():
				if SNAPPED[segmentIndex+1] == pivotIndex:
					continue
			
			var newRelation = calculate_relations(
				Vector2(point.x, point.z),
				Vector2(start.x, start.z),
				Vector2(end.x, end.z)
				)
		   
			# initial fill array
			if (RELATIONS.size() < (segmentIndex + 1)):
				RELATIONS.push_back({pivotIndex: newRelation})
			elif pivotIndex not in RELATIONS[segmentIndex].keys():
				RELATIONS[segmentIndex][pivotIndex] = newRelation
			else:
				if newRelation.side == SIDE.UNCLEAR:
					newRelation.side = RELATIONS[segmentIndex][pivotIndex].side
					
				# if collision, add point.
				if check_snap_point(newRelation, segmentIndex, pivotIndex):
					newPoints.push_back(
						{ "position": PIVOT_POSITIONS[pivotIndex],
						"segmentIndex": segmentIndex,
						"pivotIndex": pivotIndex,
						}
					)
				# else just update state
				else:
					RELATIONS[segmentIndex][pivotIndex] = newRelation
	add_points(newPoints)
	#print("valid collision points # %d" % [PIVOT_INDICES_COLLISION.size()])
	#print_time("Recalc Relations")
 
func check_snap_point(newRelation, segmentIndex, pivotIndex):
	if not newRelation.inside:
		return false
	
	if newRelation.side == RELATIONS[segmentIndex][pivotIndex].side:
		return false
	
	if not avoid_leash_explode:
		return true
		
	## safety mechanism to avoid exploding leash
	var seg_prev = (line_3d.points[segmentIndex] - line_3d.points[segmentIndex+1]).length()
	var seg1 = (line_3d.points[segmentIndex] - PIVOT_POSITIONS[pivotIndex]).length()
	var seg2 = (line_3d.points[segmentIndex+1] - PIVOT_POSITIONS[pivotIndex]).length()
	if (seg1 + seg2) * .5 > seg_prev * 2.:
		call_deferred("reset")
		return false
	if (seg1 + seg2) * .5 > seg_prev:
		return false
	return true

func mark_time():
	prev_time = Time.get_ticks_usec()
	
func print_time(name : String):
	print("%s %dms" % [name, (Time.get_ticks_usec() - prev_time) * .001])

func calculate_relations(point: Vector2, start: Vector2, end: Vector2):
	var relations = {"side": SIDE.LEFT, "inside": false}
	   
	var segment = (end-start).normalized()
	var fromStart = (point-start).normalized()
	var fromEnd = (point-end).normalized()
   
	var newSide = segment.cross(fromStart)
	if absf(newSide) < .05 and avoid_unclear_side_snapping:
		relations.side = SIDE.UNCLEAR
	else:
		newSide = sign(newSide)
		if newSide == 1:
			relations.side = SIDE.RIGHT
   
	#check if both angles are acute
	if (segment.dot(fromStart) > 0 and segment.dot(fromEnd) < 0):
		relations.inside = true
	return relations
 
func recalc_snapping():
	var deletePoints = []
	for segmentIndex in SNAPPED.size():
		var pivotIndex =  SNAPPED[segmentIndex]
		if pivotIndex == -1:
			continue
		if should_unsnap(RELATIONS[segmentIndex][pivotIndex], segmentIndex):
			deletePoints.push_back(segmentIndex)
	if (deletePoints.size()>0): remove_points(deletePoints)
   
func should_unsnap(point, segmentIndex):
	if (segmentIndex + 1 >= line_3d.points.size()) or segmentIndex == 0: return false
	var first = line_3d.points[segmentIndex] - line_3d.points[segmentIndex-1]
	var second = line_3d.points[segmentIndex+1] - line_3d.points[segmentIndex]
	# Convert to 2D Vector
	first = Vector2(first.x, first.z)
	second = Vector2(second.x, second.z)
	# unsnap double snapped points
	if second.length() == 0:
		return true
		
	var turn = sign(first.cross(second))
	
	if avoid_stuck_snapped:
		var dot = first.normalized().dot(second.normalized())
		if dot < -.96:
			return true
		
	if ((point.side == SIDE.LEFT and turn > 0) or (point.side == SIDE.RIGHT and turn < 0)):
		return true
	return false
   
 
func add_points(pointsArray):
	pointsArray = sort_points_by_distance(pointsArray)
	for newPointIndex in pointsArray.size():
		add_point(pointsArray[newPointIndex].position, pointsArray[newPointIndex].segmentIndex + 1)
		var newRelations = RELATIONS[pointsArray[newPointIndex].segmentIndex].duplicate()
		RELATIONS.insert(pointsArray[newPointIndex].segmentIndex + 1, newRelations)
		
		# update snapping info
		SNAPPED.insert(pointsArray[newPointIndex].segmentIndex + 1, pointsArray[newPointIndex].pivotIndex)
		   
func remove_points(pointsIndexArray):
	pointsIndexArray.sort()
	pointsIndexArray.reverse()
	for p in pointsIndexArray:
		remove_point(p)
		
		# update snapping info
		var unsnapped_pivot = SNAPPED.pop_at(p)
		var deletedRelations = RELATIONS.pop_at(p)
		   
		for pivotIndex in RELATIONS[p-1].keys() + deletedRelations.keys():
			if unsnapped_pivot == pivotIndex:
				RELATIONS[p-1][pivotIndex] = deletedRelations[pivotIndex]
			elif pivotIndex not in RELATIONS[p-1].keys():
				RELATIONS[p-1][pivotIndex] = deletedRelations[pivotIndex]
 
func sort_points_by_distance(newPoints: Array):
	newPoints.sort_custom(func(a, b):
		if a.segmentIndex == b.segmentIndex:
			var start = line_3d.points[a.segmentIndex]
			return (a.position-start).length() > (b.position-start).length()
		else:
			return a.segmentIndex > b.segmentIndex         
	)
	return newPoints

func update_visual_leash_line() -> void:
	
	visual_leash_line.points = line_3d.points.duplicate()
	
	if current_leash_handle_state == leash_handle_states.SECURED:
		pivot_transform_visual = snowman_leash_handle_transform
	else:
		pivot_transform_visual = pinda_hand_transform
	
	# Update chocomels leash point to their collar
	visual_leash_line.points[visual_leash_line.points.size() - 1] = chocomel_collar_position
	
	# Put the leash handle at the correct position
	leash_handle.global_transform = pivot_transform_visual
	
	var leash_handle_front_position
	match current_leash_handle_state:
		leash_handle_states.HELD:
			# Set pindas leash point at the position of the leash handle end
			var leash_handle_front_bone = leash_handle_skeleton.find_bone("GDT-leash_point")
			leash_handle_front_position = (
				(pinda_hand_transform * leash_handle_skeleton.get_bone_global_pose(leash_handle_front_bone))
				.origin)
		leash_handle_states.SECURED:
			leash_handle_front_position = pivot_transform_visual.origin
	visual_leash_line.points[0] = leash_handle_front_position
	
	# interpolate points between start and end
	var total_length = 0.
	var segment_length = []
	for i in visual_leash_line.points.size()-1:
		var p1 = visual_leash_line.points[i]
		var p2 = visual_leash_line.points[i+1]
		var d = Vector2(p1.x, p1.z).distance_to(Vector2(p2.x, p2.z))
		segment_length.push_back(d)
		total_length += d
		
	var idx
	for i in visual_leash_line.points.size()-1:
		idx = visual_leash_line.points.size() - 1 - i - 1
		var p1 = visual_leash_line.points[idx]
		var p2 = visual_leash_line.points[idx+1]
		var d = Vector2(p1.x, p1.z).distance_to(Vector2(p2.x, p2.z))
		var n = int(d / .1)
		for j in n:
			visual_leash_line.points.insert(idx+1, lerp(p2, p1, float(j) / n))
	
	total_length = 0.
	segment_length = []
	for i in visual_leash_line.points.size()-1:
		var p1 = visual_leash_line.points[i]
		var p2 = visual_leash_line.points[i+1]
		var d = Vector2(p1.x, p1.z).distance_to(Vector2(p2.x, p2.z))
		segment_length.push_back(d)
		total_length += d
	
	(func (): prev_total_length = total_length).call_deferred()
	
	var wobble_threshold = Context.player.maxmimum_leash_length * .85
	
	if wobble_timer > 0.:
		wobble_timer -= get_process_delta_time()
	if Context.pinda.leash_limit_just_reached:
		wobble_timer = 1.
	elif wobble_timer < 0.:
		wobble_timer = 0.
	
	var length_parameter = 0.
	var delta = line_3d.points[-1] - line_3d.points[0]
	
	var sag_factor = lerp(2.5, 0.001, total_length / wobble_threshold)
	sag_factor = max(.001, sag_factor)
	
	var a = (visual_leash_line.points[0].y - visual_leash_line.points[-1].y + sag_factor) / (2. * sag_factor)
	
	var time = Time.get_ticks_msec() / 1000. * 100.
	var wobble_strength = 1.
	
	for i in visual_leash_line.points.size()-2:
		length_parameter += segment_length[i]
		visual_leash_line.points[i+1].y = sag_factor * ((length_parameter / total_length) - a) ** 2. + visual_leash_line.points[0].y - ((a ** 2.) * sag_factor)
		visual_leash_line.points[i+1].y = max(visual_leash_line.points[i+1].y, pinda_position.y + 0.05)
		
		if wobble_timer > 0.:
			var wobble_factor : float = wobble_strength * (length_parameter / total_length) ** 2 * wobble_timer * sin(time)
			visual_leash_line.points[i+1].y += wobble_factor * sin(length_parameter / total_length * 4. * PI) * .125
			visual_leash_line.points[i+1].y += wobble_factor * sin(length_parameter / total_length * 3. * PI) * .25
			visual_leash_line.points[i+1].y += wobble_factor * sin(length_parameter / total_length * 2. * PI) * .5
			visual_leash_line.points[i+1].y += wobble_factor * sin(length_parameter / total_length * 1. * PI)
	
	visual_leash_line.rebuild()


# NOTE: Replacement functions to emulate Line2D functions

func get_point_count() -> int:
	# TODO: See if this really returns the correct number or too high by 1
	return line_3d.points.size()


func set_point_position(index: int, location: Vector3) -> void:
	# Replace height for point
	location.y = FIXED_HEIGHT
	line_3d.points.set(index, location)
	


func remove_point(index: int) -> void:
	line_3d.points.remove_at(index)


func add_point(location: Vector3, index: int = -1) -> void:
	line_3d.points.insert(index, location)


# NOTE: Signal functions

func _on_chocomel_has_moved(
		new_position: Vector3,
		new_velocity: Vector3,
		leash_scalar : float,
		moving_to_pinda_scalar : float,
		collar_pivot_position : Vector3
) -> void:
	chocomel_position = new_position
	chocomel_collar_position = collar_pivot_position


func _on_pinda_has_moved(
		new_pinda_position : Vector3,
		new_pinda_velocity : Vector3,
	) -> void:
	pinda_position = new_pinda_position


func _on_pinda_hand_updated(hand_transform : Transform3D):
	pinda_hand_transform = hand_transform
