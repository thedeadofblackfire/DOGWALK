@tool

extends TabContainer

@export var json : JSON
@export_tool_button("Update Credit Slides", "Callable") var update_credit_slides_action = update_credit_slides

var current_slide : CreditSlide

signal slides_done()

func _ready() -> void:
	if not Engine.is_editor_hint():
		SignalBus.credits_next_slide.connect(next_slide)

func update_credit_slides():
	print("Updating credits slides")
	
	var data : Dictionary = json.data
	
	for child in get_children():
		if child is not CreditSlide:
			continue
		child.name = "DELETE"
		child.queue_free()
	
	for slide_name in data.keys():
		var slide_data = data[slide_name]
		
		var slide : CreditSlide
		slide = find_child(slide_name)
		if not slide:
			slide = preload("res://source/sequences/credits/credit_slide.tscn").instantiate()
			add_child(slide)
			slide.owner = self.get_parent()
			slide.name = slide_name
			
		if "type" in slide_data.keys():
			slide.slide_type = CreditSlide.slide_types[slide_data["type"]]
		if "group_title" in slide_data.keys(): slide.group_title = slide_data["group_title"]
		if "credits" in slide_data.keys(): slide.credits_data = slide_data["credits"]
		if "lines" in slide_data.keys(): slide.credits_lines = slide_data["lines"]
	
	# mark title fades
	for i in get_child_count():
		if i > 0:
			get_child(i).fade_title_in = get_child(i).group_title != get_child(i-1).group_title
		if i + 1 < get_child_count():
			get_child(i).fade_title_out = get_child(i).group_title != get_child(i+1).group_title
	

func play():
	current_slide = get_child(0)
	current_slide.play_slide()

func next_slide():
	print("next slide")
	print(current_slide.get_index() + 1)
	print(get_child_count())
	if current_slide.get_index() + 1 == get_child_count():
		slides_done.emit()
		print('Slides Done')
	else:
		current_slide = get_child(current_slide.get_index() + 1)
		current_slide.play_slide()
