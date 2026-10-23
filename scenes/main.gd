extends Node2D

const ConfigLib := preload("res://src/core/config.gd")

var config: RefCounted


func _ready() -> void:
	var loaded: Dictionary = ConfigLib.load_project()
	if not loaded["ok"]:
		var message := "CONFIG ERROR: %s" % str(loaded["error"])
		printerr(message)
		push_error(message)
		get_tree().quit(1)
		return
	config = loaded["config"]
