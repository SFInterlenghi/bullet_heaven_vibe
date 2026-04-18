extends CharacterBody2D

# --- STATS ---
@export var move_speed: float = 200.0
@export var max_health: float = 100.0

# --- STATE ---
var current_health: float
signal health_changed(current_health, max_health)

# --- EXPERIENCE ---
var xp: int = 0
var max_xp: int = 100
var level: int = 1
signal xp_changed(current_xp, max_xp, level)

# --- INVINCIBILITY FRAMES ---
# Prevents player taking damage every single frame on contact
@export var invincibility_duration: float = 0.8
var is_invincible: bool = false

# --- DASH STATE ---
var is_dashing: bool = false
var dash_speed: float = 600.0
var dash_duration: float = 0.2
var dash_cooldown: float = 1.5
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var dash_direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	# Initialize health to max at game start
	current_health = max_health
	
	# We defer this emit in case HUD is not ready yet
	call_deferred("emit_health_and_xp")

func emit_health_and_xp() -> void:
	health_changed.emit(current_health, max_health)
	xp_changed.emit(xp, max_xp, level)


func _physics_process(delta: float) -> void:
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
		
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			# Re-enable collision with enemies (layer 2)
			set_collision_mask_value(2, true)
		else:
			velocity = dash_direction * dash_speed
			move_and_slide()
			return
			
	# Build movement direction from input
	var direction = Vector2.ZERO
	
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	
	# normalized() keeps diagonal speed equal to cardinal speed
	if direction != Vector2.ZERO:
		direction = direction.normalized()
		
	# Check for dash input (ui_accept defaults to Space)
	if Input.is_action_just_pressed("ui_accept") and dash_cooldown_timer <= 0.0 and direction != Vector2.ZERO:
		is_dashing = true
		dash_direction = direction
		dash_timer = dash_duration
		dash_cooldown_timer = dash_cooldown
		# Disable collision with enemies (layer 2)
		set_collision_mask_value(2, false)
		return
	
	velocity = direction * move_speed
	move_and_slide()

func take_damage(amount: float) -> void:
	# Ignore damage during invincibility window or dash
	if is_invincible or is_dashing:
		return
	
	current_health -= amount
	health_changed.emit(current_health, max_health)
	print("Player HP: ", current_health)  # temporary debug readout
	
	# Start invincibility window to prevent instant death on contact
	_start_invincibility()
	
	if current_health <= 0.0:
		die()

func _start_invincibility() -> void:
	is_invincible = true
	
	# One-shot timer — disables invincibility after duration expires
	var timer = get_tree().create_timer(invincibility_duration)
	timer.timeout.connect(func(): is_invincible = false)

func die() -> void:
	# Notify GameManager that the run is over
	# We use a group call so player doesn't need a direct reference to GameManager
	get_tree().call_group("game_manager", "on_player_died")

func collect_gem(amount: int) -> void:
	xp += amount
	while xp >= max_xp:
		xp -= max_xp
		level_up()
	xp_changed.emit(xp, max_xp, level)

func level_up() -> void:
	level += 1
	max_xp = int(max_xp * 1.5)
	
	print("Leveled up to level ", level, "!")
	get_tree().call_group("hud", "show_draft_menu")
