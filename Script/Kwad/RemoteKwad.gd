extends RigidBody

const SERVER_PATH = "res://Data/bin/kwadSimServer"
const MAX_CON_ATTEMPTS = 2

var udp_peer: PacketPeerUDP = null

var connected: bool = false

var crashed: bool = false

var osd_update = null

var pid = null

var osd_scene = preload("res://Nodes/Kwad/TileOSD.tscn")

var osd_tile = null
	
var rcData = [0.0, 0.0, 0.0, 0.0,
			  0.0, 0.0, 0.0, 0.0]

func get_server_path():
	var platform = OS.get_name()
	if platform == "Windows":
		return SERVER_PATH + ".exe"
	if platform == "OSX":
		return SERVER_PATH + ".osx"
	assert(platform == "X11" || platform == "Server")
	return SERVER_PATH + ".x11"

func new_rc_input(data):
	rcData = data

func start_server():
	udp_peer = PacketPeerUDP.new()
	udp_peer.set_dest_address("127.0.0.1", 7777)
	udp_peer.listen(6666)
	
	var path = ProjectSettings.globalize_path(get_server_path())
	
	Log.i("Starting kwadSimServer at: {}", path)
	pid = OS.execute(path, [], false)

func stop_server():
	udp_peer.put_packet("STOP".to_ascii())
	udp_peer.close()
	udp_peer = null
	
	connected = false
	
	if pid != null:
		Log.d("killing: {}", pid)
		OS.kill(pid)

func wait_for_packet():
	var k = 0
	while udp_peer.get_available_packet_count() == 0:
		OS.delay_msec(1)
		k += 1
		if k > 10:
			return false
	return true

func connect_socket(state):
	var motors_pos = [
		$motor1.translation, 
		$motor2.translation, 
		$motor3.translation, 
		$motor4.translation
	]
	
	var init_packet = [
		motor_kv, motor_R, motor_I0, 
		prop_max_rpm, prop_a_factor, prop_torque_factor, prop_inertia, prop_thrust_params, 
		frame_drag_area, frame_drag_constant, 
		self.mass, state.inverse_inertia, quad_vbat, motors_pos
	]
	
	var retries = 0
	while retries < MAX_CON_ATTEMPTS:
		Log.d("Sending init packet, attempt {}", retries)
		udp_peer.put_var(init_packet)
		
		if wait_for_packet():
			break
		
		retries += 1
	
	if retries >= MAX_CON_ATTEMPTS:
		Log.d("Max attempts reached, stopping server")
		stop_server()
		return
	
	connected = udp_peer.get_var()
	Log.i("CONNECTED: {}", connected)

# Create socket
func _ready():
	# Add the osd to the root to prevent the view shader from touching it.
	osd_tile = osd_scene.instance()
	var ui = Globals.get_ui()
	if ui != null:
		ui.add_child(osd_tile)
		ui.move_child(osd_tile, 0)
	

# Update OSD if needed:
func _process(_delta):
	if osd_update == null:
		return
	for y in range(16):
		for x in range(30):
			var c = osd_update[y * 30 + x]
			var tx = c % 36
			var ty = c / 36
			osd_tile.set_cell(x, y, 0, false, false, false, Vector2(tx, ty));
	osd_update = null

# connect, send state and receive update
func _integrate_forces(state):
	if udp_peer == null:
		start_server()
		return

	if not connected:
		connect_socket(state)
		return

	var packet = [
		state.step,
		transform.origin, 
		transform.basis, 
		state.angular_velocity, 
		state.linear_velocity, 
		rcData,
		crashed
	]
	
	udp_peer.put_var(packet)
	
	if not wait_for_packet():
		Log.d("state update timed out, restarting server...")
		stop_server()
		start_server()
		return
	
	var update_packet = udp_peer.get_var()
	state.angular_velocity = update_packet[0]
	state.linear_velocity  = update_packet[1]
	if len(update_packet) == 3:
		osd_update = update_packet[2]
		

func _enter_tree():
	start_server()

func _exit_tree():
	osd_tile.queue_free()
	stop_server()

# quad configuration, set by KwadLoader:
var motor_kv
var motor_R
var motor_I0

var prop_max_rpm
var prop_a_factor
var prop_torque_factor
var prop_inertia
var prop_thrust_params

var frame_drag_area
var frame_drag_constant

var quad_vbat

func set_motor_params(Kv, R, I0):
	self.motor_kv = Kv
	self.motor_R = R
	self.motor_I0 = I0
	
func set_prop_params(rpm, a, torque_fac, inertia, t_params):
	self.prop_max_rpm = rpm
	self.prop_a_factor = a
	self.prop_torque_factor = torque_fac
	self.prop_inertia = inertia
	self.prop_thrust_params = t_params
	
func set_frame_params(drag_area, drag_c):
	self.frame_drag_area = drag_area
	self.frame_drag_constant = drag_c
	
func set_quad_params(Vin):
	self.quad_vbat = Vin

func set_crashed(value):
	self.crashed = value

func has_crashed():
	return crashed