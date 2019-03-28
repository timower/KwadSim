extends Panel

const PITCH = 0
const YAW = 1
const ROLL = 2

const P = 0
const I = 1
const D = 2

const RCrate = 0
const RCexpo = 1
const SUPERrate = 2

var pids = [
	[40, 45, 30],
	[65, 45, 0],
	[40, 45, 30]
]

var rates = [
	[1.0, 0.1, 0.70],
	[1.0, 0.1, 0.70],
	[1.0, 0.1, 0.70]
]

var cam_angle = 20.0
var distortion = 30.0
var fov = 120.0

onready var pidUI = [
	[$PitchContainer/P, $PitchContainer/I, $PitchContainer/D],
	[$YawContainer/P, $YawContainer/I, $YawContainer/D],
	[$RollContainer/P, $RollContainer/I, $RollContainer/D]
]

onready var rateUI = [
	[$PitchContainer/RCrate, $PitchContainer/RCexpo, $PitchContainer/SuperRate, $PitchContainer/Vel],
	[$YawContainer/RCrate, $YawContainer/RCexpo, $YawContainer/SuperRate, $YawContainer/Vel],
	[$RollContainer/RCrate, $RollContainer/RCexpo, $RollContainer/SuperRate, $RollContainer/Vel],
]

onready var graph = $RateGraph
onready var angleLabel = $CamAngle/Label
onready var distortionLabel = $Distortion/DistortionLabel
onready var fovLabel = $FOV/FOVLabel

onready var mainView = $"/root/Root/MainView"

const RC_RATE_INCREMENTAL = 14.54

func apply_rates(axis, rcCommandf):
	var rcCommandfAbs = abs(rcCommandf)
	var rcExpo = rates[axis][RCexpo]
	var rcRate = rates[axis][RCrate]
	var superRate = rates[axis][SUPERrate]
	
	if rcExpo != 0:
        rcCommandf = rcCommandf * pow(rcCommandfAbs, 3) * rcExpo + rcCommandf * (1 - rcExpo)

	if rcRate > 2.0:
		rcRate += RC_RATE_INCREMENTAL * (rcRate - 2.0)
    
	var angleRate = 200.0 * rcRate * rcCommandf
	if superRate != 0:
		var rcSuperfactor = 1.0 / clamp(1.0 - (rcCommandfAbs * superRate), 0.01, 1.00)
		angleRate *= rcSuperfactor

	return angleRate;

func _ready():
	load_config()
	for axis in range(3):
		for box in range(3):
			pidUI[axis][box].min_value = 0
			pidUI[axis][box].max_value = 255 # TODO: correct?
			pidUI[axis][box].value = pids[axis][box]
			pidUI[axis][box].connect("value_changed", self, "_pid_changed")
			
			rateUI[axis][box].min_value = 0
			rateUI[axis][box].max_value = 10
			rateUI[axis][box].step = 0.01
			rateUI[axis][box].value = rates[axis][box]
			rateUI[axis][box].connect("value_changed", self, "_rate_changed")
			
		rateUI[axis][3].text = str(int(apply_rates(axis, 1.0)))
	
func _pid_changed(_value):
	for axis in range(3):
		for box in range(3):
			pids[axis][box] = int(pidUI[axis][box].value)

func _rate_changed(_value):
	for axis in range(3):
		for box in range(3):
			rates[axis][box] = rateUI[axis][box].value
		rateUI[axis][3].text = str(int(apply_rates(axis, 1.0)))
	graph.update()

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
	mainView.get_material().set_shader_param("distortion", value / 100.0)
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
	for axis in range(3):
		for box in range(3):
			pids[axis][box] = file.get_16()
			rates[axis][box] = file.get_float()
	_on_CamAngle_value_changed(file.get_float())
	_on_Distortion_value_changed(file.get_float())
	_on_FOV_value_changed(file.get_float())
	file.close()

func save_config():
	var file = File.new()
	file.open(config_name, file.WRITE)
	for axis in range(3):
		for box in range(3):
			file.store_16(pids[axis][box])
			file.store_float(rates[axis][box])
	file.store_float(cam_angle)
	file.store_float(distortion)
	file.store_float(fov)
	file.close()