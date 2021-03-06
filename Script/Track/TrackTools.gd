extends Object

class_name TrackTools

class Tool:
	var name
	var root
	
	static 	func proj_pos(camera: Camera, cam_pos: Spatial, p: Vector2) -> Array:
		var n = camera.project_ray_normal(p)
		var o = camera.global_transform.origin
			
		var space_state = camera.get_world().direct_space_state
		var ray_info = space_state.intersect_ray(o, o + 1e6 * n)
		if ray_info.size() > 0:
			var pos = ray_info.position
			var axis = Vector3(0, 1, 0).cross(ray_info.normal)
			var angle = asin(axis.length())
			var quat = Quat(axis.normalized(), angle)
			var euler = quat.get_euler()
			return [pos, euler, ray_info.normal]

		var h = cam_pos.global_transform.origin.y
		var t = (h - o.y) / n.y
		return [o + n * t, Vector3(), Vector3(0, 1, 0)]
	
	func _init(n, r):
		name = n
		root = r
		
	func selected():
		pass
		
	func deselected():
		pass
		
	func object_selected(_idx):
		pass
		
	func object_deselected():
		pass
		
	func input(_event) -> bool:
		return false
		
	func thumb_update(_obj_id):
		pass



class _PlaceTool extends Tool:
	var gate_list
	var cam_pos: Spatial
	var camera
	var track
	
	var rot_obj = null
	var rot_pos = null
	# the plane in which the rotation happens
	var rot_plane = null
	# the base vector in the plane over which the angle is calculated
	var rot_base = null
	# the angle between the base vector
	var rot_angle = null
	
	func _init(root, container, isgate, name).(name, root):
		track = root.get_node("Track")
		gate_list = container.get_node("ScrollContainer/ItemList")
		cam_pos = root.get_node("CamPos")
		camera = root.get_node("CamPos/Camera")
		
		for id in range(Globals.OBJECTS.size()):
			var object = Globals.OBJECTS[id]

			if (isgate and object.is_gate) or (not isgate and not object.is_gate):
				var idx = gate_list.get_item_count()
				gate_list.add_item(object.name, object.thumb)
				gate_list.set_item_metadata(idx, id)
		gate_list.connect("item_activated", self, "place_gate")
	
	func place_gate(idx):
		var heading = camera.global_transform.basis.get_euler().y
		var object_dict = {
			pos = cam_pos.global_transform.origin, 
			rot = Vector3(0, heading, 0), 
			id = gate_list.get_item_metadata(idx)
		}
		
		var action = TrackActions.PlaceObjectAction.new(object_dict)
		root.do_action(action)
		root.select_object(action.obj_ref)
	
	func thumb_update(obj_id):
		for idx in range(gate_list.get_item_count()):
			if gate_list.get_item_metadata(idx) == obj_id:
				gate_list.set_item_icon(idx, Globals.OBJECTS[obj_id].thumb)
				break
	
	func get_angle(x: Vector3) -> float:
		var v = (x - rot_pos).normalized()
		return atan2(v.cross(rot_base).dot(rot_plane.normal), v.dot(rot_base))
	
	func input(event) -> bool:
		if gate_list.get_selected_items().size() == 0:
			return false
			
		var obj_idx = gate_list.get_selected_items()[0]
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
			if event.is_pressed():
				var p = proj_pos(camera, cam_pos, event.position)
				var object_dict = {
					pos = p[0], 
					rot = p[1], 
					id = gate_list.get_item_metadata(obj_idx)
				}
				
				var action = TrackActions.PlaceObjectAction.new(object_dict)
				root.do_action(action)
				root.select_object(action.obj_ref)
				
				rot_obj = action.obj_ref
				rot_pos = object_dict.pos
				rot_plane = Plane(p[2], p[2].dot(rot_pos))
				rot_base = Basis(p[1]).xform(Vector3(0, 0, -1))
				rot_angle = 0
				return true
			elif rot_obj != null:
				rot_obj = null
				rot_pos = null
				rot_plane = null
				
				rot_base = null
				rot_angle = null
				return true
		elif event is InputEventMouseMotion and rot_obj != null:
			var o =  camera.global_transform.origin
			var d = camera.project_ray_normal(event.position)
			var new_pos = rot_plane.intersects_ray(o, d)
			assert(new_pos != null)
			
			var new_angle = get_angle(new_pos)
			
			var node = track.get_object_node(rot_obj)
			node.global_rotate(rot_plane.normal, rot_angle - new_angle)
			rot_angle = new_angle
			
			track.change_rot(rot_obj, node.transform.basis.get_euler())

			return true
		return false

class GateTool extends _PlaceTool:
	func _init(root, container).(root, container, true, "Place Gates"):
		pass

class ObjectTool extends _PlaceTool:
	func _init(root, container).(root, container, false, "Place Objects"):
		pass
#	var obj_list
#	var cam_pos: Spatial
#	var track
#
#	func _init(root, container).("Place Objects", root):
#		track = root.get_node("Track")
#		obj_list = container.get_node("ItemList")
#		cam_pos = root.get_node("CamPos")
#
#		for id in range(Globals.OBJECTS.size()):
#			var object = Globals.OBJECTS[id]
#			if not object.is_gate:
#				var idx = obj_list.get_item_count()
#				obj_list.add_item(object.name, object.thumb)
#				obj_list.set_item_metadata(idx, id)
#		obj_list.connect("item_activated", self, "place_object")
#
#	func place_object(idx):
#		var odict = {
#			pos = cam_pos.global_transform.origin, 
#			rot = Vector3(), 
#			id = obj_list.get_item_metadata(idx)
#		}
#		var action = TrackActions.PlaceObjectAction.new(odict)
#		root.do_action(action)
#		root.select_object(action.obj_ref)
#
#
#	func thumb_update(obj_id):
#		for idx in range(obj_list.get_item_count()):
#			if obj_list.get_item_metadata(idx) == obj_id:
#				obj_list.set_item_icon(idx, Globals.OBJECTS[obj_id].thumb)
#
#	func input(event) -> bool:
#		return false

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
	
	func object_deselected():
		move_gizmo.visible = false
	
	func gizmo_pos_changed(new_pos):
		root.do_action(TrackActions.MoveAction.new(root.selected_object, new_pos))
		#track.change_pos(root.selected_object, v)
		xpos.value = new_pos.x
		ypos.value = new_pos.y
		zpos.value = new_pos.z
	
	var disabled = false
	func pos_changed(_v):
		if disabled:
			return
		var new_pos = Vector3(xpos.value, ypos.value, zpos.value)
		#track.change_pos(root.selected_object, new_pos)
		root.do_action(TrackActions.MoveAction.new(root.selected_object, new_pos))
		move_gizmo.transform.origin = new_pos
	
	func input(event) -> bool:
		if move_gizmo.visible:
			return move_gizmo.handle_input(event)
		return false

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
	
	func object_deselected():
		rot_gizmo.visible = false
		rot_gizmo.target = null
	
	var disabled = false
	func rot_changed(_v):
		if disabled:
			return
		var new_rot = Vector3(
			deg2rad(xpos.value), 
			deg2rad(ypos.value), 
			deg2rad(zpos.value))
		
		root.do_action(TrackActions.RotateAction.new(root.selected_object, new_rot))
		#track.change_rot(root.selected_object, new_rot)
	
	func gizmo_rot_changed(new_rot):
		root.do_action(TrackActions.RotateAction.new(root.selected_object, new_rot))
		xpos.value = rad2deg(new_rot.x)
		ypos.value = rad2deg(new_rot.y)
		zpos.value = rad2deg(new_rot.z)
		
	func input(event) -> bool:
		if rot_gizmo.visible:
			return rot_gizmo.handle_input(event)
		return false

class ObjectPaintTool extends Tool:
	var last_pos = null
	var distance = null
	var obj_list = null
	var track = null
	var camera = null
	var cam_pos = null
	
	func _init(root, container).("Object Paint", root):
		track = root.get_node("Track")
		obj_list = container.get_node("ItemList")
		distance = container.get_node("Distance/SpinBox")
		cam_pos = root.get_node("CamPos")
		camera = root.get_node("CamPos/Camera")
		
		for id in range(Globals.OBJECTS.size()):
			var object = Globals.OBJECTS[id]
			if not object.is_gate:
				var idx = obj_list.get_item_count()
				obj_list.add_item(object.name, object.thumb)
				obj_list.set_item_metadata(idx, id)
				Log.d(object)
		obj_list.select(0)

	
	func place_object(pos, rot):
		var selected = obj_list.get_selected_items()[0]
		var object_dict = {
			pos = pos, 
			rot = rot, 
			id = obj_list.get_item_metadata(selected)
		}
		var action = TrackActions.PlaceObjectAction.new(object_dict)
		root.do_action(action)
	
	func remove_object(pos: Vector3):
		var obj_ref = root.get_closest_object(pos, distance.value)
		if obj_ref == 0 or obj_ref == null:
			return
		root.do_action(TrackActions.RemoveObjectAction.new(obj_ref))
		
	
	func input(event) -> bool:
		var place = not event.shift
		if event is InputEventMouseButton and event.button_index == BUTTON_LEFT and event.pressed:
			var p = proj_pos(camera, cam_pos, event.position)
			last_pos = p[0]
			if place:
				place_object(p[0], p[1])
			else:
				remove_object(p[0])
			return true
		elif event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT != 0:
			var p = proj_pos(camera, cam_pos, event.position)
			if place and p[0].distance_to(last_pos) > distance.value:
				place_object(p[0], p[1])
				last_pos = p[0]
			elif not place:
				remove_object(p[0])
			return true
		return false
	
	func thumb_update(obj_id):
		for idx in range(obj_list.get_item_count()):
			if obj_list.get_item_metadata(idx) == obj_id:
				obj_list.set_item_icon(idx, Globals.OBJECTS[obj_id].thumb)
