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

var init_packet = Packets.InitPacket.new()

var update_packet = Packets.StateUpdatePacket.new()
var osd_update_packet = Packets.StateOsdUpdatePacket.new()

var state_packet = Packets.StatePacket.new()
	
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
	# We can't do this in _ready as the position is set by the loader whos 
	# ready will be called after ours.
	init_packet.quad_motor_pos = [
		$motor1.translation, 
		$motor2.translation, 
		$motor3.translation, 
		$motor4.translation
	]
	
	init_packet.quad_mass = self.mass
	init_packet.quad_inv_inertia = state.inverse_inertia
	
	var retries = 0
	while retries < MAX_CON_ATTEMPTS:
		Log.d("Sending init packet, attempt {}", retries)
		udp_peer.put_var(init_packet.to_list())
		
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

	state_packet.delta = state.step
	state_packet.position = transform.origin
	state_packet.rotation = transform.basis 
	state_packet.angularVelocity = state.angular_velocity
	state_packet.linearVelocity = state.linear_velocity 
	state_packet.rcData = rcData
	state_packet.crashed = crashed
	
	udp_peer.put_var(state_packet.to_list())
	
	if not wait_for_packet():
		Log.d("state update timed out, restarting server...")
		stop_server()
		start_server()
		return
	
	var update = udp_peer.get_var()
	if len(update) == 3:
		osd_update_packet.from_list(update)
		update = osd_update_packet
		osd_update = osd_update_packet.osd
	else:
		update_packet.from_list(update)
		update = update_packet

	state.angular_velocity = update.angularVelocity
	state.linear_velocity  = update.linearVelocity

func _enter_tree():
	start_server()

func _exit_tree():
	osd_tile.queue_free()
	stop_server()
	
	init_packet.free()
	update_packet.free()
	osd_update_packet.free()
	state_packet.free()

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
	init_packet.motor_kv = Kv
	init_packet.motor_R = R
	init_packet.motor_I0 = I0
	
func set_prop_params(rpm, a, torque_fac, inertia, t_params):
	init_packet.prop_max_rpm = rpm
	init_packet.prop_a_factor = a
	init_packet.prop_torque_factor = torque_fac
	init_packet.prop_inertia = inertia
	init_packet.prop_thrust_factors = t_params
	
func set_frame_params(drag_area, drag_c):
	init_packet.frame_drag_area = drag_area
	init_packet.frame_drag_constant = drag_c
	
func set_quad_params(Vin):
	init_packet.quad_vbat = Vin

func set_crashed(value):
	self.crashed = value

func has_crashed():
	return crashed
