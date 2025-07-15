extends Control

@export var transition_timer : Timer
@export var control : Control
@export var loading_sprite : AnimatedSprite2D

var fade_in = true
var progress : float = 0.
var time_elapsed := 0.
var wait_time := 0. # artificial loading progress to give load time to settle

const progress_steps := 10

signal transition_done
signal screen_covered

func _ready() -> void:
	transition_timer.connect('timeout', _on_transition_timer_timeout)

func _process(delta: float) -> void:
	var ratio = get_tree().root.content_scale_size.y / 1080.
	find_child("LoadingBar").scale = Vector2(ratio, ratio)
	time_elapsed += delta
	var fac = transition_timer.time_left / transition_timer.wait_time
	if fade_in:
		control.modulate = Color(1., 1., 1., 1. - fac)
	else:
		control.modulate = Color(1., 1., 1., fac)
		
	animate_loading_bar()

func resume() -> void:
	fade_in = false
	transition_timer.start()

func _on_transition_timer_timeout() -> void:
	if fade_in:
		emit_signal("screen_covered")
	else:
		emit_signal("transition_done")
		queue_free()

func animate_loading_bar() -> void:
	var progress := time_elapsed / (transition_timer.wait_time * 2. + wait_time)
	
	var step := int(progress * progress_steps)
	
	loading_sprite.frame = step % loading_sprite.sprite_frames.get_frame_count(loading_sprite.animation)
	
	var offset = remap(float(step) / progress_steps, 0, 1, 400, 1500)
	loading_sprite.position.x = offset
