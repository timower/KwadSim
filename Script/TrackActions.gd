extends Object

class_name TrackActions

class Action:
	func do(_track):
		pass
	func undo(_track):
		pass
	func combine(_action):
		return false

class PlaceGateAction extends Action:
	var gate_dict
	var gate_ref = null
	
	func _init(gdict):
		gate_dict = gdict
		
	func do(track):
		gate_ref = track.add_gate(gate_dict)

	func undo(track):
		track.remove_object(gate_ref)
		gate_ref = null
		
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