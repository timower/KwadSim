extends Control

const DEFAUlT_KWAD = {
	"motor": "rx2205",
	"frame": "QQ190",
	"prop": "GF5x46",
	"Vbat": 16.0,
	"weight": 0.6
}

onready var kwad_option = $InfoPanel/OptionButton
onready var frame_list = $FramePanel/ItemList
onready var motor_list = $MotorPanel/ItemList
onready var prop_list = $PropPanel/ItemList

func load_kwads():
	kwad_option.clear()
	for kwad in Globals.quads:
		kwad_option.add_item(kwad)


	
func load_frames():
	frame_list.clear()
	for frame in Globals.list_dir("res://Data/Frames"):
		frame_list.add_item(frame)

func load_motors():
	motor_list.clear()
	for motor in Globals.list_dir("res://Data/Motors"):
		motor_list.add_item(motor)

func load_props():
	prop_list.clear()
	for prop in Globals.list_dir("res://Data/Props"):
		prop_list.add_item(prop)

func _ready():
	get_tree().paused = true
	load_frames()
	load_motors()
	load_props()
	load_kwads()
	select_kwad(0)

func _process(delta):
	$View/Kwad.rotate_y(delta * PI / 6)

func _on_ExitButton_pressed():
	Globals.reload_quads()
	get_tree().change_scene("res://Scenes/menu.tscn")


func _on_NewButton_pressed():
	$NameDialog.popup()

func select_kwad(id):
	kwad_option.select(id)
	var name = kwad_option.get_item_text(id)
	

func _on_MakeNewButton_pressed():
	$NameDialog.hide()
	var name = $NameDialog/LineEdit.text
	Globals.quads[name] = DEFAUlT_KWAD
	var id = kwad_option.get_item_count()
	kwad_option.add_item(name)
	select_kwad(id)

func _on_OptionButton_item_selected(ID):
	select_kwad(ID)
