extends Node

## Dictionary of items and their nodes in-game. 
## Each node is responsible for setting this on ready.
var interactable_nodes: Dictionary = {
	Constants.interactable_ids.CHOCOMEL 	 	: null,
	Constants.interactable_ids.PINDA	 	 	: null,
	Constants.interactable_ids.SNOWMAN			: null,
	Constants.interactable_ids.GATE				: null,
	Constants.interactable_ids.WILLOW	 	 	: null,
	Constants.interactable_ids.ITEM_GENERIC 	: null,
	Constants.interactable_ids.TENNIS_BALL  	: null,
	Constants.interactable_ids.SHOVEL 		 	: null,
	Constants.interactable_ids.TRAFFIC_CONE 	: null,
	Constants.interactable_ids.EAR_MUFFS 	 	: null,
	Constants.interactable_ids.BRANCH			: null,
}

# Member variables. These are set by the children on ready
@onready var level : Node
@onready var sequence_intro : Intro
@onready var sequence_ending : Ending
@onready var sequence_credits : Credits
@onready var sequence_gate : GateSequence
@onready var gate : Gate
@onready var player: Player
@onready var pinda : Pinda 
@onready var chocomel : Chocomel
@onready var leash : Leash 
@onready var camera : GameCamera
@onready var debug : Node
@onready var audio_manager : AudioManager
@onready var music_manager : MusicManager
@onready var sfx_manager : SFXManager
@onready var menu_ui : MenuUI
@onready var background_elements_ui : BackgroundElementsUI
