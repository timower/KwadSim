extends Object

class_name TrackActions

class Action:
	func do(_track):
		pass
	func undo(_track):
		pass
	func combine(_action):
		return false
		
class PlaceObjectAction extends Action:
	var obj_dict
	var obj_ref = null
	
	func _init(odict):
		obj_dict = odict
		
	func do(track):
		obj_ref = track.add_object(obj_dict)

	func undo(track):
		track.remove_object(obj_ref)
		obj_ref = null

class RemoveObjectAction extends Action:
	var obj_dict = null
	var obj_ref = null
	var gate_idx = null
	
	func _init(ref):
		obj_ref = ref
		
	func do(track):
		obj_dict = track.objects[obj_ref]
		if track.is_ref_gate(obj_ref) and gate_idx == null:
			gate_idx = track.get_gate_idx(obj_ref)
		track.remove_object(obj_ref)
		obj_ref = null

	func undo(track):
		obj_ref = track.add_object(obj_dict, gate_idx)
		
class MoveAction extends Action:
	var object
	var new_pos
	
	func _init(obj, pos):
		new_pos = pos
		object = obj
	
	func do(track):
		var old_pos = track.objects[object].pos
		track.change_pos(object, new_pos)
		new_pos = old_pos
		
	func undo(track):
		var old_pos = track.objects[object].pos
		track.change_pos(object, new_pos)
		new_pos = old_pos
	
	func combine(action):
		return action is MoveAction and action.object == object

class RotateAction extends Action:
	var object
	var new_rot
	
	func _init(obj, rot):
		new_rot = rot
		object = obj
	
	func do(track):
		var old_rot = track.objects[object].rot
		track.change_rot(object, new_rot)
		new_rot = old_rot
		
	func undo(track):
		var old_rot = track.objects[object].rot
		track.change_rot(object, new_rot)
		new_rot = old_rot
	
	func combine(action):
		return action is RotateAction and action.object == object
