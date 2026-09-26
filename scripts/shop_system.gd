extends Node

const ShopItemScript = preload("res://scripts/shop_item.gd")
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
		reward_label.text = "Acércate a un objeto para comprarlo"
	_spawn_shop_items(scene,floor_index,shop_key)
	scene.queue_redraw()

func _spawn_shop_items(scene: Node, floor_index: int, shop_key: String) -> void:
	var room_rect: Rect2 = scene.get("room_rect")
	var stock: Array[Dictionary] = ItemCatalog.shop_stock(floor_index)
	var x_slots: Array[float] = [0.31,0.50,0.69]
	for i in stock.size():
		var item_key := "%s:%d" % [shop_key,i]
		if bool(_sold_items.get(item_key,false)):
			continue
		var data: Dictionary = stock[i]
		var item = ShopItemScript.new()
		var reward_id := String(data["reward"])
		item.configure(reward_id,int(data["cost"]),String(data["name"]))
		item.position = room_rect.position+room_rect.size*Vector2(x_slots[i],0.47)
		item.purchase_requested.connect(_on_purchase_requested.bind(item_key))
		ItemAssetView.attach(item,"reward",reward_id,66.0,Vector2(0,-7),3)
		scene.add_child(item)

func _on_purchase_requested(item, item_key: String) -> void:
	if not is_instance_valid(item) or item.sold:
		return
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
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
	if scene.has_method("_apply_reward"):
		scene.call("_apply_reward",String(item.reward_id))
	_sold_items[item_key] = true
	item.mark_sold()
	var status_label = scene.get("status_label")
	if is_instance_valid(status_label):
		status_label.text = "COMPRA REALIZADA"
	var reward_label = scene.get("reward_label")
	if is_instance_valid(reward_label):
		var reward_name := String(item.display_name)
		if scene.has_method("_reward_name"):
			reward_name = String(scene.call("_reward_name",String(item.reward_id))).replace("\n"," — ")
		reward_label.text = "%s   ·   QUEDAN ¢ %d" % [reward_name,_scene_coin_count(scene)]

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
