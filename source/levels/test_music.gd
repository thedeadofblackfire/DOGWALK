extends AudioStreamPlayer

@export var enabled : bool

func _ready() -> void:
	
	# TMP start temp music only whne everything is loaded and ready
	if enabled:
		play()
