extends AnimationTree

var state_machine_playback : AnimationNodeStateMachinePlayback

var prev_play_pos := 0.

func _ready() -> void:
	state_machine_playback = get("parameters/AnimationStates/playback")

func _process(delta: float) -> void:
	
	if state_machine_playback.get_current_play_position() <= prev_play_pos:
		process_anim_start(state_machine_playback.get_current_node())
		
	prev_play_pos = state_machine_playback.get_current_play_position()

func process_anim_start(anim):
	var random := randf()
	match anim:
		"Building":
			set("parameters/AnimationStates/Building/blend_position", random)
