extends "res://scripts/main.gd"

var room_visual: IsmaelRoomVisual
var boss_hud: IsmaelBossHud

func _ready() -> void:
	room_visual = IsmaelRoomVisual.new()
	room_visual.z_index = -20
	add_child(room_visual)
	super._ready()
	_sync_room_visual()

func _begin_room(from_door: bool) -> void:
	if is_instance_valid(boss_hud):
		boss_hud.hide_boss()
	super._begin_room(from_door)
	_sync_room_visual()

func _create_touch_ui() -> void:
	super._create_touch_ui()
	var layer := hud_backdrop.get_parent()
	if is_instance_valid(reward_left):
		reward_left.queue_free()
	if is_instance_valid(reward_right):
		reward_right.queue_free()
	reward_left = IsmaelRewardPedestal.new()
	reward_left.visible = false
	reward_left.pressed.connect(_choose_reward.bind(0))
	layer.add_child(reward_left)
	reward_right = IsmaelRewardPedestal.new()
	reward_right.visible = false
	reward_right.pressed.connect(_choose_reward.bind(1))
	layer.add_child(reward_right)
	boss_hud = IsmaelBossHud.new()
	layer.add_child(boss_hud)

func _layout_touch_ui() -> void:
	super._layout_touch_ui()
	if not is_instance_valid(boss_hud):
		return
	var screen_size := get_viewport_rect().size
	var width := clampf(screen_size.x * 0.48, 520.0, 820.0)
	boss_hud.size = Vector2(width, 78.0)
	boss_hud.position = Vector2(screen_size.x * 0.5 - width * 0.5, screen_size.y - 102.0)

func _spawn_boss() -> void:
	super._spawn_boss()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is IsmaelEnemy and enemy.kind == IsmaelEnemy.EnemyKind.BOSS:
			if not enemy.health_changed.is_connected(_on_boss_health_changed):
				enemy.health_changed.connect(_on_boss_health_changed)
			if is_instance_valid(boss_hud):
				boss_hud.show_boss("GUARDIÁN DEL PISO", enemy.health)
			break

func _on_boss_health_changed(current: int, maximum: int) -> void:
	if not is_instance_valid(boss_hud):
		return
	if boss_hud.max_health != maximum:
		boss_hud.max_health = maximum
	boss_hud.set_health(current)

func _on_enemy_defeated(enemy) -> void:
	var was_boss: bool = enemy is IsmaelEnemy and enemy.kind == IsmaelEnemy.EnemyKind.BOSS
	super._on_enemy_defeated(enemy)
	if was_boss and is_instance_valid(boss_hud):
		boss_hud.hide_boss()

func _on_viewport_size_changed() -> void:
	super._on_viewport_size_changed()
	_sync_room_visual()

func _sync_room_visual() -> void:
	if is_instance_valid(room_visual):
		room_visual.configure(room_rect, _room_kind, _floor_index, _room_index)

func _draw() -> void:
	# La v2 delega el escenario a IsmaelRoomVisual para separar presentación y gameplay.
	pass
