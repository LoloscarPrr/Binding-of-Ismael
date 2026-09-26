extends RefCounted
class_name IsmaelItemAssetView

const AssetRegistry = preload("res://src/infrastructure/assets/asset_registry.gd")

static func attach(host: Node2D, category: String, item_id: String, target_size: float, offset := Vector2.ZERO, draw_order := 2) -> Sprite2D:
	if not is_instance_valid(host):
		return null
	var sprite := Sprite2D.new()
	sprite.position = offset
	sprite.z_index = draw_order
	if not AssetRegistry.configure_sprite(sprite,category,item_id,target_size):
		sprite.queue_free()
		return null
	host.add_child(sprite)
	return sprite
