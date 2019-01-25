extends Spatial

signal track_changed

var gates = []

var last_light = null

func add_gate(gate_dict):
	var id = gate_dict.id
	var pos = gate_dict.pos
	var rot = gate_dict.rot
	
	var inst = Globals.GATES[id].scene.instance()
	add_child(inst)
	
	inst.transform.origin = pos
	inst.transform.basis = Basis(rot)
	
	gates.append(gate_dict)
	emit_signal("track_changed")

func clear():
	gates = []
	for i in range(get_child_count()):
		get_child(i).queue_free()

func load_from(t_name):
	var f_name = Globals.TRACK_PATH + t_name + ".track"
	var file = File.new()
	
	if not file.file_exists(f_name):
		return false
		
	file.open(f_name, file.READ)
	var conts = file.get_var()
	file.close()
	
	clear()
	
	for gate in conts["gates"]:
		add_gate(gate)
	return true

func light_gate(idx):
	if last_light != null:
		get_child(last_light).get_node("Light").visible = false
	get_child(idx).get_node("Light").visible = true
	last_light = idx
	
func save_to(track_name):
	var file = File.new()
	file.open(Globals.TRACK_PATH + track_name + ".track", file.WRITE)
	file.store_var({"gates": gates})
	file.close()

func swap_gate(idx1, idx2):
	var tmp = gates[idx1]
	gates[idx1] = gates[idx2]
	gates[idx2] = tmp
	
	var n1 = get_child(idx1)
	var n2 = get_child(idx2)
	move_child(n1, idx2)
	move_child(n2, idx1)
	
	if last_light == idx1:
		last_light = idx2
	elif last_light == idx2:
		last_light = idx1
	
	emit_signal("track_changed")

func remove_gate(idx):
	gates.remove(idx)
	get_child(idx).queue_free()
	emit_signal("track_changed")

func change_pos(idx, pos):
	gates[idx].pos = pos
	get_child(idx).transform.origin = pos

func change_rot(idx, rot):
	gates[idx].rot = rot
	get_child(idx).transform.basis = Basis(rot)

func _ready():
	if Globals.selected_track != null:
		print(Globals.selected_track)
		load_from(Globals.selected_track)
