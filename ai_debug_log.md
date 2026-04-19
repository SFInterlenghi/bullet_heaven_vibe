# AI Debug Log & Lessons Learned

This document serves as a persistent knowledge base for AI agents working on "For Happier Days" (Bullet Heaven). It logs completed bug fixes, avoiding repetitive mistakes, and documenting best practices for Godot 4 development in this project context.

## 1. Engine & Lifecycle Pitfalls

### `add_child` in `_ready()` (Parent Busy)
- **Symptom:** `Parent node is busy setting up children, add_child() failed.` error.
- **Root Cause:** Attempting to synchronously add a child to `get_tree().root` or another node from within a `_ready()` function. The engine is still propagating the ready signal.
- **Solution:** Always use the deferred version: `call_deferred("add_child", child)`.

### Root Orphans across Scene Reloads
- **Symptom:** Ghost UI elements (like Pause Menu or Run Summary) persisting after restarting the run (e.g. clicking "Play Again").
- **Root Cause:** Nodes added directly to `get_tree().root` instead of `get_tree().current_scene`. `get_tree().reload_current_scene()` frees only the active scene, not root globals.
- **Solution:** Use `get_tree().current_scene.call_deferred("add_child", node)` for dynamic run-specific UI overlays.

### Button Text Wrap Ignored
- **Symptom:** Buttons using long text strings scale infinitely horizontally, breaking the UI layout and clipping off-screen.
- **Root Cause:** Godot's `Button` node does not inherently wrap text.
- **Solution:** Wrap a `Label` (with `autowrap_mode = TextServer.AUTOWRAP_WORD_BALANCED` and `size_flags_horizontal = SIZE_EXPAND_FILL`) inside a `PanelContainer` of a fixed `custom_minimum_size`. Use a smaller `Button` or handle GUI input on the Panel itself.

### `Input` vs `InputEvent` Check Syntax
- **Symptom:** Crash at runtime: `Invalid call. Nonexistent function 'is_action_just_pressed' in base 'InputEventMouseMotion'.`
- **Root Cause:** Calling `.is_action_just_pressed()` on the `event` object inside `_input(event: InputEvent)`. The `InputEvent` class only supports `.is_action_pressed()`, `.is_action_released()`, and `.is_action()`. The `is_action_just_pressed()` method belongs strictly to the global `Input` singleton used during `_process` or `_physics_process`.
- **Solution:** Replace `event.is_action_just_pressed("action")` with `event.is_action_pressed("action") and not event.is_echo()` inside the `_input` block.

### Static Inference `:=` with Variants
- **Symptom:** Error `Cannot infer the type of variable because the value doesn't have a set type` or `The variable type is being inferred from a Variant value`.
- **Root Cause:** Using the `:=` shortcut on an assignment where the right hand side returns a Variant (such as math functions like `max()` using different Godot engine versions) or dynamically initialized objects.
- **Solution:** Specify the static type explicitly: `var my_val: float = max(x, y)` instead of `var my_val := max(x, y)`.

### Scene Tree Node Pathing Assumptions
- **Symptom:** `Node not found: "Polygon2D"` or `Invalid assignment of property... on a base object of type 'null instance'`.
- **Root Cause:** Attempting to manipulate visual elements from a script by hard-coding their node names without checking the `.tscn` structure. This caused run-time crashes when trying to `.modulate` a character's `Polygon2D` (it was actually a `ColorRect`) or scale a gem's `CollisionShape2D` (it was a `CollisionPolygon2D`).
- **Solution:** Always wrap injected visual scaling/modulation calls in an `if has_node("ExpectedName"):` safeguard, or verify the exact node type from the `.tscn` beforehand.

### Duplicate Global Scope Identifiers
- **Symptom:** Parser Error `Variable or Function has the same name as a previously declared item.`
- **Root Cause:** Appending a full implementation of a feature (like `FUSIONS` or `get_fusion`) to the top of an Autoload file without deleting the empty/legacy template stubs sitting hundreds of lines lower in the file.
- **Solution:** Always do a full top-to-bottom search or use strict naming overhauls when converting a stubbed project file to a fully-fleshed script.

## 2. Object Pooling Issues

### Double-Return Race Condition
- **Symptom:** "Can't add child - already has a parent" errors spamming the console (1400+ per error window).
- **Root Cause:** A node gets returned to the pool, then grabbed out of the pool *before* the deferred `remove_child` from its original parent has executed.
- **Solution:** A `_pending` dictionary in `pool_manager.gd`. Nodes are flagged when requested to be returned. Only unparented, clean nodes make it into the pool arrays. 

### Stale Signal Connections (Phantom States)
- **Symptom:** Reused enemies instantly dying, displaying wrong health, or triggering "already dead" errors.
- **Root Cause:** Re-instantiating nodes from a pool bypasses `_ready()`. Old state remains.
- **Solution:** All pooled objects must implement an `_on_pool_retrieved()` function that forcefully resets `is_dead`, HP, position, and any modified colors to their baseline values. Make sure `pool_manager.gd` invokes this immediately post-retrieval.

### Node `die()` Called Twice via Multi-Hit
- **Symptom:** Massive spawning of secondary projectiles or sub-enemies from `SPAWNER` types that exceeds expected limits.
- **Root Cause:** Multiple bullets hitting the same enemy on the exact same physics frame. `take_damage()` triggered `die()` multiple times before the node despawned.
- **Solution:** Add an `is_dead` boolean guard at the top of the damage processing block.

## 3. Best Practices & Code Conventions

1. **Autoload Access:** External singletons like `WeaponDB`, `CharacterDB`, `PassiveDB`, and `GameManager` are robust read sources. Do not duplicate their structs. 
2. **References over Paths:** Never use brittle get_parent() chains (`get_parent().get_parent().get_node("...")`). Use `get_tree().get_first_node_in_group("group_name")`.
3. **Decouple UI from Logic:** Use signals (e.g. `health_changed`, `xp_changed`) so the `HUD` updates independently rather than tight references.
4. **Deferred Rendering / Physics:** Avoid `print()` inside heavy loops like `_physics_process()`. At late-game states (20+ minutes), hundreds of projectiles and enemies exist; performance regressions will severely impact the frame rate.

## 4. Performance Optimizations

### Late-game Proximity Fusion (O(N^2) lag)
- **Symptom:** At 15+ minutes, frame rate drops severely due to 1000+ XP gems constantly checking distances to each other.
- **Root Cause:** In `_physics_process`, each gem iterates the entire `gem` group `if _fusion_timer >= FUSION_INTERVAL` resulting in an exponentially laggy O(N^2) calculation cascade.
- **Solution:** Removed localized fusion. Enforced a **global active gem cap** (e.g., 300 max iterations) when spawning drops directly on enemy death (`enemy.gd`). If max limit is reached, randomly add the new XP outright to an existing alive gem via `pick_random()`. Instantly eliminates lag with zero loss to the player's potential overall XP.

## 5. Sprint 10/11 Audit Lessons (Claude Pass)

### Infinite Loop from `pass` in `while` Body
- **Symptom:** Game hangs permanently on level-up if fewer than 3 weapon options exist in the draft pool.
- **Root Cause:** A `while options.size() < 3` loop contained only `pass` with no iterator increment. The condition never becomes false, so the game freezes.
- **Solution:** Always increment the loop variable. If the body is meant to be a no-op, remove the loop entirely rather than using `pass`.

### Hand-Crafted UIDs in `.tscn` Files
- **Symptom:** `ERR_FILE_CORRUPT` or import failures when Godot encounters a UID that doesn't match its internal registry.
- **Root Cause:** Manually writing `uid="uid://cx4xchest01"` in a `.tscn` file. Godot 4.4+ expects UIDs to be auto-generated and registered in `.godot/uid_cache.bin`.
- **Solution:** Omit UIDs from hand-written `.tscn` files entirely. Let Godot assign them on first import.

### New Enemy Types Must Be Exempted from Distance Culling
- **Symptom:** Custom boss-class enemies (e.g. VOID_SPAWN) silently vanish after walking >2000px from the player.
- **Root Cause:** The distance-cull check in `_physics_process` only exempted `BOSS` and `SUB_BOSS`. New boss-tier types were treated as regular enemies and pooled.
- **Solution:** Update the cull exemption whenever adding new boss-tier `EnemyType` variants.

### Group Registration for Dynamic Lookup
- **Symptom:** `get_first_node_in_group("enemy_spawner")` returns `null` despite the spawner existing in the scene.
- **Root Cause:** The node was never added to the group. Group membership isn't automatic from the node name.
- **Solution:** Call `add_to_group("group_name")` in `_ready()` for any node that other systems need to find via group lookup.

### Stats Must Be Wired Into Consumers
- **Symptom:** Adding stat variables to `player.gd` but seeing zero gameplay effect.
- **Root Cause:** Declaring `attack_speed`, `crit_chance`, etc. on the player without modifying `weapon_manager.gd` to actually read them. Variables exist but no code path uses them.
- **Solution:** When adding a new stat, immediately trace all consumer systems (weapon cooldowns, damage calculation, dodge rolls) and wire the stat in. A stat that isn't consumed is dead code.

## 6. Additional Pitfalls (Sprint 12 Audit)

### `TextServer.AUTOWRAP_WORD_BALANCED` Does Not Exist
- **Symptom:** Parser error `Cannot find member AUTOWRAP_WORD_BALANCED in BASE TextServer` on launch.
- **Root Cause:** Godot 4.6 `TextServer.AutowrapMode` enum only defines `AUTOWRAP_OFF`, `AUTOWRAP_ARBITRARY`, `AUTOWRAP_WORD`, `AUTOWRAP_WORD_SMART`. `BALANCED` is not a valid member. Documentation and older AI suggestions reference it incorrectly.
- **Solution:** Use `TextServer.AUTOWRAP_WORD_SMART` everywhere. Also note that `Button.autowrap_mode` only exists in Godot 4.3+; for fixed-width cards prefer `PanelContainer` + `Label` with `autowrap_mode`.

### `PRESET_CENTER` on Size-0 Container Pins Top-Left to Screen Center
- **Symptom:** UI panel appears in the bottom-right quadrant instead of centered.
- **Root Cause:** `set_anchors_preset(Control.PRESET_CENTER)` calculates offsets from the container's current size. Before children are added, size is `(0,0)`, so the **top-left** corner lands at screen center.
- **Solution:** Wrap content in a `CenterContainer` with `set_anchors_preset(Control.PRESET_FULL_RECT)`. It re-centers its child on every layout pass regardless of child size.

### `Area2D.area_entered` Never Fires Between Tiny Collision Shapes
- **Symptom:** Proximity-based overlap detection (e.g., gem fusion) never triggers.
- **Root Cause:** `area_entered` requires physics shapes to actually overlap. Shapes ±8 units never satisfy overlap at normal screen distances.
- **Solution:** Use a periodic distance check in `_physics_process` or on a Timer instead.

### `get_tree()` Is Null Inside `_on_pool_retrieved()` Called Before `add_child`
- **Symptom:** Crash: `get_tree()` returns null in `_on_pool_retrieved`.
- **Root Cause:** `PoolManager.get_node_from_pool()` calls `_on_pool_retrieved()` immediately after `pop_back()`, before `add_child()`. The node is not yet in the scene tree.
- **Solution:** Never call `get_tree()` inside `_on_pool_retrieved()`. Cache any tree references in `_ready()` — they remain valid for the whole run since pool objects live in the same scene.

### Beam Weapon Moves Like a Bullet If Not Excluded From Movement Branch
- **Symptom:** Beam flies across screen instead of staying at its spawn point.
- **Root Cause:** Including `"beam"` in the same `if weapon_type == "straight" or weapon_type == "beam":` movement branch as regular bullets.
- **Solution:** Beam must be excluded from the movement branch. Set `rotation = direction.angle()` at init, use a `RectangleShape2D` for the collision, and use a lifetime timer instead of screen-bounds culling.

