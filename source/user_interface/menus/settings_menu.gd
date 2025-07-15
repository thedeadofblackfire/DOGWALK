extends Control

@export var general_tab : Control
@export var graphics_tab : Control
@export var sounds_tab : Control
@export var controls_tab : Control

@export var auto_save_button : CheckBox

@export var window_mode_setting : OptionButton
@export var resolution_setting : OptionButton
@export var shadow_quality_setting : OptionButton
@export var dof_button : CheckBox
@export var ss_aa_button : CheckBox

@export var master_volume_slider : HSlider
@export var music_volume_slider : HSlider
@export var ambience_volume_slider : HSlider
@export var sfx_volume_slider : HSlider
@export var ui_volume_slider : HSlider
@export var bass_cut_button : CheckButton
@export var bass_freq_slider : HSlider
@export var audio_mono_button : CheckButton

@export var mouse_sensitivity_slider : HSlider

var parent_menu

var silent_sync = false

var settings_nodes : Dictionary

var settings_sync : Dictionary = {
	## General
	"auto_save": toggle_apply,
	## Graphics
	"resolution": resolution_apply,
	"window_mode": option_string_apply,
	"shadow_quality": option_string_apply,
	"dof": toggle_apply,
	"ss_aa": toggle_apply,
	## Sounds
	"master_volume": value_apply,
	"music_volume": value_apply,
	"ambience_volume": value_apply,
	"sfx_volume": value_apply,
	"ui_volume": value_apply,
	"bass_cut": toggle_apply,
	"bass_freq": value_apply,
	"audio_mono": toggle_apply,
	## Controls
	"mouse_sensitivity": value_apply
}

var active_tab : MarginContainer:
	get():
		for tab in find_child("TabContainer").get_children():
			if tab.visible:
				return tab
		return null
	set(node):
		if not node:
			return
		node.show()
		active_tab = node
		

var resolutions := [
	Vector2i(3840, 2160),
	Vector2i(2560, 1440),
	Vector2i(1920, 1080),
	Vector2i(1600, 900),
	Vector2i(1280, 720),
]

func _ready() -> void:
	print(OS.get_data_dir())
	active_tab = graphics_tab
	resolution_setting.grab_focus()
	
	Context.background_elements_ui.settings.show()
	Context.background_elements_ui.settings.modulate = Color(1,1,1,1)
	
	find_child("TabContainer").tab_changed.connect(func(tab): tab_change_grab_focus.call_deferred())
	
	init_resolution_setting()
	
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	
	init_settings_dict()
	
	sync_settings()
	
	replace_icons_based_on_input_mode(InputController.current_input_mode)
	InputController.input_mode_changed.connect(replace_icons_based_on_input_mode)

func init_settings_dict():
	settings_nodes = {
		## General
		"auto_save": auto_save_button,
		## Graphics
		"resolution": resolution_setting,
		"window_mode": window_mode_setting,
		"shadow_quality": shadow_quality_setting,
		"dof": dof_button,
		"ss_aa": ss_aa_button,
		## Sounds
		"master_volume": master_volume_slider,
		"music_volume": music_volume_slider,
		"ambience_volume": ambience_volume_slider,
		"sfx_volume": sfx_volume_slider,
		"ui_volume": ui_volume_slider,
		"bass_cut": bass_cut_button,
		"bass_freq": bass_freq_slider,
		"audio_mono": audio_mono_button,
		## Controls
		"mouse_sensitivity": mouse_sensitivity_slider
	}

func replace_icons_based_on_input_mode(mode):
	find_child("TabButtonLeft").icon = preload("res://assets/textures/menu/user_interface/tab_left.png") if mode == InputController.input_modes.MOUSE else preload("res://assets/textures/menu/user_interface/LB.png")
	find_child("TabButtonRight").icon = null if mode == InputController.input_modes.MOUSE else preload("res://assets/textures/menu/user_interface/RB.png")
	find_child("BackButton").icon = preload("res://assets/textures/menu/user_interface/Esc.png") if mode == InputController.input_modes.MOUSE else preload("res://assets/textures/menu/user_interface/B_button.png")
	find_child("ResetButton").icon = preload("res://assets/textures/menu/user_interface/tab_reset.png") if mode == InputController.input_modes.MOUSE else preload("res://assets/textures/menu/user_interface/Y_button.png")

func tab_change_grab_focus():
	if not Settings.settings_dict[active_tab.name]:
		return
	settings_nodes[Settings.settings_dict[active_tab.name][0]].grab_focus()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		exit_settings.call_deferred()
	elif event.is_action("settings_reset"):
		_on_reset_button_pressed()
	elif event.is_action_pressed("ui_prev_tab"):
		active_tab = find_child("TabContainer").get_child(active_tab.get_index() - 1)
	elif event.is_action_pressed("ui_next_tab"):
		var tab_index := active_tab.get_index()
		if tab_index == find_child("TabContainer").get_child_count() - 1:
			active_tab = find_child("TabContainer").get_child(0)
		else:
			active_tab = find_child("TabContainer").get_child(tab_index + 1)

func init_resolution_setting():
	var native_resolution := DisplayServer.screen_get_size()
	
	if native_resolution not in resolutions:
		resolutions.push_back(native_resolution)
	resolutions.sort_custom(func(a, b): return a.x > b.x if a.y == b.y else a.y > b.y)
	
	for i in resolutions.size():
		resolution_setting.add_item(str(resolutions[i].x)+" x "+str(resolutions[i].y))

func exit_settings() -> void:
	queue_free()
	Context.background_elements_ui.settings.hide()
	get_viewport().gui_focus_changed.disconnect(_on_focus_changed)
	parent_menu.state = parent_menu.menu_states.MAIN
	parent_menu.settings_button.grab_focus()

func sync_settings():
	silent_sync = true
	
	for cat in Settings.settings_defaults.keys():
		for param in Settings.settings_defaults[cat].keys():
			settings_sync[param].call(param, Settings.settings_defaults[cat][param])
		
	for section in Settings.config.get_sections():
		for param in Settings.config.get_section_keys(section):
			var value = Settings.config.get_value(section, param)
			settings_sync[param].call(param, value)
	silent_sync = false

func mute_slider(name: String, mute: bool) -> void:
	var node : Node = settings_nodes[name]
	var mod = Color(1, 1, 1, .5) if mute else Color(1, 1, 1, 1)
	node.get_parent().get_child(node.get_index()-1).modulate = mod
	node.modulate = mod

func _on_resolutions_item_selected(index: int) -> void:
	var resolution : Vector2i = resolutions[index]
	Settings.apply("resolution", resolution, !silent_sync)

func _on_window_modes_item_selected(index: int) -> void:
	var mode
	match index:
		0:
			mode = "FULLSCREEN"
		1:
			mode = "BORDERLESS"
		2:
			mode = "WINDOWED"
			
	Settings.apply("window_mode", mode, !silent_sync)

func _on_shadow_setting_item_selected(index: int) -> void:
	var node : OptionButton = settings_nodes["shadow_quality"]
	var mode_name := node.get_item_text(index)
	Settings.apply("shadow_quality", mode_name, !silent_sync)

func _on_dof_button_toggled(toggled_on: bool) -> void:
	Settings.apply("dof", toggled_on, !silent_sync)

func _on_aa_button_toggled(toggled_on: bool) -> void:
	Settings.apply("ss_aa", toggled_on, !silent_sync)

func _on_master_volume_slider_value_changed(value: float) -> void:
	Settings.apply("master_volume", value, !silent_sync)
	mute_slider("master_volume", value == 0)
	mute_slider("music_volume", value == 0 or settings_nodes["music_volume"].value == 0)
	mute_slider("ambience_volume", value == 0 or settings_nodes["ambience_volume"].value == 0)
	mute_slider("sfx_volume", value == 0 or settings_nodes["sfx_volume"].value == 0)
	mute_slider("ui_volume", value == 0 or settings_nodes["ui_volume"].value == 0)

func _on_music_volume_slider_value_changed(value: float) -> void:
	Settings.apply("music_volume", value, !silent_sync)
	mute_slider("music_volume", value == 0 or settings_nodes["master_volume"].value == 0)

func _on_ambience_volume_slider_value_changed(value: float) -> void:
	Settings.apply("ambience_volume", value, !silent_sync)
	mute_slider("ambience_volume", value == 0 or settings_nodes["master_volume"].value == 0)

func _on_sfx_volume_slider_value_changed(value: float) -> void:
	Settings.apply("sfx_volume", value, !silent_sync)
	mute_slider("sfx_volume", value == 0 or settings_nodes["master_volume"].value == 0)

func _on_ui_volume_slider_value_changed(value: float) -> void:
	Settings.apply("ui_volume", value, !silent_sync)
	mute_slider("ui_volume", value == 0 or settings_nodes["master_volume"].value == 0)
	
func _on_bass_cut_button_toggled(is_toggled_on : bool) -> void:
	Settings.apply("bass_cut", is_toggled_on, !silent_sync)
	
func _on_bass_freq_slider_value_changed(value : float) -> void:
	Settings.apply("bass_freq", value, !silent_sync)
	
func _on_audio_mono_button_toggled(is_toggled_on : bool) -> void:
	Settings.apply("audio_mono", is_toggled_on, !silent_sync)

func _on_auto_save_button_toggled(toggled_on: bool) -> void:
	Settings.apply("auto_save", toggled_on, !silent_sync)

func _on_mouse_sensitivity_slider_value_changed(value: float) -> void:
	Settings.apply("mouse_sensitivity", value, !silent_sync)


func _on_back_button_pressed() -> void:
	exit_settings()

func _on_reset_button_pressed() -> void:
	var tabs : TabContainer = find_child("TabContainer")
	var current_category : String = tabs.get_child(tabs.current_tab).name
	Settings.reset_settings(current_category)
	sync_settings()

func _on_tab_button_left_pressed() -> void:
	var tab_index := active_tab.get_index()
	active_tab = find_child("TabContainer").get_child(tab_index - 1)
	print("ha")


func _on_tab_button_right_pressed() -> void:
	var tab_index := active_tab.get_index()
	if tab_index == find_child("TabContainer").get_child_count() - 1:
		active_tab = find_child("TabContainer").get_child(0)
	else:
		active_tab = find_child("TabContainer").get_child(tab_index + 1)

func _on_focus_changed(node: Control):
	if not active_tab.find_child(node.name):
		tab_change_grab_focus()


func resolution_apply(id: String, value: Vector2i):
	var node : OptionButton = settings_nodes["resolution"]
	for i in node.item_count:
		if node.get_item_text(i) == "%d x %d" % [value.x, value.y]:
			node.select(i)
			print("select_resolution")
			return

func option_string_apply(id: String, value: String):
	var node : OptionButton = settings_nodes[id]
	for i in node.item_count:
		if node.get_item_text(i).to_lower() == value.to_lower():
			node.select(i)
			return

func value_apply(id: String, value: Variant):
	settings_nodes[id].value = value

func toggle_apply(id: String, toggled: bool):
	settings_nodes[id].button_pressed = toggled
