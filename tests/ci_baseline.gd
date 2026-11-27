extends SceneTree

# Baseline contracts: read-only with respect to gameplay and user://.
const DungeonMap = preload("res://scripts/dungeon_map.gd")
const FloorCatalog = preload("res://src/domain/run/floor_catalog.gd")
const BossSeals = preload("res://src/domain/run/boss_seal_catalog.gd")
const RunProgress = preload("res://src/domain/run/run_progress.gd")
const Inventory = preload("res://src/domain/run/run_inventory.gd")
const Loot = preload("res://src/domain/run/room_loot_state.gd")
const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("BASELINE FAIL: " + description)

func _run() -> void:
	_check(FloorCatalog.TOTAL_FLOORS == 7, "Seven playable floors")
	var progress = RunProgress.new()
	for floor_number in range(1, 8):
		progress.boss_defeats[str(floor_number)] = 1
		_check(progress.boss_seals_discovered() == mini(floor_number, 5), "Original seals P%d" % floor_number)
		_check(not FloorCatalog.boss_name(floor_number).is_empty(), "Guardian P%d" % floor_number)
		for reward in BossSeals.reward_choices(floor_number, 812):
			_check(ItemCatalog.reward_ids().has(reward), "Valid guardian reward: " + reward)
		for sample in range(40):
			_test_map(floor_number, sample)
	_test_inventory()
	_test_loot()
	if failures == 0:
		print("BASELINE PASS: %d checks; 280 generated maps" % checks)
		quit(0)
	else:
		printerr("BASELINE FAIL: %d of %d checks failed" % [failures, checks])
		quit(1)

func _test_map(floor_number: int, sample: int) -> void:
	var dungeon = DungeonMap.new()
	dungeon.generate(floor_number)
	var context := "P%d sample %d seed %s" % [floor_number, sample, str(dungeon.seed_value)]
	_check(dungeon.has_room(Vector2i.ZERO), context + " start exists")
	_check(dungeon.kind(Vector2i.ZERO) == "inicio", context + " start kind")
	_check(dungeon.is_discovered(Vector2i.ZERO), context + " start discovered")
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var visited: Dictionary = {Vector2i.ZERO: true}
	var boss_count := 0
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if dungeon.kind(cell) == "jefe":
			boss_count += 1
		for next: Vector2i in dungeon.neighbors(cell):
			if dungeon.is_hidden(next) or visited.has(next):
				continue
			visited[next] = true
			queue.append(next)
	_check(visited.size() == dungeon.public_room_count(), context + " public rooms connected")
	_check(boss_count == 1, context + " one reachable guardian")
	_check(dungeon.order.size() == dungeon.room_count(), context + " order consistent")
	var unique: Dictionary = {}
	for cell: Vector2i in dungeon.order:
		unique[cell] = true
		if dungeon.is_hidden(cell):
			_check(not dungeon.is_discovered(cell), context + " hidden room remains hidden")
	_check(unique.size() == dungeon.room_count(), context + " unique room coordinates")
	# Re-entering a cleared room must retain its cleared state.
	dungeon.set_cleared(Vector2i.ZERO)
	dungeon.mark_entered(Vector2i.ZERO)
	_check(dungeon.is_cleared(Vector2i.ZERO), context + " clear state retained")

func _test_inventory() -> void:
	var inv = Inventory.new()
	inv.add_coins(3)
	_check(not inv.spend_coins(4) and inv.coins == 3, "Insufficient coins unchanged")
	_check(not inv.spend_coins(-1) and inv.coins == 3, "Negative purchase rejected")
	_check(inv.spend_coins(2) and inv.coins == 1, "Purchase debits exactly once")
	inv.add_keys(1)
	_check(inv.spend_keys(1) and not inv.spend_keys(1) and inv.keys == 0, "Key cannot be spent twice")
	inv.add_bombs(-3)
	_check(inv.bombs == 0, "Bomb count nonnegative")

func _test_loot() -> void:
	var loot = Loot.new()
	var first: int = loot.register_pickup("1:0,0", "coin", Vector2(0.5, 0.5))
	var second: int = loot.register_pickup("1:0,1", "heart", Vector2(0.3, 0.5))
	_check(first != second, "Unique pickup IDs")
	var copy: Array = loot.pending_pickups("1:0,0")
	copy[0]["kind"] = "bomb"
	_check(loot.pending_pickups("1:0,0")[0]["kind"] == "coin", "Loot snapshot isolated")
	loot.consume_pickup("1:0,0", first)
	loot.consume_pickup("1:0,0", first)
	_check(not loot.has_pending_pickups("1:0,0") and loot.has_pending_pickups("1:0,1"), "Consumed pickup stays gone; other rooms unaffected")
	var chest: int = loot.register_chest("1:0,0", "normal", Vector2(0.5, 0.5))
	loot.mark_chest_opened("1:0,0")
	loot.mark_chest_loot_spawned("1:0,0")
	_check(chest == loot.register_chest("1:0,0", "normal", Vector2.ZERO), "Revisiting chest retains identity")
	var state: Dictionary = loot.chest_state("1:0,0")
	_check(bool(state.get("opened", false)) and bool(state.get("loot_spawned", false)), "Chest cannot reset its state on revisit")
