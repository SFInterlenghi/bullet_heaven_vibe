extends Area2D

@export var dps: float      = 8.0
@export var duration: float = 2.0

var _timer: float = 0.0
var _bodies_inside: Array = []

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _draw() -> void:
	# Concentric circles: bright inner, fading outer
	draw_circle(Vector2.ZERO, 28.0, Color(1.0, 0.4, 0.0, 0.55))
	draw_circle(Vector2.ZERO, 16.0, Color(1.0, 0.7, 0.1, 0.75))
	draw_circle(Vector2.ZERO, 7.0,  Color(1.0, 1.0, 0.6, 0.9))

func _physics_process(delta: float) -> void:
	_timer += delta
	if _timer >= duration:
		queue_free()
		return

	# Tick damage to all enemies currently inside the patch
	for body in _bodies_inside:
		if is_instance_valid(body) and body.has_method("take_damage"):
			body.take_damage(dps * delta)

	# Fade out in last 0.4 s
	var remaining = duration - _timer
	if remaining < 0.4:
		modulate.a = remaining / 0.4

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		_bodies_inside.append(body)

func _on_body_exited(body: Node2D) -> void:
	_bodies_inside.erase(body)
