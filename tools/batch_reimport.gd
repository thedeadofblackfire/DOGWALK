@tool
extends Node

@export_tool_button("Batch Reimport All", "Callable") var reimport_all_action = batch_reimport_all
@export_tool_button("Batch Reimport Animations", "Callable") var reimport_anims_action = batch_reimport_anims
@export_tool_button("Batch Reimport Props", "Callable") var reimport_props_action = batch_reimport_props
@export_tool_button("Batch Reimport Libs", "Callable") var reimport_libs_action = batch_reimport_libs
@export_tool_button("Batch Reimport Sets", "Callable") var reimport_sets_action = batch_reimport_sets
@export_tool_button("Batch Reimport Custom", "Callable") var reimport_custom_action = batch_reimport_custom

@export var CUSTOM_PATH : String = 'res://assets'

var file_paths : Array[String]

func batch_reimport(path = ''):
	var filesystem = EditorInterface.get_resource_filesystem()
	if not path:
		list_files_recursive(filesystem.get_filesystem())
	else:
		list_files_recursive(filesystem.get_filesystem_path(path))
		
	filesystem.reimport_files(file_paths)

func batch_reimport_all():
	batch_reimport()

func batch_reimport_anims():
	batch_reimport('res://animations')

func batch_reimport_props():
	batch_reimport('res://assets/props')

func batch_reimport_libs():
	batch_reimport('res://assets/libs')

func batch_reimport_sets():
	batch_reimport('res://assets/sets')

func batch_reimport_custom():
	batch_reimport(CUSTOM_PATH)

func list_files_recursive(dir: EditorFileSystemDirectory) -> void:
	var path = dir.get_path()
	for i in range(dir.get_file_count()):
		var file_name = dir.get_file(i)
		if file_name.get_extension() != 'gltf':
			continue
		file_paths.push_back(path+file_name)
		
	for i in range(dir.get_subdir_count()):
		list_files_recursive(dir.get_subdir(i))
