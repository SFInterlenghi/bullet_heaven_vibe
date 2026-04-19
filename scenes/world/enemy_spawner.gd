extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var spawn_radius: float = 800.0  # was 500 — further off-screen to stop flicker

var time_since_last_spawn: float = 0.0
var total_time: float = 0.0
var player: Node2D = null
var enemy_container: Node2D = null  # reference to EnemyContainer node

func _ready() -> void:
	add_to_group("enemy_spawner")
	player = get_tree().get_first_node_in_group("player")
	enemy_container = get_parent().get_node("EnemyContainer")
	# Reset run-state flags (accessed externally by enemy.gd)
	_first_void_spawned = false

var sub_boss_spawned: bool = false
var boss_spawned: bool = false
var _first_void_spawned: bool = false  # guarantees one void reliquary early in the run

func _process(delta: float) -> void:
	time_since_last_spawn += delta
	total_time += delta

	var optimal_enemies = int(20 + total_time * 0.1)
	var max_enemies = int(40 + total_time * 0.2)

	var current_spawn_interval = spawn_interval
	var active_enemies = enemy_container.get_child_count()

	if active_enemies < optimal_enemies:
		current_spawn_interval = 0.05

	if time_since_last_spawn >= current_spawn_interval and active_enemies < max_enemies:
		time_since_last_spawn = 0.0
		_spawn_enemy()

func _spawn_enemy() -> void:
	if enemy_scene == null or player == null or enemy_container == null:
		return

	var enemy = PoolManager.get_node_from_pool(enemy_scene)

	var type_to_spawn = 0 # EnemyType.BASIC
	# Act V: Final Boss at 22:30, Sub-Boss at 17:30
	if total_time >= 1350.0 and not boss_spawned:
		boss_spawned = true
		type_to_spawn = 5 # EnemyType.BOSS
	elif total_time >= 1050.0 and not sub_boss_spawned and not boss_spawned:
		sub_boss_spawned = true
		type_to_spawn = 4 # EnemyType.SUB_BOSS
	else:
		# Enemy type pool expands with each Act.
		# Compressed vs original — FAST appears by ~1:30 so variety is felt early.
		var weights = []
		if total_time < 90.0:        # 0:00–1:30  — warm-up, Basic only
			weights = [0]
		elif total_time < 300.0:     # 1:30–5:00  — Fast joins (50 / 50)
			weights = [0, 1]
		elif total_time < 600.0:     # 5:00–10:00 — Tank joins
			weights = [0, 1, 1, 2]
		elif total_time < 900.0:     # 10:00–15:00 — Spawner joins
			weights = [0, 1, 2, 2, 3]
		elif total_time < 1200.0:    # 15:00–20:00 — heavier Tank/Spawner
			weights = [0, 1, 2, 2, 3, 3]
		else:                        # 20:00–25:00 — maximum pressure
			weights = [0, 1, 2, 2, 2, 3, 3]
		type_to_spawn = weights.pick_random()

	enemy.apply_tier(type_to_spawn)

	# Act-based health and speed scaling — tuned so a level-1 weapon
	# can still kill basic enemies in Act V, but late-game feels threatening.
	enemy.max_health += total_time * 0.4
	enemy.move_speed += total_time * 0.02
	enemy.current_health = enemy.max_health
	
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
	enemy.position = player.global_position + offset
	
	enemy_container.add_child(enemy)


func spawn_void_boss(spawn_pos: Vector2) -> void:
	var enemy = PoolManager.get_node_from_pool(enemy_scene)
	enemy.global_position = spawn_pos
	enemy.apply_tier(6) # EnemyType.VOID_SPAWN = 6
	enemy_container.call_deferred("add_child", enemy)
