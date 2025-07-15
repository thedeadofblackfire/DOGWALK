extends Node3D
class_name EmoteBubble

enum emote_states {
	NONE,
	# pinda emotes
	CHOCOMEL,
	CLOUDY,
	COMPLAINING,
	CRASH,
	DOOM_SPIRAL,
	EXCLAMATION,
	HEARTS,
	HOURGLASS,
	SNOWMAN,
	SWEAT,
	TREAT,
	# button prompts
	BUTTON_PROMPT,
	BUTTON_PRESS,
	MOVE_STICK,
	CLICK_PROMPT,
	CLICK_PRESS,
	MOVE_MOUSE,
	# snowman emotes
	FIREWORKS,
	MISSING_ARM,
	MISSING_HAT,
	MISSING_NOSE,
	MISSING_CANE,
}

const FRAMETIME := 0.25 # 4 fps
var frametime_modulo := 0.0
var animation_frames : Dictionary = {
	emote_states.CHOCOMEL : preload("res://assets/props/emote_bubble/animations/emote_bubble-chocomel.tres"),
	emote_states.DOOM_SPIRAL : preload("res://assets/props/emote_bubble/animations/emote_bubble-doom.tres"),
	emote_states.EXCLAMATION : preload("res://assets/props/emote_bubble/animations/emote_bubble-exclamation.tres"),
	emote_states.HEARTS : preload("res://assets/props/emote_bubble/animations/emote_bubble-hearts.tres"),
	emote_states.SWEAT : preload("res://assets/props/emote_bubble/animations/emote_bubble-sweat.tres"),
	emote_states.CLOUDY : preload("res://assets/props/emote_bubble/animations/emote_bubble-cloudy.tres"),
	emote_states.CRASH : preload("res://assets/props/emote_bubble/animations/emote_bubble-crash.tres"),
	emote_states.BUTTON_PROMPT : preload("res://assets/props/emote_bubble/animations/emote_bubble-button_prompt.tres"),
	emote_states.BUTTON_PRESS : preload("res://assets/props/emote_bubble/animations/emote_bubble-button_press.tres"),
	emote_states.MOVE_STICK : preload("res://assets/props/emote_bubble/animations/emote_bubble-move_stick.tres"),
	emote_states.CLICK_PROMPT : preload("res://assets/props/emote_bubble/animations/emote_bubble-click_prompt.tres"),
	emote_states.CLICK_PRESS : preload("res://assets/props/emote_bubble/animations/emote_bubble-click_press.tres"),
	emote_states.MOVE_MOUSE : preload("res://assets/props/emote_bubble/animations/emote_bubble-move_mouse.tres"),
	emote_states.FIREWORKS : preload("res://assets/props/snowman_emotes/animations/snowman_emotes-fireworks.tres"),
	emote_states.TREAT : preload("res://assets/props/emote_bubble/animations/emote_bubble-treat.tres"),
	emote_states.SNOWMAN : preload("res://assets/props/emote_bubble/animations/emote_bubble-snowman.tres"),
	emote_states.MISSING_ARM : preload("res://assets/props/snowman_emotes/animations/snowman_emotes-missing_arm.tres"),
	emote_states.MISSING_HAT : preload("res://assets/props/snowman_emotes/animations/snowman_emotes-missing_hat.tres"),
	emote_states.MISSING_NOSE : preload("res://assets/props/snowman_emotes/animations/snowman_emotes-missing_nose.tres"),
	emote_states.MISSING_CANE : preload("res://assets/props/snowman_emotes/animations/snowman_emotes-missing_cane.tres"),
}

var current_state = emote_states.NONE
@export var character : Node3D
var character_skeleton : Skeleton3D
var character_head_bone_idx : int

@export var parent_to_head_bone := true
@export var orient_to_camera := true

@export var y_offset := 0.

@export var emote_sounds : EmoteSounds

var previous_state = emote_states.NONE
var emote_timer : Timer = Timer.new()

enum anim_states {NONE, IN, LOOP, OUT}
var anim_names = {
	anim_states.IN : 'In',
	anim_states.LOOP : 'Loop',
	anim_states.OUT : 'Out',
	anim_states.NONE : 'NONE'
}
var current_anim_state : anim_states = anim_states.NONE
var current_anim_emote_state : emote_states = emote_states.NONE
var anim_frame := 0
var anim_frame_time := 0.
var anim_frame_duration := 0.

var skeleton : Skeleton3D
var emote_bones : Array[BoneAttachment3D]
	
func _ready():
	show()
	
	set_process_input(true)
	
	skeleton = self.find_child('Skeleton3D')
	
	skeleton.translate(Vector3.UP * y_offset)
	
	if parent_to_head_bone:
		character_skeleton = character.find_child('Skeleton3D')
		character_head_bone_idx = character_skeleton.find_bone('head')
		if character_head_bone_idx == -1:
			character_head_bone_idx = character_skeleton.find_bone('head')
	
	# poplulate emote bones array in order of emote states (except for idle)
	var bone_list : Array[Node] = skeleton.get_children()
	for e in emote_states:
		var no_bone_found := true
		var emote_name = e.to_lower()
		for i in bone_list.size():
			if bone_list[i].name.ends_with(emote_name):
				emote_bones.push_back(bone_list.pop_at(i))
				no_bone_found = false
				break
		if no_bone_found:
			emote_bones.push_back(null)
	
	skeleton.reset_bone_poses()
	
	update_state()
#	
	self.add_child(emote_timer)
	emote_timer.timeout.connect(_on_timer_timeout)

func _process(delta):
	if current_state != previous_state:
		if current_state != emote_states.NONE:
			update_state()
	if current_state != emote_states.NONE or current_anim_emote_state != emote_states.NONE:
		# Orient bubble bone to camera
		if parent_to_head_bone:
			self.position = character_skeleton.get_bone_global_pose(character_head_bone_idx).origin
		
		if orient_to_camera:
			var camera = get_viewport().get_camera_3d()
			var bubble_bone_idx = skeleton.find_bone('bubble')
			var bubble_transform = skeleton.get_bone_global_pose(bubble_bone_idx)
			var point = camera.global_transform.origin
			#point.y = bubble_transform.origin.y
			bubble_transform = skeleton.global_transform.inverse() * (skeleton.global_transform * bubble_transform).looking_at(point, Vector3.UP, true)
			skeleton.set_bone_global_pose(bubble_bone_idx, bubble_transform)
		
	animate_emote()
		
	previous_state = current_state

func next_anim_state(anim, animation_names):
	while true:
		if current_anim_state == anim_states.NONE:
			current_anim_state = anim_states.IN
		elif current_anim_state == anim_states.IN:
			current_anim_state = anim_states.LOOP
		elif current_anim_state == anim_states.LOOP:
			current_anim_state = anim_states.OUT
		elif current_anim_state == anim_states.OUT:
			current_anim_state = anim_states.NONE
			return ''
		anim = anim_names[current_anim_state]
		if anim in animation_names:
			break
	return anim

func stop_anim():
	current_anim_emote_state = emote_states.NONE
	current_anim_state = anim_states.NONE
	for b in emote_bones:
		if not b:
			continue
		b.hide()

func animate_emote() -> void:
	if current_anim_emote_state == emote_states.NONE:
		return
	if current_anim_emote_state not in animation_frames.keys():
		if current_state == emote_states.NONE:
			stop_anim()
		return
	
	var sprite_frames : SpriteFrames = animation_frames[current_anim_emote_state]
	var anim = anim_names[current_anim_state]
	
	if anim not in sprite_frames.get_animation_names():
		anim = next_anim_state(anim, sprite_frames.get_animation_names())
		if not anim:
			stop_anim()
			return
		
	var prev_anim_frame_time = anim_frame_time
	anim_frame_time += get_process_delta_time()
	
	if prev_anim_frame_time < anim_frame_duration:
		return
	
	# skip advancing on first frame
	if prev_anim_frame_time != 0.:
		anim_frame += 1
		anim_frame_time -= anim_frame_duration
	
	var frame_rate = sprite_frames.get_animation_speed(anim)
	var frame_count = sprite_frames.get_frame_count(anim)
	anim_frame_duration = 1. / frame_rate * sprite_frames.get_frame_duration(anim, anim_frame)
	
	# current animation has ended
	if anim_frame == frame_count:
		anim_frame = 0
		if current_anim_state == anim_states.LOOP:
			if current_state == emote_states.NONE:
				anim = next_anim_state(anim, sprite_frames.get_animation_names())
		else:
			anim = next_anim_state(anim, sprite_frames.get_animation_names())

		if not anim:
			stop_anim()
			return
	
	#print("%s %d" % [anim_states.keys()[current_anim_state], anim_frame])
	
	# Animate the bubble texture
	var emote_bone = get_emote_bone(current_anim_emote_state)
	if not emote_bone:
		return
	var current_material = emote_bone.get_child(0).get_active_material(0) # TODO: do once when it changes
	current_material.set(
		"shader_parameter/albedo_texture",
		sprite_frames.get_frame_texture(anim, anim_frame)
	)

func _on_timer_timeout():
	current_state = emote_states.NONE

func update_state() -> void:
	# reset animation
	anim_frame_time = 0.
	anim_frame = 0
	anim_frame_duration = 0.
	current_anim_state = anim_states.NONE
	current_anim_emote_state = current_state
	
	var current_bone = get_emote_bone(current_state)
	for bone in emote_bones:
		if not bone:
			continue
		if bone == current_bone:
			bone.visible = true
		else:
			bone.visible = false
		
func get_emote_bone(state : emote_states) -> BoneAttachment3D:
	return emote_bones[state]

func trigger_emote(state: emote_states, duration : float = 0.):
	current_state = state
	if emote_sounds:
		emote_sounds.play_emote(state)
	else:
		print("NO EMOTE SOUNDS SET ON: ", self.get_parent().name)
	if duration == 0.:
		emote_timer.stop()
		return
	else:
		emote_timer.start(duration)
