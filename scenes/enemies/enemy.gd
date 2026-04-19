extends CharacterBody2D

# --- STATS ---
@export var move_speed: float = 80.0
@export var max_health: float = 30.0
@export var damage_on_contact: float = 10.0
@export var damage_interval: float = 0.5  # seconds between damage ticks while touching

# --- STATE ---
var current_health: float
var player: Node2D = null

enum EnemyType { BASIC, FAST, TANK, SPAWNER, SUB_BOSS, BOSS, VOID_SPAWN }
var current_type: EnemyType = EnemyType.BASIC

# --- CONTACT TRACKING ---
var player_in_contact: bool = false
var damage_timer: float = 0.0

# --- DEATH GUARD ---
var is_dead: bool = false

# --- FREEZE STATE (Chronosphere consumable) ---
var _frozen_timer: float = 0.0

func _ready() -> void:
	current_health = max_health
	player = get_tree().get_first_node_in_group("player")
	
	# Connect DamageArea signals to detect player entering and leaving
	# body_entered fires once when a body enters the Area2D
	# body_exited fires once when a body leaves the Area2D
	$DamageArea.body_entered.connect(_on_body_entered)
	$DamageArea.body_exited.connect(_on_body_exited)

func _on_pool_retrieved() -> void:
	# get_tree() is null here — do NOT call it. Player ref from _ready() stays valid.
	is_dead = false
	current_health = max_health
	player_in_contact = false
	damage_timer = 0.0
	_frozen_timer = 0.0
	$Polygon2D.modulate = Color.WHITE
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
			scale = Vector2(5.0, 5.0)
			max_health = 1000.0
			move_speed = 60.0
			damage_on_contact = 30.0
		EnemyType.BOSS:
			$Polygon2D.color = Color(0.2, 0.05, 0.05) # Black/Crimson
			scale = Vector2(6.0, 6.0)
			max_health = 5000.0
			move_speed = 40.0
			damage_on_contact = 50.0
		EnemyType.VOID_SPAWN:
			$Polygon2D.color = Color(0.9, 0.2, 0.9) # Purple Pink
			scale = Vector2(4.0, 4.0)
			max_health = 8000.0
			move_speed = 70.0
			damage_on_contact = 60.0
			
	current_health = max_health
	player_in_contact = false
	damage_timer = 0.0

## Called by player.apply_freeze() — halts this enemy for `duration` seconds.
func set_frozen(duration: float) -> void:
	_frozen_timer = max(_frozen_timer, duration)
	$Polygon2D.modulate = Color(0.5, 0.7, 1.0)

func _physics_process(delta: float) -> void:
	if player == null:
		return

	# Freeze tick — skip all movement while frozen
	if _frozen_timer > 0.0:
		_frozen_timer -= delta
		if _frozen_timer <= 0.0:
			_frozen_timer = 0.0
			$Polygon2D.modulate = Color.WHITE
		return

	var dist = global_position.distance_to(player.global_position)
	if dist > 2000.0:
		if current_type == EnemyType.BOSS or current_type == EnemyType.SUB_BOSS or current_type == EnemyType.VOID_SPAWN:
			# Wrap/Teleport to the edge so the boss doesn't despawn
			var dir = (global_position - player.global_position).normalized()
			if dir == Vector2.ZERO:
				dir = Vector2.RIGHT
			global_position = player.global_position + dir * 1600.0
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
	if body.is_in_group("player"):
		player_in_contact = true
		damage_timer = damage_interval  # deal damage immediately on first contact
		
func _on_body_exited(body: Node2D) -> void:
	# Reset contact when player leaves
	if body.is_in_group("player"):
		player_in_contact = false
		damage_timer = 0.0

func take_damage(amount: float) -> void:
	if is_dead:
		return
	current_health -= amount
	if current_health <= 0.0:
		die()

const gem_scene = preload("res://scenes/props/gem.tscn")

func die() -> void:
	if is_dead:
		return
	is_dead = true
	GameManager.add_kill()
	# Notify player passives (momentum_stacks, zen_threshold)
	if player and player.has_method("passive_on_kill"):
		player.passive_on_kill()

	if current_type == EnemyType.BOSS:
		get_tree().call_group("game_manager", "on_game_won")

	if current_type == EnemyType.SPAWNER:
		var enemy_scene_load = load("res://scenes/enemies/enemy.tscn")
		# Use get_parent() so sub-enemies land in the same container as this
		# enemy (EnemyContainer). Using current_scene caused "already has parent
		# EnemyContainer" errors when the spawner ran before the deferred fires.
		var container = get_parent()
		for i in range(2):
			var child = PoolManager.get_node_from_pool(enemy_scene_load)
			child.global_position = global_position + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			child.apply_tier(EnemyType.BASIC)
			container.call_deferred("add_child", child)

	# BOSS drops 5 gold gems; all others drop one gem scaled by type + run time
	var drop_count: int = 5 if current_type == EnemyType.BOSS else 1
	var xp_per_gem: int = _gem_xp_for_type()
	var active_gems = get_tree().get_nodes_in_group("gem")
	
	for _i in range(drop_count):
		if active_gems.size() >= 300:
			var target = active_gems.pick_random()
			if target != null and is_instance_valid(target) and not target.get("is_absorbed"):
				target.xp_value += xp_per_gem
				target._update_tier_color()
		else:
			var gem = PoolManager.get_node_from_pool(gem_scene)
			gem.xp_value = xp_per_gem
			gem._update_tier_color()
			var scatter = Vector2(randf_range(-30, 30), randf_range(-30, 30))
			gem.global_position = global_position + (scatter if drop_count > 1 else Vector2.ZERO)
			get_tree().current_scene.call_deferred("add_child", gem)

	# -- CHEST DROPS --
	var drop_chest = false
	var chest_rarity = 0
	var p_luck: float = 1.0
	if player and "luck" in player: p_luck = player.luck

	match current_type:
		EnemyType.BASIC, EnemyType.FAST:
			# luck scales base drop chance (0.5% → up to 1.5% at luck 3.0)
			if randf() < 0.005 * p_luck: drop_chest = true; chest_rarity = 0
		EnemyType.TANK, EnemyType.SPAWNER:
			if randf() < 0.03 * p_luck:
				drop_chest = true
				# luck promotes rarity: base 30% uncommon, +10% per luck point above 1
				chest_rarity = 1 if randf() < (0.3 + (p_luck - 1.0) * 0.1) else 0
		EnemyType.SUB_BOSS:
			drop_chest = true
			# luck can promote sub-boss chest to Mythic (10% per luck point above 1)
			chest_rarity = 3 if randf() < (p_luck - 1.0) * 0.1 else 2
		EnemyType.BOSS:
			drop_chest = true; chest_rarity = 2
		EnemyType.VOID_SPAWN:
			GameManager.end_void_arena()

	if drop_chest:
		var chest = load("res://scenes/props/chest.tscn").instantiate()
		chest.rarity = chest_rarity
		if chest_rarity < 3:
			var spawner = get_tree().get_first_node_in_group("enemy_spawner")
			var run_time: float = GameManager.get_run_time()
			# Guaranteed first void reliquary after 3 minutes, then luck-scaled chance
			var void_chance: float = min(0.8, (0.15 + (p_luck - 1.0) * 0.05))
			if spawner and not spawner._first_void_spawned and run_time >= 180.0:
				chest.is_void = true
				spawner._first_void_spawned = true
			elif randf() < void_chance:
				chest.is_void = true
		chest.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", chest)

	PoolManager.return_node_to_pool(self, "res://scenes/enemies/enemy.tscn")

# Returns the XP value for the gem dropped by this enemy.
func _gem_xp_for_type() -> int:
	var run_time: float = GameManager.get_run_time()
	var base_xp: int
	match current_type:
		EnemyType.BOSS:
			base_xp = 250
		EnemyType.VOID_SPAWN:
			base_xp = 500
		EnemyType.SUB_BOSS:
			base_xp = 50
		EnemyType.TANK, EnemyType.SPAWNER:
			base_xp = 10
		_:  # BASIC, FAST
			base_xp = 10 if run_time >= 600.0 else 5
	# Luck bonus: each point of luck above 1.0 adds a 10% chance to double the gem value
	var p_luck: float = player.luck if player and "luck" in player else 1.0
	if p_luck > 1.0 and randf() < (p_luck - 1.0) * 0.1:
		base_xp *= 2
	return base_xp
