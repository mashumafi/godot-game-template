class_name SceneData
extends RefCounted

var path: String = ""
var params := {}


func _to_string() -> String:
	return path + " | params: " + str(params)
