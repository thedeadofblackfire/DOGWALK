extends Area3D
class_name MusicZoneTrigger

@export_category("Variables")
@export var music_zone_layer : MusicStateGameplay.MUSIC_ZONE
@export var custom_sync_stream_configuration: GameplayMusicSetting

func activate_music_zone():
	if custom_sync_stream_configuration:
		Context.audio_manager.music_manager.gameplay_state.set_sync_stream_configuration(custom_sync_stream_configuration)
	else:
		Context.audio_manager.music_manager.gameplay_state.switch_music_zone(music_zone_layer)
	
func set_music_zone_layer(music_zone : MusicStateGameplay.MUSIC_ZONE):
	music_zone_layer = music_zone
	
func set_custom_sync_stream_configuration(configuration : GameplayMusicSetting):
	custom_sync_stream_configuration = configuration

func _on_chocomel_entered(body: CharacterBody3D) -> void:
	activate_music_zone()
