extends Panel

const SAVE_PATH = "user://joy.conf"

var axisView = preload("res://Nodes/AxisView.tscn")

onready var joyListOpt = $OptionButton
onready var allAxis = $AllAxis

var selected_dev = -1

#warning-ignore:unused_class_variable
onready var throttle = $Throttle
#warning-ignore:unused_class_variable
onready var yaw = $Yaw
#warning-ignore:unused_class_variable
onready var pitch = $Pitch
#warning-ignore:unused_class_variable
onready var roll = $Roll

#warning-ignore:unused_class_variable
onready var aux1 = $Aux1
#warning-ignore:unused_class_variable
onready var aux2 = $Aux2
#warning-ignore:unused_class_variable
onready var aux3 = $Aux3
#warning-ignore:unused_class_variable
onready var aux4 = $Aux4

#warning-ignore:unused_class_variable
onready var axes = [
	throttle,
	pitch,
	yaw,
	roll,
	aux1,
	aux2,
	aux3,
	aux4
]

func list_joys():
	joyListOpt.clear()
	var idx = 0
	var seen_selected = false
	for joyPad in Input.get_connected_joypads():
		joyListOpt.add_item(Input.get_joy_name(joyPad), joyPad)
		
		if selected_dev == -1:
			selected_dev = joyPad
			seen_selected = true
		elif selected_dev == joyPad:
			joyListOpt.select(idx)
			seen_selected = true
			
		idx += 1
	if not seen_selected:
		selected_dev = 0
		if joyListOpt.get_item_count() > 0:
			joyListOpt.select(0)

func _ready():
	for i in range(JOY_AXIS_MAX):
		var a = axisView.instance()
		a.get_node("Label").text = "axis " + str(i) + ":"
		allAxis.add_child(a)
		
	Input.connect("joy_connection_changed", self, "joy_con_changed")
	joyListOpt.connect("item_selected", self, "joy_changed")
	get_tree().paused = self.visible
	loadConf()
	list_joys()
	Globals.joyConf = self
	
func _exit_tree():
	Globals.joyConf = null

func _input(event):
	if event is InputEventJoypadMotion and event.device == selected_dev:
		Globals.new_rc_input([roll.value, pitch.value, throttle.value, yaw.value,
							  aux1.value, aux2.value, aux3.value, aux4.value])

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel") and self.visible:
		self.visible = not self.visible
		get_tree().paused = self.visible
		saveConf()
		
	if self.visible:
		for i in range(JOY_AXIS_MAX):
			allAxis.get_child(i).get_node("ProgressBar").value = Input.get_joy_axis(selected_dev, i)

func joy_con_changed(_devId, _isConnected):
	list_joys()

func joy_changed(devId):
	selected_dev = devId

func _on_CloseButton_pressed():
	self.visible = false
	get_tree().paused = false
	saveConf()

func saveConf():
	var file = File.new()
	file.open(SAVE_PATH, file.WRITE)
	
	file.store_var(selected_dev)
	
	for axis in axes:
		axis.saveConf(file)
	
	file.close()

func loadConf():
	var file = File.new()
	if not file.file_exists(SAVE_PATH):
		return
	file.open(SAVE_PATH, file.READ)
	
	selected_dev = file.get_var()
	
	for axis in axes:
		axis.loadConf(file)
		
	file.close()
	
	