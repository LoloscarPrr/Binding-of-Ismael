extends RefCounted
class_name IsmaelVisualSpriteAtlas

# SVG originales conservados como fuentes editables en GitHub.
# Godot 4.3 los importa a .ctex y ResourceLoader abre la textura exportada.
# Se almacena una referencia por personaje para evitar recargas en Android.
static var _textures: Dictionary = {}

static func _texture(file_stem: String) -> Texture2D:
	if _textures.has(file_stem):
		return _textures[file_stem] as Texture2D
	var file_path := "res://assets/art/phase12/%s.svg" % file_stem
	if not ResourceLoader.exists(file_path):
		push_error("Falta textura importada de Fase 12: " + file_path)
		return null
	var bitmap := ResourceLoader.load(file_path) as Texture2D
	if bitmap == null:
		push_error("La ilustración no se cargó como Texture2D: " + file_path)
		return null
	_textures[file_stem] = bitmap
	return bitmap

static func player_texture(moving: bool, age_seconds: float) -> Texture2D:
	if not moving:
		return _texture("ismael_idle")
	return _texture("ismael_stride_a" if posmod(int(age_seconds*8.0),2)==0 else "ismael_stride_b")

static func enemy_texture(kind_id: String) -> Texture2D:
	var id := kind_id if kind_id in ["chaser","dasher","orbiter","brute","spitter","stalker","flyer","turret","leaper"] else "chaser"
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
