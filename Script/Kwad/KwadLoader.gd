extends Spatial

onready var motors = [$Kwad/motor1, $Kwad/motor2, $Kwad/motor3, $Kwad/motor4]

onready var kwad = $Kwad
onready var kwad_cam = $Kwad/Camera
onready var kwad_col = $Kwad/CollisionShape

var rc_inputs = [0.0, 0.0, 0.0, 0.0,
				 0.0, 0.0, 0.0, 0.0]

func load_motor(motor_name):
	var params = Globals.read_json("res://Data/Motors/" + motor_name + ".json")
	var motor_I0 = params["I0"]
	var motor_Kv = params["Kv"]
	var motor_R = params["R"]
	kwad.set_motor_params(motor_Kv, motor_R, motor_I0)

func load_prop(prop_name):
	var params = Globals.read_json("res://Data/Props/" + prop_name + ".json")
	# var prop_radius = params["radius"]
	# var prop_chord = params["chord"]
	# var prop_thrust = params["thrust"]
	var inertia = params["inertia"]
	var prop_rpm = params["rpm"]
	var prop_a = params["a"]
	var prop_torque_fac = params["torque_factor"]
	var prop_t_params = params["thrust_vel_params"]
	kwad.set_prop_params(prop_rpm, 
						 prop_a, 
						 prop_torque_fac, 
						 inertia, 
						 prop_t_params)

const DEF_PROP_RAD = 0.062

func load_frame(frame_name):
	var params = Globals.read_json("res://Data/Frames/" + frame_name + ".json")
	var drag_c = params["drag_c"]
	
	var drag_area = Vector3()
	var area = params["area"]
	drag_area.x = area[0]
	drag_area.y = area[1]
	drag_area.z = area[2]
	
	#var prop_scale = prop_radius / DEF_PROP_RAD
	#var prop_scale_vec = Vector3(prop_scale, 1, prop_scale)
	
	for i in range(4):
		var pos = params["motors"][i]
		motors[i].transform.origin = Vector3(pos[0], pos[1], pos[2])
	
		#motors[i].get_node("movingProp").scale = prop_scale_vec
		#motors[i].get_node("Prop").scale = prop_scale_vec
		
	var size = params["size"]
	kwad_col.shape.extents = Vector3(size[0], size[1], size[2])
	
#	$Area.transform.origin.y = size[1]
#	$Area/CollisionShape.shape.radius = sqrt(size[0]*size[0] + size[2]*size[2])
	
	var cam = params["cam"]
	kwad_cam.transform.origin = Vector3(cam[0], cam[1], cam[2]) 
	kwad.set_frame_params(drag_area, drag_c)
	

func load_params():
	var quad = Globals.quads[Globals.selected_quad]
	load_motor(quad["motor"])
	load_prop(quad["prop"])
	load_frame(quad["frame"])
	
	kwad.mass = quad["weight"]
	kwad.set_quad_params(quad["Vbat"])

func _ready():
	load_params()
	Globals.connect("reset", self, "_on_reset")
	_on_reset()

func _process(_delta):
	for i in range(8):
		rc_inputs[i] = Settings.get_axis(i)
	kwad.new_rc_input(rc_inputs)

func _on_reset():
	var track = Globals.get_track()
	var start = null
	if track == null:
		start = {pos = Vector3(), rot = Basis()}
	else:
		start = track.objects[0]
		
	kwad.linear_velocity = Vector3()
	kwad.angular_velocity = Vector3()
	kwad.transform.origin = start.pos 
	kwad.transform.origin += Vector3(0, 0.5 + kwad_col.shape.extents.y, 0)
	kwad.transform.basis = Basis(start.rot)
	kwad.set_crashed(false)
