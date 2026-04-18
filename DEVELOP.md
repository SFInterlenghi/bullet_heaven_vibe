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

## [2026-04-18] Sprint 4: The Armory & Draft Draft
**Summary:**
- **WeaponDB Autoload:** Created a massive `WEAPONS` dictionary spanning 8 unique geometric arrays (Orb, Piercer, Spread, Burst, Cross, Star, Boomerang, Beam). Each contains milestones for Level 3, 6, 9, and 12 mutations.
- **Universal Projectiles:** Consolidated the `bullet.tscn` to entirely abandon rigid structures in favor of parameterized `draw_polygon` arrays that adapt physics rules (orbiting, bouncing, boomeranging) on the fly based on the equipped slot.
- **Leveling Draft Hook:** Hooked `player.gd`'s `level_up()` into `get_tree().paused` logic, generating a 4-choice button draft. Draft forces random weapons from the catalog, filters out max-level/redundant pulls, and fills empty slots with global Stat Ups.
- **Boss Persistency:** Solved distance-culling wiping Bosses. If a `BOSS` or `SUB_BOSS` strays past 1400 pixels, it wraps around its exit vector and teleports exactly ~1200 pixels down the line, ensuring it eternally trails the player without losing its massive HP pool.
