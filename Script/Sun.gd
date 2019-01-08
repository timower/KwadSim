extends DirectionalLight

func _ready():
	Globals.connect("settings_changed", self, "_settings_changed")
	_settings_changed()

func _settings_changed():
	shadow_enabled = Globals.shadows
