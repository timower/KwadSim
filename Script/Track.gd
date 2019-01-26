extends Spatial

signal track_changed

# objects: array of object dictionaries
var objects = []

# gates: array of references to objects, in order
var gates = []

var last_light = null

static func is_gate(obj: Dictionary) -> bool:
	return Globals.OBJECTS[obj.id].is_gate

func add_object(obj: Dictionary) -> int:
	var type = Globals.OBJECTS[obj.id]
	var inst = type.scene.instance()
	add_child(inst)
	
	inst.transform.origin = obj.pos
	inst.transform.basis = Basis(obj.rot)
	
	var ref = objects.size()
	objects.append(obj)
	
	emit_signal("track_changed")
	return ref

func add_gate(obj: Dictionary) -> int:
	assert(is_gate(obj))
	var ref = add_object(obj)
	gates.append(ref)
	emit_signal("track_changed")
	return ref

func clear():
	last_light = null
	gates = []
	objects = []
	
	for i in range(get_child_count()):
		get_child(i).queue_free()

func load_from(t_name: String):
	var f_name = Globals.TRACK_PATH + t_name + ".track"
	var file = File.new()
	
	if not file.file_exists(f_name):
		return false
		
	file.open(f_name, file.READ)
	var conts = file.get_var()
	file.close()
	
	clear()
	
	for obj in conts["objects"]:
		add_object(obj)
	
	gates = conts["gates"]
	emit_signal("track_changed")
	
	return true
	
func save_to(track_name: String):
	var file = File.new()
	file.open(Globals.TRACK_PATH + track_name + ".track", file.WRITE)
	file.store_var({
		"objects": objects,
		"gates": gates
	})
	file.close()

func light_object(ref: int):
	if last_light != null:
		last_light.visible = false
	last_light = get_child(ref).get_node("Light")
	last_light.visible = true

func light_gate(idx):
	light_object(gates[idx])

func swap_gate(idx1: int, idx2: int):
	var tmp = gates[idx1]
	gates[idx1] = gates[idx2]
	gates[idx2] = tmp
	
	emit_signal("track_changed")

func remove_object(ref: int):
	objects.remove(ref)
	get_child(ref).queue_free()

	var remove_last = false
	for i in range(gates.size()):
		if gates[i] == ref:
			remove_last = true

		# move gates after the removed gate forward
		if remove_last and i+1 < gates.size():
			gates[i] = gates[i + 1]
		
		# subtract one from all gates that ref to an object after ref
		if gates[i] > ref:
			gates[i] -= 1
			
	if remove_last:
		gates.pop_back()
		
	emit_signal("track_changed")

func change_pos(ref: int, pos: Vector3):
	objects[ref].pos = pos
	get_child(ref).transform.origin = pos

func change_rot(ref: int, rot: Vector3):
	objects[ref].rot = rot
	get_child(ref).transform.basis = Basis(rot)

func get_gate_ref(idx: int) -> int:
	return gates[idx]

func is_ref_gate(ref: int) -> bool:
	return is_gate(objects[ref])

func get_object_node(ref: int):
	return get_child(ref)

func get_gate_node(idx: int):
	return get_child(gates[idx])

func _ready():
	if Globals.selected_track != null:
		load_from(Globals.selected_track)
