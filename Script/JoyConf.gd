extends Panel

const SAVE_PATH = "user://joy.conf"

var axisView = preload("res://Scenes/AxisView.tscn")

onready var joyListOpt = $OptionButton
onready var allAxis = $AllAxis

var selected_dev = -1

onready var throttle = $Throttle
onready var yaw = $Yaw
onready var pitch = $Pitch
onready var roll = $Roll

onready var axis = [
	throttle,
	pitch,
	yaw,
	roll
]

func list_joys():
	joyListOpt.clear()
	var idx = 0
	for joyPad in Input.get_connected_joypads():
		joyListOpt.add_item(Input.get_joy_name(joyPad), joyPad)
		
		if selected_dev == -1:
			selected_dev = joyPad
		elif selected_dev == joyPad:
			joyListOpt.select(idx)
			
		idx += 1

# Called when the node enters the scene tree for the first time.
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

func _process(delta):
	if Input.is_action_just_pressed("ui_cancel") and self.visible:
		self.visible = not self.visible
		get_tree().paused = self.visible
		saveConf()

	if self.visible:
		for i in range(JOY_AXIS_MAX):
			allAxis.get_child(i).get_node("ProgressBar").value = Input.get_joy_axis(selected_dev, i)

func joy_con_changed(devId, isConnected):
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
	throttle.saveConf(file)
	yaw.saveConf(file)
	pitch.saveConf(file)
	roll.saveConf(file)
	
	file.close()

func loadConf():
	var file = File.new()
	if not file.file_exists(SAVE_PATH):
		return
	file.open(SAVE_PATH, file.READ)
	
	selected_dev = file.get_var()
	
	throttle.loadConf(file)
	yaw.loadConf(file)
	pitch.loadConf(file)
	roll.loadConf(file)
	file.close()
	
	