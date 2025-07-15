extends AudioStreamPlayer3D

@export var item : CollectableItem
@export var change_music_zone_triggers : Array[MusicZoneTrigger]
@export var to_music_zone : MusicStateGameplay.MUSIC_ZONE
@export var to_custom_music_zone_configuration : GameplayMusicSetting
@export var instant_music_change_configuration : GameplayMusicSetting

func _ready():
	item.item_state_changed.connect(remove_object_hint_sound)

func remove_object_hint_sound(new_state : GameStatus.item_states, previous_state : GameStatus.item_states) -> void:
	
	# this function is called when item states are changed - run only for held or placed states
	if new_state == GameStatus.item_states.HELD or new_state == GameStatus.item_states.PLACED:
		
		# fade out object hint sound
		var tween: Tween = create_tween()
		tween.tween_property(self, "volume_db", -30.0, 3.0)
		await tween.finished
		self.stop()
		
		# check if item was just picked up
		var instant_music_change_condition_met : bool = (
			instant_music_change_configuration
			and previous_state == GameStatus.item_states.NONE
			and new_state == GameStatus.item_states.HELD
		)
		
		# call instant music change
		if instant_music_change_condition_met:
			Context.audio_manager.music_manager.gameplay_state.set_sync_stream_configuration(instant_music_change_configuration)
		
		# check if music zones were selected
		if change_music_zone_triggers.size() > 0:
			update_music_zones()
		
func update_music_zones():
	# change targeted music zone triggers
	for trigger in change_music_zone_triggers:
		
		if to_custom_music_zone_configuration:
			#print("changing ", trigger, " trigger to: ", to_custom_music_zone_configuration)
			trigger.set_custom_sync_stream_configuration(to_custom_music_zone_configuration)
		elif to_music_zone:
			#print("changing ", trigger, " trigger to: ", to_music_zone)
			trigger.set_music_zone_layer(to_music_zone)
	
	
