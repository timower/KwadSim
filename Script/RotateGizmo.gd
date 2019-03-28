extends Spatial

signal rot_changed

onready var target = $MeshInstance

func _ready():
	pass

func proj(camera: Camera, p: Vector2, plane: int) -> Vector3:
	var n = camera.project_ray_normal(p)
	var o = camera.global_transform.origin
	
	var h = global_transform.origin[plane]
	
	var t = (h - o[plane]) / n[plane]
	return o + n * t

func get_y_angle(camera: Camera, p1: Vector2, plane: int) -> float:
	var pos1 = proj(camera, p1, plane)
	
	var center = global_transform.origin
	pos1 -= center
	
	if plane == 0:
		return atan2(pos1.z, pos1.y)
	elif plane == 1:
		return atan2(pos1.x, pos1.z)
	else:
		return atan2(pos1.y, pos1.x)

func round_angle(m: float, x: float) -> float:
	return deg2rad(round(rad2deg(x) / m)) * m

var old_rot = 0
func handle_input(camera, event, plane):
	var mult = 1
	if event.control:
		mult = 10
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			var start_angle = get_y_angle(camera, event.position, plane)
			old_rot = round_angle(mult, start_angle)
		else:
			old_rot = null
	elif event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT != 0:
		if old_rot == null:
			return

		var angle = get_y_angle(camera, event.position, plane)
		
		#var new_rot = angle
		var new_rot = round_angle(mult, angle)

		var axis = Vector3(0, 0, 0)
		axis[plane] = 1
		target.global_rotate(axis, new_rot - old_rot)
		old_rot = new_rot
		emit_signal("rot_changed", target.global_transform.basis.get_euler())

func _on_YArea_input_event(camera, event, _click_position, _click_normal, _shape_idx):
	handle_input(camera, event, 1)

func _on_XArea_input_event(camera, event, _click_position, _click_normal, _shape_idx):
	handle_input(camera, event, 0)


func _on_ZArea_input_event(camera, event, _click_position, _click_normal, _shape_idx):
	handle_input(camera, event, 2)
