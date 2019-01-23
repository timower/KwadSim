extends Control

onready var trackPopup = $TrackDialog
onready var settings = $"/root/Root/Settings"

func _ready():
	for quad in Globals.quads:
		$QuadSelectDialog/KwadList.add_item(quad)
	$QuadSelectDialog/KwadList.select(0)
	
	var tracks = Globals.list_dir(Globals.TRACK_PATH)
	for track in tracks:
		$QuadSelectDialog/TrackList.add_item(track)
	$QuadSelectDialog/TrackList.select(0)

func _on_FlyButton_pressed():
	$QuadSelectDialog.popup()

func _on_OkFlyButton_pressed():
	var selected = $QuadSelectDialog/KwadList.get_selected_items()[0]
	Globals.selected_quad = $QuadSelectDialog/KwadList.get_item_text(selected)
	selected = $QuadSelectDialog/TrackList.get_selected_items()[0]
	Globals.selected_track = $QuadSelectDialog/TrackList.get_item_text(selected)
	get_tree().change_scene("res://Scenes/fly.tscn")


func _on_QuitButton_pressed():
	get_tree().quit()


func _on_InputButton_pressed():
	Globals.joyConf.visible = true


func _on_TrackButton_pressed():
	get_tree().change_scene("res://Scenes/TrackEdit.tscn")
	#trackPopup.popup()


func _on_TextureButton_pressed():
	settings.visible = true

# TODO: kwad editor
func _on_KwadButton_pressed():
	get_tree().change_scene("res://Scenes/KwadEdit.tscn")


