extends Control

onready var joyConf = $"/root/Root/JoyConf"
onready var trackPopup = $"/root/Root/TrackDialog"
onready var settings = $"/root/Root/Settings"

func _ready():
	pass


func _on_FlyButton_pressed():
	get_tree().change_scene("res://Scenes/fly.tscn")


func _on_QuitButton_pressed():
	get_tree().quit()


func _on_InputButton_pressed():
	joyConf.visible = true


func _on_TrackButton_pressed():
	trackPopup.popup()


func _on_TextureButton_pressed():
	settings.visible = true
