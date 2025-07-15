extends Control

@export var display_debug_text := false

# Member variables
@export var debug_ui : Control
@export var fps_stat : Label
@export var stamina_stat : Label
@export var mood_stat : Label

var pinda : CharacterBody3D

func _ready() -> void:
	
	GameStatus.debug_ui = display_debug_text


func _process(delta: float) -> void:
	
	debug_ui.visible = GameStatus.debug_ui
	
	if pinda == null:
		var pinda_id = Constants.interactable_ids.PINDA
		pinda = Context.interactable_nodes[pinda_id]
	
	fps_stat.text = "FPS = " + str(Engine.get_frames_per_second())
	stamina_stat.text = "Stamina = " + str(snappedf(pinda.stamina, 0.1))
	mood_stat.text = "Mood = " + str(snappedf(pinda.mood, 0.1))
