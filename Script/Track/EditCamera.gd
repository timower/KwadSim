extends Spatial

var dist = 0
var pitch = 30

func _ready():
	dist = $Camera.transform.origin.length()
	set_camera_pos()

func set_camera_pos():
	rotate_object_local(Vector3(1, 0, 0), -deg2rad(pitch))
	$Camera.transform = $Camera.transform.looking_at(global_transform.origin, Vector3(0, 1, 0))

func get_ground_pos(pos: Vector2) -> Vector3:
	var n = $Camera.project_ray_normal(pos)
	var o = $Camera.global_transform.origin
	var h = global_transform.origin.y
	return o + n * (h - o.y) / n.y

func _unhandled_input(event):
	if event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_RIGHT:
		if event.shift:
			global_rotate(Vector3(0, 1, 0), -event.relative.x * 0.005)
			var dpitch = -event.relative.y * 0.005
			var newpitch = pitch - rad2deg(dpitch)
			if 10 < newpitch and newpitch < 90:
				pitch = newpitch
				rotate_object_local(Vector3(1, 0, 0), dpitch)
		else:
			var pos2 = get_ground_pos(event.position)
			var pos1 = get_ground_pos(event.position - event.relative)
			var dpos = pos1 - pos2
			dpos.y = 0
			global_translate(dpos)
	elif event is InputEventMouseButton and event.pressed == false:
		if event.shift:
			if event.button_index == BUTTON_WHEEL_DOWN:
				global_translate(Vector3(0, -0.2, 0))
			elif event.button_index == BUTTON_WHEEL_UP and $Camera.transform.origin.length() > 0.5:
				global_translate(Vector3(0, 0.2, 0))
		else:
			if event.button_index == BUTTON_WHEEL_DOWN:
				$Camera.translate(Vector3(0, 0, 0.3))
			elif event.button_index == BUTTON_WHEEL_UP and $Camera.transform.origin.length() > 0.5:
				$Camera.translate(Vector3(0, 0, -0.3))
