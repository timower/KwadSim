extends Node

var s3d_width = 1280
var s3d_height = 720
var shadows = true

signal settings_changed

func _ready():
	pass

func update_settings():
	emit_signal("settings_changed")
