extends Node
class_name AudioManager

## ===== audio_manager.gd =====
## Top-level manager for audio nodes
## 
## References:
## - MusicManager
## - SFXManager
## - UISoundManager
##
## === Transition functions ===
## TODO: update README

enum BUS { MASTER, MUSIC, AMBIENCE, SFX, UI }

@export var music_manager : MusicManager
@export var ui_sound_manager : UISoundManager
@export var sfx_manager : SFXManager

func _ready():
	Context.audio_manager = self
	GameStatus.game_state_changed.connect(update_audio_state)
		
	print(ui_sound_manager)
	print(get_tree().current_scene)
	ui_sound_manager.call_deferred("connect_ui_sounds_in", get_tree().current_scene)


func update_audio_state(new_state : GameStatus.game_states, previous_state : GameStatus.game_states):
	var in_credits = (
		new_state == GameStatus.game_states.CREDITS
	)
	
	# just entering credits
	if in_credits and previous_state != GameStatus.game_states.CREDITS:
		var camera_sfx : AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		camera_sfx.stream = preload("res://assets/sfx/pinda/ACTN-pinda-outro-camera.ogg") as AudioStream
		camera_sfx.position = Context.pinda.position
		camera_sfx.bus = AudioServer.get_bus_name(BUS.MASTER)
		self.add_child(camera_sfx)
		camera_sfx.play()
		print("CAMERA")
		
	# mute sfx during credits to prevent outro animation retriggering sounds
	AudioServer.set_bus_mute(BUS.SFX, in_credits)


## Pause Menu Filter Effect
# Audio server configuration
const LOW_PASS_EFFECT_IDX = 0
const AMP_EFFECT_IDX = 1
const LOW_PASS_CUTOFF_HZ = 500.0
const DEFAULT_CUTOFF_HZ = 20000.0
const FILTER_TWEEN_DURATION = 0.1


## Enables/disables a lowpass filter effect on the music bus to 'cutoff_freq' frequency using a tween of duration 'tween_duration'
func set_lowpass_filter(enabled : bool, tween_duration : float = FILTER_TWEEN_DURATION, cutoff_freq : float = LOW_PASS_CUTOFF_HZ):
	var tween: Tween 
	
	if tween_duration > 0:
		# instance tween and get effect handle
		tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	
	var low_pass_effect: AudioEffectLowPassFilter = AudioServer.get_bus_effect(AudioManager.BUS.MUSIC, LOW_PASS_EFFECT_IDX)
	
	# toggle between applying filter to go down (500hz) or open up (20000hz)
	if enabled:
		AudioServer.set_bus_effect_enabled(AudioManager.BUS.MUSIC, LOW_PASS_EFFECT_IDX, true)
		if tween:
			tween.tween_property(low_pass_effect, "cutoff_hz", cutoff_freq, tween_duration)
		else:
			low_pass_effect.cutoff_hz = cutoff_freq
	else:
		if tween:
			tween.tween_property(low_pass_effect, "cutoff_hz", DEFAULT_CUTOFF_HZ, tween_duration)
			await tween.finished
		else:
			low_pass_effect.cutoff_hz = DEFAULT_CUTOFF_HZ
		AudioServer.set_bus_effect_enabled(AudioManager.BUS.MUSIC, LOW_PASS_EFFECT_IDX, false)



## Enable or disable music filter for pause menu
func fade_music_volume(level_db : float = 0.0, speed : float = FILTER_TWEEN_DURATION):
	print("FADING MUSIC TO: ", level_db )

	# instance tween and get effect handle
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	var amp_effect: AudioEffectAmplify = AudioServer.get_bus_effect(AudioManager.BUS.MUSIC, AMP_EFFECT_IDX)
	
	# toggle between applying filter to go down (500hz) or open up (20000hz)
	if level_db == 0.0:
		tween.tween_property(amp_effect, "volume_db", level_db, speed)
		await tween.finished
		AudioServer.set_bus_effect_enabled(AudioManager.BUS.MUSIC, AMP_EFFECT_IDX, false)
		
	else:
		AudioServer.set_bus_effect_enabled(AudioManager.BUS.MUSIC, AMP_EFFECT_IDX, true)
		tween.tween_property(amp_effect, "volume_db", level_db, speed)
		

## Enable or disable music filter for pause menu
func set_music_volume_low():
	fade_music_volume(-12.0, 1.0)
	
func reset_music_volume():
	fade_music_volume(0.0, 1.0)
