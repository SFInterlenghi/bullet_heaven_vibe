extends Area2D

@export var xp_value: int = 1   # default = green tier; set by enemy.die()

var player: Node2D = null
var is_absorbed: bool = false

# --- SUCTION ---
# Speed is fixed; radius is read live from player.pickup_radius so passives/upgrades
# can modify it without touching gem.gd.
const SUCTION_SPEED: float = 280.0

# --- GEM TIER COLORS ---
# Thresholds match enemy drop XP values: green=1, blue=5, purple=25, gold=100.
# Over-capped XP will eventually hit ruby and diamond tiers organically.
const COLOR_GREEN:   Color = Color(0.2, 1.0,  0.3,  1.0)  # < 5    (BASIC/FAST)
const COLOR_BLUE:    Color = Color(0.3, 0.5,  1.0,  1.0)  # >= 5   (TANK/SPAWNER)
const COLOR_PURPLE:  Color = Color(0.7, 0.1,  0.95, 1.0)  # >= 25  (SUB_BOSS / Elites)
const COLOR_GOLD:    Color = Color(1.0, 0.84, 0.0,  1.0)  # >= 100 (BOSS)
const COLOR_RUBY:    Color = Color(1.0, 0.1,  0.2,  1.0)  # >= 500 (Fusion Cap)
const COLOR_DIAMOND: Color = Color(0.9, 0.9,  1.0,  1.0)  # >= 2500 (Massive Late Game)

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	player = get_tree().get_first_node_in_group("player")

func _on_pool_retrieved() -> void:
	# Called by PoolManager BEFORE add_child — do NOT call get_tree().
	is_absorbed  = false
	xp_value     = 1          # enemy.die() overrides this before add_child fires
	$Polygon2D.color = COLOR_GREEN
	$Polygon2D.scale = Vector2.ONE
	if has_node("CollisionPolygon2D"):
		$CollisionPolygon2D.scale = Vector2.ONE

func _physics_process(delta: float) -> void:
	if player == null or is_absorbed:
		return

	# Suction: gems drift toward player when within pickup_radius.
	# Uses player.pickup_radius so the stat can be modified by passives/upgrades.
	var pickup_r: float = player.get("pickup_radius") if player.get("pickup_radius") else 120.0
	var dist = global_position.distance_to(player.global_position)
	if dist < pickup_r and dist > 1.0:
		var dir = (player.global_position - global_position).normalized()
		global_position += dir * SUCTION_SPEED * delta

func _on_body_entered(body: Node2D) -> void:
	if is_absorbed:
		return
	if body.is_in_group("player"):
		if body.has_method("collect_gem"):
			body.collect_gem(xp_value)
		GameManager.add_gem()
		is_absorbed = true
		PoolManager.return_node_to_pool(self, "res://scenes/props/gem.tscn")

func _update_tier_color() -> void:
	var color: Color
	var gem_scale := Vector2.ONE
	
	if xp_value >= 2500:
		color = COLOR_DIAMOND
		gem_scale = Vector2(2.0, 2.0)
	elif xp_value >= 500:
		color = COLOR_RUBY
		gem_scale = Vector2(1.5, 1.5)
	elif xp_value >= 100:
		color = COLOR_GOLD
		gem_scale = Vector2(1.2, 1.2)
	elif xp_value >= 25:
		color = COLOR_PURPLE
	elif xp_value >= 5:
		color = COLOR_BLUE
	else:
		color = COLOR_GREEN

	$Polygon2D.color = color
	# Dynamic scale
	if $Polygon2D.scale != gem_scale:
		var tw = create_tween()
		tw.tween_property($Polygon2D, "scale", gem_scale, 0.3).set_trans(Tween.TRANS_ELASTIC)
		if has_node("CollisionPolygon2D"):
			$CollisionPolygon2D.scale = gem_scale
