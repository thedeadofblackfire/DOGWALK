extends Node3D
class_name ChocomelSFX

@export var footstep_snow_sfx : AudioStreamPlayer3D
@export var emote_move_mouse_sfx : AudioStreamPlayer3D
@export var whince_sfx : AudioStreamPlayer3D

func _ready():
	GameStatus.game_state_changed.connect(setup_sounds)
	
func setup_sounds(new_state, previous_state):
	if new_state == GameStatus.game_states.INTRO and Context.chocomel:
		Context.chocomel.tried_to_bark.connect(func():
			#print("tried to bark")
			whince_sfx.play()
		)

func stop_outro_music():
	Context.music_manager.volume_db = MusicManager.NULL_VOLUME_DB
	
func fade_in_credits_music():
	print("fading in credits music")
	var tween = get_tree().create_tween().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(Context.music_manager, "volume_db", MusicManager.DEFAULT_CLIP_VOLUME_DB, 3.0)
	await tween.finished
	print("done fading in credits music")

func _process(_delta):
	if GameStatus.current_game_state == GameStatus.game_states.INTRO and Context.chocomel.current_character_state == Chocomel.character_states.MOVING:
		emote_move_mouse_sfx.stop()
	
	var in_snow = (
		Context.chocomel.terrain_detector.current_terrain_state == Constants.terrain_states.SNOW
	)
	
	var on_ice = (
		Context.chocomel.terrain_detector.current_terrain_state == Constants.terrain_states.ICE
	)
	
	# TODO: remove?
	#var running = (
		#Context.chocomel.running_time > 0.2
	#)
	
	# enable snow footsteps
	footstep_snow_sfx.volume_db = remap(Context.chocomel.velocity.length(), 0, 6, -6, 1.5)
	footstep_snow_sfx.pitch_scale = remap(Context.chocomel.velocity.length(), 0, 6, 0.8, 1.5)
	
	if in_snow:
		footstep_snow_sfx.volume_db = remap(Context.chocomel.velocity.length(), 0, 6, -1.5, 3)
		footstep_snow_sfx.pitch_scale = remap(Context.chocomel.velocity.length(), 0, 6, 0.6, 1.0)
	
	if on_ice:
		footstep_snow_sfx.volume_db = -60.0
