extends Node
class_name UISoundManager

@export var nav_sound :AudioStreamPlayer
@export var accept_sound :AudioStreamPlayer
@export var cancel_sound :AudioStreamPlayer
@export var save_sound : AudioStreamPlayer
@export var slider_sound : AudioStreamPlayer
var panner_effect : AudioEffectPanner = AudioServer.get_bus_effect(AudioManager.BUS.UI, 1)

var nodes_connected : Array[Node]


func connect_ui_sounds_in(node : Node) -> void:
	var ui_nodes : Array[Node] = node.find_children("", "Control")
	
	for element in ui_nodes:
		#print("parent: ", node, "element	: ", element)
		if element.name == "SaveButton": continue # set from editor, don't overwrite
		#if element not in nodes_connected:
		connect_sound_to(element)
			
	#print("connected ui nodes:", nodes_connected) # checks connected nodes
		
func connect_sound_to(element : Node):
	
	
	print("connecting sounds to element: ", element, " class ", element.get_class())
	if element is Button:
		if ( # if not already connected to nav sounds
			!element.is_connected("mouse_entered", nav_sound.play) 
			and !element.is_connected("focus_entered", nav_sound.play)
			and !element.is_connected("pressed", accept_sound.play)
		):
			element.mouse_entered.connect(func():
				pan_ui_sound(element)
				nav_sound.play()
			)
			element.focus_entered.connect(func():
				pan_ui_sound(element)
				nav_sound.play()
			)
			element.pressed.connect(accept_sound.play)
			nodes_connected.append(element)
			
	if element is TabContainer:
		if (
			!element.is_connected("tab_hovered", nav_sound.play)
			and !element.is_connected("tab_changed", nav_sound.play)
		):
			element.tab_hovered.connect(func():
				pan_ui_sound(element)
				nav_sound.play()
			)
			element.tab_changed.connect(func():
				pan_ui_sound(element)
				nav_sound.play()
			)
			nodes_connected.append(element)
	if element is Slider:
		if (
			!element.is_connected("value_changed", slider_sound.play) 
			and !element.is_connected("focus_entered", slider_sound.play)
			and !element.is_connected("mouse_entered", slider_sound.play)
		):
			element.value_changed.connect(slider_sound.play)
			element.mouse_entered.connect(slider_sound.play)
			element.focus_entered.connect(func():
				pan_ui_sound(element)
				nav_sound.play()
			)
			nodes_connected.append(element)
	
func pan_ui_sound(element : Control):
	var vw = get_viewport().size.x
	var margin := 0.2
	panner_effect.pan = remap(element.global_position.x, vw * margin, vw * (1 + margin), -0.25, 0.25)
	
