extends RigidBody

onready var joyConf = $"/root/Root/JoyConf"

onready var config = $"/root/Root/KwadConfig"

onready var motors = [$motor1, $motor2, $motor3, $motor4]

onready var kwadInfo = $"/root/Root/KwadInfo"
onready var speedLabel = $"/root/Root/KwadInfo/SpeedLabel"

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
var drag_area = null
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

var prop_curve = null

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

const selected_quad = "QQ190"

func read_json(name):
	var file = File.new()
	file.open(name, file.READ)
	var conts = parse_json(file.get_as_text())
	file.close()
	return conts

func load_motor(motor_name):
	var params = read_json("res://Data/Motors/" + motor_name + ".json")
	motor_I0 = params["I0"]
	motor_Kv = params["Kv"]
	motor_R = params["R"]
	motor_Kq = 60 / (motor_Kv * 2 * PI)
	min_throttle = params["min_throttle"]

func load_prop(prop_name):
	var params = read_json("res://Data/Props/" + prop_name + ".json")
	prop_radius = params["radius"]
	prop_chord = params["chord"]
	inertia = params["inertia"]
	prop_curve = params["curve"]

func load_frame(frame_name):
	var params = read_json("res://Data/Frames/" + frame_name + ".json")
	drag_c = params["drag_c"]
	drag_area = params["area"]
	Vin = params["Vbat"]

func load_params():
	# TODO: move to global settings:
	var quads = read_json("res://Data/quads.json")
	var quad = quads[selected_quad]
	load_motor(quad["motor"])
	load_prop(quad["prop"])
	load_frame(quad["frame"])

func _ready():
	load_params()
	for i in range(4):
		motors[i].get_node("MotorSound").playing = true

func get_gyro():
	var curGyro = -transform.basis.xform_inv(angular_velocity) * 180 / PI
	return curGyro * 0.9 + lastGyro * 0.1

func get_input():
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
			input[0] = 0.5
	else:
		if AIRMODE or input[0] > 0.5:
			input[0] = clamp(input[0], -motorMixMin, 1 - motorMixMax)
	
	# add throttle
	for i in range(4):
		mix_out[i] = clamp(input[0] * MIX[i][0] + mix_out[i], 0, 1)
	

func motor_torque(volts, rpm):
	var current = (volts - rpm / motor_Kv) / motor_R
	if current > 0:
		current = max(0, current - motor_I0)
	elif current < 0:
		current = min(0, current + motor_I0)
	return current * motor_Kq

func prop_thrust_torque(rpm):
	var idx = rpm / 2600.0
	var lidx = int(floor(idx))
	var uidx = int(ceil(idx))
	
	var a = idx - lidx
	var thrust = prop_curve[lidx][1] * (1 - a) + prop_curve[uidx][1] * a
	var torque = prop_curve[lidx][2] * (1 - a) + prop_curve[uidx][2] * a
	
	return Vector2(thrust, torque)

func calc_motor(delta):
	var up = global_transform.basis.y
	
	var torque_sum = 0
	for midx in range(4):
		var motor = motors[midx]
		var pos = global_transform.basis.xform(motor.translation)
		var val = mix_out[midx]
		
		var rpm = motor_state[midx][1]

		var volts = val * (Vin - min_throttle) + min_throttle
		
		var torque = motor_torque(volts, rpm)

		# calc prop torque and trhust
		var prop = prop_thrust_torque(rpm)
		var prop_torque = prop.y
		var thrust = prop.x

		# calc new rpm
		var net_torque = torque - prop_torque
		var domega = net_torque / inertia
		var drpm = (domega * delta) * 60 / (2 * PI)
		
		var maxdrpm = abs(volts * motor_Kv - rpm)
		rpm += clamp(drpm, -maxdrpm, maxdrpm)
		
		prop = prop_thrust_torque(rpm)
		thrust = prop.x

		motor_state[midx][0] = volts
		motor_state[midx][1] = rpm
		motor_state[midx][2] = torque
		motor_state[midx][3] = thrust
		
		torque_sum += MOTOR_DIR[midx] * torque
		
		thrust *= 1 + ground_effect
		apply_impulse(pos, up * delta * thrust)
		kwadInfo.get_child(midx + 1).value = val * 100
	
	apply_torque_impulse(-up * torque_sum * delta * 3)

func _physics_process(delta):
	if Input.is_action_just_pressed("reset"):
		transform.basis = Basis(Vector3())
	
	if not joyConf.throttle.has_moved:
		return
		
	var height = global_transform.origin.y
	if height < 4 * prop_radius:
		ground_effect = 0.05 / (height / (2 * prop_radius))
	else:
		ground_effect = 0
		
	var gyro_in = get_gyro()
	
	get_input()

	calc_pid(delta, gyro_in)
	
	calc_mixer()
	
	calc_motor(delta)
	
	# add drag:
	var vel2 = linear_velocity.length_squared()
	var drag_force = 0.5 * AIR_RHO * vel2 * drag_c * drag_area
	apply_impulse(Vector3(), linear_velocity.normalized() * -drag_force * delta)


func _process(delta):
	for i in range(4):
		var p = motor_state[i][1] / (Vin * motor_Kv)
		motors[i].get_node("MotorSound").pitch_scale = 0.8 +  0.7 * p
	
	var vel = linear_velocity.length()
	var height = global_transform.origin.y
	var fps = 1 / max(delta, 0.0001)
	speedLabel.text = str(int(vel * 3.6)) + " km/h\n" + \
					  str(round(height * 10)/10) + " m\n" + \
					  str(ground_effect) + "\n" + \
					  str(int(fps)) + " fps"