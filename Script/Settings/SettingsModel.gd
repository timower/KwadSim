extends Node

signal settings_changed

var settings_view = preload("res://Nodes/Settings/SettingsView.tscn")

# TODO: do we need this?
#var limits = {
#	"3D resolution": {"width": OS.get_screen_size().x, "height": OS.get_screen_size().y},
#	"2D resolution": {"width": OS.get_screen_size().x, "height": OS.get_screen_size().y},
#}

var settings = {
	graphics = {
		resolution_3D = {
			width = 1280,
			height = 720
		},
		resolution_2D = {
			enabled = false,
			width = 1280,
			height = 720
		},
		fullscreen = true,
		v_sync = true,
		shadows = true
	},
	sound = {
		volume = 25
	},
	gamepad = [
		# name    gamepad  axis min max
		["roll",     0,     0,  -1,  1],
		["pitch",    0,     0,  -1,  1],
		["throttle", 0,     0,  -1,  1],
		["yaw",      0,     0,  -1,  1],
		["axis 5",   0,     0,  -1,  1],
		["axis 6",   0,     0,  -1,  1],
		["axis 7",   0,     0,  -1,  1],
		["axis 8",   0,     0,  -1,  1],
	],
	keys= [
		# Description        id          scancode
		["Reset Quad",       "reset",       82],
		["Open Kwad Config", "kwad_config", 75],
	]
}

func get_path():
	return "user://settings.conf"

func _ready():
	read()
	apply()

func apply():
	OS.window_fullscreen = settings.graphics.fullscreen
	OS.vsync_enabled = settings.graphics.v_sync
	
	var mode = SceneTree.STRETCH_MODE_2D
	var size = Vector2(
		ProjectSettings.get_setting("display/window/size/width"), 
		ProjectSettings.get_setting("display/window/size/height")
	)
	
	if settings.graphics.resolution_2D.enabled:
		mode = SceneTree.STRETCH_MODE_VIEWPORT
		size.x = settings.graphics.resolution_2D.width
		size.y = settings.graphics.resolution_2D.height
		if not settings.graphics.fullscreen:
			OS.window_size = size
	
	get_tree().set_screen_stretch(mode, SceneTree.STRETCH_ASPECT_EXPAND, size)

	
	for key in settings.keys:
		InputMap.get_action_list(key[1])[0].scancode = key[2]
	
	var vol = linear2db(settings.sound.volume / 100.0)
	AudioServer.set_bus_volume_db(0, vol)

	emit_signal("settings_changed")

func read():
	var file = File.new()
	
	if not file.file_exists(get_path()):
		Log.d("Creating new settings file at {}", get_path())
		
		var size = OS.get_screen_size()
		
		settings.graphics.resolution_3D.width = size.x
		settings.graphics.resolution_3D.height = size.y
		
		settings.graphics.resolution_2D.width = size.x
		settings.graphics.resolution_2D.height= size.y
		
		return

	file.open(get_path(), file.READ)
	settings = file.get_var()
	file.close()
	Log.d("read settings: {}", settings)

func save():
	var file = File.new()
	file.open(get_path(), file.WRITE)
	file.store_var(settings)
	file.close()

func show():
	var view = settings_view.instance()
	get_tree().get_root().add_child(view)

func hide():
	var view = get_tree().get_root().get_node("SettingsView")
	if view == null:
		return
	get_tree().get_root().remove_child(view)
	view.queue_free()

func get_axis(axis):
	var min_val = settings.gamepad[axis][3]
	var max_val = settings.gamepad[axis][4]
	var vrange = max_val - min_val
	
	var v = Input.get_joy_axis(
		settings.gamepad[axis][1], settings.gamepad[axis][2])
	
	v = 2 * (v - min_val) / vrange - 1
	v = clamp(v, -1.0, 1.0)
	return v
