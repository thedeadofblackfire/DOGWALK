@tool

extends VBoxContainer

@export var group_title : String = "":
	get():
		return group_title
	set(val):
		find_child("GroupTitleText").text = val
		group_title = val
		find_child("GroupTitle").visible = group_title != ""

@export var credits_data : Dictionary = {"Name": "Role"}:
	get():
		return credits_data
	set(val):
		credits_data = val
		update_credits()

func _ready() -> void:
	update_credits()

func _process(delta: float) -> void:
	if not visible:
		return
	if not Engine.is_editor_hint():
		var title_node = find_child("GroupTitle")
		var slide = get_parent()
		if (slide.fade_title_in and slide.slide_progress < .5) or (slide.fade_title_out and slide.slide_progress > .5):
			find_child("GroupTitleText").modulate = Color(1., 1., 1., slide.fade_progress)
		else:
			find_child("GroupTitleText").modulate = Color(1., 1., 1., 1.)

func update_credits() -> void:
	var item_class = preload("res://source/sequences/credits/group_credit_item.tscn")
		
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
