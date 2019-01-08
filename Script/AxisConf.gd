extends HBoxContainer

export(String) var axis_name = "axis n"

onready var joyConf = self.get_parent()
onready var axisSel = $AxisBox
onready var progress = $ProgressBar

var value = -1

var axis = 0

var min_val = -1
var max_val = 1

var has_moved = false

func _ready():
	$Label.text = axis_name
	for i in range(JOY_AXIS_MAX):
		axisSel.add_item("axis " + str(i), i)

func _process(delta):
	if joyConf.visible:
		axis = axisSel.get_selected_id()
		progress.value = value

#func _physics_process(delta):
func _input(event):
	if event is InputEventJoypadMotion and event.axis == axis:
		var val = Input.get_joy_axis(joyConf.selected_dev, axis)
		has_moved = has_moved or val != 0.0
		var vrange = max_val - min_val
		if vrange == 0:
			vrange = 1
		value = clamp(2 * (val - min_val) / vrange - 1, -1, 1)
	
func _on_MaxButton_pressed():
	max_val = Input.get_joy_axis(joyConf.selected_dev, axis)


func _on_MinButton_pressed():
	min_val = Input.get_joy_axis(joyConf.selected_dev, axis)


func _on_ResetButton_pressed():
	min_val = -1
	max_val = 1

func saveConf(file):
	file.store_var(axis)
	file.store_var(min_val)
	file.store_var(max_val)
	
func loadConf(file):
	axis = file.get_var()
	axisSel.select(axis)
	min_val = file.get_var()
	max_val = file.get_var()