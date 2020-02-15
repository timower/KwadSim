extends "res://addons/gut/test.gd"

func test_default_quads():
	assert_gt(len(Globals.quads), 2)
	assert_has(Globals.quads, "TWE210")

func test_reset():
	watch_signals(Globals)
	Globals.reset()
	
	var ev = InputEventAction.new()
	ev.action = "reset"
	ev.pressed = true
	Input.parse_input_event(ev)
	
	yield(yield_to(Globals, "reset", 0.02), YIELD)
	assert_signal_emit_count(Globals, "reset", 2)

func test_read_json():
	assert_null(Globals.read_json("non_existant.json"))
	var j = Globals.read_json("res://Script/Test/Inputs/test.json")
	assert_not_null(j)
	assert_has(j, "test")
	assert_eq(j["test"], 12.0)

func test_list_dir():
	assert_null(Globals.list_dir("non_existant"))
	var root = Globals.list_dir("res://")
	assert_gt(len(root), 0)
	assert_has(root, "README")
	assert_has(root, "icon")

func test_get_tracks():
	var tracks = Globals.get_tracks()
	assert_not_null(tracks)
	assert_gt(len(tracks), 0)
	
	var dir = Directory.new()
	assert_true(dir.dir_exists(Globals.TRACK_PATH))

func test_first_of_group():
	assert_null(Globals._get_first_of_group("empty"))
	assert_null(Globals._get_first_of_group("Kwad"))
	
	var node = Node.new()
	get_tree().get_root().add_child(node)
	node.add_to_group("Kwad")
	assert_true(node.is_in_group("Kwad"))
	
	assert_eq(Globals._get_first_of_group("Kwad"), node)
	assert_null(Globals._get_first_of_group("empty"))
	
	node.free()
	
	assert_null(Globals._get_first_of_group("Kwad"))
