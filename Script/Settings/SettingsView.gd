extends Control

onready var control_root = $Panel/TabContainer
onready var key_popup = $Panel/KeyPopup

onready var key_tree = $Panel/TabContainer/keys/tree
onready var gamepad_tree = $Panel/TabContainer/gamepad/tree

onready var stick_view = $Panel/TabContainer/gamepad/StickView

onready var key_popup_title = $Panel/KeyPopup/TitleLabel
onready var key_popup_value = $Panel/KeyPopup/ValueLabel

onready var calibrate_popup = $Panel/CalibratePopup
onready var calibrate_label = $Panel/CalibratePopup/Label
onready var calibrate_button = $Panel/CalibratePopup/NextCalibrateButton
onready var calibrate_stick_view = $Panel/CalibratePopup/StickView

var selected_key = null
var selected_axis = null
var key_popup_temp = [0, 0, 0]

var init_axis_vals = {}

enum CalibrateState {
	NONE,
	MIN,
	MAX
}

var calibrate_state = CalibrateState.NONE
var calibrate_values = [0.0, 0.0, 0.0, 0.0]

func get_text_val(control_name, val_array):
	match control_name:
		"keys":
			return OS.get_scancode_string(val_array[2])
		"gamepad":
			return Input.get_joy_name(val_array[1]) + ": axis " + str(val_array[2])

func show_values(sub_settings, sub_control):
	if sub_control == null:
		Log.e("missing setting control")
		return

	match typeof(sub_settings):
		TYPE_DICTIONARY:
			for key in sub_settings:
				show_values(sub_settings[key], sub_control.get_node(key))
		TYPE_INT, TYPE_REAL:
			sub_control.value = sub_settings
		TYPE_BOOL:
			sub_control.pressed = sub_settings
		TYPE_ARRAY:
			var tree = sub_control.get_node("tree")
			tree.hide_root = true
			tree.clear()

			var root = tree.create_item()
			root.set_text(0, sub_control.name)

			for val in sub_settings:
				var item = tree.create_item(root)
				item.set_metadata(0, val.duplicate())

				item.set_text(0, val[0])
				item.set_text(1, get_text_val(sub_control.name, val))
		var _x:
			Log.e("unknown subsetting type: {}", _x)

func apply_values(sub_control, sub_settings):
	# TODO: rewrite using return value instead of passing "ref"
	for setting in sub_settings:
		var val = sub_settings[setting]
		match typeof(val):
			TYPE_DICTIONARY:
				apply_values(sub_control.get_node(setting), val)
			TYPE_INT, TYPE_REAL:
				sub_settings[setting] = sub_control.get_node(setting).value
			TYPE_BOOL:
				sub_settings[setting] = sub_control.get_node(setting).pressed
			TYPE_ARRAY:
				var tree = sub_control.get_node(setting).get_node("tree")
				var root = tree.get_root()
				var item = root.get_children()
				for i in range(len(val)):
					val[i] = item.get_metadata(0)
					item = item.get_next()
			var _x:
				Log.e("unknown apply subsetting type: {}", _x)

func _ready():
	stick_view.axis_provider = self
	calibrate_stick_view.axis_provider = self
	show_values(Settings.settings, control_root)

func _process(_delta):
	if Input.is_action_just_pressed("ui_cancel"):
		Settings.save()
		Settings.hide()

func _unhandled_input(event):
	if event is InputEventKey and selected_key != null:
		key_popup_temp[2] = event.scancode
		key_popup_value.text = get_text_val("keys", key_popup_temp)
	elif event is InputEventJoypadMotion:
		if selected_axis != null:
			if not (event.device in init_axis_vals):
				init_axis_vals[event.device] = {}
			if not (event.axis in init_axis_vals[event.device]):
				init_axis_vals[event.device][event.axis] = event.axis_value
			else:
				var diff = abs(init_axis_vals[event.device][event.axis] - event.axis_value)
				if diff > 0.3:
					init_axis_vals[event.device][event.axis] = event.axis_value
					key_popup_temp[1] = event.device
					key_popup_temp[2] = event.axis
					key_popup_value.text = get_text_val("gamepad", key_popup_temp)
					
		if calibrate_state != CalibrateState.NONE:
			update_calibrate_value()
				

func _on_ApplyButton_pressed():
	apply_values(control_root, Settings.settings)
	Settings.apply()

func _on_CloseButton_pressed():
	Settings.save()
	Settings.hide()

func _on_RevertButton_pressed():
	Settings.read()
	show_values(Settings.settings, control_root)
	Settings.apply()

func _on_keys_item_activated():
	selected_key = key_tree.get_selected()
	key_popup_title.text = "Press a key"
	key_popup.popup()

func _on_KeyPopupCancel_pressed():
	key_popup.hide()

func _on_KeyPopup_popup_hide():
	selected_key = null
	selected_axis = null

func _on_gamepad_item_activated():
	init_axis_vals = {}
	selected_axis = gamepad_tree.get_selected()
	key_popup_title.text = "Move an axis"
	key_popup.popup()

func _on_KeyPopupOk_pressed():
	if selected_key != null:
		var val = selected_key.get_metadata(0)
		val[2] = key_popup_temp[2]
		selected_key.set_text(1,  get_text_val("keys", val))
		key_popup.hide()
	elif selected_axis != null:
		var val = selected_axis.get_metadata(0)
		val[1] = key_popup_temp[1]
		val[2] = key_popup_temp[2]
		selected_axis.set_text(1, get_text_val("gamepad", val))
		key_popup.hide()

func get_axis_metadata(axis):
	var root = gamepad_tree.get_root()
	var item = root.get_children()
	for _i in range(axis):
		item = item.get_next()
	return item.get_metadata(0)

func get_axis(axis):
	var axis_data = get_axis_metadata(axis)
	
	var min_val = axis_data[3]
	var max_val = axis_data[4]
	var vrange = max_val - min_val
	
	var v = Input.get_joy_axis(axis_data[1], axis_data[2])
	
	v = 2 * (v - min_val) / vrange - 1
	v = clamp(v, -1.0, 1.0)
	return v

func set_calibrate_label(state):
	calibrate_state = state
	match calibrate_state:
		CalibrateState.MIN:
			calibrate_label.text = "Move the sticks to their minimum value"
			calibrate_button.text = "Next"
		CalibrateState.MAX:
			calibrate_label.text = "Move the sticks to their maximum value"
			calibrate_button.text = "Done"

func update_calibrate_value():
	# calibrate_values
	for i in range(4):
		var val = calibrate_values[i]
		var cur = Settings.get_axis(i)
		if abs(cur) > abs(val):
			calibrate_values[i] = cur

func _on_CalibrateButton_pressed():
	set_calibrate_label(CalibrateState.MIN)
	for i in range(4):
		var axis_data = get_axis_metadata(i)
		axis_data[3] = -1
		axis_data[4] = 1
		calibrate_values[i] = 0
	calibrate_popup.popup()

func _on_NextCalibrateButton_pressed():
	match calibrate_state:
		CalibrateState.MIN:
			set_calibrate_label(CalibrateState.MAX)
			# set min for each axis
			for i in range(4):
				var axis_data = get_axis_metadata(i)
				axis_data[3] = calibrate_values[i]
				calibrate_values[i] = 0

		CalibrateState.MAX:
			calibrate_popup.hide()
			set_calibrate_label(CalibrateState.NONE)
			# set max for each axis
			for i in range(4):
				var axis_data = get_axis_metadata(i)
				axis_data[4] = calibrate_values[i]


