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
	return o + n * (o.y / n.y)

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
			global_translate(pos2 - pos1)
	elif event is InputEventMouseButton and event.pressed == false:
		if event.button_index == BUTTON_WHEEL_DOWN:
			$Camera.translate(Vector3(0, 0, 0.3))
		elif event.button_index == BUTTON_WHEEL_UP:
			$Camera.translate(Vector3(0, 0, -0.3))