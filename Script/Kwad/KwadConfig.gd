extends Control


var cam_angle = 20.0
var distortion = 30.0
var fov = 120.0


onready var angleLabel = $CamAngle/Label
onready var distortionLabel = $Distortion/DistortionLabel
onready var fovLabel = $FOV/FOVLabel

var main_shader = preload("res://Shaders/main.tres")


func _ready():
	load_config()
	

func _process(_delta):
	if (Input.is_action_just_pressed("ui_cancel") and self.visible) or (Input.is_action_just_pressed("kwad_config") and (self.visible or not get_tree().paused)):
		self.visible = not self.visible
		get_tree().paused = self.visible
		save_config()

func _on_CloseButton_pressed():
	self.visible = not self.visible
	get_tree().paused = self.visible
	save_config()
	

func _on_CamAngle_value_changed(value):
	var camera = Globals.kwad.get_node("Camera")
	cam_angle = value
	angleLabel.get_parent().value = value
	camera.transform.basis = Basis(Vector3(deg2rad(value), 0, 0))
	angleLabel.text = str(value) + "°"


func _on_Distortion_value_changed(value):
	distortion = value
	distortionLabel.get_parent().value = value
	main_shader.set_shader_param("distortion", value / 100.0)
	distortionLabel.text = str(value)


func _on_FOV_value_changed(value):
	var camera = Globals.kwad.get_node("Camera")
	fov = value
	fovLabel.get_parent().value = value
	camera.fov = value
	fovLabel.text = str(value) + "°"

const config_name = "user://quad.conf"
func load_config():
	var file = File.new()
	if not file.file_exists(config_name):
		_on_CamAngle_value_changed(cam_angle)
		_on_Distortion_value_changed(distortion)
		_on_FOV_value_changed(fov)
		return

	file.open(config_name, file.READ)
	_on_CamAngle_value_changed(file.get_float())
	_on_Distortion_value_changed(file.get_float())
	_on_FOV_value_changed(file.get_float())
	file.close()

func save_config():
	var file = File.new()
	file.open(config_name, file.WRITE)
	file.store_float(cam_angle)
	file.store_float(distortion)
	file.store_float(fov)
	file.close()