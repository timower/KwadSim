extends Node

var joyConf = null
var kwad = null

var s3d_width = 1280
var s3d_height = 720
var shadows = true

const selected_quad = "QQ190"

signal settings_changed

func _ready():
	pass


func update_settings():
	emit_signal("settings_changed")
