extends Node

const CLEAR_ROOM_COIN_REWARD := 3
const ShopItemScript = preload("res://scripts/shop_item.gd")

var _scene_instance_id := 0
var _last_cleared_total := 0
var _active_shop_key := ""
var _sold_items: Dictionary = {}

func _process(_delta: float) -> void:
	var scene := get_tree().current_scene
	if not is_instance_valid(scene) or not scene.has_method("_get_room_kind"):
		return

	if scene.get_instance_id() != _scene_instance_id:
		_scene_instance_id = scene.get_instance_id()
		_last_cleared_total = int(scene.get("_rooms_cleared_total"))
		_active_shop_key = ""
		_sold_items.clear()

	_reward_cleared_rooms(scene)
	_try_open_shop(scene)

func _reward_cleared_rooms(scene: Node) -> void:
	var cleared_total := int(scene.get("_rooms_cleared_total"))
	if cleared_total <= _last_cleared_total:
		return
	var newly_cleared := cleared_total-_last_cleared_total
	_last_cleared_total = cleared_total
	var coins := int(scene.get("_coins"))+newly_cleared*CLEAR_ROOM_COIN_REWARD
	scene.set("_coins",coins)
	if scene.has_method("_update_pickup_hud"):
		scene.call("_update_pickup_hud")

func _try_open_shop(scene: Node) -> void:
	if bool(scene.get("_game_over")) or bool(scene.get("_run_complete")):
		return
	if String(scene.get("_room_kind")) != "tienda":
		_active_shop_key = ""
		return

	var floor_index := int(scene.get("_floor_index"))
	var cell: Vector2i = scene.get("_current_cell")
	var shop_key := "%d:%d:%d" % [floor_index,cell.x,cell.y]
	if _active_shop_key == shop_key and not get_tree().get_nodes_in_group("shop_items").is_empty():
		return
	_active_shop_key = shop_key
	_prepare_shop(scene,floor_index,shop_key)

func _prepare_shop(scene: Node,floor_index: int,shop_key: String) -> void:
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

func _spawn_shop_items(scene: Node,floor_index: int,shop_key: String) -> void:
	var room_rect: Rect2 = scene.get("room_rect")
	var stock: Array[Dictionary]
	if floor_index == 1:
		stock = [
			{"reward":"curacion","cost":3,"name":"VENDA"},
			{"reward":"cadencia","cost":5,"name":"PULSO"},
			{"reward":"dano","cost":7,"name":"MARCA"}
		]
	else:
		stock = [
			{"reward":"movimiento","cost":4,"name":"PASO"},
			{"reward":"proyectil","cost":5,"name":"IMPULSO"},
			{"reward":"vida","cost":7,"name":"CORAZÓN"}
		]

	var x_slots: Array[float] = [0.31,0.50,0.69]
	for i in stock.size():
		var item_key := "%s:%d" % [shop_key,i]
		if bool(_sold_items.get(item_key,false)):
			continue
		var data: Dictionary = stock[i]
		var item = ShopItemScript.new()
		item.configure(String(data["reward"]),int(data["cost"]),String(data["name"]))
		item.position = room_rect.position+room_rect.size*Vector2(x_slots[i],0.47)
		item.purchase_requested.connect(_on_purchase_requested.bind(item_key))
		scene.add_child(item)

func _on_purchase_requested(item,item_key: String) -> void:
	if not is_instance_valid(item) or item.sold:
		return
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var coins := int(scene.get("_coins"))
	if coins < int(item.cost):
		var missing: int = int(item.cost)-coins
		var status_label = scene.get("status_label")
		if is_instance_valid(status_label):
			status_label.text = "TE FALTAN %d MONEDAS" % missing
		item.show_unaffordable()
		return

	scene.set("_coins",coins-int(item.cost))
	if scene.has_method("_apply_reward"):
		scene.call("_apply_reward",String(item.reward_id))
	if scene.has_method("_update_pickup_hud"):
		scene.call("_update_pickup_hud")
	_sold_items[item_key] = true
	item.mark_sold()
	var status_label = scene.get("status_label")
	if is_instance_valid(status_label):
		status_label.text = "COMPRA REALIZADA"
	var reward_label = scene.get("reward_label")
	if is_instance_valid(reward_label):
		var reward_name: String = String(item.display_name)
		if scene.has_method("_reward_name"):
			reward_name = String(scene.call("_reward_name",String(item.reward_id))).replace("\n"," — ")
		reward_label.text = "%s   ·   QUEDAN ¢ %d" % [reward_name,int(scene.get("_coins"))]
