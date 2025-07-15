extends Node

var menu_theme : Theme
var default_font_size

var config : ConfigFile
var project_config : ConfigFile

var auto_save : bool = true

var mouse_sensitivity : float = 1.:
	get():
		return InputController.mouse_sensitivity
	set(value):
		InputController.mouse_sensitivity = value

var dof : bool = true:
	get():
		return dof
	set(value):
		dof = value
		(
			func(): Context.camera.camera3D.attributes.dof_blur_near_enabled = dof
		).call_deferred()
var ss_aa : bool = true:
	get():
		return ss_aa
	set(value):
		ss_aa = value
		(
			func(): get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if ss_aa else Viewport.SCREEN_SPACE_AA_DISABLED
		).call_deferred()
		

var bass_cut_active : bool = false
var bass_cut_freq : float = 60
var audio_mono_active : bool = false

var settings_dict : Dictionary = {
		"General" : [
			"auto_save"
		],
		"Graphics" : [
			"window_mode",
			"resolution",
			"shadow_quality",
			"dof",
			"ss_aa"
		],
		"Sounds" : [
			"master_volume",
			"music_volume",
			"ambience_volume",
			"sfx_volume",
			"ui_volume",
			"bass_cut",
			"bass_freq",
			"audio_mono",
		],
		"Controls" : [
			"mouse_sensitivity"
		],
	}

var settings_defaults : Dictionary = {
	"General" : {
		"auto_save": true,
	},
	## General
	## Graphics
	"Graphics" : {
		"window_mode": "BORDERLESS",
		"resolution": Vector2i(1920, 1080),
		"shadow_quality": "DEFAULT",
		"dof": true,
		"ss_aa": true,
	},
	## Sounds
	"Sounds" : {
		"master_volume": 1.,
		"music_volume": 1.,
		"ambience_volume": 1.,
		"sfx_volume": 1.,
		"ui_volume": 1.,
		"bass_cut": false,
		"bass_freq": 70,
		"audio_mono": false,
	},
	## Controls
	"Controls" : {
		"mouse_sensitivity": 1.
	}
}

func _ready() -> void:
	menu_theme = load("res://source/user_interface/menus/menu_theme.tres")
	
	default_font_size = menu_theme.default_font_size
	set_ui_scale_based_on_resolution(get_tree().root.content_scale_size)
	
	load_settings()

func init_settings(category : String = ""):
	if category == "":
		config = ConfigFile.new()
		project_config = ConfigFile.new()
	else:
		config.erase_section(category)
		if category == "Graphics":
			project_config.erase_section("display")
	
	settings_defaults["Graphics"]["resolution"] = DisplayServer.screen_get_size()

func reset_settings(category : String = "") -> void:
	init_settings(category)
	apply_settings(category)
	save_settings()

func save_settings() -> void:
	for section in config.get_sections():
		for param in config.get_section_keys(section):
			var value = config.get_value(section, param)
			if value == settings_defaults[section][param]:
				config.erase_section_key(section, param)
	config.save("user://settings.cfg")
	project_config.save("user://project_overrides.cfg")

func load_settings() -> void:
	config = ConfigFile.new()
	var err1 = config.load("user://settings.cfg")
		
	project_config = ConfigFile.new()
	var err2 = project_config.load("user://project_overrides.cfg")
	if err1 != OK or err2 != OK or not project_config or not config:
		print("init settings")
		init_settings()
		
	apply_settings()
	
	
func apply_settings(category : String = ""):
	if category == "":
		for cat in settings_defaults.keys():
			for param in settings_defaults[cat].keys():
				apply(param, settings_defaults[cat][param])
	else:
		for param in settings_defaults[category].keys():
			apply(param, settings_defaults[category][param])
		
	for section in config.get_sections():
		for param in config.get_section_keys(section):
			var value = config.get_value(section, param)
			apply(param, value)

func set_ui_scale_based_on_resolution(resolution):
	#menu_theme.default_font_size = default_font_size * resolution.y / 1080
	menu_theme.set_font_size("font_size", "PopupMenu", default_font_size * resolution.y / 2160)
	
func center_window():
	var center_screen = DisplayServer.screen_get_position() + DisplayServer.screen_get_size()/2
	var window_size = get_window().get_size_with_decorations()
	get_window().set_position(center_screen-window_size / 2)

## Apply & Store

func apply(setting: String, value: Variant, store := false) -> void:
	call("%s_apply" % [setting], value)
	if store:
		store(setting, value)

func store(setting: String, value: Variant) -> void:
	call("%s_store" % [setting], value)

func auto_save_apply(value: bool) -> void:
	auto_save = value

func auto_save_store(value: bool) -> void:
	config.set_value("General", "auto_save", value)
	Settings.save_settings()

func resolution_apply(resolution: Vector2i) -> void:
	get_tree().root.content_scale_size = resolution
	if get_window().mode == Window.MODE_WINDOWED:
		center_window()
	
	if get_window().mode == Window.MODE_WINDOWED:
		get_window().set_size(resolution)
		center_window()
		
	set_ui_scale_based_on_resolution(resolution)
	
func resolution_store(resolution: Vector2i) -> void:
	config.set_value("Graphics", "resolution", resolution)
	Settings.save_settings()

func window_mode_apply(mode_name: String) -> void:
	var mode
	match mode_name:
		"FULLSCREEN":
			mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		"BORDERLESS":
			mode = Window.MODE_FULLSCREEN
		"WINDOWED":
			mode = Window.MODE_WINDOWED
	
	if get_window().mode == mode:
		return
		
	get_window().set_mode(mode)
	print(get_window().mode)
	
	if mode == Window.MODE_WINDOWED:
		get_window().set_size(get_tree().root.content_scale_size)
		center_window()

func window_mode_store(mode_name: String) -> void:
	var mode
	match mode_name:
		"FULLSCREEN":
			mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		"BORDERLESS":
			mode = Window.MODE_FULLSCREEN
		"WINDOWED":
			mode = Window.MODE_WINDOWED
	project_config.set_value("display", "window/size/mode", mode)
	config.set_value("Graphics", "window_mode", mode_name)
	Settings.save_settings()

func shadow_quality_apply(mode_name: String) -> void:
	var sun = get_tree().current_scene.find_child("Sun")
	match mode_name:
		"LOW":
			RenderingServer.directional_shadow_atlas_set_size(2048, false)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.ShadowQuality.SHADOW_QUALITY_SOFT_VERY_LOW)
			get_viewport().positional_shadow_atlas_size = 0
			sun.directional_shadow_mode = DirectionalLight3D.ShadowMode.SHADOW_ORTHOGONAL
		"DEFAULT":
			RenderingServer.directional_shadow_atlas_set_size(4096, true)
			RenderingServer.directional_soft_shadow_filter_set_quality(RenderingServer.ShadowQuality.SHADOW_QUALITY_SOFT_LOW)
			get_viewport().positional_shadow_atlas_size = 4096
			sun.directional_shadow_mode = DirectionalLight3D.ShadowMode.SHADOW_PARALLEL_2_SPLITS

func shadow_quality_store(mode_name: String) -> void:
	config.set_value("Graphics", "shadow_quality", mode_name)
	Settings.save_settings()

func dof_apply(value: bool) -> void:
	dof = value

func dof_store(value: bool) -> void:
	config.set_value("Graphics", "dof", value)
	Settings.save_settings()

func ss_aa_apply(value: bool) -> void:
	ss_aa = value

func ss_aa_store(value: bool) -> void:
	config.set_value("Graphics", "ss_aa", value)
	Settings.save_settings()
	
func master_volume_apply(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioManager.BUS.MASTER, linear_to_db(value))
	AudioServer.set_bus_mute(AudioManager.BUS.MASTER, value == 0)
	
func master_volume_store(value: float) -> void:
	config.set_value("Sounds", "master_volume", value)
	Settings.save_settings()

func music_volume_apply(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioManager.BUS.MUSIC, linear_to_db(value))
	AudioServer.set_bus_mute(AudioManager.BUS.MUSIC, value == 0)
	
func music_volume_store(value: float) -> void:
	config.set_value("Sounds", "music_volume", value)
	Settings.save_settings()

func ambience_volume_apply(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioManager.BUS.AMBIENCE, linear_to_db(value))
	AudioServer.set_bus_mute(AudioManager.BUS.AMBIENCE, value == 0)
	
func ambience_volume_store(value: float) -> void:
	config.set_value("Sounds", "ambience_volume", value)
	Settings.save_settings()

func sfx_volume_apply(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioManager.BUS.SFX, linear_to_db(value))
	AudioServer.set_bus_mute(AudioManager.BUS.SFX, value == 0)
	
func sfx_volume_store(value: float) -> void:
	config.set_value("Sounds", "sfx_volume", value)
	Settings.save_settings()

func ui_volume_apply(value: float) -> void:
	AudioServer.set_bus_volume_db(AudioManager.BUS.UI, linear_to_db(value))
	AudioServer.set_bus_mute(AudioManager.BUS.UI, value == 0)
	
func ui_volume_store(value: float) -> void:
	config.set_value("Sounds", "ui_volume", value)
	Settings.save_settings()
	
func bass_cut_apply(is_toggled_on : bool) -> void:
	AudioServer.set_bus_effect_enabled(AudioManager.BUS.MUSIC, 2, is_toggled_on)
	bass_cut_active = is_toggled_on
	
func bass_cut_store(is_toggled_on : bool) -> void:
	config.set_value("Sounds", "bass_cut", is_toggled_on)
	Settings.save_settings()
	
func bass_freq_apply(value : float) -> void:
	print("set bass freq value: ", value)
	var high_pass_filter : AudioEffectHighPassFilter = AudioServer.get_bus_effect(AudioManager.BUS.MUSIC, 2)
	high_pass_filter.cutoff_hz = value
	
func bass_freq_store(value : float) -> void:
	config.set_value("Sounds", "bass_freq", value)
	Settings.save_settings()
	
func audio_mono_apply(is_toggled_on : bool) -> void:
	AudioServer.set_bus_effect_enabled(AudioManager.BUS.MASTER, 1, is_toggled_on)
	audio_mono_active = is_toggled_on
	
func audio_mono_store(is_toggled_on : bool) -> void:
	config.set_value("Sounds", "audio_mono", is_toggled_on)
	Settings.save_settings()

func mouse_sensitivity_apply(value: float) -> void:
	mouse_sensitivity = value
	
func mouse_sensitivity_store(value: float) -> void:
	config.set_value("Controls", "mouse_sensitivity", value)
	Settings.save_settings()
