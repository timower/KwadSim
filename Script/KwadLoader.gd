extends Spatial


onready var track = $"/root/Root/Viewport/Track" # TODO: via globals?

onready var motors = [$Kwad/motor1, $Kwad/motor2, $Kwad/motor3, $Kwad/motor4]

func load_motor(motor_name):
	var params = Globals.read_json("res://Data/Motors/" + motor_name + ".json")
	var motor_I0 = params["I0"]
	var motor_Kv = params["Kv"]
	var motor_R = params["R"]
	$Kwad.set_motor_params(motor_Kv, motor_R, motor_I0)

func load_prop(prop_name):
	var params = Globals.read_json("res://Data/Props/" + prop_name + ".json")
	var prop_radius = params["radius"]
	var prop_chord = params["chord"]
	var inertia = params["inertia"]
	var prop_thrust = params["thrust"]
	var prop_rpm = params["rpm"]
	var prop_a = params["a"]
	var prop_torque_fac = params["torque_factor"]
	$Kwad.set_prop_params(prop_thrust, prop_rpm, prop_a, prop_torque_fac, inertia)

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
	$Kwad/CollisionShape.shape.extents = Vector3(size[0], size[1], size[2])
#	$Area.transform.origin.y = size[1]
#	$Area/CollisionShape.shape.radius = sqrt(size[0]*size[0] + size[2]*size[2])
	var cam = params["cam"]
	$Kwad/Camera.transform.origin = Vector3(cam[0], cam[1], cam[2]) 
	$Kwad.set_frame_params(drag_area, drag_c)
	

func load_params():
	var quad = Globals.quads[Globals.selected_quad]
	load_motor(quad["motor"])
	load_prop(quad["prop"])
	load_frame(quad["frame"])
	var Vin = quad["Vbat"]
	$Kwad.mass = quad["weight"]
	
	$Kwad.set_quad_params(Vin)

func _ready():
	load_params()
	Globals.connect("reset", self, "_on_reset")
	_on_reset()
	
func _on_reset():
	var start = track.objects[0]
	$Kwad.linear_velocity = Vector3()
	$Kwad.angular_velocity = Vector3()
	$Kwad.transform.origin = start.pos + Vector3(0, 0.5, 0)
	$Kwad.transform.basis = Basis(start.rot)

