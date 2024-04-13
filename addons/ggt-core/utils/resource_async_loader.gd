extends Node

signal resource_loaded(res: Resource)
signal resource_stage_loaded(progress_percentage: float)
var _pending_resources := PackedStringArray()

func _ready() -> void:
	set_process(false)


func load_resource(path: String):
	if ResourceLoader.has_cached(path):
		return ResourceLoader.load(path)

	var status := ResourceLoader.load_threaded_request(path)
	if status != OK:
		push_error(status, "threaded resource failed")
		return

	_pending_resources.push_back(path)
	set_process(true)

func _process(delta: float) -> void:
	var pending := _pending_resources.duplicate()
	_pending_resources.clear()

	var progress_arr : Array[float] = [0.0]
	for path in pending:
		var loading_status := ResourceLoader.load_threaded_get_status(path, progress_arr)
		if loading_status == ResourceLoader.THREAD_LOAD_LOADED:
			call_deferred("emit_signal", "resource_stage_loaded", float(progress_arr[0]))
			call_deferred("emit_signal", "resource_loaded", ResourceLoader.load_threaded_get(path))
		elif loading_status == ResourceLoader.THREAD_LOAD_FAILED:
			push_error("Thread load failed for: {0}".format([path]))
		elif loading_status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Thread invalid resource: {0}".format([path]))
		else:
			call_deferred("emit_signal", "resource_stage_loaded", float(progress_arr[0]))
			_pending_resources.push_back(path)

	set_process(not _pending_resources.is_empty())
