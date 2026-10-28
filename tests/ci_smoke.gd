extends SceneTree

# Pruebas de humo sin interfaz: se ejecutan antes de exportar el APK.
# No abren ni escriben perfiles reales del usuario.
const ItemCatalog = preload("res://src/domain/items/item_catalog.gd")
const FloorCatalog = preload("res://src/domain/run/floor_catalog.gd")
const RunProgress = preload("res://src/domain/run/run_progress.gd")
const Player = preload("res://scripts/player.gd")
const BossSeals = preload("res://src/domain/run/boss_seal_catalog.gd")
const BossMechanicZone = preload("res://scripts/boss_mechanic_zone.gd")
const AdvancedEnemy = preload("res://scripts/advanced_enemy.gd")
const BossPhases = preload("res://src/domain/run/boss_phase_profile.gd")
const BossHud = preload("res://scripts/boss_hud.gd")
const ShopSystem = preload("res://scripts/shop_system.gd")
const FloorController = preload("res://src/presentation/game/mobile_floor_expansion_controller.gd")
const ObstacleNavigator = preload("res://scripts/enemy_obstacle_navigator.gd")
const EnemyActor = preload("res://scripts/enemy.gd")
const SolidRoomObstacle = preload("res://scripts/room_obstacle.gd")
const GuardianEchoCatalog = preload("res://src/domain/run/guardian_echo_catalog.gd")
const GuardianEchoElite = preload("res://scripts/guardian_echo_elite.gd")
const BuildBalance = preload("res://src/domain/items/build_balance.gd")
const VisualSprites = preload("res://scripts/visual_sprite_atlas.gd")
const SecretRunCatalog = preload("res://src/domain/run/secret_run_catalog.gd")
const MobileSideHud = preload("res://src/presentation/hud/mobile_combat_side_hud.gd")
const PlayerProjectile = preload("res://scripts/projectile.gd")

var _errors: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run_tests")

func _assert(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)
		printerr("QA FAIL: " + message)

func _run_tests() -> void:
	_test_item_definitions()
	_test_visual_art_phase12()
	_test_transparent_hud_and_blue_hearts()
	_test_projectile_readability()
	_test_build_balance()
	_test_floor_rosters()
	_test_metaprogression()
	_test_boss_seals()
	_test_boss_mechanics()
	_test_boss_phases()
	_test_guardian_echoes()
	_test_secrets_and_anomalies()
	_test_shop_layout_and_guardian_spawns()
	_test_enemy_obstacle_navigation()
	await _test_enemy_pathfinding_in_physics()
	_test_shot_cancellation()
	if _errors.is_empty():
		print("QA PASS: %d checks" % _checks)
		quit(0)
	else:
		printerr("QA FAIL: %d of %d checks failed" % [_errors.size(),_checks])
		quit(1)

func _test_item_definitions() -> void:
	var ids: Array[String] = ItemCatalog.reward_ids()
	_assert(ids.size() >= 23,"Se perdieron recompensas del catálogo")
	var seen: Dictionary = {}
	for id in ids:
		_assert(not seen.has(id),"Reliquia repetida: " + id)
		seen[id] = true
		var definition: Dictionary = ItemCatalog.reward_definition(id)
		_assert(not String(definition.get("effect","")).is_empty(),"Reliquia sin efecto: " + id)
	for id in ["eco_fragil","reloj_ceniza","colmillo_ritual"]:
		_assert(ids.has(id),"Falta reliquia meta: " + id)
	var synergy: Dictionary = ItemCatalog.synergy_definition("eco_sangrante")
	_assert(not synergy.is_empty(),"Se perdió sinergia Eco Sangrante")

func _test_visual_art_phase12() -> void:
	# El arte debe importarse como Texture2D en Godot Android; los
	# archivos SVG de origen permanecen editables en el repositorio.
	var idle: Texture2D = VisualSprites.player_texture(false,0.0)
	var walking_a: Texture2D = VisualSprites.player_texture(true,0.0)
	var walking_b: Texture2D = VisualSprites.player_texture(true,0.20)
	_assert(idle != null and idle.get_width() >= 64,"Ismael no importa como textura")
	_assert(walking_a != null and walking_b != null,"Faltan cuadros de marcha de Ismael")
	_assert(walking_a != walking_b,"Los cuadros de animación no cambian")
	_assert(VisualSprites.player_draw_rect().size.x >= 70,"Ismael se dibuja muy pequeño")
	for kind_id in ["chaser","dasher","orbiter","brute","spitter","stalker","flyer","turret","leaper"]:
		var enemy_art: Texture2D = VisualSprites.enemy_texture(kind_id)
		_assert(enemy_art != null and enemy_art.get_height() >= 64,"Falta sprite del enemigo %s" % kind_id)
	for floor_number in range(1,6):
		var boss_art: Texture2D = VisualSprites.boss_texture(floor_number)
		_assert(boss_art != null and boss_art.get_width() == 192,"Falta el arte del jefe %d" % floor_number)
	_assert(VisualSprites.boss_texture(1) != VisualSprites.boss_texture(5),"Los guardianes deben ser visualmente diferentes")
	_assert(VisualSprites.boss_draw_rect().size.x >= 130,"Los guardianes deben leerse mejor que enemigos básicos")

func _test_transparent_hud_and_blue_hearts() -> void:
	var p = Player.new()
	p.max_health = 6
	p.health = 6
	p.floor_shield_enabled = true
	p.floor_shield_charges = 1
	var changes_seen: Array[int] = []
	p.temporary_hearts_changed.connect(func(charges: int): changes_seen.append(charges))
	p.take_damage(1)
	_assert(p.health == 6,"La protección temporal redujo vida roja")
	_assert(p.floor_shield_charges == 0,"El corazón azul no se consumió")
	_assert(changes_seen.size() == 1 and changes_seen[0] == 0,"No se notificó la pérdida del corazón azul")
	p.set("_invulnerability",0.0)
	p.take_damage(1)
	_assert(p.health == 5,"Sin escudo se debe recibir daño normal")
	p.refill_floor_shield()
	_assert(p.floor_shield_charges == 1,"No se regeneró el corazón temporal en el piso")
	_assert(changes_seen.size() == 2 and changes_seen[1] == 1,"No se notificó la recarga del corazón azul")
	var ui = MobileSideHud.new()
	var room := Rect2(Vector2(225.0,72.0),Vector2(1070.0,418.0))
	ui.set_layout(room,Vector2(1520.0,680.0))
	_assert(ui.left_panel.end.x <= room.position.x,"El HUD de vida invade el combate")
	_assert(ui.right_panel.position.x >= room.end.x,"Las estadísticas invaden el combate")
	_assert(ui._door_lower_edge()-ui._door_upper_edge() >= 96.0,"La franja de las puertas laterales es muy estrecha")
	_assert(ui._door_upper_edge() < room.get_center().y and ui._door_lower_edge() > room.get_center().y,"El HUD tapa la puerta central")
	ui.free()
	p.free()

func _test_projectile_readability() -> void:
	_assert(is_equal_approx(PlayerProjectile.combat_clarity_factor(0),1.0),"Se oscureció el disparo inicial")
	_assert(is_equal_approx(PlayerProjectile.combat_clarity_factor(52),1.0),"Build normal pierde visibilidad")
	_assert(PlayerProjectile.combat_clarity_factor(140) >= 0.35,"Demasiado apagadas las lágrimas al final")
	_assert(PlayerProjectile.combat_clarity_factor(140) < 0.50,"Las estelas de builds extremas siguen saturando")
	_assert(PlayerProjectile.combat_clarity_factor(160) >= 0.35,"El factor de claridad llegó a cero")

func _test_build_balance() -> void:
	var normal := BuildBalance.effective_fire_interval(0.18,1,1,0)
	var double := BuildBalance.effective_fire_interval(0.18,2,1,0)
	var overloaded := BuildBalance.effective_fire_interval(0.09,3,3,3)
	_assert(is_equal_approx(normal,0.18),"Cambió la cadencia de un jugador nuevo")
	_assert(is_equal_approx(double,0.18),"El disparo doble normal fue castigado")
	_assert(overloaded > 0.12 and overloaded < 0.22,"La build de 40 objetos se vuelve injusta o satura la CPU")
	_assert(BuildBalance.available_primary_shots(0,3) == 3,"Los tiros básicos fueron limitados")
	_assert(BuildBalance.available_primary_shots(139,3) == 1,"No se respeta el límite de proyectiles")
	_assert(BuildBalance.available_primary_shots(140,3) == 0,"El límite de Android no funciona")
	var owned: Dictionary = {"dano":5,"lente":4,"vida":3,"buscadora":1,"cadencia":5}
	_assert(BuildBalance.reward_score("dano",owned,ItemCatalog.synergy_definitions(),ItemCatalog) <
		BuildBalance.reward_score("eco_fragil",owned,ItemCatalog.synergy_definitions(),ItemCatalog),
		"El sistema sigue prefiriendo duplicados planos")
	var pool := ItemCatalog.reward_ids()
	var choice_one := BuildBalance.choose_two(pool,owned,ItemCatalog.synergy_definitions(),ItemCatalog,"dano",123456)
	var choice_two := BuildBalance.choose_two(pool,owned,ItemCatalog.synergy_definitions(),ItemCatalog,"dano",123456)
	_assert(choice_one == choice_two,"Las recompensas cambian al volver a entrar en la misma sala")
	_assert(choice_one.size() == 2 and choice_one[0] != choice_one[1],"Dos pedestales ofrecen el mismo objeto")
	_assert(not choice_one.has("dano"),"Reaparece inmediatamente la última recompensa")
	var fresh_picks := 0
	for test_seed in range(100):
		var picks := BuildBalance.choose_two(pool,owned,ItemCatalog.synergy_definitions(),ItemCatalog,"",test_seed)
		for reward_id in picks:
			if int(owned.get(reward_id,0)) == 0:
				fresh_picks += 1
	_assert(fresh_picks > 120,"Las builds largas reciben demasiados objetos duplicados")
	var owned_total := BuildBalance.total_items({"dano":12,"lente":10,"vida":8,"cadencia":10})
	_assert(owned_total == 40,"La carga de 40 objetos se calcula mal")
	var sample: Array[String] = ["chaser","flyer","brute","shielded","dasher"]
	var adapted := BuildBalance.adapt_late_encounter(sample,3,40,"combate",23)
	_assert(adapted.size() == sample.size(),"El balance agrega enemigos en partidas largas")
	_assert(adapted.has("spitter"),"Las builds de 40 objetos no reciben presión táctica")
	_assert(BuildBalance.adapt_late_encounter(sample,3,9,"combate",23) == sample,"Las partidas normales se alteraron")
	_assert(BuildBalance.adapt_late_encounter(sample,2,40,"combate",23) == sample,"Se endureció el piso 2 innecesariamente")
	_assert(BuildBalance.adapt_late_encounter(sample,5,40,"jefe",23) == sample,"No debe cambiarse el jefe")
	# La progresión de los guardianes mantiene su vida base sin inflarla.
	for floor_number in range(1,6):
		var guardian = AdvancedEnemy.new()
		guardian.configure_advanced("boss",floor_number)
		var curve: Array[int] = [110,150,195,245,305]
		_assert(guardian.max_health == curve[floor_number-1],"Se aumentó la vida de un guardián")
		guardian.free()

func _test_floor_rosters() -> void:
	for floor_number in range(1,6):
		var pool: Array[String] = FloorCatalog.enemy_pool(floor_number)
		_assert(not pool.is_empty(),"Piso sin enemigos: %d" % floor_number)
		for seed_value in [11,42,137,927]:
			var roster: Array[String] = FloorCatalog.encounter_roster(floor_number,seed_value,7,"combate","arena")
			var repeated: Array[String] = FloorCatalog.encounter_roster(floor_number,seed_value,7,"combate","arena")
			_assert(roster.size() == 7,"Cantidad incorrecta de enemigos en piso %d" % floor_number)
			_assert(roster == repeated,"Encuentro no determinista en piso %d" % floor_number)
			for enemy_id in roster:
				_assert(pool.has(enemy_id.trim_suffix("_elite")),"Enemigo fuera del pool del piso %d: %s" % [floor_number,enemy_id])

func _test_metaprogression() -> void:
	var progress = RunProgress.new()
	_assert(not progress.has_unlock("santuario_eco"),"Santuario debería exigir una victoria")
	progress.max_floor_reached = 3
	_assert(progress.has_unlock("eco_fragil"),"Esquirla no desbloquea en piso 3")
	progress.events_resolved = 2
	_assert(progress.has_unlock("reloj_ceniza"),"Reloj no desbloquea al resolver eventos")
	progress.pacts_sealed = 3
	_assert(progress.has_unlock("colmillo_ritual"),"Colmillo no desbloquea al sellar pactos")
	progress.runs_completed = 1
	_assert(progress.has_unlock("santuario_eco"),"Cámara del Eco no desbloquea al ganar")
	progress.echo_challenges_completed = 3
	_assert(progress.has_unlock("corona_del_eco"),"Corona no desbloquea con tres desafíos")

func _test_boss_seals() -> void:
	var progress = RunProgress.new()
	_assert(progress.boss_seals_discovered() == 0,"Perfil nuevo debe empezar sin sellos")
	for floor_number in range(1,6):
		var definition: Dictionary = BossSeals.definition(floor_number)
		_assert(not String(definition.get("name","")).is_empty(),"Falta nombre de guardián")
		_assert(not String(definition.get("omen","")).is_empty(),"Falta presagio de guardián")
		var choices: Array[String] = BossSeals.reward_choices(floor_number,12345)
		_assert(choices.size() == 2,"Cada guardián debe tener dos bendiciones")
		_assert(choices[0] != choices[1],"Ofertas del jefe no son diferentes")
		_assert(choices == BossSeals.reward_choices(floor_number,12345),"Ofertas de sello no son deterministas")
		for reward_id in choices:
			_assert(ItemCatalog.reward_ids().has(reward_id),"Sello tiene recompensa inexistente: "+reward_id)
		progress.boss_defeats[str(floor_number)] = floor_number
		_assert(progress.boss_defeat_count(floor_number) == floor_number,"Conteo de guardián incorrecto")
		_assert(BossSeals.codex_entry(floor_number,1).contains("\n"),"Códice sin saltos de línea")
	_assert(progress.boss_seals_discovered() == 5,"No se registraron los cinco sellos")
	_assert(progress.has_unlock("cronicas_cinco_sellos"),"Códice completo no desbloquea")

func _test_boss_mechanics() -> void:
	var kinds: Array[String] = ["grillete","mordida","mirada","tumba","vacio"]
	for id in kinds:
		var zone = BossMechanicZone.new()
		zone.configure(id,0.35,0.08,Vector2.UP)
		_assert(zone.mechanic_kind == id,"Mecánica de jefe incorrecta: " + id)
		_assert(zone.telegraph_time >= 0.70,"Aviso de daño muy corto: " + id)
		_assert(zone.active_time >= 0.35,"Ventana de daño incorrecta: " + id)
		_assert(zone.area_radius > 0.0,"Área sin tamaño: " + id)
		if id == "mirada":
			_assert(zone.beam_length >= 300.0,"Haz del Vigía demasiado corto")
			_assert(is_equal_approx(zone.rotation,-PI*0.5),"Haz mal orientado")
		zone.free()
	for floor_number in range(1,6):
		var guardian = AdvancedEnemy.new()
		guardian.configure_advanced("boss",floor_number)
		_assert(guardian.advanced_kind == AdvancedEnemy.AdvancedKind.FLOOR_BOSS,"Jefe sin comportamiento avanzado")
		_assert(guardian.floor_variant == floor_number,"Mecánica del jefe asignada al piso equivocado")
		_assert(guardian.max_health >= 60,"El guardián principal fue confundido con minijefe")
		guardian.free()

func _test_boss_phases() -> void:
	_assert(BossPhases.phase_for_health(110,110) == 1,"El jefe debe iniciar en fase I")
	_assert(BossPhases.phase_for_health(61,110) == 1,"La fase II se activó antes del umbral")
	_assert(BossPhases.phase_for_health(60,110) == 2,"La fase II no se activa al 55%")
	_assert(BossPhases.phase_for_health(28,110) == 2,"La fase III se activó demasiado pronto")
	_assert(BossPhases.phase_for_health(27,110) == 3,"La fase III no se activa al 25%")
	_assert(BossPhases.phase_for_health(0,110) == 0,"Los jefes muertos no deben cambiar de fase")
	_assert(BossPhases.mechanic_stride(3) >= 3,"La última fase satura las marcas del suelo")
	_assert(BossPhases.attack_multiplier(3) >= 0.80,"La última fase dispara demasiado rápido")
	for floor_number in range(1,6):
		var title_two := BossPhases.phase_title(floor_number,2)
		var title_three := BossPhases.phase_title(floor_number,3)
		_assert(not title_two.is_empty() and not title_three.is_empty(),"Faltan avisos de fases en piso %d" % floor_number)
		_assert(title_two != title_three,"Las fases tienen el mismo anuncio en piso %d" % floor_number)
		var guardian = AdvancedEnemy.new()
		guardian.configure_advanced("boss",floor_number)
		_assert(guardian.get("_boss_phase") == 1,"El jefe inicia fuera de fase I")
		_assert(guardian.get("_boss_base_speed") > 0.0,"La velocidad base del jefe no se conserva")
		guardian.free()
	var minor = AdvancedEnemy.new()
	minor.configure_advanced("boss",1)
	minor.health = 8
	minor.max_health = 8
	_assert(minor.health == 8,"El Guardián Menor no conserva su balance")
	minor.free()
	var hud = BossHud.new()
	hud.show_boss("PRUEBA",110)
	hud.set_phase(2)
	_assert(hud.boss_phase == 2,"La barra no muestra el cambio de fase")
	hud.free()

func _test_guardian_echoes() -> void:
	var profile = RunProgress.new()
	var appeared := 0
	for seed in range(100):
		if GuardianEchoCatalog.should_appear(seed,2):
			appeared += 1
	_assert(appeared >= 40 and appeared <= 80,"Los Ecos no tienen frecuencia equilibrada")
	for floor_number in range(1,6):
		var title := GuardianEchoCatalog.title(floor_number)
		var reward := GuardianEchoCatalog.reward(floor_number)
		var support := GuardianEchoCatalog.support_roster(floor_number)
		_assert(not title.is_empty(),"Eco sin nombre en piso %d" % floor_number)
		_assert(ItemCatalog.reward_ids().has(reward),"Eco con reliquia no válida en piso %d" % floor_number)
		_assert(support.size() == 2,"Eco sin variedad de apoyo en piso %d" % floor_number)
		_assert(GuardianEchoCatalog.tribute_cost(floor_number) >= 6,"Tributo demasiado barato")
		_assert(GuardianEchoCatalog.trial_enemy_count(floor_number) <= 6,"Combate de Eco saturado")
		var warden = GuardianEchoElite.new()
		warden.configure_echo("warden",floor_number)
		_assert(warden.echo_squad_member,"El custodio no pertenece al grupo")
		_assert(warden.echo_role == GuardianEchoElite.EchoRole.WARDEN,"Custodio mal clasificado")
		_assert(warden.max_health < 60,"Custodio tiene salud de jefe")
		warden.free()
		var hunter = GuardianEchoElite.new()
		hunter.configure_echo("hunter",floor_number)
		_assert(hunter.echo_squad_member,"El heraldo no pertenece al grupo")
		_assert(hunter.echo_role == GuardianEchoElite.EchoRole.HUNTER,"Heraldo mal clasificado")
		_assert(hunter.max_health < 60,"Heraldo tiene salud de jefe")
		hunter.free()
		profile.guardian_echo_victories[str(floor_number)] = 1
	_assert(profile.guardian_echo_floors_completed() == 5,"No se contabilizan los cinco Ecos")
	_assert(profile.has_unlock("testigo_cinco_ecos"),"No se desbloquea la llave del Testigo")

func _test_secrets_and_anomalies() -> void:
	var progress = RunProgress.new()
	_assert(not progress.has_unlock("criptas_ocultas"),"Las criptas deben esperar la primera victoria")
	_assert(not progress.has_unlock("anomalias_del_descenso"),"La anomalía apareció en una primera partida")
	progress.runs_completed = 1
	_assert(progress.has_unlock("criptas_ocultas"),"No se abrieron las criptas tras completar una partida")
	_assert(progress.has_unlock("anomalias_del_descenso"),"No se habilitaron las anomalías tras ganar")
	var variants: Dictionary = {}
	for cell_x in range(-12,13):
		var variant := SecretRunCatalog.vault_variant(192,4,Vector2i(cell_x,3))
		variants[variant] = true
		_assert(not SecretRunCatalog.vault_title(variant).is_empty(),"Cripta sin identidad propia")
		for risk in [false,true]:
			var reward := SecretRunCatalog.vault_reward(variant,risk)
			_assert(ItemCatalog.reward_ids().has(reward),"Cripta ofrece reliquia inexistente")
	_assert(variants.size() == 3,"Falta una variante de las criptas")
	var encounter_modes: Dictionary = {}
	var anomaly_seen := 0
	for seed_value in range(100):
		if SecretRunCatalog.anomaly_appears(seed_value,3):
			anomaly_seen += 1
		var kind := SecretRunCatalog.anomaly_variant(seed_value,3,Vector2i(2,5))
		encounter_modes[kind] = true
		_assert(SecretRunCatalog.anomaly_bonus_enemies(kind) <= 2,"Anomalía satura la sala")
		_assert(not SecretRunCatalog.anomaly_description(kind).is_empty(),"Anomalía sin pista visual")
	_assert(anomaly_seen >= 30 and anomaly_seen <= 70,"Frecuencia de anomalías fuera del rango")
	_assert(encounter_modes.size() == 3,"Las anomalías no varían entre partidas")
	_assert(not SecretRunCatalog.anomaly_appears(61,1),"Anomalías demasiado pronto")
	progress.secret_vaults_opened = 2
	progress.anomalies_cleared = 3
	_assert(not progress.has_unlock("sello_del_cartografo"),"El logro se desbloquea prematuramente")
	progress.secret_vaults_opened = 3
	_assert(progress.has_unlock("sello_del_cartografo"),"No se desbloquea el Sello del Cartógrafo")

func _test_shop_layout_and_guardian_spawns() -> void:
	var slots: Array[Vector2] = ShopSystem.compact_slot_ratios()
	_assert(slots.size() == 6,"La tienda perdió productos")
	_assert(ShopSystem.COMPACT_ITEM_SCALE <= 0.72,"Los ítems de tienda siguen gigantes")
	for index in range(slots.size()):
		var ratio: Vector2 = slots[index]
		_assert(ratio.x >= 0.25 and ratio.x <= 0.75,"La tienda invade los bordes")
		_assert(ratio.y >= 0.26 and ratio.y <= 0.73,"La tienda invade las entradas")
		for previous in range(index):
			_assert(ratio.distance_to(slots[previous]) >= 0.14,"Dos ítems de tienda demasiado juntos")
	var arena = FloorController.new()
	var player = Player.new()
	arena.room_rect = Rect2(0.0,0.0,1100.0,550.0)
	arena.player = player
	for door_position in [
		Vector2(550.0,92.0),Vector2(550.0,458.0),
		Vector2(92.0,275.0),Vector2(1008.0,275.0),
		Vector2(550.0,154.0)
	]:
		player.position = door_position
		var safe_position: Vector2 = arena._safe_guardian_spawn_position(Vector2(0.50,0.28))
		_assert(safe_position.distance_to(player.position) >= 225.0,"Jefe aparece demasiado cerca de la entrada")
		_assert(arena.room_rect.has_point(safe_position),"Jefe aparece fuera de la sala")
	player.grant_room_entry_protection(2.90)
	_assert(float(player.get("_invulnerability")) >= 2.90,"La protección de entrada no se activa")
	player.free()
	arena.free()

func _test_enemy_obstacle_navigation() -> void:
	var arena := Rect2(50,70,1240,570)
	var pillar := Rect2(450,225,126,138)
	var obstacle: Array[Rect2] = [pillar]
	var enemy_position := Vector2(320,295)
	var ismael_position := Vector2(750,295)
	_assert(not ObstacleNavigator.segment_is_clear(enemy_position,ismael_position,obstacle),"Prueba de bloqueo no detecta una columna")
	var first_corner: Vector2 = ObstacleNavigator.next_corner(enemy_position,ismael_position,obstacle,arena)
	_assert(first_corner != ismael_position,"El enemigo sigue intentando atravesar la columna")
	_assert(arena.has_point(first_corner),"El desvío sale de la sala")
	_assert(ObstacleNavigator.segment_is_clear(enemy_position,first_corner,obstacle),"El camino hasta la esquina también choca")
	var open_goal := Vector2(360,110)
	_assert(ObstacleNavigator.next_corner(enemy_position,open_goal,obstacle,arena) == open_goal,"Desvío innecesario con ruta despejada")
	var columns: Array[Rect2] = [
		Rect2(365,215,100,130),Rect2(725,205,100,150)
	]
	var left_enemy := Vector2(225,275)
	var middle_player := Vector2(600,275)
	var side_corner := ObstacleNavigator.next_corner(left_enemy,middle_player,columns,arena)
	_assert(side_corner != middle_player,"Un enemigo lateral permanece atrapado detrás de una cobertura")
	_assert(ObstacleNavigator.segment_is_clear(left_enemy,side_corner,columns),"No puede llegar a la esquina de cobertura")
	var right_enemy := Vector2(960,275)
	var right_corner := ObstacleNavigator.next_corner(right_enemy,middle_player,columns,arena)
	_assert(right_corner != middle_player,"El enemigo del costado derecho ignora la cobertura")
	_assert(ObstacleNavigator.segment_is_clear(right_enemy,right_corner,columns),"No puede llegar a la esquina desde la derecha")
	var none: Array[Rect2] = []
	_assert(ObstacleNavigator.next_corner(left_enemy,middle_player,none,arena) == middle_player,"El camino sin obstáculos debe ser directo")

func _test_enemy_pathfinding_in_physics() -> void:
	# Reproduce la captura: Ismael permanece en medio, dos enemigos
	# avanzan desde los extremos detrás de dos coberturas sólidas.
	var stage := Node2D.new()
	root.add_child(stage)
	var arena := Rect2(40.0,50.0,1240.0,560.0)
	for obstacle_center in [Vector2(465,315),Vector2(895,315)]:
		var wall = SolidRoomObstacle.new()
		wall.configure(Vector2(110,156),2)
		wall.position = obstacle_center
		stage.add_child(wall)
	var stationary_target := Node2D.new()
	stationary_target.position = Vector2(680,315)
	stage.add_child(stationary_target)
	var left = EnemyActor.new()
	left.configure(EnemyActor.EnemyKind.CHASER,1)
	left.speed = 235.0
	left.target = stationary_target
	left.position = Vector2(275,315)
	left.set_movement_bounds(arena)
	stage.add_child(left)
	var right = EnemyActor.new()
	right.configure(EnemyActor.EnemyKind.CHASER,1)
	right.speed = 235.0
	right.target = stationary_target
	right.position = Vector2(1080,315)
	right.set_movement_bounds(arena)
	stage.add_child(right)
	for frame in range(280):
		await physics_frame
	_assert(left.global_position.x > 570.0,"Enemigo izquierdo se quedó empujando la columna")
	_assert(right.global_position.x < 790.0,"Enemigo derecho se quedó empujando la columna")
	_assert(left.global_position.distance_to(stationary_target.global_position) < 195.0,"Enemigo izquierdo no rodea la cobertura")
	_assert(right.global_position.distance_to(stationary_target.global_position) < 195.0,"Enemigo derecho no rodea la cobertura")
	stage.queue_free()
	await physics_frame

func _test_shot_cancellation() -> void:
	var player = Player.new()
	player._shoot_pose = 0.13
	var previous_generation := int(player.get("_shot_generation"))
	player.cancel_queued_shots()
	_assert(int(player.get("_shot_generation")) == previous_generation+1,"Ráfagas pendientes no se invalidan")
	_assert(is_zero_approx(player._shoot_pose),"El estado de disparo no se restablece")
	player.free()
