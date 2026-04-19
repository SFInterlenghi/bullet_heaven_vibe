extends Area2D

# 0=Chronosphere, 1=Vacuum, 2=Adrenaline, 3=Mending_Shard
@export var consumable_type: int = 0

var is_collected: bool = false

const _COLORS = [
	Color(0.3, 0.5, 1.0),   # Chronosphere — blue
	Color(1.0, 0.4, 0.8),   # Vacuum — pink
	Color(1.0, 0.2, 0.2),   # Adrenaline — red
	Color(0.2, 1.0, 0.4),   # Mending Shard — green
]
const _BANNERS = [
	"TIME FROZEN",
	"GEMS PULLED",
	"ADRENALINE +",
	"+30% HP",
]

func _ready() -> void:
	add_to_group("consumable")
	body_entered.connect(_on_body_entered)
	_apply_color()

func _on_pool_retrieved() -> void:
	is_collected = false
	modulate = Color.WHITE
	scale = Vector2.ONE
	_apply_color()

func _apply_color() -> void:
	var idx: int = clamp(consumable_type, 0, _COLORS.size() - 1)
	if has_node("Polygon2D"):
		$Polygon2D.color = _COLORS[idx]

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if not body.is_in_group("player"):
		return
	is_collected = true

	var idx: int = clamp(consumable_type, 0, _BANNERS.size() - 1)
	var hud = get_tree().get_first_node_in_group("hud")

	match consumable_type:
		0:  # Chronosphere — freeze all non-boss enemies for 4s
			body.apply_freeze(4.0)
		1:  # Vacuum (Singularity) — pull all gems to player
			body.apply_vacuum()
		2:  # Adrenaline Spike — 2× attack_speed + move_speed for 10s
			body.apply_buff("adrenaline", 10.0)
		3:  # Mending Shard — restore 30% HP
			body.heal_pct(0.30)

	if hud and hud.has_method("show_banner"):
		hud.show_banner(_BANNERS[idx], _COLORS[idx])

	PoolManager.return_node_to_pool(self, "res://scenes/props/consumable.tscn")
