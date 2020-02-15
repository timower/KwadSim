extends "res://addons/gut/test.gd"

var kwad_loader = null
var kwad = null

func before_all():
	kwad_loader = load("res://Nodes/Kwad/RemoteKwad.tscn").instance()
	get_tree().get_root().add_child(kwad_loader)
	kwad = kwad_loader.get_node("Kwad")

func after_all():
	get_tree().get_root().remove_child(kwad_loader)
	kwad_loader.free()

func test_connect():
	assert_false(kwad.connected, "start disconnected")
	yield(yield_for(0.1), YIELD)
	assert_true(kwad.connected, "connect fast")

func test_restart():
	assert_true(kwad.connected, "still connected")
	kwad.stop_server()
	OS.delay_msec(10)
	assert_false(kwad.connected, "kill disconnected")
	
	kwad.start_server()
	OS.delay_msec(10)
	kwad.connect_socket({"inverse_inertia": Vector3(1, 1, 1)})
	assert_true(kwad.connected, "still connected")

func test_timeout():
	assert_true(kwad.connected, "still connected")
	OS.kill(kwad.pid)
	kwad.pid = null
	
	yield(yield_for(0.1), YIELD)
	assert_true(kwad.connected, "reconnected")
