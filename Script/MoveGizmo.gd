extends Spatial

signal pos_changed

var gizmo_scale = 1.0

const GIZMO_SIZE = 100

var current_axis = null

var old_pos = null

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

func get_proj_point(camera: Camera, p: Vector2) -> Vector3:
       var dist = global_transform.origin.distance_to(camera.global_transform.origin)
       var n = camera.project_ray_normal(p)
       return camera.global_transform.origin + n * dist

func round_m(m: float, x: float) -> float:
	return round(x / m) * m

func handle_input(event) -> bool:
	if (not event is InputEventMouseButton) and (not event is InputEventMouseMotion):
		return false
		
	var mult = 0.1
	if event.control:
		mult = 1

	var selected_axis = null
	# highlight
	for i in range(3):
		var o = camera.global_transform.origin
		var n = camera.project_ray_normal(event.position)
		var dpos = Vector3()
		dpos[i] = 1.0
		var hpos =  global_transform.origin + gizmo_scale * dpos
		var col = Geometry.segment_intersects_sphere(o, n * 1e6, hpos, gizmo_scale * 0.5)
		if col.size() > 0:
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
			var start_pos = get_proj_point(camera, event.position)[current_axis]
			old_pos = round_m(mult, start_pos)
			return true
		else:
			var was_selected = current_axis != null
			current_axis = null
			old_pos = null
			return was_selected
	elif event is InputEventMouseMotion and current_axis != null:
		var pos = get_proj_point(camera, event.position)
		var new_pos = round_m(mult, pos[current_axis])
		
		var dpos = Vector3()
		dpos[current_axis] = new_pos - old_pos
		#print(dpos[plane])
		translate(dpos / gizmo_scale)
		old_pos = new_pos
		
		emit_signal("pos_changed", global_transform.origin)
		return true
	return false
