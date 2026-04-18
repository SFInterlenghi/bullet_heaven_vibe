# Architecture & System Documentation

## Current Scene Tree Structure

- **World** (`Node2D`)
  - **Background** (`ColorRect`): Large rectangular background.
  - **Player** (`CharacterBody2D`, Group: "camera", "player"): Central controllable character.
    - Included nodes (inferred): `WeaponManager`
  - **EnemySpawner** (`Node2D`): Independent spawner node that manages the creation of enemies.
  - **EnemyContainer** (`Node2D`): An empty spatial folder holding instantiated Enemy nodes.
  - **BulletContainer** (`Node2D`): An empty spatial folder holding instantiated Bullet nodes.

*(The `GameManager` operates as a hidden Autoload root node).*

## Primary Responsibilities of Each Script

1. **`player.gd`**: Manages player input (eight-way movement), health state with invincibility frames (i-frames) on hit, and broadcasts death via the "game_manager" group.
2. **`weapon_manager.gd`**: Functioning as an internal inventory system attached to the Player. Capable of allocating exactly 6 active weapon slots. It interprets logic from a centralized data core and manages firing cooldowns dynamically.
3. **`bullet.gd`**: Expanding into a universal `projectile.gd` utilizing generalized `Polygon2D` parameters to project 8 completely distinct arrays of visual tracking parameters (e.g. Orbs, Cross zones, Boomerangs).
4. **`enemy.gd`**: Employs scalable parameters via `apply_tier` to alter color, dimensions, and speed without breaking pooling memory. Bosses now warp along the camera's perimeter edge if left behind, preventing culling soft-locks.
5. **`enemy_spawner.gd`**: A pressure-system spawner. Maintains a required `optimal_enemies` threshold, entering overdrive-spawn cascades to enforce active screen limits. Time scales automatically unlock elite mob variants over play-time.
6. **`Draft UI`**: A CanvasLayer hook triggered upon Player level caps. Pauses the Root tree and serves 4 distinct Upgrade permutations drawn dynamically from the player's equipment inventory array.

## Existing Signals or Connections

- **Enemy `DamageArea`**: Uses `body_entered` and `body_exited` signals to toggle the boolean `player_in_contact` and trigger a timer to repeatedly apply contact damage to the player.
- **Bullet**: Connects Area2D's `area_entered` and `body_entered` to detect hits, and wires a one-shot `SceneTreeTimer` `timeout` signal to serve as a lifetime culling fallback.
- **Group Calls**: In lieu of direct signal connections or hardcoding, the `Player` signals its death by invoking `get_tree().call_group("game_manager", "on_player_died")`.

## Roadmap to Bullet Heaven

To evolve this barebones prototype into a full Bullet Heaven similar to *Vampire Survivors/Brotato*, we still need to implement:

1. **Stats, Leveling & Upgrades (The Draft System)**:
   - Leveling currently boosts stats linearly. We need to implement a "Draft Screen" that pauses the game upon Level Up, allowing the player to select from 3 random weapon/stat items.
2. **Weapon Arrays & Auto-Targeting**:
   - A system for equipping multiple weapons.
   - Weapons needing auto-aim logic (finding the closest enemy in range) instead of firing strictly to the right.
3. **Loot Drops / Chests**:
   - Mechanics for picking up health or random treasure boxes from elite enemies.
4. **Art Pass (Hand-Drawn Binding of Isaac Aesthetic)**:
   - Replace basic Godot shapes with custom 2D textures, importing Spritesheets and AnimationPlayers.
   - Adding shadows or a pseudo-3D top-down perspective feel.
