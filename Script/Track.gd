extends Spatial

signal track_changed

var scene_id = 0

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

func new_track():
	clear_track()
	add_object({
		pos = Vector3(),
		rot = Vector3(),
		id = 0
	})

func clear_track():
	for ref in range(objects.size()):
		get_object_node(ref).queue_free()
		
	last_light = null
	gates = []
	objects = []

	load_scene(0)

func load_from(t_name: String):
	var f_name = Globals.TRACK_PATH + t_name + ".track"
	var file = File.new()
	
	if not file.file_exists(f_name):
		return false
	
	file.open(f_name, file.READ)
	var conts = file.get_var()
	file.close()
	
	clear_track()
	
	for obj in conts["objects"]:
		add_object(obj)
	
	gates = conts["gates"]
	emit_signal("track_changed")
	
	if conts.has("scene"):
		load_scene(conts["scene"])
	else:
		load_scene(0)
	
	
	return true
	
func save_to(track_name: String):
	var file = File.new()
	file.open(Globals.TRACK_PATH + track_name + ".track", file.WRITE)
	file.store_var({
		"objects": objects,
		"gates": gates,
		"scene": scene_id
	})
	file.close()

func light_object(ref: int):
	if last_light != null:
		get_object_node(last_light).get_node("Light").visible = false
	get_object_node(ref).get_node("Light").visible = true
	last_light = ref

func light_gate(idx):
	light_object(gates[idx])

func swap_gate(idx1: int, idx2: int):
	var tmp = gates[idx1]
	gates[idx1] = gates[idx2]
	gates[idx2] = tmp
	
	emit_signal("track_changed")

func remove_object(ref: int):
	if ref == 0:
		return

	objects.remove(ref)
	get_object_node(ref).queue_free()

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
		
	if last_light == ref:
		last_light = null
		
	emit_signal("track_changed")

func change_pos(ref: int, pos: Vector3):
	objects[ref].pos = pos
	get_object_node(ref).transform.origin = pos

func change_rot(ref: int, rot: Vector3):
	objects[ref].rot = rot
	get_object_node(ref).transform.basis = Basis(rot)

func get_gate_ref(idx: int) -> int:
	return gates[idx]

func is_ref_gate(ref: int) -> bool:
	return is_gate(objects[ref])

func get_object_node(ref: int):
	return get_child(ref+1)

func get_gate_node(idx: int):
	return get_object_node(gates[idx])

func load_scene(id: int):
	scene_id = id
	for i in range($Scene.get_child_count()):
		$Scene.get_child(i).queue_free()
	var scene_inst = Globals.SCENES[id].scene.instance()
	$Scene.add_child(scene_inst)

func _ready():
	if Globals.selected_track != null:
		load_from(Globals.selected_track)
