extends CharacterBody2D

# --- STATS ---
@export var move_speed: float = 80.0
@export var max_health: float = 30.0
@export var damage_on_contact: float = 10.0
@export var damage_interval: float = 0.5  # seconds between damage ticks while touching

# --- STATE ---
var current_health: float
var player: Node2D = null

enum EnemyType { BASIC, FAST, TANK, SPAWNER, SUB_BOSS, BOSS }
var current_type: EnemyType = EnemyType.BASIC

# --- CONTACT TRACKING ---
# Instead of distance checks, we track whether player is physically inside DamageArea
var player_in_contact: bool = false
var damage_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	
	# Connect DamageArea signals to detect player entering and leaving
	# body_entered fires once when a body enters the Area2D
	# body_exited fires once when a body leaves the Area2D
	$DamageArea.body_entered.connect(_on_body_entered)
	$DamageArea.body_exited.connect(_on_body_exited)

func _on_pool_retrieved() -> void:
	current_health = max_health
	player_in_contact = false
	damage_timer = 0.0
	player = get_tree().get_first_node_in_group("player")
	
	# Connect DamageArea signals to detect player entering and leaving
	if not $DamageArea.body_entered.is_connected(_on_body_entered):
		$DamageArea.body_entered.connect(_on_body_entered)
	if not $DamageArea.body_exited.is_connected(_on_body_exited):
		$DamageArea.body_exited.connect(_on_body_exited)

func apply_tier(type: EnemyType) -> void:
	current_type = type
	match type:
		EnemyType.BASIC:
			$Polygon2D.color = Color(0.8, 0.1, 0.1) # Red
			scale = Vector2(1.0, 1.0)
			max_health = 30.0
			move_speed = 80.0
			damage_on_contact = 10.0
		EnemyType.FAST:
			$Polygon2D.color = Color(0.9, 0.8, 0.1) # Yellow
			scale = Vector2(0.8, 0.8)
			max_health = 15.0
			move_speed = 120.0
			damage_on_contact = 5.0
		EnemyType.TANK:
			$Polygon2D.color = Color(0.1, 0.8, 0.2) # Green
			scale = Vector2(1.5, 1.5)
			max_health = 90.0
			move_speed = 50.0
			damage_on_contact = 20.0
		EnemyType.SPAWNER:
			$Polygon2D.color = Color(0.1, 0.4, 0.9) # Blue
			scale = Vector2(1.2, 1.2)
			max_health = 50.0
			move_speed = 70.0
			damage_on_contact = 10.0
		EnemyType.SUB_BOSS:
			$Polygon2D.color = Color(0.6, 0.1, 0.8) # Purple
			scale = Vector2(3.0, 3.0)
			max_health = 1000.0
			move_speed = 60.0
			damage_on_contact = 30.0
		EnemyType.BOSS:
			$Polygon2D.color = Color(0.2, 0.05, 0.05) # Black/Crimson
			scale = Vector2(5.0, 5.0)
			max_health = 5000.0
			move_speed = 40.0
			damage_on_contact = 50.0
			
	current_health = max_health
	player_in_contact = false
	damage_timer = 0.0

func _physics_process(delta: float) -> void:
	if player == null:
		return
	
	var dist = global_position.distance_to(player.global_position)
	if dist > 1400.0:
		if current_type == EnemyType.BOSS or current_type == EnemyType.SUB_BOSS:
			# Wrap/Teleport to the edge so the boss doesn't despawn
			var dir = (global_position - player.global_position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			global_position = player.global_position + dir * 1200.0
		else:
			PoolManager.return_node_to_pool(self, "res://scenes/enemies/enemy.tscn")
			return
	
	# Chase player
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * move_speed
	move_and_slide()
	
	# Continuous damage tick while player is inside DamageArea
	if player_in_contact:
		damage_timer += delta
		if damage_timer >= damage_interval:
			damage_timer = 0.0
			# Double check player still exists before damaging
			if player and player.has_method("take_damage"):
				player.take_damage(damage_on_contact)

func _on_body_entered(body: Node2D) -> void:
		# Temporary debug — print whatever enters the DamageArea
	print("DamageArea hit by: ", body.name)
	# Only react to the player entering
	if body.is_in_group("player"):
		player_in_contact = true
		damage_timer = damage_interval  # deal damage immediately on first contact
		
func _on_body_exited(body: Node2D) -> void:
	# Reset contact when player leaves
	if body.is_in_group("player"):
		player_in_contact = false
		damage_timer = 0.0

func take_damage(amount: float) -> void:
	current_health -= amount
	if current_health <= 0.0:
		die()

const gem_scene = preload("res://scenes/props/gem.tscn")

func die() -> void:
	if current_type == EnemyType.BOSS:
		get_tree().call_group("game_manager", "on_game_won")
		
	if current_type == EnemyType.SPAWNER:
		var enemy_scene_load = load("res://scenes/enemies/enemy.tscn")
		for i in range(2):
			var child = PoolManager.get_node_from_pool(enemy_scene_load)
			child.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			child.apply_tier(EnemyType.BASIC)
			get_tree().current_scene.call_deferred("add_child", child)
			
	var gem = PoolManager.get_node_from_pool(gem_scene)
	gem.global_position = global_position
	# Spawn loosely in the current scene hierarchy
	get_tree().current_scene.call_deferred("add_child", gem)
	
	PoolManager.return_node_to_pool(self, "res://scenes/enemies/enemy.tscn")
