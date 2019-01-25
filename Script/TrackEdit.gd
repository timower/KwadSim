extends Spatial

onready var track_label = $UI/LoadPanel/LoadContainer/Label
onready var tool_option = $UI/ToolPanel/ToolContainer/OptionButton
onready var tool_opt_cont = $UI/ToolPanel/ToolContainer

onready var track_list = $UI/LoadDialog/TrackList

onready var track_tree = $UI/TreePanel/TrackTree

var selected_tool = 0
var selected_gate = null

var tracks = null
var track_name = null

var changed = false

var close_action = null


class Tool:
	var name
	var root
	
	func _init(n, r):
		name = n
		root = r
		
	func selected():
		pass
	func deselected():
		pass
	func gate_selected(idx):
		pass

class GateTool extends Tool:
	var gate_list
	var cam_pos: Spatial
	var track
	
	func _init(root, container).("Place Gates", root):
		track = root.get_node("Track")
		gate_list = container.get_node("ItemList")
		cam_pos = root.get_node("CamPos")
		
		for gate in Globals.GATES:
			gate_list.add_item(gate.name)
		gate_list.connect("item_activated", self, "place_gate")
	
	func place_gate(idx):
		root.changed = true
		track.add_gate({
			pos = cam_pos.global_transform.origin, 
			rot = Vector3(), 
			id = idx
		})
		root.select_gate(track.gates.size() - 1)

class MoveTool extends Tool:
	var xpos
	var ypos
	var zpos
	
	var track
	var move_gizmo
	
	func _init(root, container).("Move", root):
		move_gizmo = root.get_node("MoveGizmo")
		move_gizmo.connect("pos_changed", self, "gizmo_pos_changed")
		
		xpos = container.get_node("XPos/SpinBox")
		ypos = container.get_node("YPos/SpinBox")
		zpos = container.get_node("ZPos/SpinBox")
		
		track = root.get_node("Track")
		xpos.connect("value_changed", self, "pos_changed")
		ypos.connect("value_changed", self, "pos_changed")
		zpos.connect("value_changed", self, "pos_changed")
	
	func selected():
		if root.selected_gate != null:
			gate_selected(root.selected_gate)
	
	func deselected():
		move_gizmo.visible = false
	
	func gate_selected(idx):
		disabled = true
		xpos.value = track.gates[idx].pos.x
		ypos.value = track.gates[idx].pos.y
		zpos.value = track.gates[idx].pos.z
		disabled = false
			
		move_gizmo.visible = true
		move_gizmo.transform.origin = track.gates[idx].pos
	
	func gizmo_pos_changed(v):
		root.changed = true
		track.change_pos(root.selected_gate, v)
		xpos.value = v.x
		ypos.value = v.y
		zpos.value = v.z
	
	var disabled = false
	func pos_changed(v):
		if disabled:
			return
		root.changed = true
		var new_pos = Vector3(xpos.value, ypos.value, zpos.value)
		track.change_pos(root.selected_gate, new_pos)
		move_gizmo.transform.origin = new_pos

class RotateTool extends Tool:
	var xpos
	var ypos
	var zpos
	
	var track
	
	var rot_gizmo
	
	func _init(root, container).("Rotate", root):
		rot_gizmo = root.get_node("RotateGizmo")
		rot_gizmo.connect("rot_changed", self, "gizmo_rot_changed")
		
		xpos = container.get_node("XPos/SpinBox")
		ypos = container.get_node("YPos/SpinBox")
		zpos = container.get_node("ZPos/SpinBox")
		
		track = root.get_node("Track")
		xpos.connect("value_changed", self, "rot_changed")
		ypos.connect("value_changed", self, "rot_changed")
		zpos.connect("value_changed", self, "rot_changed")
	
	func selected():
		if root.selected_gate != null:
			gate_selected(root.selected_gate)
	
	func deselected():
		rot_gizmo.visible = false
	
	func gate_selected(idx):
		rot_gizmo.visible = true
		rot_gizmo.target = track.get_child(idx)
		rot_gizmo.transform.origin = track.gates[idx].pos
		
		disabled = true
		xpos.value = rad2deg(track.gates[idx].rot.x)
		ypos.value = rad2deg(track.gates[idx].rot.y)
		zpos.value = rad2deg(track.gates[idx].rot.z)
		disabled = false
	
	var disabled = false
	func rot_changed(v):
		if disabled:
			return
		root.changed = true
		var new_rot = Vector3(
			deg2rad(xpos.value), 
			deg2rad(ypos.value), 
			deg2rad(zpos.value)
		)
		track.change_rot(root.selected_gate, new_rot)
	
	func gizmo_rot_changed(new_rot):
		root.changed = true
		track.change_rot(root.selected_gate, new_rot)
		xpos.value = rad2deg(new_rot.x)
		ypos.value = rad2deg(new_rot.y)
		zpos.value = rad2deg(new_rot.z)

var tools = [
	GateTool,
	MoveTool,
	RotateTool
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
	
	$Track.connect("track_changed", self, "on_track_changed")

func set_track_name(new_name):
	track_name = new_name
	$UI/LoadPanel/LoadContainer/TrackName.text = new_name

	
func on_track_changed():
	track_tree.clear()
	var root = track_tree.create_item()
	var gates_item = track_tree.create_item(root)
	gates_item.set_text(0, "Gates")
	
	for gate in $Track.gates:
		var gate_item = track_tree.create_item(gates_item)
		gate_item.set_text(0, str(Globals.GATES[gate["id"]]["name"]))

func select_gate(idx):
	$Track.light_gate(idx)
	selected_gate = idx
	tools[selected_tool].gate_selected(idx)
	
func get_track_tree_selected_idx():
	var item = track_tree.get_selected()
	var i = item.get_parent().get_children()
	var idx = 0
	while i != null:
		if i == item:
			break
		i = i.get_next()
		idx += 1
	return idx

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
	tracks = Globals.list_dir(Globals.TRACK_PATH)
	
	if tracks == null:
		var dir = Directory.new()
		dir.make_dir(Globals.TRACK_PATH)
		return

	for track in tracks:
		track_list.add_item(track)
		
func _on_TrackList_item_activated(index):
	changed = false
	var t_name = track_list.get_item_text(index)
	
	if $Track.load_from(t_name):
		set_track_name(t_name)
		$UI/LoadDialog.hide()

func _on_NewButton_pressed():
	var t_name = $UI/LoadDialog/NewTrackName.text
	
	if t_name == "" or (tracks != null and tracks.has(t_name)):
		return
	
	changed = true
	set_track_name(t_name)
	$Track.clear()
	$UI/LoadDialog.hide()

func _on_TrackList_item_rmb_selected(index, at_position):
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
	set_track_name($UI/LoadPanel/LoadContainer/TrackName.text)
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
	var idx = get_track_tree_selected_idx()
	select_gate(idx)

func _on_TrackTree_item_activated():
	var idx = get_track_tree_selected_idx()
	$CamPos.global_transform.origin = $Track.gates[idx].pos

func _on_TrackTree_item_rmb_selected(position):
	var pop_rect = Rect2(track_tree.rect_global_position + position, Vector2(10, 10))
	$UI/TreePanel/TrackTree/PopupMenu2.popup(pop_rect)


func _on_PopupMenu2_index_pressed(index):
	var idx = get_track_tree_selected_idx()
	changed = true
	if index == 0 and idx > 0:
		# up
		$Track.swap_gate(idx, idx - 1)
		select_gate(idx-1)
	elif index == 1 and idx < $Track.gates.size() - 1:
		# down
		$Track.swap_gate(idx, idx + 1)
		select_gate(idx+1)
	elif index == 2:
		# Delete
		$Track.remove_gate(idx)


func _on_TrackName_text_changed(new_text):
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
