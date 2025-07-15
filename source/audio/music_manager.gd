# music_manager.gd
class_name MusicManager
extends AudioStreamPlayer

## ===== music_manager.gd =====
## Manages music playback, transitioning between clips and fading gameplay layers
## 
## === Main functions ===
## start_music(fade_in : bool, fade_duration : float)
## stop_music(fade_out : bool, fade_duration : float)
## transition_music_to_clip(music_clip : MusicManager.MUSIC_CLIPS)
## 
## === Transition functions ===
## TODO: update README

# PATH: "res://source/audio/music/music_state_gameplay.gd"
@export var gameplay_state : MusicStateGameplay

## READ: Songs 
# Index for music clip and gameplay layers
enum MUSIC_CLIPS { INTRO, GAMEPLAY, OUTRO, CREDITS }
var current_music_clip : MUSIC_CLIPS = MUSIC_CLIPS.INTRO # current music clip playing
var target_music_clip : MUSIC_CLIPS # music clip to be played when transitioning
var is_music_transitioning : bool # on if music is currently transitioning clips


## Configuration variables clip transitions
const NULL_VOLUME_DB : float = -80.0 # minimum possible volume (read: "sound OFF")
const DEFAULT_CLIP_VOLUME_DB : float = 0.0 # return to default volume after transition
const CLIP_FADE_DURATION : float = 2.5 # duration of clip fading in or out in seconds
const CLIP_TRANSITION_DB : float = 2.5 # temporarily bump volume to mitigate crossfade phasing
const CLIP_TRANSITION_DURATION : float = 60.0 / 114.0 # one beat duration at 114 bpm (total transition 2 beats)

var credits_timer : Timer

func _ready():
	Context.music_manager = self
	
	GameStatus.game_state_changed.connect(update_music_state)
	if !self.playing:
		await get_tree().create_timer(0.25).timeout
		start_music(true, 2.5)
	
	assert(gameplay_state, "missing MusicManager.gameplay_state, please set to MusicStateGamePlay resource")


func start_music(fade_in : bool = false, fade_duration : float = CLIP_FADE_DURATION) -> void:
	# check for fading 
	if fade_in: 
		self.volume_db = NULL_VOLUME_DB # set to null when fading
		var tween = get_tree().create_tween()
		tween.tween_property(self, "volume_db", DEFAULT_CLIP_VOLUME_DB, fade_duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	else:
		self.volume_db = DEFAULT_CLIP_VOLUME_DB # reset volume to default
		
	self.play()

func stop_music(fade_out : bool = false, fade_duration : float = CLIP_FADE_DURATION) -> void:
	if fade_out:
		var tween = get_tree().create_tween()
		tween.tween_property(self, "volume_db", NULL_VOLUME_DB, fade_duration).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
		await tween.finished
	
	self.stop()

func update_music_state(new_state : GameStatus.game_states, previous_state : GameStatus.game_states):
	# ignore call if still transitioning clips
	if is_music_transitioning and has_stream_playback():
		if is_transition_complete():
			current_music_clip = target_music_clip
			is_music_transitioning = false
	
	#print("Game state changed from ", GameStatus.game_states.keys()[previous_state], " to ", GameStatus.game_states.keys()[new_state])
	
	# Check game state first
	match new_state:
		GameStatus.game_states.MAIN_MENU:
			start_music_transition_to(MUSIC_CLIPS.INTRO)
		GameStatus.game_states.INTRO:
			start_music_transition_to(MUSIC_CLIPS.GAMEPLAY)
		GameStatus.game_states.GAMEPLAY:
			start_music_transition_to(MUSIC_CLIPS.GAMEPLAY)
			gameplay_state.setup()
		GameStatus.game_states.ENDING: #or GameStatus.game_states.CREDITS:
			start_music_transition_to(MUSIC_CLIPS.OUTRO)
		GameStatus.game_states.CREDITS:
			# check after credits
			#volume_db = DEFAULT_CLIP_VOLUME_DB
			start_music_transition_to(MUSIC_CLIPS.CREDITS)
	
	gameplay_state.should_update = (
		previous_state == GameStatus.game_states.INTRO 
		or previous_state == GameStatus.game_states.MAIN_MENU
		or previous_state == GameStatus.game_states.LOADING
		and new_state == GameStatus.game_states.GAMEPLAY 
	)

# Transitioning music between songs (intro, gameplay, outro, credits)
func start_music_transition_to(music_clip : MUSIC_CLIPS):
	
	# ignore if currently transitioning
	if is_music_transitioning: return
	
	# ignore if same clip
	if (music_clip == current_music_clip): return
	
	# set music to transitioning
	is_music_transitioning = true
	
	# switch stream playback to new music layer
	var playback : AudioStreamPlaybackInteractive = get_stream_playback()
	playback.switch_to_clip(music_clip)
	
	# boost volume during transition to mitigate volume dip due to crossfade phasing artifacts
	#var tween = get_tree().create_tween()
	#tween.tween_property(self, "volume_db", CLIP_TRANSITION_DB, CLIP_TRANSITION_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	#tween.tween_property(self, "volume_db", DEFAULT_CLIP_VOLUME_DB, CLIP_TRANSITION_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	#
	# update current clip state
	target_music_clip = music_clip
		
	if target_music_clip == MUSIC_CLIPS.CREDITS:
		
		
		if !credits_timer:
			credits_timer = Timer.new()
			credits_timer.wait_time = 100.0 # seconds, 1:40 in minutes
			credits_timer.timeout.connect(func():
				stop_music(true, 10.0)
				print("FADING MUSIC OUT OVER 10 SECONDS")
			)
			add_child(credits_timer)
			
		if is_instance_valid(credits_timer):
			if credits_timer.is_stopped():
				credits_timer.start()
				print("TRANSITIONING MUSIC TO INTRO in ", credits_timer.wait_time, " seconds")


func is_transition_complete() -> bool:
	return (get_current_clip_index() == target_music_clip)

func get_current_clip_name():
	return stream.get_clip_name(get_stream_playback().get_current_clip_index())
	
func get_current_clip_index():
	return get_stream_playback().get_current_clip_index()



## Prints current state of music
func print_music_state():
	var playback = get_stream_playback()
	var playing_clip_name = stream.get_clip_name(get_stream_playback().get_current_clip_index())
	print("stream: ", stream, " - playback: ", playback, " - clip: ", playing_clip_name, " - target clip: ", target_music_clip)
