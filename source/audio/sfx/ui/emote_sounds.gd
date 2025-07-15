extends AudioStreamPlayer3D
class_name EmoteSounds


@export var emote_sounds : Dictionary[EmoteBubble.emote_states, AudioStream]

var current_stream : AudioStream

func play_emote(emote_state : EmoteBubble.emote_states, delay : float = -1.0):
	# TODO: NONE state is triggered constantly by ????
	if emote_state == EmoteBubble.emote_states.NONE: return
	
	# check if sound exists in sounds bank
	if !emote_sounds.has(emote_state): return
		#print("EmoteSounds.gd: emote_state: ", EmoteBubble.emote_states.keys()[emote_state], " does not contain entry in emote bubble sounds or has not been set from editor.")
	
	# return if current stream is already being played
	if stream == current_stream and self.playing: return
	
	current_stream = stream
	stream = emote_sounds[emote_state]
	
	# set delay if specified
	if delay <= 0.0:
		self.play()
	else:
		var delay_timer : SceneTreeTimer
		delay_timer = get_tree().create_timer(delay)
		delay_timer.timeout.connect(self.play)
	
	## TODO: cleanup
	#print("playing emote_state sound: ", EmoteBubble.emote_states.keys()[emote_state])
