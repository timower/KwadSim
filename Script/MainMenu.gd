extends Control

func _ready():
	for quad in Globals.quads:
		$QuadSelectDialog/KwadList.add_item(quad)
	$QuadSelectDialog/KwadList.select(0)
	
	var tracks = Globals.get_tracks()
	for track in tracks:
		$QuadSelectDialog/TrackList.add_item(track[0], track[1])
	$QuadSelectDialog/TrackList.select(0)

func _on_FlyButton_pressed():
	$QuadSelectDialog.popup()

func _on_OkFlyButton_pressed():
	var selected = $QuadSelectDialog/KwadList.get_selected_items()[0]
	Globals.selected_quad = $QuadSelectDialog/KwadList.get_item_text(selected)
	selected = $QuadSelectDialog/TrackList.get_selected_items()[0]
	Globals.selected_track = $QuadSelectDialog/TrackList.get_item_text(selected)
	get_tree().change_scene("res://Scenes/Fly.tscn")


func _on_QuitButton_pressed():
	get_tree().quit()


func _on_TrackButton_pressed():
	get_tree().change_scene("res://Scenes/TrackEdit.tscn")
	#trackPopup.popup()


func _on_TextureButton_pressed():
	Settings.show()

# TODO: kwad editor
func _on_KwadButton_pressed():
	get_tree().change_scene("res://Scenes/KwadEdit.tscn")


