extends Node

class_name GateSequence
const sequence_name := "Gate"

#const pos_chocomel_start = Vector3(-1.19956, 0., 2.40852)
#const pos_pinda_start = Vector3(0.747671, 0., 0.829843)

enum sequence_states {
	INSPECT_GATE,
	GET_TO_POLE,
	INSPECT_POLE,
	GET_TO_PLANK,
	INSPECT_PLANK,
	ALERT_CHOCOMEL,
	ENTER_FENCE,
	GET_TO_GATE,
	UNLOCK_GATE,
	OPEN_GATE,
	GET_TO_FENCE,
	EXIT_FENCE,
	FINISH,
}

# sequencing
var active_sequence := false
var current_sequence_state := 0
var sequence_init = {
	sequence_states.INSPECT_GATE : seq_inspect_gate_init,
	sequence_states.GET_TO_POLE : seq_get_to_pole_init,
	sequence_states.INSPECT_POLE : seq_inspect_pole_init,
	sequence_states.GET_TO_PLANK : seq_get_to_plank_init,
	sequence_states.INSPECT_PLANK : seq_inspect_plank_init,
	sequence_states.ALERT_CHOCOMEL : seq_alert_chocomel_init,
	sequence_states.ENTER_FENCE : seq_enter_fence_init,
	sequence_states.GET_TO_GATE : seq_get_to_gate_init,
	sequence_states.UNLOCK_GATE : seq_unlock_gate_init,
	sequence_states.OPEN_GATE : seq_open_gate_init,
	sequence_states.GET_TO_FENCE : seq_get_to_fence_init,
	sequence_states.EXIT_FENCE : seq_exit_fence_init,
	sequence_states.FINISH : seq_finish_init,
}
var sequence_process = {
	sequence_states.INSPECT_GATE : seq_inspect_gate_process,
	sequence_states.GET_TO_POLE : seq_get_to_pole_process,
	sequence_states.INSPECT_POLE : seq_inspect_pole_process,
	sequence_states.GET_TO_PLANK : seq_get_to_plank_process,
	sequence_states.INSPECT_PLANK : seq_inspect_plank_process,
	sequence_states.ALERT_CHOCOMEL : seq_alert_chocomel_process,
	sequence_states.ENTER_FENCE : seq_enter_fence_process,
	sequence_states.GET_TO_GATE : seq_get_to_gate_process,
	sequence_states.UNLOCK_GATE : seq_unlock_gate_process,
	sequence_states.OPEN_GATE : seq_open_gate_process,
	sequence_states.GET_TO_FENCE : seq_get_to_fence_process,
	sequence_states.EXIT_FENCE : seq_exit_fence_process,
}

var camera : GameCamera
var pinda : Pinda
var chocomel : Chocomel
var leash : Leash
var gate : Gate
var current_start_point : Area3D

var pinda_state_machine_playback : AnimationNodeStateMachinePlayback
var chocomel_state_machine_playback : AnimationNodeStateMachinePlayback
var fence_gate_state_machine_playback : AnimationNodeStateMachinePlayback

var gate_pivot_transform : Transform3D

# Used to allow advancing sequence anyway for inspection spots, if canceled before animation was over.
var inspected_enough := false

func _ready():
	Context.sequence_gate = self
	
	print('Initialize Gate')
	call_deferred("init_gate_sequence_variables")


func _process(delta: float) -> void:
	
	# Only process when Pinda is interacting with the gate challenge
	if not active_sequence:
		return
	
	if current_sequence_state in sequence_process.keys():
		sequence_process[current_sequence_state].call()


func advance_sequence(anim := ""):
	current_sequence_state += 1
	print("Advancing %s sequence: %d (%s)" % [sequence_name, current_sequence_state, sequence_states.keys()[current_sequence_state]])
	sequence_init[current_sequence_state].call()


func retract_sequence():
	current_sequence_state -= 1
	print("Retracting %s sequence: %d (%s)" % [sequence_name, current_sequence_state, sequence_states.keys()[current_sequence_state]])
	sequence_init[current_sequence_state].call()


func start(interaction_id : Constants.interactable_ids):
	if interaction_id != Constants.interactable_ids.GATE:
		return
	print('Starting Gate Challenge')
	
	# (Re)initiate the current sequence step
	sequence_init[current_sequence_state].call()
	active_sequence = true
	
	pinda.reached_point_of_interest.disconnect(start)


func stop():
	print('Exiting Gate Challenge')
	
	# Wrap up the gate challenge sequence if done
	#if current_sequence_state == sequence_states.FINISH:
		#pinda.set_state_reward_chocomel()
		#self.queue_free()
	
	# Stop sequence processes
	active_sequence = false
	
	# Hook up start function again for next time
	pinda.reached_point_of_interest.disconnect(reached_next_point)
	pinda.reached_point_of_interest.connect(start)
	


func init_gate_sequence_variables():
	pinda = Context.pinda
	chocomel = Context.chocomel
	leash = Context.leash
	camera = Context.camera
	
	# Init gate prop variables
	gate = Context.interactable_nodes[Constants.interactable_ids.GATE]
	fence_gate_state_machine_playback = gate.animation_tree.get("parameters/playback")
	
	fence_gate_state_machine_playback.start("default")
	# In case the starting animation was set wrong
	leash.update_pivot_positions()
	gate.open_gate_collision.disabled = true
	gate.closed_gate_collision.disabled = false
	
	# Init Pinda variables
	pinda_state_machine_playback = Context.pinda.animation_tree.get("parameters/AnimationStates/playback")
	
	# Init Chocomel variables
	chocomel_state_machine_playback = chocomel.animation_tree.get("parameters/animation states/playback")
	
	if Context.debug.skip_gate:
		skip_gate_challenge()
		return
	
	# Start setup
	pinda.reached_point_of_interest.connect(start)
	# Enable the start point_of_interest for the gate challenge
	gate.gate_inspection_spot.monitorable = true
	
	# Debug
	#current_sequence_state = sequence_states.ENTER_FENCE


func check_valid_character_state() -> bool:
	
	var conditions_met := (
		pinda.current_character_state == pinda.character_states.GATE
		or pinda.queued_character_state == pinda.character_states.GATE
		or pinda.current_character_state == pinda.character_states.CINEMATIC
		or pinda.queued_character_state == pinda.character_states.CINEMATIC
	)
	return conditions_met


func queue_pinda_to_gate_transform(bone_name : String) -> void:
	# Set Pinda transform
	var bone_pivot := gate.skeleton.find_bone(bone_name)
	# BUG: For some reason the orientation of the spot2 and 3 are 180 degrees off.
	# Also the spot1 can sometimes be off by a few degrees. No idea why ...
	var pivot_transform := gate.skeleton.get_bone_global_pose(bone_pivot)
	pinda.queued_transform = gate.global_transform * pivot_transform
	#gate_pivot_transform = gate.global_transform * pivot_transform
	
	#print("new rotation = " + str(pivot_transform.basis.z))


## NOTE: Sequence logic

func seq_inspect_gate_init() -> void:
	print("Init Gate Inspection")
	
	pinda.queue_next_character_state(
		pinda.character_states.GATE,
		pinda.animation_states.INSPECTING_SPOT1
	)
	
	# Set Pinda transform
	queue_pinda_to_gate_transform("pivot_gate_south")
	fence_gate_state_machine_playback.travel("inspect spot 1")
	pinda.animation_tree.animation_finished.connect(advance_sequence)
	inspected_enough = false


func seq_inspect_gate_process() -> void:
	check_stopped_inspecting()
	check_enough_inspecting()

func seq_get_to_pole_init() -> void:
	print("Get to Pole")
	pinda.animation_tree.animation_finished.disconnect(advance_sequence)
	
	make_pinda_seek_next_point(gate.fence_inspection_spot)


func seq_get_to_pole_process() -> void:
	check_stopped_seeking()


func seq_inspect_pole_init() -> void:
	print("Init Pole Inspection")
	
	pinda.queue_next_character_state(
		pinda.character_states.GATE,
		pinda.animation_states.INSPECTING_SPOT2
	)
	
	queue_pinda_to_gate_transform("pivot_fence")
	pinda.animation_tree.animation_finished.connect(advance_sequence)
	inspected_enough = false


func seq_inspect_pole_process() -> void:
	check_stopped_inspecting()
	check_enough_inspecting()


func seq_get_to_plank_init() -> void:
	print("Get to Plank")
	pinda.animation_tree.animation_finished.disconnect(advance_sequence)
	
	make_pinda_seek_next_point(gate.plank_inspection_spot)


func seq_get_to_plank_process() -> void:
	check_stopped_seeking()


func seq_inspect_plank_init() -> void:
	print("Init Plank Inspection")
	
	pinda.queue_next_character_state(
		pinda.character_states.GATE,
		pinda.animation_states.INSPECTING_SPOT3
	)
	
	queue_pinda_to_gate_transform("pivot_plank_south")
	pinda.animation_tree.animation_finished.connect(finish_inspecting)
	inspected_enough = false


func seq_inspect_plank_process() -> void:
	check_stopped_inspecting()


func seq_alert_chocomel_init() -> void:
	print("Shout to chocomel")
	
	pinda.force_next_character_state(
		pinda.character_states.GATE,
		pinda.animation_states.CALLING_OUT
	)
	pinda.emote_bubbles.trigger_emote(pinda.emote_bubbles.emote_states.CHOCOMEL, pinda.EMOTE_DURATION)
	pinda.set_rotation_from_vector(Vector3.BACK)
	pinda.animation_tree.animation_finished.connect(finished_alerting_chocomel)


func seq_alert_chocomel_process() -> void:
	if not check_valid_character_state():
		current_sequence_state = sequence_states.ENTER_FENCE
		pinda.animation_tree.animation_finished.disconnect(finished_alerting_chocomel)
		stop()


func seq_enter_fence_init() -> void:
	print("Enter fence")
	
	pinda.set_rotation_from_vector(Vector3.FORWARD)
	
	pinda.queue_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.MOVING_THROUGH_FENCE
	)
	
	queue_pinda_to_gate_transform("pivot_plank_south")
	
	pinda.animation_tree.animation_finished.connect(teleport_to_north_of_fence)


func seq_enter_fence_process() -> void:
	# Invincible
	pass

func seq_get_to_gate_init() -> void:
	print("Go to open the gate")
	
	make_pinda_seek_next_point(gate.open_gate_spot)


func seq_get_to_gate_process() -> void:
	
	if check_dragging_through_fence():
		current_sequence_state = sequence_states.ENTER_FENCE # TASK Check if this actually works


func seq_unlock_gate_init() -> void:
	print("Unlock the gate")
	
	pinda.queue_next_character_state(
		pinda.character_states.GATE,
		pinda.animation_states.UNLOCKING_GATE
	)
	queue_pinda_to_gate_transform("pivot_gate_north")
	
	fence_gate_state_machine_playback.travel("unlocking gate")
	
	pinda.animation_tree.animation_finished.connect(advance_sequence)


func seq_unlock_gate_process() -> void:
	# Stay in the sequence on this side of the fence
	check_stopped_opening_gate()


func seq_open_gate_init() -> void:
	print("Open the gate")
	pinda.animation_tree.animation_finished.disconnect(advance_sequence)
	
	pinda.queue_next_character_state(
		pinda.character_states.GATE,
		pinda.animation_states.GATE_OPEN
	)
	queue_pinda_to_gate_transform("pivot_gate_north")
	
	fence_gate_state_machine_playback.travel("open gate")
	gate.animation_tree.animation_finished.connect(gate_is_fully_opened)
	gate.open_gate_collision.disabled = false
	gate.closed_gate_collision.disabled = true
	
	# Can make the leash more stable
	leash.update_pivot_positions()
	
	pinda.animation_tree.animation_finished.connect(advance_sequence)


func seq_open_gate_process() -> void:
	# Invincible
	if not check_valid_character_state():
		advance_sequence()
		pinda.animation_tree.animation_finished.disconnect(advance_sequence)


func seq_get_to_fence_init() -> void:
	print("Get back to the fence")
	
	make_pinda_seek_next_point(gate.other_side_spot)


func seq_get_to_fence_process() -> void:
	# Stay in the sequence on this side of the fence
	
	check_dragging_through_fence()


func seq_exit_fence_init() -> void:
	print("Get back through the fence")
	
	pinda.queue_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.MOVING_THROUGH_FENCE
	)
	queue_pinda_to_gate_transform("pivot_plank_north")
	
	#fence_gate_state_machine_playback.travel("secret path")
	
	pinda.animation_tree.animation_finished.connect(teleport_to_south_of_fence)


func seq_exit_fence_process() -> void:
	# Stay in the sequence on this side of the fence
	pass


func seq_finish_init() -> void:
	
	for spot in gate.interest_points:
		# Deleting the nodes because just disabling 'monitorable' didn't work
		spot.queue_free()
	pinda.reset_point_of_interest()
	
	# Reset leash
	leash.update_pivot_positions()
	
	GameStatus.gate_opened = true
	self.queue_free()


func skip_gate_challenge() -> void:
	print("Gate sequence skipped. Gate is open")
	fence_gate_state_machine_playback.start("open gate")
	gate.animation_tree.animation_finished.connect(gate_is_fully_opened)
	gate.animation_tree.animation_finished.connect(remove_youself)
	
	gate.open_gate_collision.disabled = false
	gate.closed_gate_collision.disabled = true
	leash.update_pivot_positions()
	
	GameStatus.gate_opened = true
	for spot in gate.interest_points:
		spot.queue_free()


func remove_youself(anim := "") -> void:
	gate.animation_tree.animation_finished.disconnect(remove_youself)
	self.queue_free()


# NOTE: Signaled functions to advance the states


func check_stopped_inspecting() -> void:
	if not check_valid_character_state():
		
		pinda.animation_tree.animation_finished.disconnect(advance_sequence)
		pinda.animation_tree.animation_finished.disconnect(finish_inspecting)
		fence_gate_state_machine_playback.travel("default")
		
		if inspected_enough:
			advance_sequence()
		
		stop()


func check_enough_inspecting() -> void:
	if pinda.current_animation_position >= 3.0:
		inspected_enough = true


func check_stopped_opening_gate() -> void:
	if not check_valid_character_state():
		# Make sure pinda is canceled out of the current animaton
		pinda.force_next_character_state(
			pinda.character_states.CATCHING_UP,
			pinda.animation_states.REGULAR
		)
		pinda.trigger_yanking_animation()
		
		retract_sequence()
		pinda.animation_tree.animation_finished.disconnect(advance_sequence)
		fence_gate_state_machine_playback.travel("lifted pose")


func check_stopped_seeking() -> void:
	if pinda.current_character_state != pinda.character_states.SEEKING:
		stop()


func make_pinda_seek_next_point(next_spot : Area3D) -> void:
	
	# Disable all spots
	for spot in gate.interest_points:
		# Deleting the nodes because just disabling 'monitorable' didn't work
		spot.monitorable = false
	
	# Only enable the next one
	next_spot.monitorable = true
	
	# Update next interest location
	pinda.point_of_interest_location = next_spot.global_position
	
	# Set pinda state to seek next point
	pinda.queue_next_character_state(
		pinda.character_states.SEEKING,
		pinda.animation_states.REGULAR
	)
	
	pinda.reached_point_of_interest.connect(reached_next_point)


func reached_next_point(interaction_id := Constants.interactable_ids.GATE) -> void:
	if interaction_id != Constants.interactable_ids.GATE:
		stop()
	print("Reached next point")
	
	pinda.reached_point_of_interest.disconnect(reached_next_point)
	advance_sequence()


func finish_inspecting(anim : String) -> void:
	
	if anim.ends_with("spot03"):
		print("Lifting Plank")
		pinda.force_next_character_state(
			pinda.character_states.CINEMATIC,
			pinda.animation_states.OPENING_SPOT3
		)
		fence_gate_state_machine_playback.travel("lift plank")
	else:
		print("Finished Inspecting Spots")
		pinda.animation_tree.animation_finished.disconnect(finish_inspecting)
		advance_sequence()


func finished_alerting_chocomel(anim : String) -> void:
	if anim.ends_with("calling_far"):
		advance_sequence()
		pinda.animation_tree.animation_finished.disconnect(finished_alerting_chocomel)


func teleport_to_north_of_fence(anim : String) -> void:
	
	if anim.ends_with("fence_in") or anim.ends_with("fence_fallen"):
		advance_sequence()
		pinda.global_position = gate.other_side_spot.global_position
		
		# Can make the leash more stable
		leash.update_pivot_positions()

		pinda.animation_tree.animation_finished.disconnect(teleport_to_north_of_fence)


func teleport_to_south_of_fence(anim : String) -> void:
	
	#if anim.ends_with("fence_in") or anim.ends_with("fence_fallen"):
	pinda.global_position = gate.plank_inspection_spot.global_position
	
	# Can make the leash more stable
	leash.update_pivot_positions()

	pinda.animation_tree.animation_finished.disconnect(teleport_to_south_of_fence)
	
	# TODO: This is very easy to fail. Better check in some other way if the sequence should end.
	if fence_gate_state_machine_playback.get_current_node().ends_with("opened"):
		
		# Reset Pinda's animation state
		pinda_state_machine_playback.start('Start')
		
		# Wrap up the gate challenge sequence if done
		pinda.set_state_reward_chocomel()
		
		seq_finish_init()
	else:
		current_sequence_state = sequence_states.ENTER_FENCE
		
		make_pinda_seek_next_point(gate.plank_inspection_spot)
		# To make sure that the sequence isn't double advanced when re-entering
		pinda.reached_point_of_interest.disconnect(reached_next_point)

func check_dragging_through_fence() -> bool:
	
	var distance_to_fence_exit := (gate.other_side_spot.global_position - pinda.global_position).length()
	var conditions_met := (
		pinda.current_character_state == pinda.character_states.STUCK
		and distance_to_fence_exit <= 0.8
		and pinda.pull_factor >= 1.0
	)
	if not conditions_met:
		return false
	
	pinda.force_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.FALLEN_THROUGH_FENCE
	)
	queue_pinda_to_gate_transform("pivot_plank_north")
	pinda.animation_tree.animation_finished.connect(teleport_to_south_of_fence)
	stop()
	
	return true


## Check if the gate finished opening.
func gate_is_fully_opened(anim := "String") -> void:
	print("Updating leash points")
	
	# Needed becaus the leash collision points changed
	leash.update_pivot_positions()
	
	gate.animation_tree.animation_finished.disconnect(gate_is_fully_opened)
