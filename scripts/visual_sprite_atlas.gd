extends RefCounted
class_name IsmaelVisualSpriteAtlas

# SVG originales conservados como fuentes editables.
# Godot 4.3 exporta los SVG como archivos raw y los rasteriza UNA VEZ
# mediante Image.load_svg_from_buffer; luego ImageTexture queda cacheada.
# Evita preloads de SVG dependientes del importador en Android headless.
static var _textures: Dictionary = {}

static func _texture(file_stem: String) -> Texture2D:
	if _textures.has(file_stem):
		return _textures[file_stem] as Texture2D
	var file_path := "res://assets/art/phase12/%s.svg" % file_stem
	var bytes := FileAccess.get_file_as_bytes(file_path)
	if bytes.is_empty():
		push_error("Arte Fase 12 no incluido en APK: " + file_path)
		return null
	var raster := Image.new()
	var error_code := raster.load_svg_from_buffer(bytes,1.0)
	if error_code != OK:
		push_error("No se pudo rasterizar " + file_path + ": " + str(error_code))
		return null
	var bitmap := ImageTexture.create_from_image(raster)
	_textures[file_stem] = bitmap
	return bitmap

static func player_texture(moving: bool, age_seconds: float) -> Texture2D:
	if not moving:
		return _texture("ismael_idle")
	return _texture("ismael_stride_a" if posmod(int(age_seconds*8.0),2)==0 else "ismael_stride_b")

static func enemy_texture(kind_id: String) -> Texture2D:
	var id := kind_id if kind_id in ["chaser","dasher","orbiter","brute","spitter","stalker"] else "chaser"
	return _texture("enemy_"+id)

static func boss_texture(floor_index: int) -> Texture2D:
	var titles: Array[String] = ["carcelero","mandibula","vigia","sepulturero","hueco"]
	return _texture("boss_"+titles[clampi(floor_index,1,5)-1])

static func cached_texture_count() -> int:
	return _textures.size()

static func player_draw_rect() -> Rect2:
	return Rect2(-43.0,-49.0,86.0,86.0)

static func enemy_draw_rect(kind_id: String) -> Rect2:
	match kind_id:
		"brute": return Rect2(-38.0,-39.0,76.0,76.0)
		"stalker": return Rect2(-31.0,-33.0,62.0,65.0)
	return Rect2(-34.0,-37.0,68.0,70.0)

static func boss_draw_rect() -> Rect2:
	return Rect2(-77.0,-82.0,154.0,154.0)
