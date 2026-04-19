# Claude Handoff — "For Happier Days" Bullet Heaven

## Project State

This is a Godot 4.6 (GDScript) Bullet Heaven / Vampire Survivors-style roguelite. The codebase has gone through 10+ sprints of development.

## Key Files to Read First

1. **`ai_debug_log.md`** — Critical. Contains all known engine pitfalls, pooling race conditions, and hard-won lessons. Read this BEFORE writing any code. Every bug pattern here has been hit at least once.
2. **`DEVELOP.md`** — Full chronological change log. Shows what was done, when, and why.
3. **`IMPLEMENTATION_PLAN.md`** — The master roadmap. Shows what's done and what's still pending.

## What Was Done in Sprint 10/11 (Current)

### Completed
- **Full RPG stat block** on `player.gd`: `health_regen`, `armor`, `dodge_chance`, `crit_chance`, `crit_damage`, `luck`, `attack_speed`, `cd_reduction`, `area_of_effect`
- **Stats wired into consumers**: `attack_speed` divides weapon cooldowns in `weapon_manager.gd`, `crit_chance`/`crit_damage` roll per-projectile, `dodge_chance` in `take_damage()`, `armor` as flat reduction
- **Draft system reworked**: 3 weapons + 1 passive (character-exclusive from CharacterDB) + stat fallbacks (heal, max_hp, armor, speed, crit, luck)
- **Chest system**: `chest.tscn`/`.gd` — drops from enemies on death, rarity-scaled. Opens on player contact → triggers draft menu
- **Void Reliquary**: Luck-scaled chance for any chest to become a Void Reliquary. Player gets a confirmation dialog. Accepting halves move_speed and damage_multiplier, spawns a VOID_SPAWN enemy (8000 HP, fast, aggressive). Killing it cures the curse and drops a Mythic chest. Player can DECLINE the challenge. One instance of the void chest should be guaranteed at early stages for testing purposes, after one appearence it becomes rare as intended.
- **Boss scaling**: Sub-Boss 5x, Boss 6x, Void Spawn 4x
- **Run summary scroll fix**: Stats wrapped in ScrollContainer to protect "Play Again" button

### Bugs Found and Fixed (Claude Audit)
- Infinite `while` loop in draft generation (`pass` body, no increment)
- Draft screen added to `root` instead of `current_scene` (orphan on reload)
- Duplicate passive in slot 4 (always picked index 0 even if used)
- VOID_SPAWN not exempted from distance culling
- Enemy spawner not in `"enemy_spawner"` group
- Hand-crafted UID in `chest.tscn`
- Chest missing `PROCESS_MODE_ALWAYS`

## What's NOT Done Yet

### Task 4: Destructibles (Static Anomalies)
- Create `destructible.tscn` + `destructible.gd` — pulsating visual objects that spawn periodically around the player
- When destroyed by weapons: kills ALL enemies on screen (screen nuke)
- **50% chance** the nuke also destroys all XP gems on screen (risk/reward tradeoff)
- Should drop a consumable pickup after detonating

### Task 5: Consumables (Unstable Energies)
- `consumable.tscn` + `consumable.gd` — pickup items dropped by destructibles
- **Chronosphere**: Freeze all non-boss enemies for 4 seconds
- **Singularity (Vacuum)**: Instantly pull all XP gems to player position
- **Adrenaline Spike**: Double attack_speed and move_speed for 10 seconds
- **Mending Shard**: Restore 30% HP

### Other Pending Work
- `show_chest_menu()` in `hud.gd` currently just calls `show_draft_menu()` — needs rarity-aware reward scaling (Mythic chests should give multiple upgrades, etc.)
- `area_of_effect` stat on player is declared but not consumed by weapon geometry
- `cd_reduction` stat is declared but not applied to dash/ult/passive cooldowns
- The `luck` stat influences void chest spawn chance but doesn't yet affect gem quality or chest rarity rolls beyond that

## Architecture Notes

- **Object Pooling**: All enemies and gems use `PoolManager`. New pooled objects MUST implement `_on_pool_retrieved()`. See ai_debug_log for race condition prevention.
- **Signals over references**: Player broadcasts `health_changed`, `xp_changed`, `ultimate_changed`. HUD listens. Never use `get_parent().get_parent()` chains.
- **Deferred adds**: Always use `call_deferred("add_child", node)` for dynamic spawns. Never `add_child()` in `_ready()`.
- **UI on current_scene**: Dynamic UI overlays go on `get_tree().current_scene`, NOT `get_tree().root`. Root nodes survive `reload_current_scene()`.
- **No prints in hot paths**: `_physics_process` runs 60+fps with 100+ entities. A single `print()` causes measurable frame drops.

## Autoloads
- `GameManager` — run state, stats, pause, win/loss
- `WeaponDB` — weapon definitions, upgrades, fusions, ascensions
- `CharacterDB` — character definitions, passives, ultimates
- `PassiveDB` — passive ability definitions
- `PoolManager` — node recycling with deferred detach

## First Prompt for Claude

```
I'm picking up development on "For Happier Days," a Godot 4.6 Bullet Heaven game.

Before writing any code, please:

1. Read `ai_debug_log.md` — it contains critical engine pitfalls and pooling race conditions that have caused crashes before. Every lesson there was learned the hard way.

2. Read `IMPLEMENTATION_PLAN.md` and `DEVELOP.md` to understand the full roadmap and what's been done.

3. Audit the following files for any remaining bugs or performance issues:
   - `scenes/enemies/enemy.gd` — chest drop logic, void spawn curse removal
   - `scenes/ui/hud.gd` — draft generation, stat application, void prompt
   - `scenes/props/chest.gd` — void event triggering
   - `scenes/player/player.gd` — stat block, damage pipeline
   - `scenes/player/weapon_manager.gd` — attack_speed/crit integration
   - `scenes/world/enemy_spawner.gd` — void boss spawning

4. After your audit, proceed with implementing:
   - Task 4: Static Anomalies (destructibles with screen-nuke + 50% XP wipe risk)
   - Task 5: Consumables (Chronosphere, Vacuum, Adrenaline, Mending Shard)
   - Wire the remaining unwired stats: `area_of_effect`, `cd_reduction`, full `luck` integration

5. Apply engineering best practices:
   - Pool any new scene types that spawn frequently
   - Respect the deferred-add pattern for all dynamic nodes
   - Guard against double-fire/double-die patterns
   - Keep _physics_process lean (no allocations, no prints)

Please report what you find in the audit before proceeding with implementation.
```
