extends RefCounted
class_name IsmaelControlLayoutRepository

const PATH := "user://control_layout.cfg"

func load_centers() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return {
			"left_center":Vector2(-1.0,-1.0),
			"right_center":Vector2(-1.0,-1.0)
		}
	return {
		"left_center":config.get_value("controls","left_center",Vector2(-1.0,-1.0)),
		"right_center":config.get_value("controls","right_center",Vector2(-1.0,-1.0))
	}

func save_centers(left_center: Vector2, right_center: Vector2) -> Error:
	var config := ConfigFile.new()
	config.set_value("controls","left_center",left_center)
	config.set_value("controls","right_center",right_center)
	return config.save(PATH)
