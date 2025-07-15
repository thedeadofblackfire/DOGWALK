extends Control

class_name Credits
const sequence_name := "Credits"

enum sequence_states {
	PRE,
	SCROLL,
	END
}

# sequencing
var sequence_state := 0
var sequence_init = {
	sequence_states.SCROLL : seq_scroll_init,
	sequence_states.END : seq_end_init,
}
var sequence_process = {
	sequence_states.SCROLL : seq_scroll_process,
}

var video_player : VideoStreamPlayer
var credits_start_timer : Timer

@export var slide_stack : Node


func _ready():
	Context.sequence_credits = self
	print('Initialize Credits')
	init_credits()
	start()
	size = Vector2i(3840,2160)

func _process(delta: float) -> void:
	if sequence_state in sequence_process.keys():
		sequence_process[sequence_state].call()
	
	if Context.menu_ui.pause_menu.visible:
		self.modulate = Color(1,1,1,.5)
	else:
		self.modulate = Color(1,1,1,1)

func advance_sequence():
	sequence_state += 1
	print("Advancing %s sequence: %d (%s)" % [sequence_name, sequence_state, sequence_states.keys()[sequence_state]])
	sequence_init[sequence_state].call()

func start():
	print('Starting Credits')
	if Context.debug.skip_credits:
		stop()
		return
	
	get_tree().paused = true
	Context.background_elements_ui.making_of.show()
	video_player.play()
	
	Context.menu_ui.main_menu.hide()
	#show()
	hide()
	
	GameStatus.current_game_state = GameStatus.game_states.CREDITS
	advance_sequence()

func stop():
	print('Exiting Credits')
	
	get_tree().paused = false
	Context.menu_ui.main_menu.show()
	hide()
	
	GameStatus.current_game_state = GameStatus.game_states.MAIN_MENU
	
	InputController.mouse_vector = Vector2.ZERO
	GameStatus.call_deferred("reset_state")
	get_tree().call_deferred('reload_current_scene')
	
	video_player.queue_free()
	credits_start_timer.stop()
	self.queue_free()
	
func init_credits():
	
	# Create video player
	video_player = VideoStreamPlayer.new()
	video_player.name = "MakingOfVideo"
	Context.background_elements_ui.video_container.add_child(video_player)
	video_player.owner = owner
	
	video_player.stream = preload("res://assets/videos/credits_making_of.ogv")
	video_player.expand = true
	
	credits_start_timer = Timer.new()
	credits_start_timer.name = "TextTimer"
	add_child(credits_start_timer)
	credits_start_timer.owner = owner
	credits_start_timer.wait_time = 5.0

## sequence logic
	
func seq_scroll_init():
	video_player.play()
	credits_start_timer.start()
	credits_start_timer.timeout.connect(
		func():
			credits_start_timer.stop()
			slide_stack.play()
			show()
			slide_stack.slides_done.connect(advance_sequence)
	)

func seq_scroll_process():
	print("credits are scrolling")

func seq_end_init():
	slide_stack.slides_done.disconnect(advance_sequence)
	stop()
