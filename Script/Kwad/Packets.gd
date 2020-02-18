# 1 "D:/Projects/KwadSimServer/gdscript/Packets.gd"
# 1 "<built-in>"
# 1 "<command-line>"
# 1 "D:/Projects/KwadSimServer/gdscript/Packets.gd"
extends Object

class_name Packets


 # This file is generated from KwadSimServer/Packets.def, do not edit

class Packet extends Object:
	var _props = []

	func _init():
		for prop in get_property_list():
			if prop.usage == PROPERTY_USAGE_SCRIPT_VARIABLE and prop.name != "_props":
				_props.append(prop.name)

	func to_list():
		var result = []
		result.resize(len(_props))
		for i in range(len(_props)):
			result[i] = get(_props[i])
			assert(result[i] != null, _props[i]+ " is null")
		return result

	func from_list(lst):
		for i in range(len(_props)):
			set(_props[i], lst[i])
			assert(get(_props[i]) != null, _props[i]+ " set null")
# 45 "D:/Projects/KwadSimServer/gdscript/Packets.gd"
# 1 "d:\\projects\\kwadsimserver\\src\\packets.def" 1

class InitPacket extends Packet:
	var motor_kv: float
	var motor_R: float
	var motor_I0: float

	var prop_max_rpm: float
	var prop_a_factor: float
	var prop_torque_factor: float
	var prop_inertia: float
	var prop_thrust_factors: Array

	var frame_drag_area: Vector3
	var frame_drag_constant: float

	var quad_mass: float
	var quad_inv_inertia: Vector3
	var quad_vbat: float
	var quad_motor_pos: Array


class StatePacket extends Packet:
	var delta: float
	var position: Vector3
	var rotation: Basis

	var angularVelocity: Vector3
	var linearVelocity: Vector3
	var rcData: Array
	var crashed: bool


class StateUpdatePacket extends Packet:
	var angularVelocity: Vector3
	var linearVelocity: Vector3


class StateOsdUpdatePacket extends Packet:
	var angularVelocity: Vector3
	var linearVelocity: Vector3
	var osd: Array

# 45 "D:/Projects/KwadSimServer/gdscript/Packets.gd" 2
