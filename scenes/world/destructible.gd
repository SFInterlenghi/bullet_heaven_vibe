extends Area2D

# false = common crate/barrel: drops a consumable, no screen nuke
# true  = Static Anomaly: screen nuke + 50% XP wipe risk + consumable
@export var is_anomaly: bool = false

@export var max_health: float = 60.0

var current_health: float
var is_broken: bool = false
var _time: float = 0.0

func _ready() -> void:
	add_to_group("destructible")
	current_health = max_health
	body_entered.connect(_on_body_entered)
	_apply_visuals()

func _apply_visuals() -> void:
	if has_node("Polygon2D"):
		# Anomalies pulse red-orange; common crates are plain orange
		$Polygon2D.color = Color(0.9, 0.2, 0.1) if is_anomaly else Color(0.9, 0.5, 0.1)

func _on_pool_retrieved() -> void:
	is_broken = false
	current_health = max_health
	scale = Vector2.ONE
	modulate = Color.WHITE
	_time = 0.0
	_apply_visuals()

func _process(delta: float) -> void:
	_time += delta
	# Anomalies pulse faster and larger to signal danger
	var freq: float  = 6.0 if is_anomaly else 4.0
	var amp: float   = 0.10 if is_anomaly else 0.07
	var pulse: float = 1.0 + sin(_time * freq) * amp
	scale = Vector2(pulse, pulse)

func take_damage(amount: float) -> void:
	if is_broken:
		return
	current_health -= amount
	var hp_ratio: float = clamp(current_health / max_health, 0.0, 1.0)
	modulate = Color(1.0, hp_ratio, hp_ratio)
	if current_health <= 0.0:
		_break()

func _break() -> void:
	if is_broken:
		return
	is_broken = true

	if is_anomaly:
		_anomaly_detonate()
	else:
		_common_break()

	_drop_consumable()
	PoolManager.return_node_to_pool(self, "res://scenes/world/destructible.tscn")

# ── Common crate: quiet break, just drops a consumable ───────────────────────

func _common_break() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner("CRATE BROKEN", Color(0.9, 0.6, 0.2))

# ── Static Anomaly: screen nuke + 50% XP wipe ────────────────────────────────

func _anomaly_detonate() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	var cam_rect: Rect2 = _get_cam_rect().grow(200.0)

	# Kill all normal enemies in view; bosses receive chip damage only
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("is_dead"):
			continue
		var etype = e.get("current_type")
		if etype == 4 or etype == 5 or etype == 6:  # SUB_BOSS / BOSS / VOID_SPAWN
			e.take_damage(500.0)
		elif cam_rect.has_point(e.global_position):
			e.take_damage(99999.0)

	# 50% chance to wipe all XP gems on screen
	if randf() < 0.5:
		for g in get_tree().get_nodes_in_group("gem"):
			PoolManager.return_node_to_pool(g, "res://scenes/props/gem.tscn")
		if hud and hud.has_method("show_banner"):
			hud.show_banner("XP DESTABILIZED!", Color(1.0, 0.3, 0.2))
	else:
		if hud and hud.has_method("show_banner"):
			hud.show_banner("ANOMALY CLEARED", Color(0.2, 1.0, 0.8))

# ── Shared consumable drop ────────────────────────────────────────────────────

func _drop_consumable() -> void:
	var c_scene = load("res://scenes/props/consumable.tscn")
	if c_scene:
		var consumable = c_scene.instantiate()
		consumable.consumable_type = randi() % 4
		consumable.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", consumable)

func _get_cam_rect() -> Rect2:
	var screen_rect: Rect2 = get_viewport().get_visible_rect()
	var cam_node = get_tree().get_first_node_in_group("camera")
	var cam_offset = Vector2.ZERO
	if cam_node:
		cam_offset = cam_node.global_position - screen_rect.size * 0.5
	return Rect2(cam_offset, screen_rect.size)

func _on_body_entered(_body: Node2D) -> void:
	pass  # damage comes via take_damage() from bullets
