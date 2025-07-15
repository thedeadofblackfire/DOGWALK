@tool

extends VBoxContainer

@export var credits_lines : Array = [""]:
	get():
		return credits_lines
	set(val):
		credits_lines = val
		update_credits()

func _ready() -> void:
	update_credits()

func update_credits() -> void:
	var item_class = preload("res://source/sequences/credits/text_credit_item.tscn")
		
	for c in get_children():
		if c is CreditItem:
			c.queue_free()
	
	for l in credits_lines:
		var credit = item_class.instantiate()
		credit.name = "Credit"
		self.add_child(credit)
		credit.owner = self.get_parent()
		credit.credit_name = ""
		credit.credit_role = ""
		credit.credit_text = l
		credit.slide = get_parent()
