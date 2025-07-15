extends Node3D
class_name SFXManager

@export var bush_sound_pool : ObjectPool
@export var topple_sound_pool : ObjectPool
@export var untopple_sound_pool : ObjectPool

@export var hint_sound_branch : AudioStreamPlayer3D
@export var hint_sound_shovel : AudioStreamPlayer3D
@export var hint_sound_tennis_ball : AudioStreamPlayer3D
@export var hint_sound_traffic_cone : AudioStreamPlayer3D

enum SOUND { BUSH, TOPPLE, UNTOPPLE }

func _ready():
	Context.audio_manager.sfx_manager = self
	Context.sfx_manager = self

func play_sound_at_position(spawn_position : Vector3, sfx_type : SOUND):
	
	var sfx_player : AudioStreamPlayer3D
	
	#print("Playing sound ", sound_stream.resource_name, " at position ", spawn_position)
	match sfx_type:
		SOUND.BUSH:
			sfx_player = bush_sound_pool.get_item() # returns null if max pool size reached
			if !sfx_player: return # return if no sound available
			elif !sfx_player.finished.has_connections(): # connect if first instantiated
				sfx_player.finished.connect(bush_sound_pool.return_item.bind(sfx_player))
		
		SOUND.TOPPLE:
			sfx_player = topple_sound_pool.get_item() # returns null if max pool size reached
			if !sfx_player: return # return if no sound available
			elif !sfx_player.finished.has_connections(): # connect if first instantiated
				sfx_player.finished.connect(topple_sound_pool.return_item.bind(sfx_player))
		
		SOUND.UNTOPPLE:
			sfx_player = untopple_sound_pool.get_item() # returns null if max pool size reached
			if !sfx_player: return # return if no sound available
			elif !sfx_player.finished.has_connections(): # connect if first instantiated
				sfx_player.finished.connect(untopple_sound_pool.return_item.bind(sfx_player))
	
	sfx_player.global_position = spawn_position
	sfx_player.play()
