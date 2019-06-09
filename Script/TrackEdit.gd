extends Spatial

onready var track_label = $UI/LoadPanel/LoadContainer/TrackName
onready var tool_option = $UI/ToolPanel/ToolContainer/OptionButton
onready var tool_opt_cont = $UI/ToolPanel/ToolContainer

onready var scene_opt = $UI/LoadPanel/LoadContainer/SceneOption

onready var track_list = $UI/LoadDialog/TrackList

onready var track_tree = $UI/TreePanel/TrackTree

var selected_tool = 0
var selected_object = null

var tracks = null
var track_name = null

var changed = false

var close_action = null

var gates_item = null

var action_stack = []
var redo_stack = []

var tools = [
	TrackTools.GateTool,
	TrackTools.ObjectTool,
	TrackTools.MoveTool,
	TrackTools.RotateTool,
	TrackTools.ObjectPaintTool
]


func select_tool(idx):
	tools[selected_tool].deselected()
	tool_opt_cont.get_child(selected_tool + 1).visible = false
	
	tool_option.select(idx)
	selected_tool = idx
	
	tool_opt_cont.get_child(idx + 1).visible = true
	tools[idx].selected()

func _ready():
	for i in range(tools.size()):
		tools[i] = tools[i].new(self, tool_opt_cont.get_child(i + 1))
		tool_option.add_item(tools[i].name)
	select_tool(0)
	$UI/LoadDialog.popup_exclusive = true
	$UI/LoadDialog.popup()
	
	for i in range(Globals.SCENES.size()):
		scene_opt.add_item(Globals.SCENES[i].name)
	
	$Track.connect("track_changed", self, "on_track_changed")

func _process(delta):
	if Input.is_action_just_pressed("undo"):
		undo_action()
	if Input.is_action_just_pressed("redo"):
		redo_action()

func set_track_name(new_name):
	track_name = new_name
	track_label.text = new_name

	
func on_track_changed(objects_changed: bool):
	if objects_changed:
		track_tree.clear()
		var root = track_tree.create_item()
		gates_item = track_tree.create_item(root)
		gates_item.set_text(0, "Gates")
		var objects_item = track_tree.create_item(root)
		objects_item.set_text(0, "Objects")
		
		for ref in $Track.objects.size():
			var obj = $Track.objects[ref]
			var name = Globals.OBJECTS[obj.id]["name"]
			if not $Track.is_ref_gate(ref):
				var obj_item = track_tree.create_item(objects_item)
				obj_item.set_text(0, name)
				obj_item.set_metadata(0, ref)
		
		for idx in $Track.gates.size():
			var ref = $Track.get_gate_ref(idx)
			var name = Globals.OBJECTS[$Track.objects[ref].id]["name"] + " id:" + str(ref)
			var gate_item = track_tree.create_item(gates_item)
			gate_item.set_text(0, name)
			gate_item.set_metadata(0, idx)
	
	if selected_object != null and selected_object < $Track.objects.size():
		select_object(selected_object)
	else:
		deselect_object()

func select_object(ref: int):
	if $Track.is_ref_gate(ref):
		$Track.light_object(ref)
	else:
		pass # TODO: move light 
	selected_object = ref
	tools[selected_tool].object_selected(ref)

func deselect_object():
	selected_object = null
	tools[selected_tool].object_deselected()

#func select_gate(idx):
#	$Track.light_gate(idx)
#	selected_object = $Track.get_gate_ref(idx)
#	tools[selected_tool].gate_selected(idx)

func do_action(action: Object):
	action.do($Track)
	if action_stack.empty() or not action.combine(action_stack.back()):
		action_stack.append(action)
	redo_stack.clear()
	changed = true
	
	
func undo_action():
	if action_stack.empty():
		return

	var action = action_stack.pop_back()
	action.undo($Track)
	redo_stack.append(action)
	changed = true
	
func redo_action():
	if redo_stack.empty():
		return
		
	var action = redo_stack.pop_back()
	action.do($Track)
	action_stack.append(action)
	changed = true
	
func get_track_tree_selected_ref() -> int:
	var item = track_tree.get_selected()
	if item.get_parent() == gates_item:
		var idx = item.get_metadata(0)
		return $Track.get_gate_ref(idx)
	else:
		return item.get_metadata(0)

func show_load_menu():
	$UI/LoadDialog.popup_exclusive = false
	$UI/LoadDialog.popup()

func exit():
	get_tree().change_scene("res://Scenes/menu.tscn")

func exit_fly():
	Globals.selected_track = track_name
	get_tree().change_scene("res://Scenes/fly.tscn")

###############
# UI Signals: #
###############

func _on_OptionButton_item_selected(ID):
	select_tool(ID)
	

func _on_LoadDialog_about_to_show():
	track_list.clear()
	tracks = Globals.get_tracks()

	for track in tracks:
		track_list.add_item(track)
		
func _on_TrackList_item_activated(index):
	changed = false
	var t_name = track_list.get_item_text(index)
	
	if $Track.load_from(t_name):
		scene_opt.select($Track.scene_id)
		set_track_name(t_name)
		$UI/LoadDialog.hide()

func _on_NewButton_pressed():
	var t_name = $UI/LoadDialog/NewTrackName.text
	
	if t_name == "" or (tracks != null and tracks.has(t_name)):
		return
	
	changed = true
	set_track_name(t_name)
	$Track.new_track()
	scene_opt.select(0)
	$UI/LoadDialog.hide()

func _on_TrackList_item_rmb_selected(_index, at_position):
	var rect = Rect2(track_list.get_global_rect().position + at_position, Vector2(10, 10))
	$UI/LoadDialog/PopupMenu.popup(rect)

func _on_PopupMenu_index_pressed(index):
	if index == 0:
		# Delete:
		var selected_track_idx = track_list.get_selected_items()[0]
		var selected_track_name = track_list.get_item_text(selected_track_idx)
		var dir = Directory.new()
		dir.remove(Globals.TRACK_PATH + selected_track_name + ".track")
		_on_LoadDialog_about_to_show()

func _on_LoadButton_pressed():
	if changed:
		close_action = funcref(self, "show_load_menu")
		$UI/ConfirmSaveDialog.popup()
		return
	show_load_menu()

func _on_SaveButton_pressed():
	set_track_name(track_label.text)
	if track_name == "":
		return
	$Track.save_to(track_name)
	changed = false

func _on_FlyButton_pressed():
	if changed:
		close_action = funcref(self, "exit_fly")
		$UI/ConfirmSaveDialog.popup()
		return
	exit_fly()

func _on_ExitButton_pressed():
	if changed:
		close_action = funcref(self, "exit")
		$UI/ConfirmSaveDialog.popup()
		return
	exit()


func _on_TrackTree_item_selected():
	if track_tree.get_selected().get_parent() == track_tree.get_root():
		return
	var ref = get_track_tree_selected_ref()
	select_object(ref)

func _on_TrackTree_item_activated():
	if track_tree.get_selected().get_parent() == track_tree.get_root():
		return
	var ref = get_track_tree_selected_ref()
	$CamPos.global_transform.origin = $Track.objects[ref].pos

func _on_TrackTree_item_rmb_selected(position):
	if track_tree.get_selected().get_parent() == track_tree.get_root():
		return
	# TODO: hide up/down when non gate is selected
	var pop_rect = Rect2(track_tree.rect_global_position + position, Vector2(10, 10))
	$UI/TreePanel/TrackTree/PopupMenu2.popup(pop_rect)


func _on_PopupMenu2_index_pressed(index):
	var item = track_tree.get_selected()
	var idx = null
	var ref = 0
	if item.get_parent() == gates_item:
		idx = item.get_metadata(0)
		ref = $Track.get_gate_ref(idx)
	else:
		ref = item.get_metadata(0)
	changed = true
	if index == 0 and idx != null and idx > 0:
		# up
		$Track.swap_gate(idx, idx - 1)
		select_object($Track.get_gate_ref(idx-1))
	elif index == 1 and idx != null and idx < $Track.gates.size() - 1:
		# down
		$Track.swap_gate(idx, idx + 1)
		select_object($Track.get_gate_ref(idx+1))
	elif index == 2:
		# Delete
		$Track.remove_object(ref)


func _on_TrackName_text_changed(_new_text):
	changed = true

func _on_CancelButton_pressed():
	$UI/ConfirmSaveDialog.hide()

func _on_CloseButton_pressed():
	close_action.call_func()
	$UI/ConfirmSaveDialog.hide()
	
func _on_CloseSaveButton_pressed():
	_on_SaveButton_pressed()
	close_action.call_func()
	$UI/ConfirmSaveDialog.hide()
	
func _unhandled_input(event):
	tools[selected_tool].input(event)


func _on_SceneOption_item_selected(ID):
	$Track.load_scene(ID)
