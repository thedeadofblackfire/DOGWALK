extends Node

# Debug toggles
var debug_ui := false
var debug_low_stamina := false
var debug_low_mood := false
var debug_increase_stamina := false
var debug_decrease_stamina := false
var debug_increase_mood := false
var debug_decrease_mood := false


## Gameplay variables and states
# TODO: should eventuallty be reset on reset/loaded via function

signal game_state_changed(new_state : game_states, previous_state : game_states)

enum game_states {MAIN_MENU, LOADING, INTRO, GAMEPLAY, ENDING, CREDITS}
var current_game_state := game_states.GAMEPLAY:
	get():
		return current_game_state
	set(value):
		game_state_changed.emit(value, current_game_state)
		current_game_state = value
		print("GAME STATE: %s" % [game_states.keys()[current_game_state]])

var ready_for_ending:
	get():
		for item_id in items_status:
			if items_status[item_id] != item_states.PLACED:
				return false
		return true

var all_items_found:
	get():
		for item_id in items_status:
			if items_status[item_id] == item_states.NONE:
				return false
		return true

enum item_states {NONE, HELD, PLACED}
## Current state of all items
var items_status : Dictionary[Constants.interactable_ids, item_states] = {
	Constants.interactable_ids.BRANCH 			: -1,
	Constants.interactable_ids.TENNIS_BALL		: -1,
	Constants.interactable_ids.SHOVEL 			: -1,
	Constants.interactable_ids.TRAFFIC_CONE		: -1,
}

var gate_opened := false


func _ready() -> void:
	self.add_to_group("Persist")
	
func _process(delta: float) -> void:
	if current_game_state == game_states.GAMEPLAY:
		check_ending()
		
func check_ending() -> void:
	if ready_for_ending:
		trigger_ending()

func trigger_ending() -> void:
	print("Triggering Ending")
	
	var ending = Ending.new()
	ending.name = "Ending"
	Context.level.add_child(ending)
	ending.owner = Context.level
	Context.sequence_ending = ending

func save_state():
	var save_dict := {
		"node" : get_path(),
		"items_status" : items_status,
		"gate_opened" : gate_opened,
	}
	return save_dict

func load_state(node_data):
	gate_opened = node_data["gate_opened"]
	if gate_opened:
		Context.sequence_gate.skip_gate_challenge()
	for k in Constants.item_ids:
		if k not in items_status:
			continue
		Context.interactable_nodes[k].item_state = int(node_data["items_status"][str(k)])

func init_state():
	for k in Constants.item_ids:
		if k not in items_status:
			continue
		Context.interactable_nodes[k].item_state = -1

func reset_state():
	for k in Constants.item_ids:
		if k not in items_status:
			continue
		Context.interactable_nodes[k].item_state = 0

## NOTE: Functions that other scripts can access to trigger logic


## Set game state variables for item pickup
func picked_up_item(target_item_id : int) -> void:
	Context.interactable_nodes[target_item_id].item_state = item_states.HELD


## Set game state variables for using item on snowman
func placed_item(target_item_id : int) -> void:
	
	# Update bone targets in case something moved (like the arm for the shovel)
	Context.interactable_nodes[Constants.interactable_ids.SNOWMAN].set_bone_targets()
	
	Context.interactable_nodes[target_item_id].item_state = item_states.PLACED

func init_load():
	# scale down pompom if traffic cone is held
	if Context.interactable_nodes[Constants.interactable_ids.TRAFFIC_CONE].item_state == item_states.HELD:
		Context.pinda.scale_down_pompom("")
	
