@tool

extends Control

class_name CreditSlide

enum slide_types {SINGLE, GROUP, TEXT}

var node_names := {
	slide_types.SINGLE: "SingleCredits",
	slide_types.GROUP: "GroupCredits",
	slide_types.TEXT: "TextCredits"
}

@export var slide_timer : Timer
@export var slide_type : slide_types:
	get():
		return slide_type
	set(val):
		slide_type = val
		if slide_type == -1:
			return
		for k in node_names:
			find_child(node_names[k]).visible = node_names[k] == node_names[slide_type]
@export var group_title : String = "":
	get():
		return group_title
	set(val):
		group_title = val
		find_child(node_names[slide_types.GROUP]).group_title = group_title
@export var credits_data : Dictionary = {"Name": "Role"}:
	get():
		return credits_data
	set(val):
		credits_data = val
		update_credits()
@export var credits_lines : Array = ["Text"]:
	get():
		return credits_lines
	set(val):
		credits_lines = val
		update_credits()

const fade_time := .5
var fade_progress : float = 1.
var slide_progress : float = 0.

@export var fade_title_in := true
@export var fade_title_out := true

func _ready() -> void:
	if Engine.is_editor_hint():
		update_credits()
	else:
		slide_timer.timeout.connect(finish_slide)

func _process(delta: float) -> void:
	if not visible:
		return
	slide_progress = 1. - (slide_timer.time_left / slide_timer.wait_time)
	if not Engine.is_editor_hint():
		fade_progress = clamp((1. - abs((slide_progress - .5) * 2.)) / (fade_time / slide_timer.wait_time * 2.), 0., 1.)

func play_slide():
	show()
	slide_timer.start()
	slide_progress = 0.
	fade_progress = 0.

func finish_slide():
	hide()
	SignalBus.credits_next_slide.emit()

func update_credits():
	for k in node_names.keys():
		var node = find_child(node_names[k])
		if not node:
			continue
		if "credits_data" in node:
			node.credits_data = credits_data
		if "credits_lines" in node:
			node.credits_lines = credits_lines
		node.visible = node_names[k] == node_names[slide_type]
