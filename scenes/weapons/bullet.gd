extends Area2D

@export var speed: float = 400.0
@export var damage: float = 10.0
@export var lifetime: float = 2.0

var weapon_type: String = "straight"
var is_chasing: bool = false
var direction: Vector2 = Vector2.RIGHT

var weapon_shape: PackedVector2Array
var weapon_color: Color = Color.WHITE

var max_pierce: int = 1
var current_pierce: int = 0
var max_bounces: int = 0
var current_bounces: int = 0

var boomerang_returned: bool = false
var start_pos: Vector2

# Orbital specific
var player_ref: Node2D = null
var orbital_angle: float = 0.0
var spin_radius: float = 80.0
var spin_speed: float = PI

var lifetime_timer: SceneTreeTimer = null

func _ready() -> void:
	# Hide the old ColorRect if it's still attached
	if has_node("ColorRect"):
		$ColorRect.visible = false
		
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func init_weapon(w: Dictionary, upgrades: Dictionary, start_loc: Vector2, target: Node2D, index: int, total: int, player: Node2D) -> void:
	var data = w["data"]
	weapon_type = data["type"]
	weapon_shape = data["shape"]
	weapon_color = data["color"]
	damage = data["base_damage"] * upgrades.get("damage_mult", 1.0)
	speed = data["base_speed"] * upgrades.get("speed_mult", 1.0)
	
	# Scale physics geometry if an upgrade calls for it
	var scale_mult = upgrades.get("scale_mult", 1.0)
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
		spin_radius = upgrades.get("spin_radius", 80.0)
		spin_speed = upgrades.get("spin_speed", 1.0) * PI
		lifetime = 999.0 # orbit forever
		
	elif weapon_type == "zone":
		if target:
			global_position = target.global_position + Vector2(randf_range(-40, 40), randf_range(-40, 40))
		lifetime = upgrades.get("duration", 2.0)
		is_chasing = upgrades.get("chasing", false)
		
	elif weapon_type == "boomerang":
		speed = data["base_speed"] * upgrades.get("speed_mult", 1.0)
		
	max_pierce = upgrades.get("max_pierce", upgrades.get("penetrate", 1))
	max_bounces = upgrades.get("max_bounces", 0)
	
	queue_redraw()
	
	if lifetime < 100.0:
		lifetime_timer = get_tree().create_timer(lifetime)
		lifetime_timer.timeout.connect(_on_lifetime_expired)

func _draw() -> void:
	if weapon_shape.size() >= 3:
		draw_polygon(weapon_shape, PackedColorArray([weapon_color]))
	else:
		draw_circle(Vector2.ZERO, 5.0, weapon_color)

func _physics_process(delta: float) -> void:
	if weapon_type == "straight" or weapon_type == "beam":
		position += direction * speed * delta
		
	elif weapon_type == "orbital":
		if player_ref != null:
			orbital_angle += spin_speed * delta
			var offset = Vector2(cos(orbital_angle), sin(orbital_angle)) * spin_radius
			global_position = player_ref.global_position + offset
			
	elif weapon_type == "boomerang":
		if not boomerang_returned:
			position += direction * speed * delta
			if global_position.distance_to(start_pos) > 300.0:
				boomerang_returned = true
		else:
			if player_ref:
				direction = (player_ref.global_position - global_position).normalized()
			position += direction * (speed * 1.5) * delta
			if player_ref and global_position.distance_to(player_ref.global_position) < 30.0:
				queue_free()
				
	elif weapon_type == "bounce":
		position += direction * speed * delta
		
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

func _check_screen_bounds() -> void:
	if weapon_type == "orbital" or weapon_type == "zone":
		return
		
	var camera = get_viewport()
	var screen_rect = camera.get_visible_rect()
	var cam_node = get_tree().get_first_node_in_group("camera")
	var cam_offset = Vector2.ZERO
	if cam_node:
		cam_offset = cam_node.global_position - screen_rect.size / 2
		
	var culling_rect = Rect2(cam_offset, screen_rect.size).grow(100.0)
	if not culling_rect.has_point(global_position):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)
		
		# Resolving lifetime hits gracefully
		if weapon_type == "zone" or weapon_type == "orbital" or weapon_type == "boomerang":
			pass
		elif weapon_type == "bounce":
			current_bounces += 1
			if current_bounces >= max_bounces:
				queue_free()
			else:
				direction = direction.rotated(randf_range(PI/2, 3*PI/2))
		else:
			current_pierce += 1
			if current_pierce >= max_pierce:
				queue_free()

func _on_area_entered(_area: Area2D) -> void:
	pass

func _on_lifetime_expired() -> void:
	queue_free()
