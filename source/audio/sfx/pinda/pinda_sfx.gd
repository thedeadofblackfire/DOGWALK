# pinda_sfx.gd
extends Node3D
class_name PindaSFX

# Footsteps
@export var footstep_audio_wood : AudioStream
@export var footstep_audio_ice : AudioStream
@export var footstep_audio_ground : AudioStream
@export var footstep_audio_snow : AudioStream
@export var footstep_sfx : AudioStreamPlayer3D
@export var footstep_snow_lift_sfx : AudioStreamPlayer3D

@export var terrain_detector : TerrainDetector
@export var ice_sliding_sfx : AudioStreamPlayer3D
@export var floor_dragging_sfx : AudioStreamPlayer3D

@export var brrr_cold_sfx : AudioStreamPlayer3D
@export var wow_fast_sfx : AudioStreamPlayer3D

@export var impact_sfx : AudioStreamPlayer3D
@export var ouch_sfx : AudioStreamPlayer3D
@export var fall_flat_sfx : AudioStreamPlayer3D
@export var rolling_sfx : AudioStreamPlayer3D

@export var stuck_in_snow_sfx : AudioStreamPlayer3D
@export var stuck_in_snow_voice : AudioStreamPlayer3D

@export var emote_hearts_sfx : AudioStreamPlayer3D
@export var emote_cloudy_sfx : AudioStreamPlayer3D
@export var emote_exclamation_sfx : AudioStreamPlayer3D

@export var pickup_item_sound : AudioStreamPlayer3D

@export var gate_unlock_music_conf : GameplayMusicSetting
var music_state_gameplay : MusicStateGameplay

var leash_limit_cooldown_timer : Timer
var brrr_cold_cooldown_timer : Timer
var wow_fast_cooldown_timer : Timer

func _ready():
	GameStatus.game_state_changed.connect(connect_game_state_control)
	terrain_detector.terrain_state_changed.connect(switch_footstep_terrain_sfx)
	
	leash_limit_cooldown_timer = Timer.new()
	leash_limit_cooldown_timer.one_shot = true
	add_child(leash_limit_cooldown_timer)
	
	brrr_cold_cooldown_timer = Timer.new()
	brrr_cold_cooldown_timer.one_shot = false
	add_child(brrr_cold_cooldown_timer)
	
	wow_fast_cooldown_timer = Timer.new()
	wow_fast_cooldown_timer.one_shot = false
	add_child(wow_fast_cooldown_timer)


func connect_game_state_control(new_state, previous_state):
	var starting_gameplay = (
		new_state == GameStatus.game_states.GAMEPLAY 
		and previous_state == GameStatus.game_states.GAMEPLAY
	)
	
	if starting_gameplay:
		music_state_gameplay = Context.audio_manager.music_state.gameplay_state


func _process(_delta):
	
	if GameStatus.current_game_state == GameStatus.game_states.GAMEPLAY:
		# NOTE: TODO: change pinda random sounds according to movement state:
		var idling : bool = (
			Context.pinda.current_character_state == Chocomel.character_states.IDLE
			and Context.chocomel.sitting_time < 8.0
		)
		var interacting : bool = (
			Context.pinda.current_character_state == Context.pinda.character_states.INTERACTION
		)
		var walking : bool = (
			Context.pinda.velocity.length() > 0.5 
			and Context.pinda.velocity.length() < 1.5
		)
		var running : bool = (
			Context.pinda.velocity.length() >= 1.5
			and Context.chocomel.running_time > 0.5
		)
		var sprinting : bool = (
			Context.chocomel.running_time >= 5
		)
		var pulling : bool = (
			Context.pinda.current_character_state == Pinda.character_states.PULLING
		)
		# ice sliding sfx
		var on_ice = (
			terrain_detector.current_terrain_state == Constants.terrain_states.ICE
		)
		var stuck : bool = (
			Context.pinda.current_character_state == Pinda.character_states.STUCK
		)
		var floor_dragged : bool = (
			Context.pinda.current_character_state == Pinda.character_states.STUCK
		)
		var in_snow : bool = (
			Context.pinda.terrain_detector.current_terrain_state == Constants.terrain_states.SNOW
		)
		var pushed : bool = (
			Context.pinda.current_character_state == Pinda.character_states.PUSHED
		)
		
		var stuck_in_snow : bool = (
			Context.pinda.current_character_state == Pinda.character_states.STUCK
			and terrain_detector.current_terrain_state == Constants.terrain_states.SNOW
		)
		var in_cinematic : bool = (
			Context.pinda.current_character_state == Pinda.character_states.CINEMATIC
		)
		
		
		# footstep sfx velocity to pitch
		if Context.pinda.velocity.length() >= 0.1:
			calc_footstep_pitch_scale()
		
		if on_ice:
			
			update_ice_sliding_sfx()
			
			if !stuck and !interacting and !in_cinematic and Context.pinda.velocity.length() > 0.2:
				update_ice_voice_sfx()
				
			elif brrr_cold_sfx.is_playing():
				stop_ice_voice_sfx()
			
		elif brrr_cold_sfx.is_playing():
			stop_ice_voice_sfx()
				
		var too_fast : bool = (
			sprinting or (on_ice and Context.pinda.velocity.length() > 2)
		)
		
		if too_fast and wow_fast_cooldown_timer.is_stopped():
			wow_fast_cooldown_timer.start(randf_range(3.0, 6.0))
			if !wow_fast_cooldown_timer.is_connected("timeout", wow_fast_sfx.play):
				print("connecting wow timer")
				wow_fast_cooldown_timer.timeout.connect(wow_fast_sfx.play)
			wow_fast_sfx.play()
			
		elif wow_fast_sfx.is_playing():
			wow_fast_cooldown_timer.stop()
			wow_fast_sfx.stop()
			
		
		# TODO: setup terrain type sounds
		## Floor dragging + pushed
		if pushed:
			if not floor_dragging_sfx.is_playing():
				floor_dragging_sfx.play()
		elif floor_dragged and !on_ice and Context.pinda.velocity.length() >= 0.1:
			if not floor_dragging_sfx.is_playing():
				floor_dragging_sfx.play()
		elif floor_dragging_sfx.is_playing():
			floor_dragging_sfx.stop()
			
		if in_snow:
			floor_dragging_sfx.pitch_scale = 3
		else:
			floor_dragging_sfx.pitch_scale = 4
			
		# leash limit sfx
		if Context.pinda.leash_limit_just_reached and leash_limit_cooldown_timer.is_stopped():
			#Context.leash.leash_limit_sound.play()
			Context.leash.leash_bounce_sound.play()
			leash_limit_cooldown_timer.start(1.0)
			print("pinda_sfx.gd play_bounce_sound.play() called")


func update_ice_sliding_sfx():
	if Context.pinda.velocity.length() < 0.35:
		ice_sliding_sfx.playing = false
		return
		

	if !ice_sliding_sfx.is_playing():
		ice_sliding_sfx.playing = true
		
	ice_sliding_sfx.pitch_scale = remap(Context.pinda.velocity.length(), 0.5, 7, 0.8, 1.2)
	ice_sliding_sfx.volume_db = remap(Context.pinda.velocity.length(), 0.5, 7, -18.0, 0.0)


func update_ice_voice_sfx():
	if brrr_cold_cooldown_timer.is_stopped():
		brrr_cold_cooldown_timer.start(randf_range(3.0, 6.0))
		brrr_cold_cooldown_timer.timeout.connect(brrr_cold_sfx.play)
		
func stop_ice_voice_sfx():
	brrr_cold_cooldown_timer.stop()
	brrr_cold_sfx.stop()

var awaiting_terrain_switch : bool = false
var target_terrain : Constants.terrain_states = Constants.terrain_states.NONE

## TODO: Cleanup
func play_stuck_in_snow_sounds():
	#print("PLAYING STUCK SNOW SFX")
	#if !stuck_in_snow_sfx.playing:
		#stuck_in_snow_sfx.play()
	if !stuck_in_snow_voice.playing:
		stuck_in_snow_voice.play()

func stop_stuck_in_snow_sounds():
	#print("STOPPING STUCK SNOW SFX")
	stuck_in_snow_sfx.stop()
	stuck_in_snow_voice.stop()


func switch_footstep_terrain_sfx(new_terrain, previous_terrain):
	
	if awaiting_terrain_switch:
		target_terrain = previous_terrain
		footstep_sfx.finished.disconnect(switch_footstep_terrain_sfx)
		awaiting_terrain_switch = false
		# TODO: CHANGE TERRAINS ONCE FOOTSTEP_SFX IS FINISHED
	
	if new_terrain == previous_terrain:
		return
		
	if footstep_sfx.is_playing() and !awaiting_terrain_switch:
		awaiting_terrain_switch = true
		target_terrain = new_terrain
		footstep_sfx.finished.connect(switch_footstep_terrain_sfx.bind(target_terrain, previous_terrain))
	
	match previous_terrain:
		Constants.terrain_states.ICE:
			ice_sliding_sfx.stop()
	
	match new_terrain:
		Constants.terrain_states.NONE:
			footstep_sfx.stream = footstep_audio_ground
			footstep_sfx.volume_db = -6.0
		Constants.terrain_states.SNOW:
			footstep_sfx.stream = footstep_audio_snow
			footstep_sfx.volume_db = -9.0
		Constants.terrain_states.ROAD:
			footstep_sfx.stream = footstep_audio_ground
			footstep_sfx.volume_db = -6.0
		Constants.terrain_states.ICE:
			ice_sliding_sfx.play()
			footstep_sfx.stream = footstep_audio_ice
			footstep_sfx.volume_db = -3.0


func set_fall_flat_pitch_scale():
	var velocity_pitch : float = remap(Context.pinda.velocity.length(), 0, 10, 0.95, 1.15)
	var stamina_pitch : float = remap(Context.pinda.stamina, 0, 10, 0.9, 1.0)
	var mood_pitch : float = remap(Context.pinda.mood, 0, 10, 0.85, 1.0)
	
	var new_pitch : float = (stamina_pitch + mood_pitch) * 0.5 * velocity_pitch
	fall_flat_sfx.pitch_scale = new_pitch


func set_rolling_pitch_scale():
	var stamina_pitch : float = remap(Context.pinda.stamina, 0, 10, 0.5, 1.0)
	var mood_pitch : float = remap(Context.pinda.mood, 0, 10, 0.5, 1.0)
	
	var new_pitch : float = (stamina_pitch + mood_pitch) * 0.5
	fall_flat_sfx.pitch_scale = new_pitch


func calc_footstep_pitch_scale():
	#print(
		#"Movement state: ", 
		#Context.audio_manager.music_manager.gameplay_state.current_movement_state,
		#"- Pinda velocity: ",
		#Context.pinda.velocity.length()
	#)
	
	var footstep_pitch : float = remap(Context.pinda.velocity.length(), 0, 6, 0.85, 1.35)
	footstep_sfx.pitch_scale = footstep_pitch

func play_leash_click():
	Context.leash.leash_limit_sound.play()
	if !Context.leash.leash_bounce_sound.is_playing():
		Context.leash.leash_bounce_sound.play()
	print("pinda_sfx.gd play_leash_click() called")

func filter_music_on():
	Context.audio_manager.set_lowpass_filter(true, .5, 250)

func filter_music_off():
	Context.audio_manager.set_lowpass_filter(false, .5)

func unlock_gate_music_trigger():
	if gate_unlock_music_conf:
		#music_state_gameplay.switch_music_zone(MusicStateGameplay.MUSIC_ZONE.FENCE_HINT)
		Context.audio_manager.music_manager.gameplay_state.set_sync_stream_configuration(gate_unlock_music_conf)
