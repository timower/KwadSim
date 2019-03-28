extends Panel

const SETTINGS_FILE = "user://settings.conf"

var limits = {
	"3D resolution": {"width": OS.get_screen_size().x, "height": OS.get_screen_size().y},
	"2D resolution": {"width": OS.get_screen_size().x, "height": OS.get_screen_size().y},
}

var settings = {
	"3D resolution": {
		"width": 1280,
		"height": 720
	},
	"2D resolution": {
		"enabled": false,
		"width": 1280,
		"height": 720
	},
	"Graphics": {
		"Fullscreen": true,
		"V-Sync": true,
		"Shadows": true,
	},
	"Volume": 25,

	"Keys":  [
		["reset", "Reset Quad", 82],
		["kwad_config", "Open Kwad Config", 75],
	]
}

onready var settings_tree = $Tree

var tree_item_map = {}

func load_settings():
	var file = File.new()
	
	if not file.file_exists(SETTINGS_FILE):
		var size = OS.get_screen_size()
		
		settings["3D resolution"]["width"] = size.x
		settings["3D resolution"]["height"] = size.y
		
		settings["2D resolution"]["width"] = size.x
		settings["2D resolution"]["height"]= size.y
		
		show_settings()
		return

	file.open(SETTINGS_FILE, file.READ)
	settings = file.get_var()
	file.close()
	show_settings()
	
func save_settings():
	var file = File.new()
	file.open(SETTINGS_FILE, file.WRITE)
	file.store_var(settings)
	file.close()
	
func apply_settings():
	Globals.s3d_width = settings["3D resolution"]["width"]
	Globals.s3d_height = settings["3D resolution"]["height"]
	OS.window_fullscreen = settings["Graphics"]["Fullscreen"]
	Globals.shadows = settings["Graphics"]["Shadows"]
	OS.vsync_enabled = settings["Graphics"]["V-Sync"]
	
	var size = Vector2(ProjectSettings.get_setting("display/window/size/width"), ProjectSettings.get_setting("display/window/size/height"))
	var mode = SceneTree.STRETCH_MODE_2D
	if settings["2D resolution"]["enabled"]:
		mode = SceneTree.STRETCH_MODE_VIEWPORT
		size = Vector2(settings["2D resolution"]["width"], settings["2D resolution"]["height"])
		if not settings["Graphics"]["Fullscreen"]:
			OS.window_size = size
	
	get_tree().set_screen_stretch(mode, SceneTree.STRETCH_ASPECT_EXPAND, size)

	
	for key in settings["Keys"]:
		InputMap.get_action_list(key[0])[0].scancode = key[2]
	
	var vol = linear2db(settings["Volume"] / 100.0)
	AudioServer.set_bus_volume_db(0, vol)
	
	Globals.update_settings()

func show_setting(parent: TreeItem, set_name: String, map, limit):
	var setting = map[set_name]
	var item = settings_tree.create_item(parent)
	tree_item_map[item] = [map, set_name]
	
	item.set_text(0, set_name)
	item.set_editable(1, true)
	
	if setting is Dictionary:
		item.set_editable(1, false)
		var sub_limit = null
		if limit.has(set_name):
			sub_limit = limit[set_name]
		for sub in setting:
			show_setting(item, sub, setting, sub_limit)
	elif setting is int or setting is float:
		item.set_cell_mode(1, TreeItem.CELL_MODE_RANGE)
		if limit.has(set_name):
			item.set_range_config(1, 0, limit[set_name], 1)
		item.set_range(1, setting)
	elif setting is bool:
		item.set_cell_mode(1, TreeItem.CELL_MODE_CHECK)
		item.set_checked(1, setting)
	elif set_name == "Keys":
		item.set_editable(1, false)
		for key in setting:
			var key_item = settings_tree.create_item(item)
			key_item.set_text(0, key[1])
	
			var code =  key[2]
			key_item.set_text(1, OS.get_scancode_string(code))
	
			tree_item_map[key_item] = key
			

func show_settings():
	tree_item_map.clear()
	settings_tree.clear()
	
	var root = settings_tree.create_item()
	settings_tree.hide_root = true
	
	for set_name in settings:
		show_setting(root, set_name, settings, limits)


func _ready():
	load_settings()
	apply_settings()

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		load_settings()
		visible = false

func _on_ApplyButton_pressed():
	apply_settings()
	save_settings()

func _on_CloseButton_pressed():
	load_settings()
	visible = false
	get_tree().paused = false

var popup_key = null

func _on_Tree_item_activated():
	var item = settings_tree.get_selected()
	if item.get_parent().get_text(0) != "Keys":
		return
	var key = tree_item_map[item]
	popup_key = key
	$KeyPopup.popup()

func _unhandled_input(event):
	if popup_key == null:
		return
	if not event is InputEventKey:
		return

	popup_key[2] = event.scancode
	popup_key = null

	$KeyPopup.hide()
	show_settings()

func _on_Tree_item_edited():
	var item = settings_tree.get_selected()
	
	var s = tree_item_map[item]
	var map = s[0]
	var set_name = s[1]
	var setting = map[set_name]
	
	if set_name == "width":
		for res in ["3D resolution", "2D resolution"]:
			if map == settings[res]:
				var aspect = OS.window_size.x / OS.window_size.y
				var height = round(item.get_range(1) / aspect)
				settings[res]["height"] = height
				item.get_next().set_range(1, height)
			
	if setting is Dictionary:
		print("Shouldn't happend?")
	elif setting is int or setting is float:
		map[set_name] = item.get_range(1)
	elif setting is bool:
		map[set_name] = item.is_checked(1)
	