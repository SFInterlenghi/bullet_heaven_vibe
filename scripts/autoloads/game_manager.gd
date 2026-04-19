extends Node

# --- CHARACTER SELECTION ---
# Set by main_menu.gd before changing to world.tscn.
var selected_character_id: String = "wanderer"

# --- RUN STATS ---
# Populated throughout the run; read by run_summary.tscn on game end.
var run_stats: Dictionary = {
	"enemies_killed": 0,
	"damage_dealt":   0.0,
	"damage_taken":   0.0,
	"gems_collected": 0,
	"highest_level":  1,
	"time_survived":  0.0,
	# Per-weapon damage: weapon_id -> { "name", "damage", "color" }
	# Sorted and displayed in the run summary damage table.
	"weapon_damage":  {},
}

func reset_run_stats() -> void:
	run_stats = {
		"enemies_killed": 0,
		"damage_dealt":   0.0,
		"damage_taken":   0.0,
		"gems_collected": 0,
		"highest_level":  1,
		"time_survived":  0.0,
		"weapon_damage":  {},
	}

# --- STAT TRACKERS (called from game systems) ---
func add_kill() -> void:
	run_stats["enemies_killed"] += 1

func add_damage_dealt(amount: float, weapon_id: String = "", weapon_name: String = "", weapon_color: Color = Color.WHITE) -> void:
	run_stats["damage_dealt"] += amount
	if weapon_id == "":
		return
	if not run_stats["weapon_damage"].has(weapon_id):
		run_stats["weapon_damage"][weapon_id] = {
			"name":   weapon_name,
			"damage": 0.0,
			"color":  weapon_color,
		}
	run_stats["weapon_damage"][weapon_id]["damage"] += amount

func add_damage_taken(amount: float) -> void:
	run_stats["damage_taken"] += amount

func add_gem() -> void:
	run_stats["gems_collected"] += 1

func update_level(lvl: int) -> void:
	if lvl > run_stats.get("highest_level", 1):
		run_stats["highest_level"] = lvl

# --- PAUSE CONTROL ---
# _paused tracks whether the pause MENU is open (not draft/summary pauses).
var _paused: bool = false

func _ready() -> void:
	add_to_group("game_manager")

func toggle_pause() -> void:
	# If something else (draft screen, run summary) already owns the pause
	# state, don't interfere — their own UI handles the unpause.
	if get_tree().paused and not _paused:
		return
	_paused = !_paused
	get_tree().paused = _paused
	for m in get_tree().get_nodes_in_group("pause_menu"):
		m.visible = _paused

func quit_run() -> void:
	_paused = false
	_arena_active = false
	get_tree().paused = false
	reset_run_stats()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")

# --- HELPERS ---
func get_run_time() -> float:
	## Live run time in seconds — used by player.collect_gem() for the XP multiplier.
	for hud in get_tree().get_nodes_in_group("hud"):
		if "time_elapsed" in hud:
			return hud.time_elapsed
	return 0.0

# --- VOID ARENA ---
# The arena is a region 50 000px above the main world.
# Teleporting there auto-culls main-world enemies via distance check.
# Disabling the EnemySpawner also pauses total_time, freezing HP scaling.

const ARENA_OFFSET       = Vector2(0.0, -50000.0)
const ARENA_BG_COLOR     = Color(1.0, 0.82, 0.87)   # baby pink
const WORLD_BG_COLOR     = Color(0.102, 0.102, 0.18) # original dark blue

var _arena_active: bool   = false
var _saved_player_pos: Vector2 = Vector2.ZERO

func start_void_arena() -> void:
	if _arena_active:
		return
	_arena_active = true

	var player  = get_tree().get_first_node_in_group("player")
	var spawner = get_tree().get_first_node_in_group("enemy_spawner")

	_saved_player_pos = player.global_position

	# Freeze the spawner — stops new spawns AND pauses total_time (HP scaling)
	spawner.set_process(false)
	spawner.set_physics_process(false)

	# Baby-pink arena background
	var bg = get_tree().get_first_node_in_group("world_background")
	if bg:
		bg.color = ARENA_BG_COLOR

	# Place player on the left side of the arena
	var arena_center: Vector2 = _saved_player_pos + ARENA_OFFSET
	player.global_position    = arena_center + Vector2(-550, 0)
	player.velocity           = Vector2.ZERO

	# Spawn VOID_SPAWN on the right side (deferred so physics settles first)
	spawner.call_deferred("spawn_void_boss", arena_center + Vector2(550, 0))

	# Notify HUD
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_banner"):
		hud.show_banner("VOID ARENA — SURVIVE!", Color(0.9, 0.2, 0.9))

func end_void_arena() -> void:
	if not _arena_active:
		return
	_arena_active = false

	var player  = get_tree().get_first_node_in_group("player")
	var spawner = get_tree().get_first_node_in_group("enemy_spawner")

	# Restore background
	var bg = get_tree().get_first_node_in_group("world_background")
	if bg:
		bg.color = WORLD_BG_COLOR

	# Re-enable spawner (resumes total_time and new spawns around restored player pos)
	spawner.set_process(true)
	spawner.set_physics_process(true)

	# Restore player stats that were halved by the void curse
	if player and player.get("_void_curse_active"):
		player._void_curse_active  = false
		player.move_speed         *= 2.0
		player._base_move_speed   *= 2.0
		player.damage_multiplier  *= 2.0

	# Teleport player home
	player.global_position = _saved_player_pos
	player.velocity        = Vector2.ZERO

	# Victory reward — Mythic chest (no chest prop needed, open it directly)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		if hud.has_method("show_banner"):
			hud.show_banner("VOID VANQUISHED! ✦", Color(0.2, 1.0, 0.9))
		if hud.has_method("show_chest_menu"):
			hud.show_chest_menu(3)  # Mythic chest

# --- END CONDITIONS ---
func _collect_time() -> void:
	for hud in get_tree().get_nodes_in_group("hud"):
		if "time_elapsed" in hud:
			run_stats["time_survived"] = hud.time_elapsed
			break

func _spawn_summary(cause: String) -> void:
	# Add to current_scene, NOT root.
	# root-level nodes survive reload_current_scene() — adding to the current
	# scene ensures the summary is freed with the scene when Play Again fires.
	var summary = load("res://scenes/ui/run_summary.tscn").instantiate()
	get_tree().current_scene.add_child(summary)
	summary.populate(run_stats.duplicate(), cause)
	reset_run_stats()

func on_player_died() -> void:
	if get_tree().paused:
		return  # guard against duplicate calls
	if _arena_active:
		_arena_active = false
		var spawner = get_tree().get_first_node_in_group("enemy_spawner")
		if spawner:
			spawner.set_process(true)
			spawner.set_physics_process(true)
	get_tree().paused = true
	_collect_time()
	_paused = false  # summary owns the pause now, not us
	_spawn_summary("death")

func on_game_won() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	_collect_time()
	_paused = false
	_spawn_summary("victory")
