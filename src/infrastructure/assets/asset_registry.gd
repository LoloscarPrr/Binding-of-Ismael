extends RefCounted
class_name IsmaelAssetRegistry

const ITEM_TEXTURES := {
	"pickup:heart":"res://assets/items/pickups/heart.svg",
	"pickup:coin":"res://assets/items/pickups/coin.svg",
	"pickup:bomb":"res://assets/items/pickups/bomb.svg",
	"pickup:key":"res://assets/items/pickups/key.svg",
	"reward:vida":"res://assets/items/pickups/heart.svg",
	"reward:curacion":"res://assets/items/rewards/bandage.svg",
	"reward:movimiento":"res://assets/items/rewards/boots.svg",
	"reward:cadencia":"res://assets/items/rewards/watch.svg",
	"reward:proyectil":"res://assets/items/rewards/tear.svg",
	"reward:dano":"res://assets/items/rewards/red_eye.svg",
	"reward:buscadora":"res://assets/items/rewards/moth_eye.svg",
	"reward:perforante":"res://assets/items/rewards/needle.svg",
	"reward:escudo":"res://assets/items/rewards/rosary.svg",
	"reward:rafaga":"res://assets/items/rewards/glove.svg",
	"reward:mapa":"res://assets/items/rewards/map.svg",
	"reward:monedero":"res://assets/items/rewards/purse.svg"
}

static func texture_for(category: String, item_id: String) -> Texture2D:
	var key := "%s:%s" % [category,item_id]
	var path := String(ITEM_TEXTURES.get(key,""))
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var resource := load(path)
	return resource as Texture2D

static func configure_sprite(sprite: Sprite2D, category: String, item_id: String, target_size: float) -> bool:
	if not is_instance_valid(sprite):
		return false
	var texture := texture_for(category,item_id)
	if texture == null:
		sprite.texture = null
		sprite.visible = false
		return false
	sprite.texture = texture
	sprite.visible = true
	var texture_size := texture.get_size()
	var largest := maxf(texture_size.x,texture_size.y)
	var scale_factor := target_size/largest if largest > 0.0 else 1.0
	sprite.scale = Vector2.ONE*scale_factor
	return true
