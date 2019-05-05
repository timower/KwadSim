extends RigidBody

onready var config = $"/root/Root/KwadConfig"

onready var motors = [$motor1, $motor2, $motor3, $motor4]

onready var kwadInfo = $"/root/Root/KwadInfo"
onready var speedLabel = $"/root/Root/KwadInfo/SpeedLabel"
onready var track = $"/root/Root/Viewport/Track" # TODO: via globals?

# Constants

const AIR_RHO = 1.225

const MOTOR_DIR = [1.0, -1.0, -1.0, 1.0]

const MIX = [
	[1.0,  1.0,  1.0, -1.0],
	[1.0,  1.0, -1.0,  1.0],
	[1.0, -1.0, -1.0, -1.0],
	[1.0, -1.0,  1.0,  1.0],
]

const PTERM_SCALE = 0.032029
const ITERM_SCALE = 0.244381
const DTERM_SCALE = 0.000529

const PIDSUM_LIMIT = 500
const PIDSUM_LIMIT_YAW = 400
const PID_MIXER_SCALING = 1000.0

const ITERM_LIMIT = 400
const AIRMODE = true

# Quad parameters:

var drag_c = null
var drag_area = Vector3(0, 0, 0)
var Vin = null

# motor parameters:

var motor_R  = null
var motor_I0 = null
var motor_Kv = null

var motor_Kq = null #

var min_throttle = null

# propeller parameters:
var inertia = null
var prop_radius = null
var prop_chord = null

#./qprop ../runs/GF5x4.6 ../runs/s400-6v-dd  0.1,50/11 0,26000/11 0 -9 | sed '/#\|GVCALC\|\*\*/d' | awk -v RS= '{printf("[%s, [\n %s\n]],\n", $2, $0)}' | awk '{if (NF > 4) { printf("\t[%s, %s, %s],\n", $1, $4, $5) } else { print($0)}}' | sed 's/NaN/0/g' | sed 's/E/e/g
var prop_curve = null
var prop_curve_drpm = null
var prop_curve_dv0 = null

# State:

var lastGyro = Vector3()

var input = [0, 0, 0, 0]

var pid_out = [0, 0, 0]

var pid_state = [
	#I  D
	[0, 0],
	[0, 0],
	[0, 0]
]

var mix_out = [0, 0, 0, 0]

var motor_state = [
	# volts, rpm, torque, thrust
	[0,      0,   0,      0],
	[0,      0,   0,      0],
	[0,      0,   0,      0],
	[0,      0,   0,      0]
]

var ground_effect = 0

var crashed = false
var crash_timer = 0

var size = null

func load_motor(motor_name):
	var params = Globals.read_json("res://Data/Motors/" + motor_name + ".json")
	motor_I0 = params["I0"]
	motor_Kv = params["Kv"]
	motor_R = params["R"]
	motor_Kq = 60 / (motor_Kv * 2 * PI)
	min_throttle = params["min_throttle"]

func load_prop(prop_name):
	var params = Globals.read_json("res://Data/Props/" + prop_name + ".json")
	prop_radius = params["radius"]
	prop_chord = params["chord"]
	inertia = params["inertia"]
	prop_curve = params["curve"]
	prop_curve_drpm = prop_curve[1][0] - prop_curve[0][0]
	prop_curve_dv0 = prop_curve[0][1][1][0] - prop_curve[0][1][0][0]

const DEF_PROP_RAD = 0.062

func load_frame(frame_name):
	var params = Globals.read_json("res://Data/Frames/" + frame_name + ".json")
	drag_c = params["drag_c"]
	
	var area = params["area"]
	drag_area.x = area[0]
	drag_area.y = area[1]
	drag_area.z = area[2]
	
	var prop_scale = prop_radius / DEF_PROP_RAD
	var prop_scale_vec = Vector3(prop_scale, 1, prop_scale)
	for i in range(4):
		var pos = params["motors"][i]
		motors[i].transform.origin = Vector3(pos[0], pos[1], pos[2])
		motors[i].get_node("movingProp").scale = prop_scale_vec
		motors[i].get_node("Prop").scale = prop_scale_vec
		
	size = params["size"]
	$CollisionShape.shape.extents = Vector3(size[0], size[1], size[2])
#	$Area.transform.origin.y = size[1]
#	$Area/CollisionShape.shape.radius = sqrt(size[0]*size[0] + size[2]*size[2])
	var cam = params["cam"]
	$Camera.transform.origin = Vector3(cam[0], cam[1], cam[2]) 
	

func load_params():
	var quad = Globals.quads[Globals.selected_quad]
	load_motor(quad["motor"])
	load_prop(quad["prop"])
	load_frame(quad["frame"])
	Vin = quad["Vbat"]
	mass = quad["weight"]

func _ready():
	load_params()
	Globals.kwad = self
	for i in range(4):
		motors[i].get_node("MotorSound").playing = true
	Globals.connect("reset", self, "_on_reset")
	_on_reset()

func get_gyro():
	var curGyro = -transform.basis.xform_inv(angular_velocity) * 180 / PI
	return curGyro * 0.9 + lastGyro * 0.1

func get_input():
	var joyConf = Globals.joyConf
	input[0] = ((joyConf.throttle.value + 1) / 2)
	
	input[1] = config.apply_rates(0, joyConf.pitch.value)
	input[2] = config.apply_rates(1, joyConf.yaw.value)
	input[3] = config.apply_rates(2, joyConf.roll.value)

func calc_pid(delta, gyro_in):
	for axis in range(3):
		var setPoint = input[axis + 1] # skip throttle
		var gyroRate = gyro_in[axis]
		var errorRate = setPoint - gyroRate
		
		var Kp = config.pids[axis][0] * PTERM_SCALE
		var Ki = config.pids[axis][1] * ITERM_SCALE
		var Kd = config.pids[axis][2] * DTERM_SCALE
		
		var iterm = pid_state[axis][0]
		
		var D_delta = -(gyroRate - pid_state[axis][1]) / delta
		pid_state[axis][1] = gyroRate
		
		var P = Kp * errorRate
		var I = clamp(iterm + Ki * errorRate * delta, -ITERM_LIMIT, ITERM_LIMIT)
		pid_state[axis][0] = I
		var D = Kd * D_delta
		# var F = ...
		
		pid_out[axis] = P + I + D # + F

func calc_mixer():
	var throttle = input[0]
	
	var scaledPidPitch = clamp(pid_out[0], -PIDSUM_LIMIT, PIDSUM_LIMIT) / PID_MIXER_SCALING 
	var scaledPidYaw = clamp(pid_out[1], -PIDSUM_LIMIT_YAW, PIDSUM_LIMIT_YAW) / PID_MIXER_SCALING
	var scaledPidRoll = clamp(pid_out[2], -PIDSUM_LIMIT, PIDSUM_LIMIT) / PID_MIXER_SCALING
	
	var motorMixMax = 0
	var motorMixMin = 0
	
	for midx in range(4):
		var mmix = MIX[midx]
		
		var val = scaledPidPitch * mmix[1] + \
				  scaledPidYaw * mmix[2] +   \
				  scaledPidRoll * mmix[3] 

		mix_out[midx] = val
		
		if val > motorMixMax:
			motorMixMax = val
		elif val < motorMixMin:
			motorMixMin = val
	
	var motorMixRange = motorMixMax - motorMixMin

	if motorMixRange > 1.0:
		for i in range(4):
			mix_out[i] /= motorMixRange
		if AIRMODE:
			throttle = 0.5
	else:
		if AIRMODE or throttle > 0.5:
			throttle = clamp(throttle, -motorMixMin, 1 - motorMixMax)
	
	# add throttle
	for i in range(4):
		mix_out[i] = clamp(throttle * MIX[i][0] + mix_out[i], 0, 1)
	

func motor_torque(volts, rpm):
	var current = (volts - rpm / motor_Kv) / motor_R
	if current > 0:
		current = max(0, current - motor_I0)
	elif current < 0:
		current = min(0, current + motor_I0)
	return current * motor_Kq

func get_thrust(idx_rpm, idx_v0):
	return max(0, prop_curve[idx_rpm][1][idx_v0][1])

func prop_thrust(rpm, v0):
	var rpm_idx = (rpm - prop_curve[0][0]) / prop_curve_drpm
	var rpm_lidx = min(int(floor(rpm_idx)), prop_curve.size()-1)
	var rpm_uidx = min(int(ceil(rpm_idx)), prop_curve.size()-1)
	
	var a = rpm_idx - rpm_lidx
	
	var v0_idx = (v0 - prop_curve[0][1][0][0]) / prop_curve_dv0
	var v0_lidx = clamp(int(floor(v0_idx)), 0, prop_curve[0][1].size()-1)
	var v0_uidx = clamp(int(floor(v0_idx)), 0, prop_curve[0][1].size()-1)
	
	var b = v0_idx - v0_lidx
	
	var thrust_1 = get_thrust(rpm_lidx, v0_lidx) * (1 - b) + get_thrust(rpm_lidx, v0_uidx) * b
	var thrust_2 = get_thrust(rpm_uidx, v0_lidx) * (1 - b) + get_thrust(rpm_uidx, v0_uidx) * b
	
	var thrust = thrust_1 * (1 - a) + thrust_2 * a
	
	return thrust

func get_torque(idx_rpm, idx_v0):
	return max(0, prop_curve[idx_rpm][1][idx_v0][2])

func prop_torque(rpm, v0):
	var rpm_idx = (rpm - prop_curve[0][0]) / prop_curve_drpm
	var rpm_lidx = min(int(floor(rpm_idx)), prop_curve.size() - 1)
	var rpm_uidx = min(int(ceil(rpm_idx)), prop_curve.size()-1)
	
	var a = rpm_idx - rpm_lidx
	
	var v0_idx = (v0 - prop_curve[0][1][0][0]) / prop_curve_dv0
	var v0_lidx = clamp(int(floor(v0_idx)), 0, prop_curve[0][1].size()-1)
	var v0_uidx = clamp(int(floor(v0_idx)), 0, prop_curve[0][1].size()-1)
	
	var b = v0_idx - v0_lidx
	
	var torque_1 = get_torque(rpm_lidx, v0_lidx) * (1 - b) + get_torque(rpm_lidx, v0_uidx) * b
	var torque_2 = get_torque(rpm_uidx, v0_lidx) * (1 - b) + get_torque(rpm_uidx, v0_uidx) * b
	var torque = torque_1 * (1 - a) + torque_2 * a
	
	return torque

func calc_motor(delta):
	var up = global_transform.basis.y
	
	var v0 = max(0, up.dot(linear_velocity))
	
	var torque_sum = 0
	for midx in range(4):
		var motor = motors[midx]
		var pos = global_transform.basis.xform(motor.translation)
		var val = mix_out[midx]
		
		var rpm = motor_state[midx][1]

		var volts = val * (Vin - min_throttle) + min_throttle
		
		var torque = motor_torque(volts, rpm)

		# calc prop torque and trhust
		var prop_torque = prop_torque(rpm, v0)

		# calc new rpm
		var net_torque = torque - prop_torque
		var domega = net_torque / inertia
		var drpm = (domega * delta) * 60 / (2 * PI)
		
		var maxdrpm = abs(volts * motor_Kv - rpm)
		rpm += clamp(drpm, -maxdrpm, maxdrpm)
		
		var thrust = prop_thrust(rpm, v0)

		motor_state[midx][0] = volts
		motor_state[midx][1] = rpm
		motor_state[midx][2] = torque
		motor_state[midx][3] = thrust
		
		torque_sum += MOTOR_DIR[midx] * torque
		
		thrust *= 1 + ground_effect
		apply_impulse(pos, up * delta * thrust)
		kwadInfo.get_child(midx + 1).value = val * 100
	
	apply_torque_impulse(-up * torque_sum * delta)

func _on_reset():
	var start = track.objects[0]
	linear_velocity = Vector3()
	angular_velocity = Vector3()
	transform.origin = start.pos + Vector3(0, 0.2 + size[1], 0)
	transform.basis = Basis(start.rot)
	pid_state = [
		#I  D
		[0, 0],
		[0, 0],
		[0, 0]
	]
	crashed = false

func _physics_process(delta):
	crash_timer -= delta
	if crashed:
		if crash_timer <= 0:
			Globals.reset()
		else:
			return
		
	if Globals.joyConf == null or not Globals.joyConf.throttle.has_moved:
		return

		
	# ground effect:
	ground_effect = 0
	var space_state = get_world().direct_space_state
	var orig = global_transform.origin
	var down = global_transform.origin - global_transform.basis.y * 10
	var ray_info = space_state.intersect_ray(orig, down, [self])
	if ray_info.size() > 0:
		var pos = ray_info.position
		var height = orig.distance_to(pos)
		if height < 3 * prop_radius and input[0] > 0.05:
			ground_effect = 0.05 / (height / (2 * prop_radius))
		
	var gyro_in = get_gyro()
	
	get_input()

	calc_pid(delta, gyro_in)
	
	calc_mixer()
	
	calc_motor(delta)
	
	# add drag:
	var vel2 = linear_velocity.length_squared()
	var dir = linear_velocity.normalized()
	var local_dir = global_transform.basis.xform_inv(dir)
	var area = drag_area.dot(local_dir.abs())
	var drag_force = 0.5 * AIR_RHO * vel2 * drag_c * area
	apply_impulse(Vector3(), dir * -drag_force * delta)
	
	var vel2_rot = angular_velocity.length_squared()
	var dir_rot = angular_velocity.normalized()
	# TODO: CORRECT the size parameter to be dependent on axis and on quad frame
	var drag_torque = 0.125 * AIR_RHO * vel2_rot * drag_c * 0.000003
	apply_torque_impulse(dir_rot * -drag_torque * delta)


func _process(delta):
	for i in range(4):
		var p = motor_state[i][1] / (Vin * motor_Kv)
		motors[i].get_node("MotorSound").pitch_scale = 0.8 +  0.7 * p
		
		var speed = motor_state[i][1] 
		var rotating = motor_state[i][1] > 10
		motors[i].get_node("movingProp").visible = rotating
		motors[i].get_node("Prop").rotate_y(MOTOR_DIR[i] * speed / (Vin * motor_Kv) * 50  * delta)

	var vel = linear_velocity.length()
	var height = global_transform.origin.y
	var fps = 1 / max(delta, 0.0001)
	speedLabel.text = str(int(vel * 3.6)) + " km/h\n" + \
					  str(round(height * 10)/10) + " m\n" + \
					  str(round(motor_state[0][1])) + " rpm\n" + \
					  str(ground_effect) + "\n" + \
					  str(int(fps)) + " fps"
#					  str(motor_state[0][3]) + " N\n" + \

var last_vel
func _integrate_forces(state):
	if state.get_contact_count() > 0:
		var norm = state.get_contact_local_normal(0)
		var nvel = last_vel.dot(norm)
#		if abs(nvel) > 1:
#			print(nvel)
		if abs(nvel) > 4.5 and not crashed:
			for i in range(4):
				motor_state[i][1] = 0
			crashed = true
			crash_timer = 2
	
	last_vel = state.linear_velocity
