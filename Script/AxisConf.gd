extends HBoxContainer

export(String) var axis_name = "axis N"

onready var joyConf = get_parent()
onready var axisSel = $AxisBox
onready var progress = $ProgressBar

var value = 0

var axis = 0

var min_val = -1
var max_val = 1

var has_moved = false

func _ready():
	$Label.text = axis_name
	for i in range(JOY_AXIS_MAX):
		axisSel.add_item("axis " + str(i), i)

func _input(event):
	if event is InputEventJoypadMotion and event.axis == axis \
			and event.device == joyConf.selected_dev:
		has_moved = true

		var val = event.axis_value

		var vrange = max_val - min_val
		value = 2 * (val - min_val) / vrange - 1
		value = clamp(value, -1, 1)
		progress.value = value
	
func _on_MaxButton_pressed():
	max_val = Input.get_joy_axis(joyConf.selected_dev, axis)
	if max_val == min_val:
		max_val += 0.001


func _on_MinButton_pressed():
	min_val = Input.get_joy_axis(joyConf.selected_dev, axis)
	if min_val == max_val:
		min_val += 0.001


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

func _on_AxisBox_item_selected(ID):
	axis = ID
