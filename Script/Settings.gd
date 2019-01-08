extends Panel

const SETTINGS_FILE = "user://settings.conf"

onready var s3d_width = $TabContainer/Graphics/GContainer/Resolution/Width
onready var s3d_height = $TabContainer/Graphics/GContainer/Resolution/Height

onready var s2d_enabled = $"TabContainer/Graphics/GContainer/2DResolution/CheckBox"
onready var s2d_width = $"TabContainer/Graphics/GContainer/2DResolution/Width"
onready var s2d_height = $"TabContainer/Graphics/GContainer/2DResolution/Height"

onready var fullscreen = $TabContainer/Graphics/GContainer/Fullscreen/Check
onready var vsync = $"TabContainer/Graphics/GContainer/V-Sync/Check"
onready var shadows =  $TabContainer/Graphics/GContainer/Shadows/Check

onready var sfx_volume = $"TabContainer/Sound/VBoxContainer/SFX volume/HSlider"

onready var key_tree = $TabContainer/Keyboard/Tree

var keys = [
	["reset", "Reset Quad", 82],
	["kwad_config", "Open Kwad Config", 75],
]

var tree_item_map = {}

func load_settings():
	var file = File.new()
	
	if not file.file_exists(SETTINGS_FILE):
		var size = OS.get_screen_size()
		
		s3d_width.value = size.x #Globals.s3d_width
		s3d_height.value = size.y #Globals.s3d_height
		
		s2d_width.value = size.x #get_viewport_rect().size.x
		s2d_height.value = size.y #get_viewport_rect().size.y
		show_keys()
		return

	file.open(SETTINGS_FILE, file.READ)
	var contents = parse_json(file.get_as_text())
	
	fullscreen.pressed = contents["fullscreen"]
	
	s3d_width.value = contents["s3d_width"]
	s3d_height.value = contents["s3d_height"]
	
	s2d_enabled.pressed = contents["s2d_enabled"]
	_on_CheckBox_toggled(s2d_enabled.pressed)
	s2d_width.value = contents["s2d_width"]
	s2d_height.value = contents["s2d_height"]
	
	vsync.pressed = contents["vsync"]
	shadows.pressed = contents["shadows"]
	
	sfx_volume.value = contents["sfx_volume"]
	
	keys = contents["keys"]
	file.close()
	
	show_keys()
	
func save_settings():
	var file = File.new()
	file.open(SETTINGS_FILE, file.WRITE)
	var contents = {
		"fullscreen": fullscreen.pressed,
		"s3d_width": s3d_width.value,
		"s3d_height": s3d_height.value,
		"s2d_enabled": s2d_enabled.pressed,
		"s2d_width": s2d_width.value,
		"s2d_height": s2d_height.value,
		"vsync": vsync.pressed,
		"shadows": shadows.pressed,
		"sfx_volume": sfx_volume.value
	}
	
	contents["keys"] = keys
	file.store_string(to_json(contents))
	file.close()
	
func apply_settings():
	OS.window_fullscreen = fullscreen.pressed
	Globals.s3d_width = s3d_width.value
	Globals.s3d_height = s3d_height.value
	Globals.shadows = shadows.pressed
	
	var size = Vector2(ProjectSettings.get_setting("display/window/size/width"), ProjectSettings.get_setting("display/window/size/height"))
	var mode = SceneTree.STRETCH_MODE_2D
	if s2d_enabled.pressed:
		mode = SceneTree.STRETCH_MODE_VIEWPORT
		size = Vector2(s2d_width.value, s2d_height.value)
		if not fullscreen.pressed:
			OS.window_size = size
	
	get_tree().set_screen_stretch(mode, SceneTree.STRETCH_ASPECT_KEEP, size)

	OS.vsync_enabled = vsync.pressed
	
	for key in keys:
		InputMap.get_action_list(key[0])[0].scancode = key[2]
	
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear2db(sfx_volume.value / 100.0))
	
	Globals.update_settings()

func show_keys():
	key_tree.clear()
	var root = key_tree.create_item()
	key_tree.hide_root = true

	for key in keys:
		var item = key_tree.create_item(root)
		item.set_text(0, key[1])
		
		var code =  key[2]
		item.set_text(1, OS.get_scancode_string(code))
		
		tree_item_map[item] = key

func _ready():
	load_settings()
	apply_settings()

func _process(delta):
	pass

func _on_ApplyButton_pressed():
	apply_settings()
	save_settings()

func _on_CloseButton_pressed():
	load_settings()
	visible = false

func _on_CheckBox_toggled(button_pressed):
	s2d_width.editable = button_pressed
	s2d_height.editable = button_pressed

var popup_key = null

func _on_Tree_item_activated():
	var item = key_tree.get_selected()
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
	show_keys()