extends Spatial

signal rot_changed

onready var target = null

var gizmo_scale = 1.0

const GIZMO_SIZE = 120

var current_axis = null

var old_rot = 0

onready var camera = $"../CamPos/Camera"

onready var axis = [
	$Xaxis,
	$Yaxis,
	$Zaxis
]

var materials = []

export var highlight_mat: SpatialMaterial

func _ready():
	for a in axis:
		materials.append(a.get_surface_material(0))
	
func _process(_delta):
	if not visible:
		return
	# recalculate scale
	var cam_transform = camera.get_global_transform()
	
	var camz = -cam_transform.basis.z.normalized()
	var camy = -cam_transform.basis.y.normalized()
	
	var p = Plane(camz, cam_transform.origin.dot(camz))
	var gizmo_d = abs(p.distance_to(transform.origin))

	var d0 = camera.unproject_position(cam_transform.origin + camz * gizmo_d).y
	var d1 = camera.unproject_position(cam_transform.origin + camz * gizmo_d + camy ).y
	var dd = abs(d0 - d1)
	if dd == 0:
		dd = 0.0001
	gizmo_scale = (GIZMO_SIZE / dd)

	transform.basis = Basis(Vector3(0, 1, 0), 0).scaled(gizmo_scale * Vector3(1, 1, 1))


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

func handle_input(event):
	if (not event is InputEventMouseButton) and (not event is InputEventMouseMotion):
		return
		
	var mult = 1
	if event.control:
		mult = 10
	
	
	var selected_axis = null
	# highlight
	for i in range(3):
		var o = camera.global_transform.origin
		var n = camera.project_ray_normal(event.position)
		var dpos = Vector3()
		dpos[i] = 1.0
		
		var plane = Plane(dpos, dpos.dot(global_transform.origin))
		
		var col = plane.intersects_ray(o, n)
		if col == null:
			continue
		
		var dist = global_transform.origin.distance_to(col)
		
		var inner_radius = 0.65 * gizmo_scale
		var outer_radius = 0.75 * gizmo_scale
		
		if inner_radius <= dist and dist <= outer_radius:
			selected_axis = i
			break
	
	for i in range(3):
		if i == selected_axis:
			axis[i].set_surface_material(0, highlight_mat)
		else:
			axis[i].set_surface_material(0, materials[i])
	
	if event is InputEventMouseButton and event.button_index == BUTTON_LEFT:
		if event.is_pressed() and selected_axis != null:
			current_axis = selected_axis
			var start_angle = get_y_angle(camera, event.position, current_axis)
			old_rot = round_angle(mult, start_angle)
		else:
			current_axis = null
			old_rot = null
	elif event is InputEventMouseMotion and current_axis != null:
		if old_rot == null:
			return
			
		var angle = get_y_angle(camera, event.position, current_axis)
		#var new_rot = angle
		var new_rot = round_angle(mult, angle)

		var normal = Vector3(0, 0, 0)
		normal[current_axis] = 1
		target.global_rotate(normal, new_rot - old_rot)
		old_rot = new_rot
		emit_signal("rot_changed", target.global_transform.basis.get_euler())