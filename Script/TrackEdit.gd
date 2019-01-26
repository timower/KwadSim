extends Spatial

onready var track_label = $UI/LoadPanel/LoadContainer/Label
onready var tool_option = $UI/ToolPanel/ToolContainer/OptionButton
onready var tool_opt_cont = $UI/ToolPanel/ToolContainer

onready var track_list = $UI/LoadDialog/TrackList

onready var track_tree = $UI/TreePanel/TrackTree

var selected_tool = 0
var selected_object = null

var tracks = null
var track_name = null

var changed = false

var close_action = null

var gates_item = null

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
	func object_selected(idx):
		pass
	func input(event):
		pass

class GateTool extends Tool:
	var gate_list
	var cam_pos: Spatial
	var track
	
	func _init(root, container).("Place Gates", root):
		track = root.get_node("Track")
		gate_list = container.get_node("ItemList")
		cam_pos = root.get_node("CamPos")
		
		for id in range(Globals.OBJECTS.size()):
			var object = Globals.OBJECTS[id]
			if object.is_gate:
				var idx = gate_list.get_item_count()
				gate_list.add_item(object.name)
				gate_list.set_item_metadata(idx, id)
		gate_list.connect("item_activated", self, "place_gate")
	
	func place_gate(idx):
		root.changed = true
		var ref = track.add_gate({
			pos = cam_pos.global_transform.origin, 
			rot = Vector3(), 
			id = gate_list.get_item_metadata(idx)
		})
		root.select_object(ref)

class ObjectTool extends Tool:
	var obj_list
	var cam_pos: Spatial
	var track
	
	func _init(root, container).("Place Objects", root):
		track = root.get_node("Track")
		obj_list = container.get_node("ItemList")
		cam_pos = root.get_node("CamPos")
		
		for id in range(Globals.OBJECTS.size()):
			var object = Globals.OBJECTS[id]
			if not object.is_gate:
				var idx = obj_list.get_item_count()
				obj_list.add_item(object.name)
				obj_list.set_item_metadata(idx, id)
		obj_list.connect("item_activated", self, "place_object")
	
	func place_object(idx):
		root.changed = true
		var ref = track.add_object({
			pos = cam_pos.global_transform.origin, 
			rot = Vector3(), 
			id = obj_list.get_item_metadata(idx)
		})
		root.select_object(ref)

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
		if root.selected_object != null:
			object_selected(root.selected_object)
	
	func deselected():
		move_gizmo.visible = false
	
	func object_selected(ref):
		disabled = true
		xpos.value = track.objects[ref].pos.x
		ypos.value = track.objects[ref].pos.y
		zpos.value = track.objects[ref].pos.z
		disabled = false
			
		move_gizmo.visible = true
		move_gizmo.transform.origin = track.objects[ref].pos
	
	func gizmo_pos_changed(v):
		root.changed = true
		track.change_pos(root.selected_object, v)
		xpos.value = v.x
		ypos.value = v.y
		zpos.value = v.z
	
	var disabled = false
	func pos_changed(v):
		if disabled:
			return
		root.changed = true
		var new_pos = Vector3(xpos.value, ypos.value, zpos.value)
		track.change_pos(root.selected_object, new_pos)
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
		if root.selected_object != null:
			object_selected(root.selected_object)
	
	func deselected():
		rot_gizmo.visible = false
	
	func object_selected(ref):
		rot_gizmo.visible = true
		rot_gizmo.target = track.get_object_node(ref)
		rot_gizmo.transform.origin = track.objects[ref].pos
		
		disabled = true
		xpos.value = rad2deg(track.objects[ref].rot.x)
		ypos.value = rad2deg(track.objects[ref].rot.y)
		zpos.value = rad2deg(track.objects[ref].rot.z)
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
		track.change_rot(root.selected_object, new_rot)
	
	func gizmo_rot_changed(new_rot):
		root.changed = true
		track.change_rot(root.selected_object, new_rot)
		xpos.value = rad2deg(new_rot.x)
		ypos.value = rad2deg(new_rot.y)
		zpos.value = rad2deg(new_rot.z)

class ObjectPaintTool extends Tool:
	var last_pos = null
	var distance = null
	var obj_list = null
	var track = null
	var camera = null
	
	func _init(root, container).("Object Paint", root):
		track = root.get_node("Track")
		obj_list = container.get_node("ItemList")
		distance = container.get_node("Distance/SpinBox")
		camera = root.get_node("CamPos/Camera")
		
		for id in range(Globals.OBJECTS.size()):
			var object = Globals.OBJECTS[id]
			if not object.is_gate:
				var idx = obj_list.get_item_count()
				obj_list.add_item(object.name)
				obj_list.set_item_metadata(idx, id)
				print(object)
		obj_list.select(0)
	
	func place_object(pos):
		root.changed = true
		var selected = obj_list.get_selected_items()[0]
		var ref = track.add_object({
			pos = pos, 
			rot = Vector3(), 
			id = obj_list.get_item_metadata(selected)
		})
		#root.select_object(ref)
	
	func proj_pos(p: Vector2) -> Vector3:
		var n = camera.project_ray_normal(p)
		var o = camera.global_transform.origin
		var h = 0 # TODO: use cam height
		var t = (h - o.y) / n.y
		return o + n * t
		
	
	func input(event):
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
			var p = proj_pos(event.position)
			last_pos = p
			print(p)
			place_object(p)
		elif event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT != 0:
			var p = proj_pos(event.position)
			if p.distance_to(last_pos) > distance.value:
				place_object(p)
				last_pos = p
			

var tools = [
	GateTool,
	ObjectTool,
	MoveTool,
	RotateTool,
	ObjectPaintTool
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
		var name = Globals.OBJECTS[$Track.objects[ref].id]["name"]
		var gate_item = track_tree.create_item(gates_item)
		gate_item.set_text(0, name)
		gate_item.set_metadata(0, idx)

func select_object(ref: int):
	if $Track.is_ref_gate(ref):
		$Track.light_object(ref)
	else:
		pass # TODO: move light 
	selected_object = ref
	tools[selected_tool].object_selected(ref)

#func select_gate(idx):
#	$Track.light_gate(idx)
#	selected_object = $Track.get_gate_ref(idx)
#	tools[selected_tool].gate_selected(idx)
	
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
	
func _unhandled_input(event):
	tools[selected_tool].input(event)
