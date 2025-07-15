extends Node

class_name Ending
const sequence_name := "Ending"

enum sequence_states {
	GAME,
	CEREMONY,
	CREDITS
}

# sequencing
var sequence_state := 0
var sequence_init = {
	sequence_states.CREDITS : seq_credits_init,
	sequence_states.CEREMONY : seq_ceremony_init,
}
var sequence_process = {
	sequence_states.CEREMONY : seq_ceremony_process,
}

var camera : GameCamera
var pinda : Pinda
var chocomel : Chocomel
var leash : Leash
var pinda_camera_prop : Node3D
var treat_prop : Node3D
var leash_handle_prop : Node3D
var snowman : StaticBody3D
var snowman_emote_bubble : EmoteBubble
var chocomel_emote_bubble : EmoteBubble

var pinda_pivot : Node3D
var chocomel_pivot : Node3D
var leash_attachment_point : Node3D
var ending_camera : Camera3D

var pinda_state_machine_playback : AnimationNodeStateMachinePlayback
var chocomel_state_machine_playback : AnimationNodeStateMachinePlayback
var snowman_state_machine_playback : AnimationNodeStateMachinePlayback

func _ready():
	Context.sequence_ending = self
	print('Initialize Ending')
	call_deferred("init_ending")
	call_deferred("start")

func _process(delta: float) -> void:
	if sequence_state in sequence_process.keys():
		sequence_process[sequence_state].call()

func advance_sequence():
	sequence_state += 1
	print("Advancing %s sequence: %d (%s)" % [sequence_name, sequence_state, sequence_states.keys()[sequence_state]])
	sequence_init[sequence_state].call()

func start():
	print('Starting Ending')
	if Context.debug.skip_ending:
		stop()
		return
	GameStatus.current_game_state = GameStatus.game_states.ENDING
	advance_sequence()

func stop():
	print('Exiting Ending')
	
	Context.sequence_credits = preload("res://source/sequences/credits/credits.tscn").instantiate()
	Context.menu_ui.find_child("CreditsDummy").add_child(Context.sequence_credits)
	
	self.queue_free()
	
func init_ending():
	pinda = Context.pinda
	chocomel = Context.chocomel
	leash = Context.leash
	snowman = Context.interactable_nodes[Constants.interactable_ids.SNOWMAN]

	# Init Snowman
	snowman_emote_bubble = snowman.get_parent().find_child("PR-snowman_emotes")
	snowman_state_machine_playback = snowman.animation_tree.get("parameters/playback")
	
	# Init Pinda
	pinda_state_machine_playback = Context.pinda.animation_tree.get("parameters/AnimationStates/playback")
	
	# Init Chocomel
	chocomel_state_machine_playback = chocomel.animation_tree.get("parameters/animation states/playback")
	chocomel_emote_bubble = chocomel.find_child("EmoteBubble")
	
	# Init Leash
	leash.current_leash_handle_state = leash.leash_handle_states.SECURED
	
	# Init reference camera
	ending_camera = Context.level.find_child("EndingCamera")

func reset_character_transforms():
	if pinda_pivot:
		pinda.global_transform = pinda_pivot.global_transform
	if chocomel_pivot:
		chocomel.global_transform  = chocomel_pivot.global_transform

func init_character_transforms():
		
	## Pinda Transform
	pinda_pivot = Node3D.new()
	self.add_child(pinda_pivot)
	pinda_pivot.owner = self
	
	pinda_pivot.global_transform = snowman.skeleton.get_bone_global_pose(snowman.skeleton.find_bone("Pinda"))
	pinda_pivot.global_transform = snowman.skeleton.global_transform * pinda_pivot.global_transform
	
	## Chocomel Transform
	chocomel_pivot = Node3D.new()
	self.add_child(chocomel_pivot)
	chocomel_pivot.owner = self
	
	chocomel_pivot.global_transform = pinda_pivot.global_transform * (chocomel.global_transform.inverse() * chocomel.skeleton.global_transform).inverse()
	
	reset_character_transforms()
	
	
	leash.reset()

func approach_ending_camera():
	var lerp_rate = 1. * get_process_delta_time()
	Context.camera.global_transform = lerp(Context.camera.global_transform, ending_camera.global_transform, lerp_rate)
	Context.camera.camera3D.fov = lerp(Context.camera.camera3D.fov, ending_camera.fov, lerp_rate)


## sequence logic
	
func seq_ceremony_init():
	snowman_emote_bubble.trigger_emote(EmoteBubble.emote_states.FIREWORKS)
	init_character_transforms()
	pinda.force_next_character_state(
		pinda.character_states.CINEMATIC,
		pinda.animation_states.REGULAR
	)
	chocomel.force_next_character_state(
		chocomel.character_states.CINEMATIC,
		chocomel.animation_states.IDLE
	)
	pinda.force_next_animation("Ending")
	chocomel.force_next_animation("Ending")
	
	pinda.animation_tree.animation_finished.connect(_on_finish_outro_anim)
	
	# init camera prop
	pinda_camera_prop = preload("res://assets/props/pinda_camera/PR-pinda_camera.tscn").instantiate()
	self.add_child(pinda_camera_prop)
	pinda_camera_prop.owner = self
	pinda_camera_prop.global_transform = pinda_pivot.global_transform
	var pinda_camera_anim_player : AnimationPlayer = pinda_camera_prop.find_child("AnimationPlayer")
	pinda_camera_anim_player.play("PR-pinda_camera-anim_lib/CINE-pinda_camera-outro")
	
	# init treats prop
	treat_prop = preload("res://assets/props/treat/PR-treat.tscn").instantiate()
	self.add_child(treat_prop)
	treat_prop.owner = self
	treat_prop.global_transform = pinda_pivot.global_transform
	var treat_prop_anim_player : AnimationPlayer = treat_prop.find_child("AnimationPlayer")
	treat_prop_anim_player.play("PR-treat-anim_lib/CINE-treat-outro")
	
	# init leash_handle prop
	Context.leash.hide()
	Context.leash.leash_handle.hide()
	
	leash_handle_prop = preload("res://assets/props/leash_handle/PR-leash_handle.tscn").instantiate()
	self.add_child(leash_handle_prop)
	leash_handle_prop.owner = self
	leash_handle_prop.global_transform = pinda_pivot.global_transform
	var leash_handle_prop_anim_player : AnimationPlayer = leash_handle_prop.find_child("AnimationPlayer")
	leash_handle_prop_anim_player.play("PR-leash_handle-anim_lib/CINE-leash_handle-outro")
	
	# init camera switch
	Context.camera.current_camera_state = Context.camera.camera_states.DIRECTED
	
	# init treat emote timer
	var treat_timer := Timer.new()
	self.add_child(treat_timer)
	treat_timer.timeout.connect(ask_for_treat)
	treat_timer.start(10.292)
	chocomel_emote_bubble.position += Vector3.UP * 1.
	
func seq_ceremony_process():
	reset_character_transforms()
	approach_ending_camera()

func ask_for_treat():
	chocomel_emote_bubble.trigger_emote(EmoteBubble.emote_states.TREAT, 3.58)

func _on_finish_outro_anim(anim : String):
	if anim.ends_with("outro"):
		pinda.animation_tree.animation_finished.disconnect(_on_finish_outro_anim)
		advance_sequence()

func seq_credits_init():
	stop()
