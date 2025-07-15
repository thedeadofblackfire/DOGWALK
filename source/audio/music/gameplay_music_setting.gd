extends Resource
class_name GameplayMusicSetting

@export var configuration : Dictionary[MusicStateGameplay.SYNC_STREAMS, bool] = {
	MusicStateGameplay.SYNC_STREAMS.IDLE_WALK_RUN_SPRINT : false,
	MusicStateGameplay.SYNC_STREAMS.IDLE_WALK_RUN : false,
	MusicStateGameplay.SYNC_STREAMS.WALK : false,
	MusicStateGameplay.SYNC_STREAMS.WALK_RUN_SPRINT : false,
	MusicStateGameplay.SYNC_STREAMS.RUN_SPRINT : false,
	MusicStateGameplay.SYNC_STREAMS.SPRINT : false,
	MusicStateGameplay.SYNC_STREAMS.PULL : false,
	MusicStateGameplay.SYNC_STREAMS.REST_MEDITATE_HEAL : false,
	MusicStateGameplay.SYNC_STREAMS.MEDITATE_HEAL : false,
	MusicStateGameplay.SYNC_STREAMS.HEAL : false,
	MusicStateGameplay.SYNC_STREAMS.FOREST : false,
	MusicStateGameplay.SYNC_STREAMS.FENCE : false,
	MusicStateGameplay.SYNC_STREAMS.POND : false,
	MusicStateGameplay.SYNC_STREAMS.POND_EXTRA : false,
}
