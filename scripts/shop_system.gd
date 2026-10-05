extends Node

const ShopItemScript = preload("res://scripts/shop_item.gd")
const ShopConsumableItemScript = preload("res://scripts/shop_consumable_item.gd")
const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const ItemAssetView = preload("res://src/presentation/items/item_asset_view.gd")

var _scene_instance_id := 0
var _active_shop_key := ""
var _sold_items: Dictionary = {}

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene) or not scene.has_method("_get_room_kind"):
		return
	if scene.get_instance_id()!=_scene_instance_id:
		_scene_instance_id = scene.get_instance_id()
		_active_shop_key = ""
		_sold_items.clear()
	_try_open_shop(scene)

func _try_open_shop(scene: Node) -> void:
	if bool(scene.get("_game_over")) or bool(scene.get("_run_complete")):
		return
	if String(scene.get("_room_kind"))!="tienda":
		_active_shop_key = ""
		return
	var floor_index := int(scene.get("_floor_index"))
	var cell: Vector2i = scene.get("_current_cell")
	var shop_key := "%d:%d:%d" % [floor_index,cell.x,cell.y]
	if _active_shop_key==shop_key and not get_tree().get_nodes_in_group("shop_items").is_empty():
		return
	_active_shop_key = shop_key
	_prepare_shop(scene,floor_index,shop_key)

func _prepare_shop(scene: Node, floor_index: int, shop_key: String) -> void:
	if scene.has_method("_set_door_open"):
		scene.call("_set_door_open",true)
	if scene.has_method("_sync_room_visual"):
		scene.call("_sync_room_visual")
	var status_label = scene.get("status_label")
	if is_instance_valid(status_label):
		status_label.text = "TIENDA DEL ERRANTE"
	var reward_label = scene.get("reward_label")
	if is_instance_valid(reward_label):
		reward_label.text = "Mejoras arriba · recursos abajo · camina sobre un objeto para comprar"
	_spawn_shop_items(scene,floor_index,shop_key)
	scene.queue_redraw()

func _spawn_shop_items(scene: Node, floor_index: int, shop_key: String) -> void:
	var room_rect: Rect2 = scene.get("room_rect")
	var stock: Array[Dictionary] = ItemCatalog.shop_stock(floor_index)
	var slots: Array[Vector2] = [
		Vector2(0.28,0.35),Vector2(0.50,0.35),Vector2(0.72,0.35),
		Vector2(0.28,0.66),Vector2(0.50,0.66),Vector2(0.72,0.66)
	]
	for i in stock.size():
		if i >= slots.size():
			break
		var item_key := "%s:%d" % [shop_key,i]
		if bool(_sold_items.get(item_key,false)):
			continue
		var data: Dictionary = stock[i]
		var item_type := String(data.get("type","reward"))
		var item_id := String(data.get("reward",""))
		var item = ShopConsumableItemScript.new() if item_type=="pickup" else ShopItemScript.new()
		item.configure(item_id,int(data["cost"]),String(data["name"]))
		item.position = room_rect.position+room_rect.size*slots[i]
		item.purchase_requested.connect(_on_purchase_requested.bind(item_key,item_type,item_id))
		ItemAssetView.attach(item,item_type,item_id,60.0,Vector2(0,-7),3)
		scene.add_child(item)

func _on_purchase_requested(item, item_key: String, item_type: String, item_id: String) -> void:
	if not is_instance_valid(item) or item.sold:
		return
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return

	# Un corazón de tienda cura; no debe cobrar si Ismael ya está a vida completa.
	if item_type=="pickup" and item_id=="heart" and not _player_needs_health(scene):
		var full_status = scene.get("status_label")
		if is_instance_valid(full_status):
			full_status.text = "VIDA LLENA"
		var full_reward = scene.get("reward_label")
		if is_instance_valid(full_reward):
			full_reward.text = "No gastaste monedas · vuelve si recibes daño"
		return

	var coins := _scene_coin_count(scene)
	if coins<int(item.cost):
		var missing := int(item.cost)-coins
		var status_label = scene.get("status_label")
		if is_instance_valid(status_label):
			status_label.text = "TE FALTAN %d MONEDAS" % missing
		item.show_unaffordable()
		return
	if not _spend_scene_coins(scene,int(item.cost)):
		item.show_unaffordable()
		return

	if item_type=="pickup":
		if scene.has_method("_on_pickup_collected"):
			scene.call("_on_pickup_collected",item_id)
	else:
		if scene.has_method("_apply_reward"):
			scene.call("_apply_reward",item_id)

	_sold_items[item_key] = true
	item.mark_sold()
	var status_label = scene.get("status_label")
	if is_instance_valid(status_label):
		status_label.text = "COMPRA REALIZADA"
	var reward_label = scene.get("reward_label")
	if is_instance_valid(reward_label):
		var purchase_name := String(item.display_name)
		if item_type=="reward" and scene.has_method("_reward_name"):
			purchase_name = String(scene.call("_reward_name",item_id)).replace("\n"," — ")
		elif item_type=="pickup":
			purchase_name = _pickup_purchase_text(item_id)
		reward_label.text = "%s   ·   QUEDAN ¢ %d" % [purchase_name,_scene_coin_count(scene)]

func _player_needs_health(scene: Node) -> bool:
	var player = scene.get("player")
	if not is_instance_valid(player):
		return true
	return int(player.get("health")) < int(player.get("max_health"))

func _pickup_purchase_text(item_id: String) -> String:
	match item_id:
		"heart": return "CORAZÓN — VIDA RECUPERADA"
		"bomb": return "BOMBA — +1 BOMBA"
		"key": return "LLAVE — +1 LLAVE"
		_: return ItemCatalog.pickup_name(item_id)

func _scene_coin_count(scene: Node) -> int:
	if scene.has_method("get_run_coins"):
		return int(scene.call("get_run_coins"))
	return int(scene.get("_coins"))

func _spend_scene_coins(scene: Node, amount: int) -> bool:
	if scene.has_method("spend_run_coins"):
		return bool(scene.call("spend_run_coins",amount))
	var coins := int(scene.get("_coins"))
	if coins<amount:
		return false
	scene.set("_coins",coins-amount)
	if scene.has_method("_update_pickup_hud"):
		scene.call("_update_pickup_hud")
	return true
