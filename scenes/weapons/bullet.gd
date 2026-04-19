extends Area2D

@export var speed: float = 400.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0

var weapon_type: String = "straight"
var weapon_id: String   = ""
var weapon_name: String = ""
var is_chasing: bool = false
var direction: Vector2 = Vector2.RIGHT

var weapon_shape: PackedVector2Array
var weapon_color: Color = Color.WHITE

var max_pierce: int = 1
var current_pierce: int = 0
var max_bounces: int = 0
var current_bounces: int = 0

var boomerang_returned: bool = false
var boomerang_travel_dist: float = 300.0
var start_pos: Vector2

# Orbital specific
var player_ref: Node2D = null
var orbital_angle: float = 0.0
var spin_radius: float = 80.0
var spin_speed: float = PI

var _life_timer: float = 0.0

func _on_pool_retrieved() -> void:
	current_pierce = 0
	current_bounces = 0
	boomerang_returned = false
	is_chasing = false
	orbital_angle = 0.0
	weapon_type = "straight"
	weapon_id = ""
	weapon_name = ""
	direction = Vector2.RIGHT
	player_ref = null
	_life_timer = 0.0

func _ready() -> void:
	# Hide the old ColorRect if it's still attached
	if has_node("ColorRect"):
		$ColorRect.visible = false
		
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func init_weapon(w: Dictionary, upgrades: Dictionary, start_loc: Vector2, target: Node2D, index: int, total: int, player: Node2D) -> void:
	var data = w["data"]
	weapon_type  = data["type"]
	weapon_id    = w.get("id", "")
	weapon_name  = data.get("name", "")
	weapon_shape = data["shape"]
	weapon_color = data["color"]
	damage = data["base_damage"] * upgrades.get("damage_mult", 1.0)
	speed = data["base_speed"] * upgrades.get("speed_mult", 1.0)

	# Combine upgrade scale with player area_of_effect stat (min 0.5 to keep collision valid)
	var aoe: float = clamp(player.area_of_effect if "area_of_effect" in player else 1.0, 0.5, 4.0)
	var scale_mult = upgrades.get("scale_mult", 1.0) * aoe
	if scale_mult != 1.0:
		var duplicate_shape = PackedVector2Array()
		for i in range(weapon_shape.size()):
			duplicate_shape.append(weapon_shape[i] * scale_mult)
		weapon_shape = duplicate_shape
		
	# Build orientation logic
	global_position = start_loc
	start_pos = start_loc
	player_ref = player
	
	if target != null:
		direction = (target.global_position - global_position).normalized()
	else:
		direction = Vector2.RIGHT
		
	# Apply weapon behavioral mutations
	if weapon_type == "straight":
		if upgrades.has("spread"):
			# Cone distribution for "Spread"
			var cone = upgrades["spread"]
			var angle_offset = -cone/2.0 + (cone / max(1, total - 1)) * index
			if total == 1: angle_offset = 0.0
			direction = direction.rotated(angle_offset)
		elif total > 1:
			# Cross-fire configurations for "Piercer" (forward, backward, up, down)
			if index == 1: direction = -direction
			if index == 2: direction = direction.rotated(PI/2)
			if index == 3: direction = direction.rotated(-PI/2)
				 
	elif weapon_type == "orbital":
		orbital_angle = (index * TAU) / max(1, total)
		spin_radius = upgrades.get("spin_radius", 80.0) * aoe
		spin_speed = upgrades.get("spin_speed", 1.0) * PI
		lifetime = 999.0 # orbit forever

	elif weapon_type == "beam":
		# Stationary beam: rotate to face fire direction, swap collision to a long rectangle
		rotation = direction.angle()
		lifetime = upgrades.get("duration", 0.1)
		var beam_len: float = 200.0 * aoe
		var col = get_node_or_null("CollisionShape2D")
		if col:
			var rect = RectangleShape2D.new()
			rect.size = Vector2(beam_len, 8.0)
			col.shape = rect
			col.position = Vector2(beam_len * 0.5, 0.0)

	elif weapon_type == "zone":
		if target:
			global_position = target.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		lifetime = upgrades.get("duration", 2.0)
		is_chasing = upgrades.get("chasing", false)

	elif weapon_type == "boomerang":
		speed = data["base_speed"] * upgrades.get("speed_mult", 1.0)
		boomerang_travel_dist = upgrades.get("travel_dist", 300.0)  # B8 fix

	max_pierce = upgrades.get("max_pierce", upgrades.get("penetrate", 1))
	max_bounces = upgrades.get("max_bounces", 0)
	
	queue_redraw()
	
	if lifetime < 100.0:
		_life_timer = lifetime

func _draw() -> void:
	if weapon_shape.size() >= 3:
		draw_polygon(weapon_shape, PackedColorArray([weapon_color]))
	else:
		draw_circle(Vector2.ZERO, 5.0, weapon_color)

func _physics_process(delta: float) -> void:
	if _life_timer > 0.0:
		_life_timer -= delta
		if _life_timer <= 0.0:
			PoolManager.return_node_to_pool(self, "res://scenes/weapons/bullet.tscn")
			return

	if weapon_type == "straight":
		position += direction * speed * delta
		
	elif weapon_type == "orbital":
		if player_ref != null:
			orbital_angle += spin_speed * delta
			var offset = Vector2(cos(orbital_angle), sin(orbital_angle)) * spin_radius
			global_position = player_ref.global_position + offset
			
	elif weapon_type == "boomerang":
		if not boomerang_returned:
			position += direction * speed * delta
			if global_position.distance_to(start_pos) > boomerang_travel_dist:
				boomerang_returned = true
		else:
			if player_ref:
				direction = (player_ref.global_position - global_position).normalized()
			position += direction * (speed * 1.5) * delta
			if player_ref and global_position.distance_to(player_ref.global_position) < 30.0:
				PoolManager.return_node_to_pool(self, "res://scenes/weapons/bullet.tscn")
				
	elif weapon_type == "bounce":
		position += direction * speed * delta
		_check_bounce_walls()


	elif weapon_type == "zone":
		if is_chasing:
			var enemies = get_tree().get_nodes_in_group("enemy")
			var curr_target = null
			var min_dist = INF
			for e in enemies:
				var d = global_position.distance_to(e.global_position)
				if d < min_dist: min_dist = d; curr_target = e
			if curr_target:
				var dir = (curr_target.global_position - global_position).normalized()
				position += dir * 80.0 * delta

	_check_screen_bounds()

func _get_cam_rect() -> Rect2:
	var screen_rect = get_viewport().get_visible_rect()
	var cam_node = get_tree().get_first_node_in_group("camera")
	var cam_offset = Vector2.ZERO
	if cam_node:
		cam_offset = cam_node.global_position - screen_rect.size / 2
	return Rect2(cam_offset, screen_rect.size)

func _check_screen_bounds() -> void:
	# These types manage their own lifetime — never cull by screen bounds.
	if weapon_type == "orbital" or weapon_type == "zone" or weapon_type == "bounce" or weapon_type == "beam":
		return

	var culling_rect = _get_cam_rect().grow(100.0)
	if not culling_rect.has_point(global_position):
		PoolManager.return_node_to_pool(self, "res://scenes/weapons/bullet.tscn")

func _check_bounce_walls() -> void:
	# Reflect direction off the visible screen edges (true wall bounce).
	var r = _get_cam_rect()
	var changed = false
	if global_position.x < r.position.x or global_position.x > r.end.x:
		direction.x = -direction.x
		changed = true
	if global_position.y < r.position.y or global_position.y > r.end.y:
		direction.y = -direction.y
		changed = true
	if changed:
		direction = direction.normalized()

func _on_body_entered(body: Node2D) -> void:
	if not body.has_method("take_damage"):
		return

	# B16: Guard pierce/bounce limits BEFORE dealing damage so same-frame
	# multi-enemy collisions don't over-pierce.
	if weapon_type == "bounce":
		if current_bounces >= max_bounces:
			return
	elif weapon_type != "zone" and weapon_type != "orbital" and weapon_type != "boomerang" and weapon_type != "beam":
		if current_pierce >= max_pierce:
			return

	body.take_damage(damage)
	GameManager.add_damage_dealt(damage, weapon_id, weapon_name, weapon_color)

	# orbit_knockback passive: push enemies on orbital hit
	if weapon_type == "orbital" and player_ref and "active_passives" in player_ref:
		if "orbit_knockback" in player_ref.active_passives:
			var kb_force: float = PassiveDB.PASSIVES["orbit_knockback"]["knockback_force"]
			var push_dir: Vector2 = (body.global_position - global_position).normalized()
			if push_dir == Vector2.ZERO:
				push_dir = Vector2.RIGHT
			if body is CharacterBody2D:
				body.velocity += push_dir * kb_force

	if weapon_type == "zone" or weapon_type == "orbital" or weapon_type == "boomerang" or weapon_type == "beam":
		pass  # These types persist through enemy hits
	elif weapon_type == "bounce":
		current_bounces += 1
		if current_bounces >= max_bounces:
			PoolManager.return_node_to_pool(self, "res://scenes/weapons/bullet.tscn")
		else:
			# B10: Slight random deflection on enemy hit (wall bounces are handled
			# separately in _check_bounce_walls with true reflection).
			direction = direction.rotated(randf_range(-PI / 4, PI / 4)).normalized()
	else:
		current_pierce += 1
		if current_pierce >= max_pierce:
			PoolManager.return_node_to_pool(self, "res://scenes/weapons/bullet.tscn")

func _on_area_entered(area: Area2D) -> void:
	if not area.is_in_group("destructible"):
		return
	if not area.has_method("take_damage"):
		return

	# Destructibles count as one pierce; don't consume a pierce charge on zone/orbital/beam
	if weapon_type == "zone" or weapon_type == "orbital" or weapon_type == "beam":
		area.take_damage(damage)
		return

	if weapon_type == "bounce":
		if current_bounces >= max_bounces:
			return
	else:
		if current_pierce >= max_pierce:
			return

	area.take_damage(damage)
	# Destructibles don't count toward damage stats
	current_pierce += 1
	if weapon_type != "boomerang" and current_pierce >= max_pierce:
		PoolManager.return_node_to_pool(self, "res://scenes/weapons/bullet.tscn")
