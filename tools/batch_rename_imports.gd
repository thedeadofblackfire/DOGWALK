@tool
extends Node

@export_tool_button("Batch Rename Imports", "Callable") var rename_action = batch_rename_imports

var TOGGLE = false


var file_paths : Array[String]
var idx = 0

func _process(delta: float) -> void:
	if TOGGLE:
		rename_file(file_paths[idx])
		idx += 1
		if idx >= file_paths.size():
			end_process()

func end_process():
	file_paths.clear()
	idx = 0
	TOGGLE = false

func batch_rename_imports():
	if TOGGLE: end_process()
	else:
		TOGGLE = true
		var filesystem = EditorInterface.get_resource_filesystem()
		
		list_files_recursive(filesystem.get_filesystem())

func list_files_recursive(dir: EditorFileSystemDirectory) -> void:
	var path = dir.get_path()
	for i in range(dir.get_file_count()):
		var file_name = dir.get_file(i)
		if file_name.get_extension() != 'tscn':
			continue
		if not FileAccess.file_exists(path+file_name.get_basename()+'.gltf'):
			continue
		file_paths.push_back(path+file_name)
		
	for i in range(dir.get_subdir_count()):
		list_files_recursive(dir.get_subdir(i))
	
func rename_file(filepath):
	print('Rename gltf node at '+filepath)
	var scene = ResourceLoader.load(filepath)
	var root_node = scene.instantiate()
	var gltf_node = null
	for child in root_node.get_children():
		if child.is_class('Node3D') and child.name == root_node.name:
			gltf_node = child
			break
	if not gltf_node:
		return
	if gltf_node.name.ends_with('-IMPORT'):
		return
	gltf_node.name = root_node.name+'-IMPORT'
	print('RENAMED '+str(gltf_node.name))
	scene.pack(root_node)
	ResourceSaver.save(scene, filepath)
