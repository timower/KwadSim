extends Panel

onready var joyConf = $"/root/Root/JoyConf"
onready var kwadConf = $"/root/Root/KwadConfig"

func _ready():
	get_tree().paused = self.visible

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel"):
		self.visible = not self.visible
		get_tree().paused = self.visible
		
func _on_ResumeButton_pressed():
	visible = false
	get_tree().paused = false


func _on_KConfigButton_pressed():
	kwadConf.visible = true
	self.visible = false

func _on_IConfigButton_pressed():
	joyConf.visible = true
	self.visible = false


func _on_SettingsButton_pressed():
	$"/root/Root/Settings".visible = true


func _on_QuitButton_pressed():
	get_tree().quit()


func _on_MenuButton_pressed():
	get_tree().change_scene("res://Scenes/menu.tscn")
