# Scenes manager.
# When the loading of a new scene is completed, it calls
# two methods on the new loaded scene (if they are defined):
# 1. `pre_start(params)`: called as soon as the scene is loaded in memory.
#   It passes the `params` object received by
#   `Game.change_scene(new_scene, params)`.
# 2. `start()`: called when the scene transition is finished and when the
#  gameplay input is unlocked
extends Node

signal change_started
signal change_finished

var _params := {} # params caching
var _loading_start_time := 0

@onready var _history := preload("res://addons/ggt-core/scenes/scenes-history.gd").new()
@onready var _loader_mt := preload("res://addons/ggt-core/utils/resource_async_loader.gd").new()
var config := preload("res://addons/ggt-core/config.tres")


func _ready():
	add_child(_loader_mt)
	_loader_mt.resource_stage_loaded.connect(Transitions._on_resource_stage_loaded)
	change_started.connect(_on_change_started)
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cur_scene: Node = get_tree().current_scene
	_history.add(cur_scene.scene_file_path, {})
	# if playing a specific scene
	if ProjectSettings.get("application/run/main_scene") != cur_scene.scene_file_path:
		# call pre_start and start method to ensure compatibility with "Play Scene"
		if cur_scene.has_method("pre_start"):
			cur_scene.pre_start({})
		if cur_scene.has_method("start"):
			cur_scene.start()


func get_last_loaded_scene_data() -> SceneData:
	return _history.get_last_loaded_scene_data()


func _set_new_scene(resource: PackedScene):
	var current_scene := get_tree().current_scene
	current_scene.queue_free()
	await current_scene.tree_exited  # wait for the current scene to be fully removed
	var instanced_scn: Node = resource.instantiate()  # triggers _init
	get_tree().root.add_child(instanced_scn)  # triggers _ready
	get_tree().current_scene = instanced_scn
	if instanced_scn.has_method("pre_start"):
		await instanced_scn.pre_start(_params)
	Transitions.fade_out()
	await Transitions.anim.animation_finished
	if instanced_scn.has_method("start"):
		instanced_scn.start()
	change_finished.emit()
	_params = {}
	_loading_start_time = 0


func _transition_appear(params: Dictionary):
	Transitions.fade_in(params)


# Multithread interactive loading
func change_scene_multithread(new_scene: String, params := {}):
	change_started.emit(new_scene, params)
	_params = params
	_loading_start_time = Time.get_ticks_msec()
	_transition_appear(params)
	_loader_mt.resource_loaded.connect(_on_resource_loaded, CONNECT_ONE_SHOT)
	await Transitions.transition_covered_screen
	_loader_mt.load_resource(new_scene)


func _on_change_started(new_scene: String, params: Dictionary):
	_history.add(new_scene, params)


func _on_resource_loaded(resource: PackedScene):
	if Transitions.is_transition_in_playing():
		await Transitions.anim.animation_finished
	var load_time := Time.get_ticks_msec() - _loading_start_time  # ms
	print(
		"{scn} loaded in {elapsed}ms".format({"scn": resource.resource_path, "elapsed": load_time})
	)
	# artificially wait some time in order to have a gentle scene transition
	if load_time < config.transitions_minimum_duration_ms:
		await get_tree().create_timer((config.transitions_minimum_duration_ms - load_time) / 1000.0).timeout
	_set_new_scene(resource)
