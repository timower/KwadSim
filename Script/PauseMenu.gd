extends Control

onready var kwad_conf = $KwadConfig
onready var pause_menu = $PauseMenu

func _ready():
	get_tree().paused = pause_menu.visible

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		pause_menu.visible = not pause_menu.visible
		get_tree().paused = pause_menu.visible
		
func _on_ResumeButton_pressed():
	visible = false
	get_tree().paused = false


func _on_KConfigButton_pressed():
	kwad_conf.visible = true
	pause_menu.visible = false


func _on_SettingsButton_pressed():
	Settings.show()


func _on_QuitButton_pressed():
	get_tree().quit()


func _on_MenuButton_pressed():
	get_tree().paused = false
	get_tree().change_scene("res://Scenes/Menu.tscn")
