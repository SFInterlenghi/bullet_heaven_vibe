extends Node2D

var _spawn_timer: float = 0.0
var _next_interval: float = 8.0
var _player: Node2D = null

const SCENE = preload("res://scenes/world/destructible.tscn")

func _ready() -> void:
	add_to_group("destructible_spawner")
	_player = get_tree().get_first_node_in_group("player")
	_next_interval = randf_range(8.0, 12.0)

func _process(delta: float) -> void:
	_spawn_timer += delta

	if _spawn_timer >= _next_interval:
		_spawn_timer = 0.0
		_next_interval = randf_range(8.0, 12.0)
		_try_spawn()

func _try_spawn() -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group("player")
	if _player == null:
		return

	var alive: Array = get_tree().get_nodes_in_group("destructible")
	var max_alive: int = _get_max_alive()
	if alive.size() >= max_alive:
		return

	# Don't spawn during active boss fight
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("current_type") in [5, 6]:  # BOSS / VOID_SPAWN
			return

	var angle: float = randf() * TAU
	var dist: float = randf_range(600.0, 850.0)
	var spawn_pos: Vector2 = _player.global_position + Vector2(cos(angle), sin(angle)) * dist

	var d = PoolManager.get_node_from_pool(SCENE)
	d.global_position = spawn_pos
	# ~25% chance to spawn a Static Anomaly; scales up slightly in later acts
	var t: float = GameManager.get_run_time()
	var anomaly_chance: float = 0.15 + clamp(t / 3000.0, 0.0, 0.15)  # 15% → 30% by Act V
	d.is_anomaly = randf() < anomaly_chance
	d._apply_visuals()
	get_tree().current_scene.call_deferred("add_child", d)

func _get_max_alive() -> int:
	var t: float = GameManager.get_run_time()
	if t < 300.0:   return 3   # Act I
	if t < 600.0:   return 4   # Act II
	if t < 900.0:   return 6   # Act III
	if t < 1200.0:  return 6   # Act IV
	return 4                    # Act V — fewer, tension is from boss
