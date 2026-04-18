extends Area2D

@export var xp_value: int = 10

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.has_method("collect_gem"):
			body.collect_gem(xp_value)
		
		# Return to pool instead of queue_free()
		PoolManager.return_node_to_pool(self, "res://scenes/props/gem.tscn")
