extends Node

@export var skip_launch_logos := false
@export var skip_wake_up := false
@export var skip_intro := false
@export var skip_gate := false
@export var skip_ending := false
@export var skip_credits := false
@export var always_happy := false
@export var always_fast := false

func _ready() -> void:
	Context.debug = self
