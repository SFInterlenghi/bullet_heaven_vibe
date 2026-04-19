# Development Log

## [2026-04-18] Project Audit and System Setup
**Summary:**
Initialized documentation for the Bullet Heaven prototype. I conducted a full system audit of the existing Godot Godot 4.6 (Forward Plus) project. The current state contains a minimal functional foundation:
- A controllable player with eight-way movement and invincibility frames.
- A functional weapon manager that automatically shoots temporary bullets to the right.
- Basic enemies that chase the player and inflict continuous touching damage.
- An enemy spawner that spawns basic enemies in a circular layout around the player.
- A `GameManager` autoload that gracefully handles the player's death and triggers a Game Over screen.

No logic/code adjustments were made during this step to preserve the foundation intact. Both `ARCHITECTURE.md` and `DEVELOP.md` were formalized.

## [2026-04-18] Sprint 1: Combat, HUD, and XP System Iteration
**Summary:**
- **Combat Logic:** Fixed `DamageArea` collision mask on Enemies. The Player now correctly receives damage upon collision.
- **HUD & UI:** Created a CanvasLayer-based HUD tracking a game timer, health bar, and an XP bar. Wired up signal-based communication so the Player (`health_changed`, `xp_changed`) broadcasts its own state to decouple UI from logic.
- **XP Ecosystem:** Implemented Gems! Enemies drop a small diamond gem upon death which grants XP. The Player features leveling logic that increases speed and max health upon leveling up.
- **Core Architecture Refactor:** Introduced `PoolManager` Autoload to recycle repetitive instances like Gems and Enemies rather than memory-heavy `queue_free()`.
- **Level Design:** Introduced global time scaling in `enemy_spawner.gd`. As time elapses, spawned enemies receive health and speed buffs.

## [2026-04-18] Sprint 2: Physics Tweaks & Player Dash
**Summary:**
- **Physics Calibration:** Scaled up the `DamageArea` inside `enemy.tscn` to be incrementally larger than its rigid physics boundaries. This guarantees the area intercepts the Player and deals damage without the physics engine nullifying the overlap.
- **Dash Mechanic:** Introduced a high-speed Dash toggle on the `Spacebar` with a 1.5-second cooldown. While active, the Player ignores the enemy Physics Layer, passing straight through swarms to eliminate stuck-states.
- **Background Bounds:** Reparented the Background `ColorRect` to an infinite `CanvasLayer`. The background no longer stays anchored to initial global coordinates and now seamlessly frames the camera infinitely.
- **Cleaned Codebase:** Resolved dual-connection signal bugs firing over instances in `enemy.gd` and solved `PoolManager` processing halts utilizing `set_deferred` physics callbacks.

## [2026-04-18] Sprint 3: Dynamic Spawns & Enemy Archetypes
**Summary:**
- **Enemy Class Variants:** Scaled the single enemy node into 5 dynamic subtypes utilizing `apply_tier()`. Mobs now spawn as Basic (Red, standard), Fast (Yellow, frail), Tank (Green, slow but strong), Spawner (Blue, splits into basic mobs upon death), Sub-Boss (Purple, highly scaled), and Boss (Black, endgame trigger).
- **Phased Wave Spawning:** The `enemy_spawner` was upgraded into a pressure-driven wave manager. It calculates `optimal_enemies` capacity. If the active field drops below optimal, it rapid-fires spawns to maintain tension. Additionally, specific enemy types unlock over standard time thresholds (Basic -> Fast -> Tank -> Spawner), culminating in the Boss.
- **Dash Immunities & Fixes:** Player `take_damage()` was wrapped with a dash-checker, ensuring true invincibility frames during a spacebar dash.
- **Distance Culling:** To prevent Pool memory from capping out with irrelevant stragglers, enemies further than 1400 pixels distance from the player are silently reclaimed into the Object Pool without generating XP gems or split-spawns.
- **Win Condition Hooks:** Built a bare-bones `YOU WIN` CanvasLayer sequence triggered when the ultimate `BOSS` archetype is defeated.

## [2026-04-18] Sprint 5: Bug Fixes & Pacing Recalibration
**Summary:**
- **B1 — Pool retrieval:** `pool_manager.gd::get_node_from_pool()` now calls `node._on_pool_retrieved()` after pop if the method exists. Fixes stale enemy state on reuse.
- **B2 — XP curve:** Replaced `max_xp *= 1.5` with `xp_for_level(lvl) = int(60 + pow(lvl, 1.3) * 15)`. Targets ~50 levels per 25-min run (was ~8 achievable levels with the old exponential). Added `xp_for_level()` helper to `player.gd`.
- **B3 — Enemy scaling:** Reduced HP bonus `total_time * 1.5 → * 0.2` and speed bonus `* 0.1 → * 0.02`. At 25 min BASIC goes from 30 to ~330 HP (was 2280). BOSS goes from 5000 to ~5300 HP (was 7250). Killable throughout.
- **B4 — Boss timing:** Boss now spawns at 22:30 (1350 s), Sub-Boss at 17:30 (1050 s). Was 2.5 min and 1 min respectively.
- **Enemy type weights:** Unlocked by Act — BASIC only for 0–5 min, FAST joins 5–10 min, TANK 10–15, SPAWNER 15–20, heavier TANK/SPAWNER pressure 20–25. Whitespace and comment cleanup.
- **B8 — Boomerang range:** Added `boomerang_travel_dist` variable to `bullet.gd`. `init_weapon` now reads `upgrades.get("travel_dist", 300.0)` instead of hardcoded 300.0. All crescent upgrade levels now work correctly.
- **B10 — Star bounce reflection:** Extracted `_get_cam_rect()` helper. Added `_check_bounce_walls()` that reflects `direction` off screen edges with proper `x`/`y` normals. `_check_screen_bounds()` now excludes bounce type from culling. Enemy hits use a smaller `±PI/4` deflection instead of full random.
- **B11 — Debug print removed:** Eliminated `print("DamageArea hit by: ...")` from `enemy.gd`. Was firing every physics frame during contact.
- **B14 — Draft stat deduplication:** Replaced `stats.pick_random()` loop with a shuffle + index walk so stat upgrade cards cannot repeat in the same draft.
- **B15 — Dash input decoupled:** Added custom `dash` input action (Space) to `project.godot`. `player.gd` now uses `Input.is_action_just_pressed("dash")` instead of `ui_accept`, preventing menu conflicts.
- **B16 — Pierce guard:** `bullet.gd::_on_body_entered` now checks pierce/bounce limit _before_ calling `take_damage()`. Prevents same-frame multi-enemy over-pierce.
- **weapon_db.gd restructure:** All 8 base weapons reduced from 4 milestones (3/6/9/12, max 12) to 2 milestones (3/6, max 6). `"max_level": 6` added to every weapon entry — `weapon_manager.gd` already reads this field. Continuous multipliers unchanged. Added `FUSIONS` dict and `get_fusion()` helper (Sprint 9 work). Level 6 comment marks ascension eligibility for all weapons.
- **Deferred from Sprint 5:** B5/B6/B7 (UI scenes, Sprint 6), B9 (bullet pooling, Sprint 10), B12 (gem tiering, Sprint 7), B13 (bullet_container path, Sprint 6).

## [2026-04-18] Playtest Feedback Pass 1
**Issues addressed from "Issues found during tests.txt":**
- **#1 — Level-up card upgrade details:** `hud.gd::show_draft_menu()` now calls `_describe_weapon_upgrade()` helper which reads `WeaponDB.get_upgrade_data()` and formats DMG multiplier, rate multiplier, projectile count, pierce, burst, bounces (∞ at 99), orbit radius, boomerang range, zone duration, chasing/tracking flags, and MAX level / ascension note. Cards now show "NEW / LV.UP + weapon name → Level N" as header.
- **#2 — Enemy variety too slow:** Act thresholds compressed. FAST joins at 1:30 (was 5:00), TANK at 5:00 (was 10:00), SPAWNER at 10:00 (was 15:00). Heavier mix tiers adjusted accordingly. Player should see FAST enemies within the first 2 minutes.
- **#3 — Clock advances during level-up:** `hud.gd::_process` now skips `time_elapsed += delta` while `get_tree().paused` is true.
- **#4 — Enemies flickering near player:** `spawn_radius` increased 500 → 800. Despawn threshold in `enemy.gd` increased 1400 → 2000. Boss wrap distance increased 1200 → 1600 to match.
- **#5/#6 — Gem pickup feel / missed gems:** `gem.gd` now runs `_physics_process` — gems within 180 px of the player drift toward them at 260 px/s. Fixes both the "hitbox too small" feel and the miss-detection when the player moves quickly through a gem.
- **#7 — Gem screen clutter / fusion:** `gem.gd` now connects `area_entered`. When two gems overlap, the higher-priority one absorbs the other (XP values sum, absorbed gem returns to pool). Guard flag `is_absorbed` prevents the simultaneous dual-fire from double-counting. Gems change color by tier: Teal < 20 XP → Blue ≥ 20 → Purple ≥ 40 → Gold ≥ 80. `_on_pool_retrieved` resets value, flag, and color.
- **#8 — Win condition / testing cap:** `hud.gd` now triggers `on_game_won` at 25:00 (1500 s) via `win_triggered` flag if the BOSS hasn't already ended the run.
- **#9 — No destructibles at 5:16:** Deferred to Sprint 7 (not yet implemented in any sprint).

## [2026-04-18] Sprint 5 Follow-up: Pool Stale-Entry + Double-Die (1460 errors)
**Summary:**
Two separate bugs producing the same error flood:

- **BUG A — Stale pool entries:** Despite the `_pending` guard, nodes could still end up in the pool before `_detach_and_pool` fully completed (timing edge cases in deferred execution). Fix: `get_node_from_pool` now uses a `while` loop that skips any popped node which still has a parent, effectively draining stale entries. The stale node stays in the scene tree and gets returned normally when it eventually dies or is culled. `scene.instantiate()` is used as fallback.
- **BUG B — `die()` called twice in same physics step:** When multiple bullets hit an enemy simultaneously, `take_damage()` fired multiple times before `is_dead` was set. Each `die()` call spawned sub-enemies and returned the node to the pool, causing duplicate pool entries and duplicate deferred `add_child` calls. Fix: `is_dead: bool` flag added to `enemy.gd`. `take_damage()` returns early if `is_dead`. `die()` sets `is_dead = true` as its first action. `_on_pool_retrieved()` resets `is_dead = false`.
- **BUG C — SPAWNER sub-enemies added to wrong parent:** `die()` used `get_tree().current_scene.call_deferred("add_child", child)` (World) for SPAWNER sub-enemies. The enemy_spawner's `_process` runs before deferred calls fire, and could grab the same node and add it to `EnemyContainer`. When the deferred `add_child` to World then fired, the node already had `EnemyContainer` as parent. Fix: changed to `get_parent().call_deferred("add_child", child)` — sub-enemies land in the same container as their parent SPAWNER.

## [2026-04-18] Sprint 5 Follow-up: Pool Double-Return Bug
**Summary:**
- **ROOT CAUSE — double return_node_to_pool in same frame:** A node can be returned to the pool twice simultaneously — e.g. a bullet calls `take_damage → die → return_node_to_pool` AND `_physics_process` distance-cull fires `return_node_to_pool` on the same enemy in the same frame. The previous fix (deferred push via `_detach_and_pool`) deferred the push correctly, but a second `call_deferred("_detach_and_pool", ...)` was still queued for the same node. Both fire at end-of-frame: first one removes from parent + pushes; second one (parent now null) skips remove + pushes again. Node now has two entries in the pool. Retrieved twice → second `add_child` fails with "already has a parent".
- **FIX:** Added `_pending: Dictionary` (instance_id → true) to `pool_manager.gd`. `return_node_to_pool` checks `_pending` first — if the node is already queued for return, the call is a silent no-op. `_detach_and_pool` erases the id from `_pending` when it completes, so the node is clean for future pool cycles.

## [2026-04-18] Sprint 5 Follow-up: Pool Race Condition (16 919 errors)
**Summary:**
- **ROOT CAUSE — `pool_manager.gd` race condition:** `return_node_to_pool()` called `call_deferred("remove_child", node)` (deferred, fires next frame) but then immediately called `push_back(node)` (synchronous). Result: the node sat in the pool while still parented to `EnemyContainer`. The next `get_node_from_pool()` call in the same frame retrieved it, and `enemy_container.add_child(enemy)` exploded with "Can't add child — already has a parent". The Godot engine then emitted a compensating `remove_child` error, giving two error lines per spawn cycle → 16 919 errors in a short run.
- **FIX:** Replaced the deferred `remove_child` + immediate `push_back` with a single `call_deferred("_detach_and_pool", node, scene_path)`. The new `_detach_and_pool()` helper does `remove_child` then `push_back` atomically in the right order. The node is never in the pool while it still has a parent.

## [2026-04-18] Sprint 5 Follow-up: Crash Fix & Warning Cleanup
**Summary:**
- **CRASH — `enemy.gd::_on_pool_retrieved` null tree:** `PoolManager.get_node_from_pool()` calls `_on_pool_retrieved()` immediately after `pop_back()`, before `add_child()` — so `get_tree()` returns null. Fix: removed `player = get_tree().get_first_node_in_group("player")` from `_on_pool_retrieved()`. The `player` reference stored in `_ready()` remains valid for the entire run; no refresh is needed. Added an explanatory comment so the invariant is clear to future readers.
- **WARN — `weapon_manager.gd:70` UNUSED_PARAMETER:** Renamed `is_sub_burst` → `_is_sub_burst`. The parameter exists to keep a uniform call-site signature for burst vs normal fire; the underscore prefix silences the engine warning without removing the intent.
- **WARN — `weapon_manager.gd:75` UNUSED_VARIABLE:** Removed `var type = w["data"]["type"]` — was left over from an earlier conditional that was since inlined. The type is read directly by `bullet.gd::init_weapon()` from the passed dictionary.
- **WARN — `hud.gd:123` INTEGER_DIVISION:** Changed `int(time_elapsed) / 60` to `int(time_elapsed / 60.0)` so division happens on floats before truncation, matching GDScript's expected type path.

## [2026-04-18] Roadmap: Implementation Plan Revision 2
**Summary:**
- **Feature 1 expanded:** Characters now have 3 exclusive passives (2 active at run start, 3rd unlocks at player level 10) and 1 ultimate ability on Left Shift. `character_db.gd` and `passive_db.gd` added as new autoloads. Six ultimates designed (Temporal Shift, Aegis, Sniper Mode, Cyclone, Artillery, Arcane Nova). Fire-trail passive needs `fire_patch.tscn` world object.
- **Level budget resolved:** Base weapon max reduced from 12 → **6** (milestones at 3 and 6). Fused weapons remain at max 12. Ascension triggers at level 6 (character's main weapon only). Target player levels raised from 28 → **50 per run**. Budget math confirms 3 legendary fused weapons fully leveled costs 69 picks; 75 available (50 player + 25 chest) — feasible with optimal play.
- **New XP curve:** `60 + pow(lvl, 1.3) * 15` — tuned for 50 levels/25 min.
- **Feature 7b added:** Pause Menu (Escape) and Stats Overlay (Tab-hold) — separate from run summary. Pause has Resume/Controls/Quit. Stats panel shows live weapons, passives, ultimate cooldown, player stats.
- **Sprint 6 expanded** to include pause menu and stats overlay alongside draft UI refactor. Sprint 8 expanded to include full passive/ultimate implementation.
- **Input actions planned:** `ultimate` (Left Shift), `pause` (Escape), `stats` (Tab) to be added to `project.godot`.

## [2026-04-18] Roadmap: Comprehensive Implementation Plan
**Summary:**
- **IMPLEMENTATION_PLAN.md authored:** Full multi-sprint roadmap (Sprints 5–14) covering bug fixes, run pacing, characters/ascension, weapon fusion, destructibles/consumables, chests, draft UI refactor, run summary, meta-progression skeleton, and unique mechanics (elites, curses, weather, combos).
- **Pacing defined:** 25-minute runs broken into 5 Acts with milestones (Elite at 4:00, mini-bosses 7:30/12:00/15:00, sub-boss 17:30, final boss 22:30). Target ~28 levels per run.
- **Bug audit (B1–B16):** Documented 16 bugs / tech-debt items in the current codebase — most critical: `PoolManager.get_node_from_pool()` never calls `_on_pool_retrieved()` (stale state); `max_xp *= 1.5` makes level 25 unreachable (~1.6M XP); enemy HP scales +2250 over 25 min (unplayable); boomerang ignores upgrade-defined `travel_dist`; bullets use `queue_free` instead of pool.
- **Data model decisions:** Ascension as `"ascended"` subkey in WeaponDB; fusion via sorted-pair keys in new `FUSIONS` dict; character data in new `character_db.gd` autoload; persistent gold in `save_manager.gd` → `user://save.json`.
- **XP economy:** New curve `80 + pow(lvl, 1.45) * 22`; tiered gems (Green/Blue/Purple/Gold); time-based XP multiplier; pickup radius with gem suction.
- **No code changes this entry** — planning only.

## [2026-04-18] Sprint 5 Setup: Godot MCP Integration & Project Handoff
**Summary:**
- **Godot MCP Addon:** Installed `@satelliteoflove/godot-mcp` v2.17.0 via `npx --install-addon`. Plugin enabled in `project.godot`. WebSocket bridge runs on `ws://127.0.0.1:6550` when the Godot editor is open.
- **Claude Code Settings:** Created `D:/bullet_heaven/.claude/settings.json` registering the `godot` MCP server (stdio bridge via `npx -y @satelliteoflove/godot-mcp`). Requires Claude Code restart to activate.
- **Dev Log Policy:** All code changes, config changes, and architectural decisions from this point forward are logged here.

## [2026-04-19] Sprint 7: XP Economy & Gem Tiers
**Summary:**
- **Gem tier colors** (`gem.gd`): Replaced the single teal default with four tiers matching the drop table — Green (< 5 XP), Blue (>= 5), Purple (>= 25), Gold (>= 100). Color constants updated, `_update_tier_color()` thresholds updated, `_on_pool_retrieved()` resets to `xp_value = 1` + GREEN.
- **Tiered drops by enemy type** (`enemy.gd` + `_gem_xp_for_type()`):
  - BASIC/FAST: green (1 XP) before 10:00, blue (5 XP) from 10:00 onward.
  - TANK/SPAWNER: blue (5 XP) always.
  - SUB_BOSS: purple (25 XP).
  - BOSS: 5 × gold (100 XP each), scattered within ±30 px.
  - `_on_pool_retrieved()` reset to 1; `enemy.die()` sets `gem.xp_value` + calls `gem._update_tier_color()` before the deferred `add_child` fires.
- **XP time multiplier** (`player.gd::collect_gem()`): `mult = 1 + run_time/300`, capped at 6×. Applied to gem XP before adding to player. Early-game baseline preserved; late-game gold gems deliver satisfying bursts.
- **`pickup_radius` as player stat** (`player.gd`): New `@export var pickup_radius: float = 120.0`. Gem suction now reads `player.pickup_radius` live (passives/upgrades can modify it). Removed hardcoded `SUCTION_RADIUS` constant from gem.gd.
- **`GameManager.get_run_time()`** (`game_manager.gd`): Helper that reads `hud.time_elapsed` from the HUD group. Used by both `collect_gem()` XP multiplier and `enemy._gem_xp_for_type()`.
- **Fusion still works**: two green gems fuse to 2 XP (still green); five fuse to 5 XP (turns blue). Fusion preserves XP exactly; multiplier is applied on pickup, not on fusion.

## [2026-04-19] Sprint 6 Follow-up: UI Orphan Fixes + Weapon Damage Table
**Summary:**
- **BUG — `hud.gd:26/30` "parent busy setting up children"**: `add_child()` called synchronously on `get_tree().root` inside `_ready()` while the root was still propagating its own ready chain. Fix: changed both spawns (pause_menu, stats_overlay) to `get_tree().current_scene.call_deferred("add_child", ...)`. Also added `is_inside_tree()` guard in `_process` for the stats overlay (safe during the one-frame window before the deferred fires).
- **BUG — run_summary + HUD persist after "Play Again"**: `game_manager` was adding run_summary to `get_tree().root`. `reload_current_scene()` only frees the current scene subtree — root-level nodes are orphaned and survive the reload. Same root cause for the pause_menu/stats_overlay from hud. Fix: moved `_spawn_summary()` to use `current_scene.add_child()`. Nodes added to current_scene are freed when the scene reloads.
- **BUG — draft screen & pause menu rendered in bottom-right**: `PRESET_CENTER` on a size-0 container placed the top-left at screen center. Fixed in previous session by wrapping in `CenterContainer` with `PRESET_FULL_RECT`.
- **FEATURE — per-weapon damage table in run summary**:
  - `game_manager.run_stats` now includes `"weapon_damage": {}` — a dict keyed by `weapon_id` holding `{name, damage, color}`.
  - `add_damage_dealt()` gains optional `weapon_id`, `weapon_name`, `weapon_color` params (backward-compatible defaults).
  - `bullet.gd` stores `weapon_id` and `weapon_name` from `init_weapon()`; passes them + `weapon_color` to `add_damage_dealt()` on every hit.
  - `run_summary.gd` redesigned: two-column layout (weapon damage table left, player stats right). Weapon rows show a live polygon icon (weapon shape from WeaponDB scaled to 40×40 via the `draw` signal), weapon name, and damage dealt. Rows sorted by damage descending with a total row at bottom. "Damage Dealt" removed from the right-column stats (it is now the total in the left column).
- **KNOWLEDGE — `PITFALLS.md`** created at `~/.claude/projects/D--bullet-heaven/memory/PITFALLS.md` and indexed in `MEMORY.md`. Documents 7 confirmed bugs with root causes and fixes so future agents avoid repeating them. Covers: add_child-in-ready, root-orphan-on-reload, PRESET_CENTER on empty containers, area_entered on tiny shapes, pool race conditions, get_tree-in-pool-retrieved, beam weapon architecture.

## [2026-04-18] Sprint 6: Draft UI Refactor, Run Summary, Pause & Stats Overlay
**Summary:**
- **Input actions added** (`project.godot`): `pause` (Escape), `stats` (Tab), `ultimate` (Left Shift).
- **GameManager rewrite** (`game_manager.gd`): `run_stats` dictionary tracking kills, damage dealt/taken, gems collected, highest level, time survived. Stat tracker methods: `add_kill()`, `add_damage_dealt()`, `add_damage_taken()`, `add_gem()`, `update_level()`. `toggle_pause()` guards against stealing the pause state from draft/summary screens. `on_player_died()` and `on_game_won()` instantiate the new `run_summary.tscn` and reset stats. `quit_run()` reloads the scene.
- **`run_summary.tscn`/`.gd`** (new): CanvasLayer layer=20, PROCESS_MODE_ALWAYS. `populate(stats, cause)` builds a stats screen showing time, level, kills, damage dealt/taken, gems. Title green for victory, red for death. "Play Again" reloads the scene.
- **`draft_screen.tscn`/`.gd`** (new): CanvasLayer layer=5, PROCESS_MODE_ALWAYS. Emits `card_selected(option)` signal. `populate(options)` builds cards with staggered tween reveal (0.07s per card, fade + scale-up). `_describe_upgrade()` helper shows full stat breakdown per weapon level.
- **`pause_menu.tscn`/`.gd`** (new): CanvasLayer layer=10, PROCESS_MODE_ALWAYS. Registers in group "pause_menu" for GameManager discovery. Resume → `GameManager.toggle_pause()`; Quit Run → `GameManager.quit_run()`.
- **`stats_overlay.tscn`/`.gd`** (new): CanvasLayer layer=8. Tab-hold show/hide. Two panels: WEAPONS (name, level, DMG/Rate per slot) and PLAYER STATS (HP, speed, level + run totals from GameManager.run_stats).
- **`hud.gd` migration**: Instantiates pause_menu and stats_overlay in `_ready()`. `show_draft_menu()` now instantiates `draft_screen.tscn`, calls `populate()`, connects `card_selected`. `_input()` handles Escape → `GameManager.toggle_pause()` (blocked while draft open). `_process()` handles Tab → `stats_overlay.show/hide_overlay()`. Removed inline `_describe_weapon_upgrade()` (lives in draft_screen.gd now).
- **Stat tracking wired in**:
  - `enemy.gd::die()` → `GameManager.add_kill()`
  - `bullet.gd::_on_body_entered()` → `GameManager.add_damage_dealt(damage)`
  - `player.gd::take_damage()` → `GameManager.add_damage_taken(amount)` + removed debug `print()`
  - `player.gd::level_up()` → `GameManager.update_level(level)`
  - `gem.gd::_on_body_entered()` → `GameManager.add_gem()`
- **Gem fusion fix**: Replaced broken `area_entered` approach (collision shapes ±8 units, never physically overlap) with proximity-based check every 0.5 s. `_check_fusion()` scans gem group for nodes within 50 px, absorbs closest, updates tier color. Also removed `set_collision_mask_value(4, true)` and the `area_entered` signal connection from `_ready()`.
- **Beam weapon fix** (`bullet.gd` + `weapon_db.gd`): Beam is now stationary — placed at player position, rotated to fire direction (`rotation = direction.angle()`), and stays in place for its full `duration`. Collision shape swapped at runtime to `RectangleShape2D` (200 × 8 px, centered at x=100). Shape in weapon_db updated to 200 px long rectangle. Beam excluded from screen-bounds culling. Beam persists through multiple enemy hits (same as zone/orbital). Removed beam from the moving-straight branch of `_physics_process`.
- **Boomerang size fix** (`weapon_db.gd`): Crescent shape scaled ×2 (all vertices doubled). Visual is now clearly visible.

## [2026-04-18] Sprint 4: The Armory & Draft Draft
**Summary:**
- **WeaponDB Autoload:** Created a massive `WEAPONS` dictionary spanning 8 unique geometric arrays (Orb, Piercer, Spread, Burst, Cross, Star, Boomerang, Beam). Each contains milestones for Level 3, 6, 9, and 12 mutations.
- **Universal Projectiles:** Consolidated the `bullet.tscn` to entirely abandon rigid structures in favor of parameterized `draw_polygon` arrays that adapt physics rules (orbiting, bouncing, boomeranging) on the fly based on the equipped slot.
- **Leveling Draft Hook:** Hooked `player.gd`'s `level_up()` into `get_tree().paused` logic, generating a 4-choice button draft. Draft forces random weapons from the catalog, filters out max-level/redundant pulls, and fills empty slots with global Stat Ups.
- **Boss Persistency:** Solved distance-culling wiping Bosses. If a `BOSS` or `SUB_BOSS` strays past 1400 pixels, it wraps around its exit vector and teleports exactly ~1200 pixels down the line, ensuring it eternally trails the player without losing its massive HP pool.

## [2026-04-19] Sprint 8: Characters, Passives & Ascension
**Summary:**
- **CharacterDB autoload** (`scripts/autoloads/character_db.gd`): Defines 3 playable characters — Wanderer (piercer, 100HP, `temporal_shift`), Monk (orb, 80HP, `aegis`), Archer (beam, 90HP, `sniper_mode`). Each has 3 passives (first 2 active from run start, 3rd unlocks at Lv.10) and an ultimate with individual cooldown.
- **PassiveDB autoload** (`scripts/autoloads/passive_db.gd`): 7 passive abilities across 5 hooks — `on_fire` (twin_barrels), `on_take_damage` (armor_shards), `on_kill` (momentum_stacks, zen_threshold), `on_move` (fire_trail), `on_hit` (orbit_knockback), `on_init` (piercing_eye).
- **FirePatch scene** (`scenes/world/fire_patch.gd` + `.tscn`): Area2D that deals 8 DPS to enemies inside for 2 s, fades out in the last 0.4 s. Spawned by the Monk's `fire_trail` passive while moving.
- **Ascended Weapons** (`weapon_db.gd`): 8 ascended forms added (`lancer`, `phantom_orb`, `typhoon`, `storm_burst`, `sacred_cross`, `supernova`, `hurricane`, `death_ray`). Base weapons now carry `ascended_id`. Ascended weapons have `max_level=12`, 4 milestones (3/6/9/12), and are only reachable via ascension — never shown as new-weapon draft picks.
- **Character application** (`player.gd`): `apply_character(char_id)` sets stats, loads passives, clears WeaponManager and adds the character's starting weapon. Called in `_ready()` using `GameManager.selected_character_id`.
- **Passive system** (`player.gd`): `active_passives[]` list. `passive_on_kill()` handles momentum_stacks speed boost and zen_threshold damage multiplier. `passive_on_move()` spawns fire patches. `get_damage_reduction()` reads armor_shards. `damage_multiplier` applied in weapon_manager before firing.
- **Ultimate abilities** (`player.gd`): `cast_ultimate()` dispatches by `_ultimate_id` — `temporal_shift` (0.3× time scale + invincibility for 5 real seconds via `ignore_time_scale`), `aegis` (200-damage absorb shield), `sniper_mode` (next 8 shots ×5 damage). Ultimate cooldown ticks in `_physics_process`, emits `ultimate_changed` signal for HUD.
- **Passive hooks wired in**: `twin_barrels` fires extra projectile at 0.75× damage in weapon_manager; `piercing_eye` forces `max_pierce=9999` on straight/beam after init; `orbit_knockback` adds velocity impulse to enemies on orbital hit (`bullet.gd`); `passive_on_kill()` called from `enemy.die()`.
- **Weapon ascension flow** (`weapon_manager.gd`, `draft_screen.gd`, `hud.gd`): Ascension option appears in level-up draft when a weapon is at max_level AND has an `ascended_id`. Gold-tinted card in draft screen. `WeaponManager.ascend_weapon()` swaps the slot's id/level/data in-place. The `generate_draft_options()` gate prevents ascended weapons appearing as new-weapon picks and prevents the base weapon re-appearing after ascension.
- **Main Menu** (`scenes/ui/main_menu.gd` + `.tscn`): Procedurally built character-select screen. Each card shows name, description, starting weapon, base stats, passives (with Lv.10 tag on 3rd), and ultimate name + cooldown. Clicking sets `GameManager.selected_character_id`, resets run_stats, and `change_scene_to_file` to `world.tscn`.
- **HUD additions** (`hud.gd`): Ultimate cooldown ProgressBar added dynamically to VBoxContainer second row. Bar fills as cooldown ticks to 0, turns gold when ready. Pressing `[Q]` triggers `player.cast_ultimate()`. `passive_unlocked` signal shows a 3-second fade-out banner at the top of screen on level 10.
- **Navigation updated**: `GameManager.quit_run()` → `change_scene_to_file("main_menu.tscn")`. `run_summary.gd` "Play Again" → `change_scene_to_file("main_menu.tscn")`. `project.godot` main scene changed to `main_menu.tscn`. CharacterDB and PassiveDB added to autoloads.

## [2026-04-19] Sprint 8 Follow-up: Main Menu Card Overflow Fix
**Summary:**
- **BUG — Character select cards overflowed screen width**: `Button.text` does NOT wrap — the button grew as wide as its longest text line. With character descriptions (~50-60 chars at 17pt), each card expanded to ~500 px × 3 cards > 1280 px screen width, clipping the Archer card.
- **Fix — `main_menu.gd` redesigned**: Cards are now `PanelContainer` nodes with `custom_minimum_size = Vector2(260, 0)`. Text content uses `Label` nodes with `autowrap_mode = TextServer.AUTOWRAP_WORD_BALANCED` + `size_flags_horizontal = SIZE_EXPAND_FILL`. A small `Button` at the bottom handles click interaction. Cards stay at 260 px wide; 3 cards + spacing = 820 px << 1280 px.
- **KNOWLEDGE — PITFALLS.md #8 added**: Documents the Button text non-wrapping pitfall with root cause and the PanelContainer + Label(autowrap) pattern as the correct fix.
- **NOTE — PassiveDB/CharacterDB "not declared" error**: These are stale editor parse errors that appear when Godot has not yet reloaded after `project.godot` was edited externally. Resolution: **Project → Reload Project** in the Godot editor. Both autoloads work correctly at runtime (evidenced by the main menu rendering passive names).

## [2026-04-19] System Audit & Debug Log Creation
**Summary:**
- **Code & Roadmap Review:** Audited codebase up to Sprint 8 (Characters, Passives & Ascension) and read through the `IMPLEMENTATION_PLAN.md`.
- **Debug Log Initiated:** Created `ai_debug_log.md` detailing crucial engine pitfalls, pooling race conditions, and general Godot 4 best practices accumulated over Sprints 1-8. This serves as a knowledge base to avoid regressing on solved bugs like `add_child` ready races and double-return pool behaviors.
- **Next Step Defined:** Confirmed that the immediate next priority according to the schedule is **Sprint 9: Weapon Fusion** (involving `FUSIONS` dictionary, the `fuse_weapons()` function, and Draft UI injection).
- **Minor Bugs Identified during Review:**
  - `weapon_manager.gd::get_closest_enemy()` scans the "enemy" group and checks distance, but does not explicitly ignore `is_dead == true` enemies. Dead enemies waiting to be pooled might briefly attract projectiles.
  - `bullet_scene` spawning in `weapon_manager.gd` still uses `instantiate()` directly, avoiding `PoolManager`, which will cause stuttering at extreme levels (Deferred to Sprint 10 per roadmap).

## [2026-04-19] Sprint 8 Follow-up: Input Event Syntax Bug
**Summary:**
- **BUG — `hud.gd:173` "Nonexistent function is_action_just_pressed":** 
  - **Symptom:** The game crashed when picking a class because Godot was passing an `InputEventMouseMotion` object (from hovering the mouse over the UI) to `_input(event)` which then called `event.is_action_just_pressed("ultimate")`.
  - **Fix:** Swapped `event.is_action_just_pressed("ultimate")` with `event.is_action_pressed("ultimate") and not event.is_echo()`. `InputEvent` API doesn't support the `.is_action_just_pressed()` wrapper available on the `Input` singleton.
  - Logged this input lifecycle lesson to `ai_debug_log.md`.

## [2026-04-19] Sprint 8 Follow-up: GDScript Variant Inference Bug
**Summary:**
- **BUG — `run_summary.gd:193 & 202` "Cannot infer the type of variable":**
  - **Symptom:** Parse error crashing the game `Cannot infer the type of "node" variable because the value doesn't have a set type.` and `The variable type is being inferred from a Variant value`.
  - **Fix:** Replaced implicit typed assignments (`:=`) with explicitly typed declarations (`var sc: float = ...`, `var node: Control = ...`) since Godot's GDScript parser was struggling to infer the static type of `max()` and the `Control` creation across assignment scopes. 
  - Logged GDScript static typing implicit failure to `ai_debug_log.md`.

## [2026-04-19] Sprint 9 Execution: Fusions, Lag Fixes, Balance
**Summary:**
- **Performance:** Completely resolved the 15-minute FPS lag. Replaced `gem.gd` O(N²) array loops with a global limit of 300 instances handled within `enemy.gd`. Surplus XP is instantaneously deposited into random living gems.
- **Visual Improvements:** Overloaded Gems now dynamically scale up by 150% (Red Ruby Tier) and 200% (White Diamond Tier). Player now flashes various colors via `Tween` when Ultimates trigger.
- **Input Refinement:** Expanded the Ultimate bind to trigger on both `[SHIFT]` and `[Q]`. Moved detection from CanvasLayer `hud.gd` to physical `player.gd` `_physics_process()` to guarantee flawless activation.
- **Economy Balance:** Enemy spawning logic scales health heavily (+0.4 per second) and basic weapons only scale +10% per level.
- **Bug Fix:** Bound orbital weapons from spawning infinitely without deletion. Old orbitals simply `queue_free/PoolManager.return` before shooting anew to permanently enforce limits matching the stat card.
- **Weapon Fusions:** Added `FUSIONS` table and `mythic` weapons to `weapon_db.gd`.
- **Character Weapon Integrity:** Modified `hud.gd` draft pool algorithm to strictly bar a specific character's defined `main_weapon` from populating inside other characters' runs. This restricts Ascension purely to a player's core identity.
- **New Pool Additions:** Designed 3 new base weapons (`Magic Missile`, `Whip`, and `Dagger`) along with their Ascensions to replace the locked class weapons on the draft screen.
- **Late-Sprint Hotfixes:** Resolved three critical start-up crashes related to node-tree pathing (`Polygon2D` vs `ColorRect`, `CollisionShape2D` vs `CollisionPolygon2D`) and a duplicate `FUSIONS` variable/function declaration leftover from template stubs. Converted Ultimate charging to trigger cleanly on enemy kills instead of time passing. Documented these oversights to `ai_debug_log.md`.


## [2026-04-19] Sprint 10 & 11 Initialization: RPG Stats, Chests, & Void Spawns

**Added / Modified:**
- **Base Stats System:** Added health_regen, rmor, dodge_chance, crit_chance, crit_damage, luck, ttack_speed, cd_reduction, and rea_of_effect into player.gd. Connected these visually into the draft UI fallback stats generator.
- **Chest System:** Enemies now have a chance to drop chest.tscn. The chest pauses the game and prompts the player. Base implementation is complete.
- **Void Spawn Event:** Added the EnemyType.VOID_SPAWN logic heavily influenced by the new luck stat. Void Reliquaries act as cursed event chests where accepting the curse halves your stats but spawns a gigantic Sub-Boss that holds mythical rewards.
- **Boss Scaling:** Scaled Visuals/Colliders of Sub-Boss to 5.0x and Final Boss to 6.0x size.
- **Draft Logic Improvements:** Passive drafts now strictly pull from the designated CharacterDB passive pool. Card visuals in draft_screen now use utowrap_mode rigidly. un_summary stat boxes now sit inside secure ScrollContainers.

**Pending for Next Agent (Claude):**
- Implement the actual destructible objects (destructible.tscn / Static Anomalies) which screen-nuke enemies but potentially delete XP.
- Implement the consumable.tscn drops (Vacuum, Chronosphere, Adrenaline).
- Write the logic that dispenses the 4+ upgrades and stat boosts during the Mythic Chest unlock.
- Global bugfixes & general continuous optimization.


## [2026-04-19] Sprint 12: Polish, Stat-Wiring & Static Anomalies

### Phase 0 — Hotfixes
- **`TextServer.AUTOWRAP_WORD_BALANCED` → `AUTOWRAP_WORD_SMART`**: Constant doesn't exist in Godot 4.6. Fixed in `draft_screen.gd` and `main_menu.gd` comment. Added entry to `ai_debug_log.md` with all missing PITFALLS lessons (CenterContainer, area_entered tiny shapes, get_tree() in pool_retrieved, beam architecture).
- **Dead signal removed**: `passive_unlocked(passive_id)` + `_unlock_passive` var removed from `player.gd` (passives are drafted, signal never fired). Replaced with `show_banner_signal(text, color)`. HUD `_on_passive_unlocked` rewritten as general `show_banner(text, color)` — used by chest, consumables, destructibles.

### Phase 1 — Stat Wiring Completion
- **`cd_reduction`**: Now divides weapon effective cooldown alongside `attack_speed` in `weapon_manager.gd`. Also shortens dash cooldown and accelerates ultimate kill-charge tick in `player.gd`.
- **`area_of_effect`**: Applied in `bullet.gd::init_weapon()` — scales weapon shape vertices, orbital `spin_radius`, and beam rectangle length. Clamped 0.5–4.0.
- **`luck`**: Wired into chest drop chance, rarity promotion rolls, gem XP doubling, and effective crit chance. Each point above 1.0 adds meaningful bonuses.
- **Draft stat pool expanded**: 12 stats now draftable (added `crit_damage`, `attack_speed`, `cd_reduction`, `area`, `dodge`, `regen`). Shuffle-and-exclude prevents repeats in one draft. `_apply_stat(player, id, stacks)` helper extracted — supports `stacks=3` for mega-stat chest rewards.
- **`_base_attack_speed`** added to `player.gd` so Adrenaline buff can multiply cleanly without drifting on repeated picks.

### Phase 2 — Chest Rarity Reward Scaling
- **`show_chest_menu(rarity)`** now builds rarity-appropriate option sets via `_build_chest_options(rarity)`:
  - Common (0): 1 weapon upgrade or fallback heal
  - Uncommon (1): 2 weapon upgrades
  - Rare (2): 3 weapon upgrades + 1 guaranteed mega-stat (×3 application)
  - Mythic (3): 4 mega-stats (×3 each)
- **`mega_stat` draft type** added — `_on_draft_selected` routes to `_apply_stat(..., 3)`.
- Banner shown on chest open: colour-coded by rarity.

### Phase 3 — Void Reliquary Polish
- **`_void_curse_active: bool`** on `player.gd` — prevents stat doubling without a matching halving if player somehow hits two void reliquaries.
- **`chest.gd` rewrite**: re-entry prompt cooldown (3s after declining), removed `void_accepted` bool (was redundant), `start_void_event` checks `_void_curse_active` before halving, `_base_move_speed` halved alongside `move_speed`.
- **Curse reversal** on VOID_SPAWN death in `enemy.gd` — only doubles stats when `_void_curse_active` is true, then clears flag.
- **Guaranteed first void**: `enemy_spawner._first_void_spawned` flag — first chest dropping after 3:00 is forced void. After that, luck-scaled chance.
- **VOID_SPAWN gem XP** fixed: now returns 500 XP (was falling through to BASIC 5 XP branch).

### Phase 4 — Static Anomalies (Destructibles)
- **`scenes/world/destructible.gd` + `.tscn`**: Area2D that pulses in size, has `take_damage()`, double-die guard, and `detonate()`:
  - Nukes all visible non-boss enemies (bosses take 500 chip damage)
  - 50% chance to wipe all XP gems (banner: "XP DESTABILIZED!" vs "ANOMALY CLEARED")
  - Drops one random consumable at detonation point
  - Returns to pool on detonation
- **`scenes/world/destructible_spawner.gd`**: Manages 3–6 alive destructibles by Act. Spawns 600–850px from player every 8–12s. Skips spawn during boss fights.
- **`world.tscn`**: `DestructibleSpawner` node added as sibling of `EnemyContainer`.
- **`bullet.gd`**: `_on_area_entered` now routes damage to `"destructible"` group members (Area2D → Area2D requires `area_entered`, not `body_entered`). Consumes one pierce charge.

### Phase 5 — Consumables (Unstable Energies)
- **`scenes/props/consumable.gd` + `.tscn`**: Area2D pickup, 4 types driven by `consumable_type: int`:
  - 0 Chronosphere — freezes all non-boss enemies 4s
  - 1 Vacuum (Singularity) — teleports all gems to player position
  - 2 Adrenaline Spike — 2× attack_speed + move_speed for 10s
  - 3 Mending Shard — restores 30% HP
- **`player.gd` buff system**: `_active_buffs: Dictionary` (id → seconds). Ticked in `_physics_process`. `_refresh_stat_modifiers()` recalculates `move_speed` and `attack_speed` from base values + active buffs.
- **`player.gd` consumable methods**: `apply_buff()`, `apply_freeze()`, `apply_vacuum()`, `heal_pct()`.
- **`enemy.gd` freeze hook**: `_frozen_timer: float`, `set_frozen(duration)` method, freeze tick at top of `_physics_process` (skips all movement). Blue tint while frozen. Reset in `_on_pool_retrieved`.
- Consumables pooled via `PoolManager`; `_on_pool_retrieved` resets `is_collected` and restores color.

### Phase 6 — Misc Cleanups
- **Fusion legendary bonus**: `fuse_weapons()` stores `fusion["legendary_bonus"]` in `w["bonus"]`. `_fire_projectile` reads `bonus["extra_count"]` for count and `bonus["damage_mult"]` for per-shot multiplier.
- **HUD timer immune to `Engine.time_scale`**: `_process` now accumulates `time_elapsed` using `Time.get_ticks_msec()` wall-clock delta, so Temporal Shift's 0.3× time scale no longer slows the run clock.

## [2026-04-19] Sprint 12 Continuation: Void Arena Wiring

### Final Wiring Pass
- **`chest.gd::start_void_event()`**: Replaced inline `spawner.spawn_void_boss()` call with `GameManager.start_void_arena()`. Curse application (halving stats) kept in chest so it lands before the arena teleport.
- **`enemy.gd::die()` VOID_SPAWN branch**: Replaced inline curse-reversal + `drop_chest=true` with single `GameManager.end_void_arena()` call. GameManager handles stat restoration, bg color, spawner re-enable, player teleport home, and Mythic chest reward.
- **`game_manager.on_player_died()`**: Clears `_arena_active` and re-enables spawner process before pausing the tree, so dying inside the arena doesn't leave the spawner permanently disabled.
- **`game_manager.quit_run()`**: Clears `_arena_active` so the autoload is clean if the player quits from the pause menu mid-arena.

## [2026-04-19] Sprint 10/11: Claude Audit Pass
**Summary:**
- **8 critical bugs fixed** across hud.gd, enemy.gd, enemy_spawner.gd, chest.gd, and chest.tscn.
- **Stats wired into consumers:** ttack_speed now divides weapon cooldowns. crit_chance/crit_damage now roll per-projectile. Previously these were dead variables.
- **Most critical fix:** Infinite while loop in draft generation � a pass body with no iterator increment would hang the game permanently if fewer than 3 weapon options existed.
- **Handoff document created:** CLAUDE_HANDOFF.md with full project context, remaining tasks, and a ready-to-use first prompt.
- **ai_debug_log.md** updated with 5 new lessons from this audit.

