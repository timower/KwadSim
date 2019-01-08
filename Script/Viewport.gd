extends Viewport

func _ready():
	settings_changed()
	Globals.connect("settings_changed", self, "settings_changed")

func settings_changed():
	self.size = Vector2(Globals.s3d_width, Globals.s3d_height)


func _on_Button_pressed():
	$"/root/Root/PauseMenu".visible = true
	get_tree().paused = true
