extends Node2D

@export var enemy_scene: PackedScene
@export var spawn_interval: float = 2.0
@export var spawn_radius: float = 500.0

var time_since_last_spawn: float = 0.0
var total_time: float = 0.0
var player: Node2D = null
var enemy_container: Node2D = null  # reference to EnemyContainer node

func _ready() -> void:
	# Find player via group tag
	player = get_tree().get_first_node_in_group("player")
	
	# Get EnemyContainer by name from parent (World)
	# get_parent() = World node, then find child named "EnemyContainer"
	enemy_container = get_parent().get_node("EnemyContainer")

var sub_boss_spawned: bool = false
var boss_spawned: bool = false

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
	if total_time >= 150.0 and not boss_spawned:
		boss_spawned = true
		type_to_spawn = 5 # EnemyType.BOSS
	elif total_time >= 60.0 and not sub_boss_spawned and not boss_spawned:
		sub_boss_spawned = true
		type_to_spawn = 4 # EnemyType.SUB_BOSS
	else:
		var weights = []
		if total_time < 30.0:
			weights = [0]
		elif total_time < 60.0:
			weights = [0, 0, 1]
		elif total_time < 120.0:
			weights = [0, 0, 1, 2]
		else:
			weights = [0, 0, 1, 2, 3]
		type_to_spawn = weights.pick_random()
		
	enemy.apply_tier(type_to_spawn)
	
	# Time scaling logic overlaid on base tier stats
	enemy.max_health += total_time * 1.5
	enemy.move_speed += total_time * 0.1
	enemy.current_health = enemy.max_health
	
	var angle = randf() * TAU
	var offset = Vector2(cos(angle), sin(angle)) * spawn_radius
	enemy.position = player.global_position + offset
	
	enemy_container.add_child(enemy)
