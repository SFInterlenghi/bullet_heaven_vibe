extends Area2D

# 0: Common, 1: Uncommon, 2: Rare, 3: Mythic
@export var rarity: int = 0
@export var is_void: bool = false

var _prompt_cooldown: float = 0.0  # prevents re-prompt spam after declining

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	body_entered.connect(_on_body_entered)

	if is_void:
		$Polygon2D.color = Color(0.8, 0.1, 0.9)  # Purple dark
	else:
		match rarity:
			0: $Polygon2D.color = Color(0.6, 0.4, 0.2)  # Brown
			1: $Polygon2D.color = Color(0.8, 0.8, 0.8)  # Silver
			2: $Polygon2D.color = Color(1.0, 0.8, 0.1)  # Gold
			3: $Polygon2D.color = Color(0.2, 1.0, 0.8)  # Cyan

func _process(delta: float) -> void:
	if _prompt_cooldown > 0.0:
		_prompt_cooldown -= delta

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if is_void:
		if _prompt_cooldown > 0.0:
			return  # declined recently — ignore re-entry until cooldown expires
		get_tree().paused = true
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_void_prompt"):
			hud.show_void_prompt(self)
	else:
		open_chest()

func open_chest() -> void:
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_chest_menu"):
		hud.show_chest_menu(rarity)
	queue_free()

## Called by HUD when player declines the void prompt — start re-entry cooldown.
func on_void_declined() -> void:
	_prompt_cooldown = 3.0

func start_void_event() -> void:
	var p = get_tree().get_first_node_in_group("player")
	if p and not p.get("_void_curse_active"):
		p._void_curse_active   = true
		p.move_speed          *= 0.5
		p._base_move_speed    *= 0.5
		p.damage_multiplier   *= 0.5

	GameManager.start_void_arena()
	queue_free()
