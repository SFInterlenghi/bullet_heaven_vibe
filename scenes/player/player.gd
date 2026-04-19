extends CharacterBody2D

# --- STATS ---
@export var move_speed: float    = 200.0
@export var max_health: float    = 100.0
@export var pickup_radius: float = 120.0  # gem suction range; readable by gem.gd + passives

# Full RPG Stat Block
var health_regen: float     = 0.0  # Regenerated every 5 seconds (scaled down per frame)
var armor: float            = 0.0  # Flat damage resistance
var area_of_effect: float   = 1.0  # Scalar for weapon geometry sizes
var attack_speed: float     = 1.0  # Weapon cooldown multiplier (higher = faster)
var luck: float             = 1.0  # Influences chest spawns, rarity, gem qualities
var dodge_chance: float     = 0.0  # % chance to evade damage
var crit_chance: float      = 0.0  # % chance to land a critical strike
var crit_damage: float      = 1.5  # Multiplier upon critical strike
var cd_reduction: float     = 0.0  # Cooldown modifier for dash, ult, and active passives

# Base values stored separately so buff multipliers stay accurate
# even after the player picks up stat cards.
var _base_move_speed: float   = 200.0
var _base_attack_speed: float = 1.0

# --- CHARACTER / PASSIVE SYSTEM ---
var damage_multiplier: float = 1.0  # boosted by zen_threshold passive
var active_passives: Array   = []   # passive IDs currently active
# Void curse state — prevents stat doubling without matching halving.
# Accessed externally by chest.gd and enemy.gd via player._void_curse_active.
var _void_curse_active: bool = false

# --- ULTIMATE ABILITY ---
var _ultimate_id: String          = "temporal_shift"
var _ultimate_cooldown_max: float = 90.0
var _ultimate_timer: float        = 0.0   # counts down to 0 = ready

signal ultimate_changed(timer: float, cooldown_max: float)

# --- PASSIVE STATE ---
# momentum_stacks (on_kill)
var _momentum_stacks: int        = 0
var _momentum_decay_timer: float = 0.0

# fire_trail (on_move)
var _fire_trail_timer: float = 0.0

# aegis shield (ultimate: aegis)
var _aegis_hp: float = 0.0

# sniper_mode: next N shots deal 5× damage (ultimate: sniper_mode)
var _sniper_shots: int = 0

# zen_threshold: track which thresholds have already fired
var _zen_thresholds_hit: Array = []

# --- CONSUMABLE BUFFS ---
# Dict of buff_id → remaining_seconds. Refreshed each pick-up.
var _active_buffs: Dictionary = {}

# --- STATE ---
var current_health: float
signal health_changed(current_health, max_health)

# --- EXPERIENCE ---
var xp: int = 0
var max_xp: int = 100
var level: int = 1
signal xp_changed(current_xp, max_xp, level)

# --- INVINCIBILITY FRAMES ---
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
	current_health = max_health
	# Apply chosen character (set by main menu via GameManager.selected_character_id)
	apply_character(GameManager.selected_character_id)
	call_deferred("emit_health_and_xp")

func emit_health_and_xp() -> void:
	health_changed.emit(current_health, max_health)
	xp_changed.emit(xp, max_xp, level)
	ultimate_changed.emit(_ultimate_timer, _ultimate_cooldown_max)

# ── Character Application ─────────────────────────────────────────────────────

func apply_character(char_id: String) -> void:
	if not CharacterDB.CHARACTERS.has(char_id):
		push_warning("apply_character: unknown id '%s', falling back to wanderer" % char_id)
		char_id = "wanderer"

	var cdata = CharacterDB.CHARACTERS[char_id]

	# Stats
	max_health          = cdata["base_health"]
	current_health      = max_health
	move_speed          = cdata["base_speed"]
	_base_move_speed    = cdata["base_speed"]
	pickup_radius       = cdata["pickup_radius"]

	# Ultimate
	_ultimate_id           = cdata["ultimate"]
	_ultimate_cooldown_max = cdata["ultimate_cooldown"]
	_ultimate_timer        = _ultimate_cooldown_max  # start empty, charging via kills

	# Passives — Start raw (0 passives) via Draft
	active_passives    = []
	_void_curse_active = false

	# Starting weapon — WeaponManager._ready() already ran (child fires first),
	# so we clear and re-add the correct weapon here.
	var mgr = get_node_or_null("WeaponManager")
	if mgr:
		mgr.equipped_weapons.clear()
		mgr.add_weapon(cdata["main_weapon"])

# ── Passive Hooks ─────────────────────────────────────────────────────────────

## Called by enemy.die() immediately after GameManager.add_kill().
func passive_on_kill() -> void:
	# ── momentum_stacks ──
	if "momentum_stacks" in active_passives:
		var p = PassiveDB.PASSIVES["momentum_stacks"]
		_momentum_stacks = min(_momentum_stacks + 1, p["stack_max"])
		_momentum_decay_timer = p["decay_time"]
		move_speed = _base_move_speed * (1.0 + _momentum_stacks * p["speed_mult"])

	# ── zen_threshold ──
	if "zen_threshold" in active_passives:
		var p = PassiveDB.PASSIVES["zen_threshold"]
		var kills: int = GameManager.run_stats["enemies_killed"]
		for threshold in p["thresholds"]:
			if kills == threshold and not _zen_thresholds_hit.has(threshold):
				_zen_thresholds_hit.append(threshold)
				damage_multiplier += p["damage_boost"]
				
	# ── Ultimate charging (1 kill = 1 charge tick, scaled by cd_reduction) ──
	if _ultimate_timer > 0.0:
		_ultimate_timer = max(0.0, _ultimate_timer - (1.0 * max(0.1, 1.0 + cd_reduction)))
		ultimate_changed.emit(_ultimate_timer, _ultimate_cooldown_max)

## Called by player._physics_process every frame.
## Handles fire_trail spawning while moving.
func passive_on_move(delta: float, is_moving: bool) -> void:
	if not "fire_trail" in active_passives:
		return
	if not is_moving:
		_fire_trail_timer = 0.0
		return
	var p = PassiveDB.PASSIVES["fire_trail"]
	_fire_trail_timer += delta
	if _fire_trail_timer >= p["spawn_rate"]:
		_fire_trail_timer = 0.0
		var patch = load("res://scenes/world/fire_patch.tscn").instantiate()
		patch.dps      = p["patch_damage"]
		patch.duration = p["patch_duration"]
		patch.global_position = global_position
		# Add to current_scene so it's freed on scene reload
		get_tree().current_scene.call_deferred("add_child", patch)

## Returns the fraction of incoming damage that is absorbed (0.0–1.0).
func get_damage_reduction() -> float:
	var reduction: float = 0.0
	if "armor_shards" in active_passives:
		reduction += PassiveDB.PASSIVES["armor_shards"]["damage_reduction"]
	return clamp(reduction, 0.0, 0.95)

# ── Ultimate ──────────────────────────────────────────────────────────────────

func cast_ultimate() -> void:
	if _ultimate_timer > 0.0:
		return  # still on cooldown
	_ultimate_timer = _ultimate_cooldown_max
	ultimate_changed.emit(_ultimate_timer, _ultimate_cooldown_max)

	match _ultimate_id:
		"temporal_shift":
			# 5 real-second invincibility + 0.3× time scale slow
			is_invincible = true
			Engine.time_scale = 0.3
			
			var tw = create_tween()
			tw.tween_property($ColorRect, "modulate", Color(0.2, 0.5, 1.0), 0.2)
			
			var t = get_tree().create_timer(5.0, true, false, true)
			t.timeout.connect(func():
				is_invincible  = false
				Engine.time_scale = 1.0
				var tw2 = create_tween()
				if is_instance_valid(self) and has_node("ColorRect"):
					tw2.tween_property($ColorRect, "modulate", Color.WHITE, 0.4)
			)

		"aegis":
			# Absorbs up to 200 damage before normal HP takes a hit
			_aegis_hp = 200.0
			var tw = create_tween()
			tw.tween_property($ColorRect, "modulate", Color(1.0, 0.8, 0.1), 0.2)
			tw.tween_property($ColorRect, "modulate", Color.WHITE, 1.0).set_delay(0.5)

		"sniper_mode":
			# Next 8 shots deal 5× damage (tracked in weapon_manager)
			_sniper_shots = 8
			var tw = create_tween()
			tw.tween_property($ColorRect, "modulate", Color(1.0, 0.2, 0.2), 0.2)
			tw.tween_property($ColorRect, "modulate", Color.WHITE, 1.0).set_delay(0.5)

# ── Physics / Input ───────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:

	if current_health < max_health and health_regen > 0.0:
		current_health = min(max_health, current_health + (health_regen / 5.0) * delta)
		health_changed.emit(current_health, max_health)

	# ── Active buff tick ──
	if not _active_buffs.is_empty():
		var expired: Array = []
		for bid in _active_buffs.keys():
			_active_buffs[bid] -= delta
			if _active_buffs[bid] <= 0.0:
				expired.append(bid)
		for bid in expired:
			_active_buffs.erase(bid)
		_refresh_stat_modifiers()

	# ── Momentum decay ──
	if "momentum_stacks" in active_passives and _momentum_stacks > 0:
		_momentum_decay_timer -= delta
		if _momentum_decay_timer <= 0.0:
			_momentum_stacks = 0
			move_speed = _base_move_speed

	# ── Dash cooldown ──
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta

	# ── Dash movement ──
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			is_dashing = false
			set_collision_mask_value(2, true)
		else:
			velocity = dash_direction * dash_speed
			move_and_slide()
			return

	# ── Build direction from input ──
	var direction = Vector2.ZERO
	if Input.is_action_pressed("move_right"): direction.x += 1
	if Input.is_action_pressed("move_left"):  direction.x -= 1
	if Input.is_action_pressed("move_down"):  direction.y += 1
	if Input.is_action_pressed("move_up"):    direction.y -= 1

	var is_moving: bool = direction != Vector2.ZERO
	if is_moving:
		direction = direction.normalized()

	# ── fire_trail passive ──
	passive_on_move(delta, is_moving)

	# ── Dash trigger ──
	if Input.is_action_just_pressed("dash") and dash_cooldown_timer <= 0.0 and is_moving:
		is_dashing      = true
		dash_direction  = direction
		dash_timer      = dash_duration
		# cd_reduction shortens dash cooldown (and ult cooldown)
		dash_cooldown_timer = dash_cooldown / max(0.1, 1.0 + cd_reduction)
		set_collision_mask_value(2, false)
		return

	# ── Ultimate trigger ──
	if Input.is_action_just_pressed("ultimate"):
		cast_ultimate()

	velocity = direction * move_speed
	move_and_slide()

# ── Damage / Health ───────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if is_invincible or is_dashing:
		return

	if randf() < dodge_chance:
		return # Dodge!
		
	# Aegis shield absorbs first
	if _aegis_hp > 0.0:
		var absorbed = min(_aegis_hp, amount)
		_aegis_hp -= absorbed
		amount    -= absorbed
		if amount <= 0.0:
			return

	# armor reduction
	amount = max(1.0, amount - armor)

	# armor_shards damage reduction
	amount *= (1.0 - get_damage_reduction())

	current_health -= amount
	health_changed.emit(current_health, max_health)
	GameManager.add_damage_taken(amount)
	_start_invincibility()

	if current_health <= 0.0:
		die()

func _start_invincibility() -> void:
	is_invincible = true
	var timer = get_tree().create_timer(invincibility_duration)
	timer.timeout.connect(func(): is_invincible = false)

func die() -> void:
	get_tree().call_group("game_manager", "on_player_died")

# ── XP / Levelling ───────────────────────────────────────────────────────────

func collect_gem(amount: int) -> void:
	var run_time: float = GameManager.get_run_time()
	var mult: float = min(1.0 + run_time / 300.0, 6.0)
	xp += int(float(amount) * mult)
	while xp >= max_xp:
		xp -= max_xp
		level_up()
	xp_changed.emit(xp, max_xp, level)

func xp_for_level(lvl: int) -> int:
	return int(25 + pow(float(lvl), 1.4) * 10)

func level_up() -> void:
	level += 1
	max_xp = xp_for_level(level)
	GameManager.update_level(level)
	get_tree().call_group("hud", "show_draft_menu")

# ── Consumable methods ────────────────────────────────────────────────────────

func apply_buff(id: String, duration: float) -> void:
	_active_buffs[id] = duration
	_refresh_stat_modifiers()

## Recalculates move_speed and attack_speed from base values + active buffs.
func _refresh_stat_modifiers() -> void:
	var spd_mult: float = 1.0
	var as_mult: float  = 1.0
	if _active_buffs.has("adrenaline"):
		spd_mult *= 2.0
		as_mult  *= 2.0
	# momentum_stacks already adjusts move_speed directly; we don't double-apply here
	if _momentum_stacks == 0:
		move_speed   = _base_move_speed * spd_mult
	attack_speed = _base_attack_speed * as_mult

## Freezes all non-boss enemies for `duration` seconds.
func apply_freeze(duration: float) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.get("is_dead"):
			continue
		var etype = e.get("current_type")
		if etype == 4 or etype == 5 or etype == 6:  # SUB_BOSS / BOSS / VOID_SPAWN
			continue
		if e.has_method("set_frozen"):
			e.set_frozen(duration)

## Instantly moves all XP gems to the player's position (collected next frame by suction).
func apply_vacuum() -> void:
	for g in get_tree().get_nodes_in_group("gem"):
		if g.get("is_absorbed"):
			continue
		g.global_position = global_position

## Heals the player by a fraction of max health.
func heal_pct(pct: float) -> void:
	current_health = min(max_health, current_health + max_health * pct)
	health_changed.emit(current_health, max_health)
