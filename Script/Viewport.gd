extends Viewport

onready var main_view = $"/root/Root/MainView"

var main_shader = preload("res://Shaders/main.tres")
#var vr_shader = preload("res://Shaders/vr.tres")

func _ready():
	settings_changed()
	Globals.connect("settings_changed", self, "settings_changed")

func settings_changed():
	self.size = Vector2(Globals.s3d_width, Globals.s3d_height)
	var aspect = size.x / size.y
	main_shader.set_shader_param("aspect", aspect)
	main_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED


func _on_Button_pressed():
	$"/root/Root/PauseMenu".visible = true
	get_tree().paused = true
