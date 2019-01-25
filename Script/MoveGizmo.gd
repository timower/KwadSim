extends Spatial

signal pos_changed

func _ready():
	pass

func get_proj_point(camera: Camera, p: Vector2) -> Vector3:
	var dist = global_transform.origin.distance_to(camera.global_transform.origin)
	var n = camera.project_ray_normal(p)
	return camera.global_transform.origin + n * dist

func round_m(m: float, x: float) -> float:
	return round(x / m) * m

var old_pos = null
func pos_change(camera, event, plane):
	var mult = 0.1
	if event.control:
		mult = 1
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.pressed:
			var start_pos = get_proj_point(camera, event.position)[plane]
			old_pos = round_m(mult, start_pos)
		else:
			old_pos = null
	elif event is InputEventMouseMotion and event.button_mask & BUTTON_MASK_LEFT != 0:
		var pos = get_proj_point(camera, event.position)
		var new_pos = round_m(mult, pos[plane])
		
		var dpos = Vector3()
		dpos[plane] = new_pos - old_pos
		
		translate(dpos)
		old_pos = new_pos
		
		emit_signal("pos_changed", global_transform.origin)

func _on_YArea_input_event(camera, event, click_position, click_normal, shape_idx):
	pos_change(camera, event, 1)


func _on_XArea_input_event(camera, event, click_position, click_normal, shape_idx):
	pos_change(camera, event, 0)


func _on_ZArea_input_event(camera, event, click_position, click_normal, shape_idx):
	pos_change(camera, event, 2)
