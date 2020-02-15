extends Control

onready var main_view = $MainView
onready var viewport = $Viewport

var main_shader = preload("res://Shaders/main.tres")
#var vr_shader = preload("res://Shaders/vr.tres")

func _ready():
	settings_changed()
	Settings.connect("settings_changed", self, "settings_changed")

func settings_changed():
	viewport.size = Vector2(
		Settings.settings.graphics.resolution_3D.width,
		Settings.settings.graphics.resolution_3D.height)
	var aspect = viewport.size.x / viewport.size.y
	main_shader.set_shader_param("aspect", aspect)

	#TextureRect.STRETCH_SCALE#
	main_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
