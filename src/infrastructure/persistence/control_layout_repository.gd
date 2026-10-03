extends RefCounted
class_name IsmaelControlLayoutRepository

const PATH := "user://control_layout.cfg"

func load_layout() -> Dictionary:
	var config := ConfigFile.new()
	if config.load(PATH) != OK:
		return {
			"left_center":Vector2(-1.0,-1.0),
			"right_center":Vector2(-1.0,-1.0),
			"left_size_ratio":-1.0,
			"right_size_ratio":-1.0,
			"bomb_center_ratio":Vector2(-1.0,-1.0),
			"bomb_size_ratio":-1.0
		}
	return {
		"left_center":config.get_value("controls","left_center",Vector2(-1.0,-1.0)),
		"right_center":config.get_value("controls","right_center",Vector2(-1.0,-1.0)),
		"left_size_ratio":float(config.get_value("controls","left_size_ratio",-1.0)),
		"right_size_ratio":float(config.get_value("controls","right_size_ratio",-1.0)),
		"bomb_center_ratio":config.get_value("controls","bomb_center_ratio",Vector2(-1.0,-1.0)),
		"bomb_size_ratio":float(config.get_value("controls","bomb_size_ratio",-1.0))
	}

func load_centers() -> Dictionary:
	# Backwards-compatible entry point used by older Presentation controllers.
	return load_layout()

func save_layout(
	left_center: Vector2,
	right_center: Vector2,
	left_size_ratio: float,
	right_size_ratio: float
) -> Error:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("controls","left_center",left_center)
	config.set_value("controls","right_center",right_center)
	config.set_value("controls","left_size_ratio",left_size_ratio)
	config.set_value("controls","right_size_ratio",right_size_ratio)
	return config.save(PATH)

func save_centers(left_center: Vector2, right_center: Vector2) -> Error:
	# Preserve any custom stick sizes when legacy callers only update positions.
	var stored := load_layout()
	return save_layout(
		left_center,
		right_center,
		float(stored.get("left_size_ratio",-1.0)),
		float(stored.get("right_size_ratio",-1.0))
	)

func save_bomb_layout(center_ratio: Vector2, size_ratio: float) -> Error:
	var config := ConfigFile.new()
	config.load(PATH)
	config.set_value("controls","bomb_center_ratio",center_ratio)
	config.set_value("controls","bomb_size_ratio",size_ratio)
	return config.save(PATH)
