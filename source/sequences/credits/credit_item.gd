@tool

extends MarginContainer
class_name CreditItem

@onready var slide : CreditSlide

@export var credit_role : String = "Role":
	get():
		return credit_role
	set(val):
		credit_role = val
		var role_node = find_child("Role")
		if not role_node: return
		role_node.text = val
		has_role = credit_role != ""
@export var credit_name : String = "Name":
	get():
		return credit_name
	set(val):
		credit_name = val
		var name_node = find_child("Name")
		if not name_node:
			return
		name_node.text = val
@export var credit_text : String = "Text":
	get():
		return credit_text
	set(val):
		credit_text = val
		var text_node = find_child("Text")
		if not text_node:
			return
		text_node.text = val
@export var has_role : bool = true:
	get():
		return has_role
	set(value):
		has_role = value
		var role_node = find_child("Role")
		if not role_node: return
		role_node.visible = has_role
		add_theme_constant_override("margin_top", 200 if has_role else 0)
		add_theme_constant_override("margin_bottom", 0 if has_role else 0)

func _process(delta: float) -> void:
	if not visible:
		return
	if not Engine.is_editor_hint():
		modulate = Color(1., 1., 1., slide.fade_progress)
