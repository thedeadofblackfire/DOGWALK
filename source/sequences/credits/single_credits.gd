@tool

extends VBoxContainer

@export var credits_data : Dictionary = {"Name": "Role"}:
	get():
		return credits_data
	set(val):
		credits_data = val
		update_credits()

func _ready() -> void:
	update_credits()

func update_credits() -> void:
	var item_class = preload("res://source/sequences/credits/single_credit_item.tscn")
		
	for c in get_children():
		if c is CreditItem:
			c.queue_free()
	
	for k in credits_data.keys():
		var credit = item_class.instantiate()
		credit.name = "Credit"
		self.add_child(credit)
		credit.owner = self.get_parent()
		credit.credit_name = k
		credit.credit_role = credits_data[k]
		credit.slide = get_parent()
