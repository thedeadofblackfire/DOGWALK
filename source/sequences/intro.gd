extends Node

class_name Intro
const sequence_name := "Intro"

enum sequence_states {
	MENU,
	PEBBLE,
	PICK_UP,
	ATTACH,
	REWARD,
	WAIT,
	GAME
}

# sequencing
var sequence_state := 0
var sequence_init = {
	sequence_states.PEBBLE : seq_pebble_init,
	sequence_states.PICK_UP : seq_pick_up_init,
	sequence_states.ATTACH : seq_attach_init,
	sequence_states.REWARD : seq_reward_init,
	sequence_states.WAIT : seq_wait_init,
	sequence_states.GAME : seq_game_init,
}
var sequence_process = {
	sequence_states.MENU : seq_menu_process,
	sequence_states.PEBBLE : seq_pebble_process,
	sequence_states.PICK_UP : seq_pick_up_process,
	sequence_states.ATTACH : seq_attach_process,
	sequence_states.REWARD : seq_reward_process,
	sequence_states.WAIT : seq_wait_process,
}

var camera : GameCamera
var pinda : Pinda
var chocomel : Chocomel
var leash : Leash
var branch : Node3D
var snowman : StaticBody3D
var snowman_emote_bubble : EmoteBubble
var snowman_emote_bubble_nose : EmoteBubble
var snowman_emote_bubble_cane : EmoteBubble
var snowman_emote_bubble_button_prompt : EmoteBubble
var chocomel_emote_bubble : EmoteBubble
var branch_emote_bubble : EmoteBubble

var pinda_pivot : Node3D
var chocomel_pivot : Node3D
var leash_attachment_point : Node3D
var button_prompt_timer : Timer
const button_prompt_wait_time := 2.

var main_menu
var pinda_state_machine_playback : AnimationNodeStateMachinePlayback
var chocomel_state_machine_playback : AnimationNodeStateMachinePlayback
var snowman_state_machine_playback : AnimationNodeStateMachinePlayback

var branch_camera_magnet_zone : CameraMagnetZone
const branch_detection_radius = 2.5

var leash_camera_magnet_zone : CameraMagnetZone
const CALL_FOR_ADVENTURE_RADIUS := 3.5

func _ready():
	Context.sequence_intro = self
	print('Initialize Intro')
	call_deferred("init_intro")
	
	button_prompt_timer = Timer.new()
	button_prompt_timer.wait_time = button_prompt_wait_time
	button_prompt_timer.autostart = false
	self.add_child(button_prompt_timer)
	button_prompt_timer.timeout.connect(move_prompt)

func _process(delta: float) -> void:
	if sequence_state in sequence_process.keys():
		sequence_process[sequence_state].call()
	
	if button_prompt_timer.timeout.is_connected(move_prompt):
		if chocomel.current_animation_state == chocomel.animation_state_names[chocomel.animation_states.WAKING]:
			button_prompt_timer.timeout.disconnect(move_prompt)
			chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.NONE)

func advance_sequence():
	sequence_state += 1
	print("Advancing %s sequence: %d (%s)" % [sequence_name, sequence_state, sequence_states.keys()[sequence_state]])
	sequence_init[sequence_state].call()

func start():
	print('Starting Intro')
	if Context.debug.skip_intro:
		stop()
		return
	GameStatus.current_game_state = GameStatus.game_states.INTRO
	advance_sequence()

func stop():
	print('Exiting Intro')
	if GameStatus.current_game_state not in [GameStatus.game_states.LOADING]:
		GameStatus.current_game_state = GameStatus.game_states.GAMEPLAY
	
	# Reset Pinda's animation state, but let Chocomel sleep
	pinda.queue_next_character_state(
		pinda.character_states.CATCHING_UP,
		pinda.animation_states.REGULAR
	)
	
	pinda.force_next_animation("Seeking and Catching Up")
	pinda.reset_point_of_interest()
	
	if Context.debug.skip_wake_up:# TODO: remove debug
		chocomel.force_next_character_state(
			chocomel.character_states.IDLE,
			chocomel.animation_states.IDLE
		)
		chocomel_state_machine_playback.start('Start')
	
	leash.current_leash_handle_state = leash.leash_handle_states.HELD
	
	# make sure branch state is initialized
	branch.item_state = GameStatus.item_states.PLACED
	
	snowman_state_machine_playback.start("Idle")
	
	self.queue_free()
	(func(): SignalBus.trigger_auto_save.emit()).call_deferred()
	
func init_intro():
	pinda = Context.pinda
	chocomel = Context.chocomel
	leash = Context.leash
	snowman = Context.interactable_nodes[Constants.interactable_ids.SNOWMAN]
	branch = Context.interactable_nodes[Constants.interactable_ids.BRANCH]
	
	# Init Camera Zones
	branch_camera_magnet_zone = Context.level.find_child("CameraMagnetZone_branch").find_child("CameraMagnetZone_Area")
	branch_camera_magnet_zone.disabled = true
	leash_camera_magnet_zone = Context.level.find_child("CameraMagnetZone_leash_point").find_child("CameraMagnetZone_Area")
	leash_camera_magnet_zone.disabled = true

	# Init Snowman
	snowman_emote_bubble = snowman.get_parent().find_child("PR-snowman_emotes")
	snowman_emote_bubble_nose = snowman.get_parent().find_child("PR-snowman_emotes_nose")
	snowman_emote_bubble_cane = snowman.get_parent().find_child("PR-snowman_emotes_cane")
	snowman_emote_bubble_button_prompt = snowman.get_parent().find_child("EmoteBubble_Prompt")
	snowman_state_machine_playback = snowman.animation_tree.get("parameters/playback")
	snowman_state_machine_playback.start("Intro")
	snowman.animation_tree.animation_started.connect(init_character_transforms)
	
	# Init Branch
	branch_emote_bubble = branch.get_parent().find_child("EmoteBubble_Prompt")
	
	# Init Pinda
	pinda_state_machine_playback = Context.pinda.animation_tree.get("parameters/AnimationStates/playback")
	
	pinda.force_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.BUILDING
	)
	
	# Init Chocomel
	chocomel_state_machine_playback = chocomel.animation_tree.get("parameters/animation states/playback")
	chocomel_emote_bubble = chocomel.find_child("EmoteBubble")
	
	chocomel.force_next_character_state(
		chocomel.character_states.CINEMATIC,
		chocomel.animation_states.SLEEPING
	)
	
	# Init Leash
	leash.current_leash_handle_state = leash.leash_handle_states.SECURED

func reset_pinda_transform():
	if pinda_pivot:
		pinda.global_transform = pinda_pivot.global_transform

func init_character_transforms(anim : String):
	if not anim.ends_with("intro"):
		return
		
	## Pinda Transform
	pinda_pivot = Node3D.new()
	self.add_child(pinda_pivot)
	pinda_pivot.owner = self
	
	pinda_pivot.global_transform = snowman.skeleton.get_bone_global_pose(snowman.skeleton.find_bone("Pinda-intro"))
	pinda_pivot.global_transform = snowman.skeleton.global_transform * pinda_pivot.global_transform
	
	reset_pinda_transform()
	
	## Chocomel Transform
	chocomel_pivot = Node3D.new()
	self.add_child(chocomel_pivot)
	chocomel_pivot.owner = self
	
	chocomel_pivot.global_transform = snowman.skeleton.get_bone_global_pose(snowman.skeleton.find_bone("Chocomel-intro"))
	chocomel_pivot.global_transform = snowman.skeleton.global_transform * chocomel_pivot.global_transform
	
	chocomel.global_transform  = chocomel_pivot.global_transform
	leash.reset()
	
	snowman.animation_tree.animation_started.disconnect(init_character_transforms)

func move_prompt():
	match InputController.current_input_mode:
		InputController.input_modes.MOUSE:
			chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.MOVE_MOUSE)
			#Context.chocomel.sound_effects.play_emote_sound(EmoteBubble.emote_states.MOVE_MOUSE)
			
		InputController.input_modes.CONTROLLER:
			chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.MOVE_STICK)

## sequence logic

func seq_menu_process():
	reset_pinda_transform()

func seq_pebble_init():
	pinda.queue_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.THINKING
	)
	pinda.animation_tree.animation_started.connect(attach_rock)
	pinda.animation_tree.animation_finished.connect(think_about_arm)
	chocomel.has_barked.connect(check_for_branch)

func seq_pebble_process():
	reset_pinda_transform()

func attach_rock(anim : String):
	if anim.ends_with("attach_rock"):
		snowman_state_machine_playback.start('Attach Rock')
		pinda.animation_tree.animation_started.disconnect(attach_rock)

func think_about_arm(anim : String):
	if anim.ends_with("attach_rock"):
		snowman_emote_bubble.trigger_emote(EmoteBubble.emote_states.MISSING_ARM)
		branch_camera_magnet_zone.disabled = false
		button_prompt_timer.start()
		pinda.animation_tree.animation_finished.disconnect(think_about_arm)
		
		# Button prompt
		match InputController.current_input_mode:
			InputController.input_modes.MOUSE:
				branch_emote_bubble.trigger_emote(EmoteBubble.emote_states.CLICK_PROMPT)
			InputController.input_modes.CONTROLLER:
				branch_emote_bubble.trigger_emote(EmoteBubble.emote_states.BUTTON_PROMPT)

func check_for_branch():
	if pinda_state_machine_playback.get_current_node() != "Thinking":
		return
	print("checking for branch")
	if (chocomel.global_position - Context.interactable_nodes[Constants.interactable_ids.BRANCH].global_position).length() < branch_detection_radius:
		chocomel.has_barked.disconnect(check_for_branch)
		
		pinda.emote_bubbles.trigger_emote(
			EmoteBubble.emote_states.EXCLAMATION,
			pinda.EMOTE_DURATION
		)
		pinda.force_next_animation("React Bark Branch")
		pinda.animation_tree.animation_finished.connect(stick_seen)
		branch_emote_bubble.trigger_emote(EmoteBubble.emote_states.NONE)

func stick_seen(anim : String):
	print("stick seen")
	if anim.ends_with("bark_turn"):
		pinda.animation_tree.animation_finished.disconnect(stick_seen)
		advance_sequence()

func seq_pick_up_init():
	snowman_emote_bubble.trigger_emote(EmoteBubble.emote_states.NONE)
	chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.NONE)
	
	pinda.force_next_character_state(
		pinda.character_states.SEEKING,
		pinda.animation_states.REGULAR
	)

func seq_pick_up_process():
	# set point of interest
	pinda.spotted_point_of_interest(branch)
	
	if branch.item_state == GameStatus.item_states.HELD:
		advance_sequence()

func seq_attach_init():
	# currently not actually happening, since pinda is just handing out treats
	pinda.queue_next_character_state(
		pinda.character_states.SEEKING,
		pinda.animation_states.REGULAR
	)
	pinda.reached_point_of_interest.connect(attach_branch)
	pinda.animation_tree.animation_finished.connect(swap_camera_magnet_zones)

func swap_camera_magnet_zones(anim := "") -> void:
	branch_camera_magnet_zone.disabled = true
	leash_camera_magnet_zone.disabled = false
	pinda.animation_tree.animation_finished.disconnect(swap_camera_magnet_zones)

func seq_attach_process():
	# set point of interest
	pinda.current_point_of_interest = pinda_pivot
	pinda.point_of_interest_interaction_id = -1
	pinda.point_of_interest_location = pinda_pivot.global_position
	pinda.point_of_interest_location.y = 0.0
	
	if pinda_state_machine_playback.get_current_node() in ["Attach Branch"]:
		reset_pinda_transform()

func attach_branch(id):
	pinda.reached_point_of_interest.disconnect(attach_branch)
	pinda.force_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.ATTACH_BRANCH
	)
	
	snowman_state_machine_playback.start('Attach Branch')
	pinda.animation_tree.animation_finished.connect(finish_attach)
	
	GameStatus.placed_item(Constants.interactable_ids.BRANCH)

func finish_attach(anim : String):
	if anim.ends_with("attach_branch"):
		pinda.animation_tree.animation_finished.disconnect(finish_attach)
		advance_sequence()

func seq_reward_init():
	print("start reward")
	
	pinda.set_state_reward_chocomel()
	
	pinda.entering_character_state.connect(end_reward)
	pass
	
func seq_reward_process():
	# set point of interest
	pinda.current_point_of_interest = pinda_pivot
	pinda.point_of_interest_interaction_id = -1
	pinda.point_of_interest_location = pinda_pivot.global_position
	pinda.point_of_interest_location.y = 0.0
	
	if pinda_state_machine_playback.get_current_node() in ["Attach Branch"]:
		reset_pinda_transform()

func end_reward(state):
	if state not in [pinda.character_states.CATCHING_UP, pinda.character_states.SEEKING]:
		return
	pinda.entering_character_state.disconnect(end_reward)
	
	pinda.force_next_character_state(
		pinda.character_states.SEEKING,
		pinda.animation_states.REGULAR
	)
		
	print("end reward")
	pinda.reached_point_of_interest.connect(found_back_to_pivot)

func found_back_to_pivot(poi_id):
	pinda.reached_point_of_interest.disconnect(found_back_to_pivot)
	advance_sequence()

func seq_wait_init():
	pinda.global_transform = pinda_pivot.global_transform
	
	pinda.force_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.THINKING
	)
	
	snowman_emote_bubble.trigger_emote(EmoteBubble.emote_states.MISSING_HAT)
	snowman_emote_bubble_nose.trigger_emote(EmoteBubble.emote_states.MISSING_NOSE)
	snowman_emote_bubble_cane.trigger_emote(EmoteBubble.emote_states.MISSING_CANE)
	
	leash_attachment_point = Node3D.new()
	leash_attachment_point.name = "Leash Attachment Point"
	self.add_child(leash_attachment_point)
	leash_attachment_point.global_position = snowman.skeleton.get_bone_global_pose(snowman.skeleton.find_bone("Pinda")).origin
	leash_attachment_point.owner = self
	enforce_leash_goal_point()
	
	leash_camera_magnet_zone.disabled = true
	
	chocomel.has_barked.connect(init_run_to_chocomel)

func seq_wait_process():
	if leash_attachment_point:
		enforce_leash_goal_point()
	
	var leash_point_distance := (leash_attachment_point.global_position - chocomel.global_position).length()
	var enough_distance := leash_point_distance >= CALL_FOR_ADVENTURE_RADIUS
	if enough_distance:
		match InputController.current_input_mode:
			InputController.input_modes.MOUSE:
				chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.CLICK_PROMPT)
			InputController.input_modes.CONTROLLER:
				chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.BUTTON_PROMPT)
	else:
		chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.NONE)

func enforce_leash_goal_point():
		# set point of interest
		pinda.current_point_of_interest = leash_attachment_point
		pinda.point_of_interest_interaction_id = -1
		pinda.point_of_interest_location = leash_attachment_point.global_position
		pinda.point_of_interest_location.y = 0.0

func init_run_to_chocomel():
	print("checking for leash")
	var leash_point_distance := (leash_attachment_point.global_position - chocomel.global_position).length()
	var enough_distance := leash_point_distance >= CALL_FOR_ADVENTURE_RADIUS
	if not enough_distance:
		return
	chocomel.has_barked.disconnect(init_run_to_chocomel)
	snowman_emote_bubble.trigger_emote(EmoteBubble.emote_states.NONE)
	snowman_emote_bubble_nose.trigger_emote(EmoteBubble.emote_states.NONE)
	snowman_emote_bubble_cane.trigger_emote(EmoteBubble.emote_states.NONE)
	chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.NONE)
	snowman_emote_bubble_button_prompt.trigger_emote(EmoteBubble.emote_states.NONE)
	
	leash_camera_magnet_zone.disabled = false
	
	pinda.force_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.REGULAR
	)
	pinda.force_next_animation("React Bark Leash")
	pinda.animation_tree.animation_finished.connect(start_run_to_chocomel)


func start_run_to_chocomel(anim : String):
	if not anim.ends_with("_aha"):
		return
	pinda.animation_tree.animation_finished.disconnect(start_run_to_chocomel)
	
	pinda.emote_bubbles.trigger_emote(
		EmoteBubble.emote_states.EXCLAMATION,
		pinda.EMOTE_DURATION
	)
	pinda.force_next_character_state(
		pinda.character_states.SEEKING,
		pinda.animation_states.REGULAR
	)
	
	pinda.reached_point_of_interest.connect(unleash_chocomel)

func unleash_chocomel(poi_id):
	print('reached leash')
	pinda.reached_point_of_interest.disconnect(unleash_chocomel)
	pinda.global_rotation = Vector3.ZERO
	
	leash.current_leash_handle_state = leash.leash_handle_states.HELD
	
	pinda.force_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.DETACH_POINT
	)
	pinda.animation_tree.animation_finished.connect(end_sequence)
	
func end_sequence(anim : String):
	pinda.animation_tree.animation_finished.disconnect(end_sequence)
	
	leash_camera_magnet_zone.disabled = true
	chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.NONE)
	
	print("ending sequence")
	advance_sequence()

func seq_game_init():
	stop()
