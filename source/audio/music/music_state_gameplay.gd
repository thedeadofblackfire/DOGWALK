extends Node
class_name MusicStateGameplay

@export var gameplay_sync_stream_player : AudioStreamSynchronized

@export var fence_music_zone_setting : GameplayMusicSetting
@export var fence_hint_music_zone_setting : GameplayMusicSetting
@export var forest_music_zone_setting : GameplayMusicSetting
@export var forest_heart_music_zone_setting : GameplayMusicSetting
@export var no_music_zone_setting : GameplayMusicSetting
@export var pond_music_zone_setting : GameplayMusicSetting
@export var pond_hint_music_zone_setting : GameplayMusicSetting
@export var snowman_music_zone_setting : GameplayMusicSetting

@export var idle_movement_state_setting : GameplayMusicSetting
@export var walking_movement_state_setting : GameplayMusicSetting
@export var running_movement_state_setting : GameplayMusicSetting
@export var sprinting_movement_state_setting : GameplayMusicSetting
@export var pulling_movement_state_setting : GameplayMusicSetting
@export var resting_movement_state_setting : GameplayMusicSetting
@export var meditating_movement_state_setting : GameplayMusicSetting
@export var healing_movement_state_setting : GameplayMusicSetting

enum MUSIC_ZONE { NONE, SNOWMAN, FOREST, FOREST_HEART, FENCE, FENCE_HINT, POND, POND_HINT }
enum MOVEMENT_STATE { IDLING, WALKING, RUNNING, SPRINTING, PULLING, RESTING, MEDITATING, HEALING }

var current_music_zone : MUSIC_ZONE = MUSIC_ZONE.SNOWMAN
var current_movement_state : MOVEMENT_STATE = MOVEMENT_STATE.IDLING

var should_update : bool = false

## Stream index corresponding to gameplay layers 
## NOTE: order needs to match gameplay_synchronized_streams.tres settings
## PATH: "res://source/audio/music/gameplay_synchronized_streams.tres"
enum SYNC_STREAMS { 
	IDLE_WALK_RUN_SPRINT, # always on except MEDITATE - HEAL state
	IDLE_WALK_RUN, # only on in IDLE or WALK_RUN_SPRINT state
	WALK, # on in WALK_RUN_SPRINT, RUN and SPRINT states
	WALK_RUN_SPRINT, # only on in WALK_RUN_SPRINT state
	RUN_SPRINT, # on in RUN and SPRINT state
	SPRINT, # on in SPRINT state
	PULL, # on when PULLING
	REST_MEDITATE_HEAL, # only on in REST state
	MEDITATE_HEAL, # only on in MEDITATE state
	HEAL, # only on in HEAL state
	FOREST, # on in FOREST area
	FENCE, # on in FENCE area
	POND, # on in POND area
	POND_EXTRA # on in POND area
}

var meditating_state_timer : Timer
var healing_state_timer : Timer
var meditating_state_active : bool = false
var healing_state_active : bool = false

var setup_complete : bool = false

func setup():
	meditating_state_timer = Timer.new()
	healing_state_timer = Timer.new()
	meditating_state_timer.wait_time = 8.0
	healing_state_timer.wait_time = 18.0
	meditating_state_timer.timeout.connect(func(): meditating_state_active = true)
	healing_state_timer.timeout.connect(func(): healing_state_active = true)
	
	add_child(meditating_state_timer)
	add_child(healing_state_timer)
	
	if Context.pinda:
		Context.pinda.started_petting_loops.connect(func(): 
			meditating_state_timer.start()
			print("MEDITATING TIMER STARTED")
		)
		Context.pinda.started_petting_loops.connect(func(): 
			healing_state_timer.start()
			print("HEALING TIMER STARTED")
		)
	
	setup_complete = true

func _process(delta):
	if should_update and setup_complete:
		update(delta)


## Updates all gameplay related music
func update(delta : float):
	
	# first update for zones
	update_music_zone()
	
	var ignore_movement_state : bool = (
		current_music_zone == MUSIC_ZONE.FOREST_HEART
		or current_music_zone == MUSIC_ZONE.FENCE_HINT
		or current_music_zone == MUSIC_ZONE.POND
		or current_music_zone == MUSIC_ZONE.POND_HINT
	)
	
	# check if movement should be updated
	if !ignore_movement_state:
		update_movement_state()
	
	update_sync_streams(delta)


## Updates music zone streams
func update_music_zone():
	var on_ice : bool = (
		Context.chocomel.terrain_detector.current_terrain_state == Constants.terrain_states.ICE
	)
	
	if on_ice:
		switch_music_zone(MUSIC_ZONE.POND)
	elif current_music_zone == MUSIC_ZONE.POND:
		switch_music_zone(MUSIC_ZONE.NONE)


## Updates player movement state streams
func update_movement_state():
	var idling : bool = (
		Context.chocomel.current_character_state == Chocomel.character_states.IDLE
		and Context.chocomel.sitting_time < 8.0
	)
	var resting : bool = (
		Context.chocomel.sitting_time >= 5.0
	)
	var meditating : bool = (
		Context.chocomel.sitting_time >= 15.0
		and Context.chocomel.sitting_time < 20.0
	)
	var healing : bool = (
		Context.chocomel.sitting_time >= 20.0
	)
	## TODO: remove if unused
	#var interacting : bool = (
		#Context.pinda.current_character_state == Context.pinda.character_states.INTERACTION
	#)
	var walking : bool = (
		Context.chocomel.velocity.length() > 0.5 
		and Context.chocomel.velocity.length() < 2.0
		and Context.chocomel.running_time < 0.5
	)
	var running : bool = (
		Context.chocomel.velocity.length() >= 2.0
		and Context.pinda.velocity.length() > 1.0
		and Context.chocomel.running_time > 0.5
	)
	var sprinting : bool = (
		Context.chocomel.running_time >= 1.5
	)
	var petting : bool = (
		Context.pinda.current_interaction_type == Pinda.interaction_types.PETTING
	)
	var pulling : bool = (
		Context.chocomel.current_character_state == Chocomel.character_states.PULLING
		and Context.pinda.current_character_state == Pinda.character_states.STUCK
	)
	
	if pulling:
		switch_movement_state(MOVEMENT_STATE.PULLING)
	if petting:
		switch_movement_state(MOVEMENT_STATE.RESTING)
		if meditating_state_active:
			switch_movement_state(MOVEMENT_STATE.MEDITATING)
			if healing_state_active:
				switch_movement_state(MOVEMENT_STATE.HEALING)
	else:
		meditating_state_timer.stop()
		healing_state_timer.stop()
		meditating_state_active = false
		healing_state_active = false

	if idling:
		switch_movement_state(MOVEMENT_STATE.IDLING)
	elif walking:
		switch_movement_state(MOVEMENT_STATE.WALKING)
	elif running:
		switch_movement_state(MOVEMENT_STATE.RUNNING)
		if sprinting:
			switch_movement_state(MOVEMENT_STATE.SPRINTING)


## Stores which streams should be currently active
var sync_streams_active : Dictionary[SYNC_STREAMS, bool] = {
	SYNC_STREAMS.IDLE_WALK_RUN_SPRINT : false,
	SYNC_STREAMS.IDLE_WALK_RUN : false,
	SYNC_STREAMS.WALK : false,
	SYNC_STREAMS.WALK_RUN_SPRINT : false,
	SYNC_STREAMS.RUN_SPRINT : false,
	SYNC_STREAMS.SPRINT : false,
	SYNC_STREAMS.PULL : false,
	SYNC_STREAMS.REST_MEDITATE_HEAL : false,
	SYNC_STREAMS.MEDITATE_HEAL : false,
	SYNC_STREAMS.HEAL : false,
	SYNC_STREAMS.FOREST : false,
	SYNC_STREAMS.FENCE : false,
	SYNC_STREAMS.POND : false,
	SYNC_STREAMS.POND_EXTRA : false,
}


## Configuration for fading streams in or out
const DEFAULT_SYNC_STREAM_VOLUME_DB : float = 0.0 # target volume when stream is active
const NULL_SYNC_STREAM_VOLUME_DB : float = -60.0 # target volume when stream is inactive (read: OFF)
const SYNC_STREAM_ATTACK_RATIO : float = 0.975 # lerp rate for fading in streams
const SYNC_STREAM_RELEASE_RATIO : float = 0.135 # lerp rate for fading out streams 


func set_sync_stream_configuration(music_layer : GameplayMusicSetting):
	#print("setting sync streams to: ", music_layer)
	for sync_stream_id in music_layer.configuration:
		set_sync_stream_active(sync_stream_id, music_layer.configuration[sync_stream_id])


## Enabling or disabling individual streams
func set_sync_stream_active(layer_idx : SYNC_STREAMS, enabled : bool):
	sync_streams_active[layer_idx] = enabled


## Updates gameplay sync streams (read: layers) to lerped volumes
func update_sync_streams(delta : float) -> void:
	#if Context.audio_manager.music_manager.current_music_clip != MusicManager.MUSIC_CLIPS.GAMEPLAY: return
	
	# iterate gameplay sync streams
	for sync_stream_idx in sync_streams_active:
		# get stream info
		var is_stream_active : bool = sync_streams_active[sync_stream_idx]
		
		## Need the stream string name?
		#var stream_name : String = SYNC_STREAMS.keys()[sync_stream_idx]
		
		# calculate smoothed volume
		var current_volume : float = get_sync_stream_volume(sync_stream_idx)
		var target_volume : float = DEFAULT_SYNC_STREAM_VOLUME_DB if is_stream_active else NULL_SYNC_STREAM_VOLUME_DB
		var smooth_speed : float = SYNC_STREAM_ATTACK_RATIO if is_stream_active else SYNC_STREAM_RELEASE_RATIO
		var smoothed_volume : float = lerpf(current_volume, target_volume, smooth_speed * delta)
		# update stream with smoothed volume
		set_sync_stream_volume(sync_stream_idx, smoothed_volume)


func set_sync_stream_volume(layer_idx : SYNC_STREAMS, volume : float):
	gameplay_sync_stream_player.set_sync_stream_volume(layer_idx, volume)
func get_sync_stream_volume(layer_idx: SYNC_STREAMS) -> float:
	return gameplay_sync_stream_player.get_sync_stream_volume(layer_idx)


func switch_movement_state(new_movement_state : MOVEMENT_STATE):
	#print("switching movement state to: ", new_movement_state)
	match new_movement_state:
		MOVEMENT_STATE.IDLING:
			set_sync_stream_configuration(idle_movement_state_setting)
		MOVEMENT_STATE.WALKING:
			set_sync_stream_configuration(walking_movement_state_setting)
		MOVEMENT_STATE.RUNNING:
			set_sync_stream_configuration(running_movement_state_setting)
		MOVEMENT_STATE.SPRINTING:
			set_sync_stream_configuration(sprinting_movement_state_setting)
		MOVEMENT_STATE.PULLING:
			set_sync_stream_configuration(pulling_movement_state_setting)
		MOVEMENT_STATE.RESTING:
			set_sync_stream_configuration(resting_movement_state_setting)
		MOVEMENT_STATE.MEDITATING:
			set_sync_stream_configuration(meditating_movement_state_setting)
		MOVEMENT_STATE.HEALING:
			set_sync_stream_configuration(healing_movement_state_setting)
			
	current_movement_state = new_movement_state

func switch_music_zone(new_music_zone : MUSIC_ZONE):
	match new_music_zone:
		MUSIC_ZONE.NONE:
			set_sync_stream_configuration(no_music_zone_setting)
		MUSIC_ZONE.SNOWMAN:
			set_sync_stream_configuration(snowman_music_zone_setting)
		MUSIC_ZONE.FOREST:
			set_sync_stream_configuration(forest_music_zone_setting)
		MUSIC_ZONE.FENCE:
			set_sync_stream_configuration(fence_music_zone_setting)
		MUSIC_ZONE.POND:
			set_sync_stream_configuration(pond_music_zone_setting)
		MUSIC_ZONE.POND_HINT:
			set_sync_stream_configuration(pond_hint_music_zone_setting)
		MUSIC_ZONE.FOREST_HEART:
			set_sync_stream_configuration(forest_heart_music_zone_setting)
		MUSIC_ZONE.FENCE_HINT:
			set_sync_stream_configuration(fence_hint_music_zone_setting)
			
	current_music_zone = new_music_zone
