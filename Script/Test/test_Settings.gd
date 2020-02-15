extends "res://addons/gut/test.gd"

const TEMP_PATH = "user://temp.conf"

var settings = null

func before_each():
	settings = partial_double("res://Script/Settings/SettingsModel.gd").new()
	stub(settings, 'get_path').to_return(TEMP_PATH)
	settings._ready()

func after_each():
	settings.free()

	var dir = Directory.new()
	if dir.file_exists(TEMP_PATH):
		dir.remove(TEMP_PATH)
	
func test_get_path():
	# make sure the stubbing works
	assert_eq(settings.get_path(), TEMP_PATH)

func test_save():
	assert_eq(settings.settings.sound.volume, 25)
	settings.save()
	settings.settings.sound.volume = 1337
	settings.read()
	assert_eq(settings.settings.sound.volume, 25)
	
	settings.settings.sound.volume = 1337
	settings.save()
	settings.read()
	assert_eq(settings.settings.sound.volume, 1337)
	
