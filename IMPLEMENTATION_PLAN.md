# Bullet Heaven — Implementation Plan 

Game name: "For Happier Days" - Internal joke in the PT-BR translation (Para Dias mais felizes)

**Target:** Ship a complete, playable 25-minute bullet heaven run loop before the art pass.
**Scope:** Code, systems, balance, UX. Excludes all asset generation (sprites, audio, VFX art).
**Current state:** Sprint 4 complete — WeaponDB, universal bullet, draft UI, 6 enemy tiers, pool manager.

---

## Pacing Target: The 25-Minute Run

A run is structured as 5 acts. Pacing drives every system.

| Act | Time | Theme | Milestones |
|---|---|---|---|
| **I — Warm-up** | 0:00 – 5:00 | Learn controls, first 2 weapons | Elite appears at 4:00 |
| **II — Build-up** | 5:00 – 10:00 | 3–4 weapons, first fusion option | Mini-boss at 7:30 |
| **III — Power Spike** | 10:00 – 15:00 | Weapons hit lvl 6+, ascension visible | 2 mini-bosses; destructibles peak |
| **IV — Endurance** | 15:00 – 20:00 | Max weapon level pressure | Sub-boss at 17:30, elite swarms |
| **V — Climax** | 20:00 – 25:00 | Ascended main weapon, final fight | Final Boss enters 22:30, death or win at 25:00 |

**Target level curve:** ~50 levels in a 25-min run. Early levels fast (1 per 20s), late levels slow (1 per 60s). See §Feature 2 for the formula. This higher count is required to make 3 legendary fusions mathematically achievable (§Feature 3 budget math).

---

## Bug & Tech-Debt Audit (must fix in Sprint 5)

Read first — several of these corrupt run state silently.

| # | File | Issue | Fix |
|---|---|---|---|
| **B1** | `pool_manager.gd` | `get_node_from_pool()` never calls `_on_pool_retrieved()` on the node. Enemies reused from pool keep stale signal connections and old state flags. Only `apply_tier()` saves us by coincidence. | After `pop_back()`, call `node._on_pool_retrieved()` via `has_method` check. |
| **B2** | `player.gd:123` | `max_xp = int(max_xp * 1.5)` → level 25 needs ~1.6M XP. Unplayable. | Replace with curve formula (§Feature 2). |
| **B3** | `enemy_spawner.gd:68-69` | `max_health += total_time * 1.5` → BASIC has +2250 HP at 25 min vs base 30. | Rework as piecewise by Act (§Pacing). |
| **B4** | `enemy_spawner.gd:47-50` | Boss at 150s, sub-boss at 60s. Way too early. | Move to 22:30 and 17:30 respectively. |
| **B5** | `game_manager.gd:21-31` | Win state = hardcoded `CanvasLayer` + `Label`. Not a real scene. | Build `win_screen.tscn` with run summary (§Feature 7). |
| **B6** | `game_manager.gd:9-19` | Game Over instantiates but does not `change_scene`. Lingers in tree. | Route through `change_scene_to_file` + summary stats. |
| **B7** | `hud.gd:26-58` | Draft UI built dynamically with `PanelContainer.new()` every level-up. No theme, no animation. | Extract to `draft_screen.tscn` with theme + tween-in (§Feature 6). |
| **B8** | `bullet.gd:121` | Boomerang uses hardcoded `300.0` range. Ignores `travel_dist` from `crescent_upgrades()`. | Read `upgrades.get("travel_dist", 300.0)` in `init_weapon`. |
| **B9** | `bullet.gd` | Bullets use `queue_free()`, not pool. Hundreds per second at late game. | Pool via `PoolManager.return_node_to_pool(self, "res://scenes/weapons/bullet.tscn")`. Add `_on_pool_retrieved()` that resets `current_pierce`, `current_bounces`, `boomerang_returned`, disconnects & reconnects signals. |
| **B10** | `bullet.gd:170-174` | Star weapon bounces with `direction.rotated(randf_range(PI/2, 3*PI/2))` — random angle, not wall reflection. | Bounce off actual screen edges using normal reflection; random only on enemy hit. |
| **B11** | `enemy.gd:117-119` | `print("DamageArea hit by: ", body.name)` every frame of contact. Performance + log spam. | Remove debug print. |
| **B12** | `enemy.gd` | `gem_scene` is `const`-preloaded at top; gems are not tiered. Single XP value everywhere. | Tier gem scene (§Feature 2). |
| **B13** | `weapon_manager.gd:8` | `bullet_container = get_parent().get_parent().get_node("BulletContainer")` — fragile path. | Use `get_tree().get_first_node_in_group("bullet_container")`. |
| **B14** | `hud.gd:60-94` | Draft filter prevents duplicate weapon IDs but does **not** prevent duplicate **stat** picks. Rolling 2× "Heal 50% HP" possible. | Shuffle stats and pick without replacement. |
| **B15** | `player.gd:75` | Dash on `ui_accept` (Space). Same key is used for UI confirm → dash triggers through menus. | Make custom action `dash` bound to Space, and consume input on pause. |
| **B16** | `bullet.gd:162-178` | `_on_body_entered` applies damage even if the bullet is already at its pierce limit on the same frame (multiple enemies enter same frame). | Check pierce/bounce limit **before** applying damage. |

---

## Feature 1 — Main Characters, Passives, Ultimates & Ascension

**Intent:** Each character has a unique main weapon, 3 exclusive passive abilities (2 always-on + 1 unlocking mid-run), and 1 ultimate active ability on `Left Shift`. At max weapon level (6), the main weapon "ascends" into a radically different form. Characters are the primary meta-progression unlock (§Feature 8).

### Data model

New autoload `character_db.gd` (`scripts/autoloads/`). Full structure:

```gdscript
var CHARACTERS = {
  "wanderer": {
    "name": "The Wanderer",
    "main_weapon": "piercer",
    "base_health": 100.0,
    "base_speed": 200.0,
    "pickup_radius": 60.0,
    # 3 passives. Passive 0 & 1 active from run start. Passive 2 unlocks at player level 10.
    "passives": ["twin_barrels", "armor_shards", "momentum_stacks"],
    # 1 ultimate on Left Shift
    "ultimate": "ult_time_rewind",
    "ultimate_cooldown": 90.0,
  },
  "monk": {
    "name": "The Monk",
    "main_weapon": "orb",
    "base_health": 80.0,
    "base_speed": 220.0,
    "pickup_radius": 80.0,
    "passives": ["orbit_knockback", "fire_trail", "zen_threshold"],
    "ultimate": "ult_invulnerability",
    "ultimate_cooldown": 60.0,
  },
  # Archer (main=beam), Berserker (main=crescent), Hunter (main=spread), Mage (main=cross)
}
```

### Passive system

New autoload `passive_db.gd` (`scripts/autoloads/`). Each entry defines a passive's hook point and parameters. The player reads its character's passive list from `CharacterDB` and registers them at run start.

```gdscript
var PASSIVES = {
  "twin_barrels": {
    "name": "Twin Barrels",
    "desc": "Fires 2 of every projectile, but each deals 25% less damage.",
    "hook": "on_fire",           # fires in weapon_manager._fire_projectile
    "count_mult": 2,
    "damage_mult": 0.75,
  },
  "fire_trail": {
    "name": "Blazing Steps",
    "desc": "Leaves fire patches every 0.3s that deal 8 DPS for 2s.",
    "hook": "on_move",           # fires in player._physics_process when moving
    "spawn_rate": 0.3,
    "patch_damage": 8.0,
    "patch_duration": 2.0,
  },
  "zen_threshold": {
    "name": "Zen Threshold",
    "desc": "Every 20/50/100 kills permanently boosts all damage by 10%.",
    "hook": "on_kill",           # fires in enemy.die() via group signal
    "thresholds": [20, 50, 100],
    "damage_boost": 0.10,
  },
  "armor_shards": {
    "name": "Armor Shards",
    "desc": "Take 15% less damage from all sources.",
    "hook": "on_take_damage",
    "damage_reduction": 0.15,
  },
  "momentum_stacks": {
    "name": "Momentum",
    "desc": "Consecutive kills within 2s stack speed +3% (max 10 stacks).",
    "hook": "on_kill",
    "stack_max": 10,
    "speed_per_stack": 0.03,
    "decay_time": 2.0,
  },
  "orbit_knockback": {
    "name": "Orbital Force",
    "desc": "Orbs knock enemies back on hit.",
    "hook": "on_hit",            # fires in bullet._on_body_entered for orbital type
    "knockback_force": 300.0,
  },
  # ... one passive defined per slot across all characters
}
```

**Hook routing:**
- `on_fire` → `weapon_manager.gd::_fire_projectile()` calls `player.passive_on_fire(w, upgrades)` before instantiating bullets
- `on_move` → `player.gd::_physics_process()` tracks `fire_trail_timer`, spawns `fire_patch.tscn`
- `on_kill` → `enemy.gd::die()` calls `get_tree().call_group("player", "passive_on_kill")`
- `on_take_damage` → `player.gd::take_damage()` reads `damage_reduction` from active passives
- `on_hit` → `bullet.gd::_on_body_entered()` checks `weapon_type == "orbital"`, applies knockback

**Passive 2 unlock:** At player level 10, `player.gd::level_up()` calls `PassiveManager.unlock_passive(character.passives[2])`. Show a brief banner notification (not a full draft pause — just a timed label).

### Ultimate ability system

`player.gd` tracks:
```gdscript
var ultimate_cooldown_remaining: float = 0.0
var ultimate_id: String = ""
```

`_physics_process` checks `Input.is_action_just_pressed("ultimate")` (bind Left Shift). Cooldown shown as arc/bar in HUD. Each ultimate is a method in a new `UltimateSystem` (could be inline in `player.gd` v1):

| Character | Ultimate | Description | Cooldown |
|---|---|---|---|
| Wanderer | **Temporal Shift** | Save current HP + position snapshot; pressing again within 5s reverts. If not triggered: auto-reverts on death (one-time safety net). | 90s |
| Monk | **Aegis** | 5 seconds of complete invulnerability + 50% damage boost. | 60s |
| Archer | **Sniper Mode** | Next 10 beam shots are instant-kill (single target). | 75s |
| Berserker | **Cyclone** | Player spins in place for 3s, all boomerangs orbit at high speed; radius pulses. | 80s |
| Hunter | **Artillery** | Fire 36 spread projectiles in a full 360° ring simultaneously. | 70s |
| Mage | **Arcane Nova** | Teleport to cursor; all enemies within 600px are frozen 3s + take 300 damage. | 85s |

**Input setup:** Add `ultimate` input action in `project.godot` bound to `Left Shift`.

### Weapon ascension

Ascension now triggers at **level 6** (the new base weapon max — see §Feature 3 for level budget).

Extend `WeaponDB.WEAPONS` with an `ascended` subkey:

```gdscript
"piercer": {
  ...,
  "ascended": {
    "name": "Soul Railgun",
    "type": "beam",
    "shape": PackedVector2Array([...]),
    "color": Color(1.0, 0.3, 0.0),
    "base_cooldown": 0.4,
    "base_damage": 200.0,
    "base_speed": 2000.0,
    "get_upgrades": "piercer_ascended_upgrades",
  }
}
```

- Ascension is offered **only** for the character's `main_weapon` at level 6 (base max).
- The "ASCEND" draft card replaces the normal level-6 upgrade slot. If player declines, they can still fuse the weapon instead (mutually exclusive per run).
- After ascending: `w["ascended"] = true`, `w["data"]` pointer swaps to the ascended dict, `w["level"]` resets to 1 for the ascended progression. No further ascension. Ascended weapons cannot be fused.
- Secondary (non-main) weapons still cap at level 6 with no ascension.

### Ascended forms (first pass — balance in Sprint 9)

| Base | Ascended Name | Change |
|---|---|---|
| Piercer | **Soul Railgun** | Beam type, full piercing, 0.4s cooldown, massive damage |
| Orb | **Planetary Ring** | 1 huge orbital that pulses AoE continuously |
| Spread | **Hailstorm** | 12 projectiles in 360° every 0.3s |
| Burst | **Minigun** | 20-shot bursts with soft-homing, 0.02s inter-shot |
| Cross | **Sacred Ground** | 3 giant persistent cross zones that chase enemies |
| Star | **Shatterstar** | Splits into 3 on each bounce; near-infinite bounces |
| Boomerang | **Eternal Return** | Orbits player permanently, auto-seeks nearby enemies |
| Beam | **Death Laser** | Continuous beam that slowly rotates around player |

### Code changes (Sprint 8)

- `scripts/autoloads/character_db.gd` — new file
- `scripts/autoloads/passive_db.gd` — new file
- `player.gd` — `active_passives[]`, `passive_on_kill()`, `passive_on_take_damage()`, `cast_ultimate()`, `ultimate_cooldown_remaining` timer, Left Shift input
- `weapon_manager.gd` — `passive_on_fire()` hook; ascension swap at level 6 for main weapon
- `enemy.gd::die()` — emit kill signal for passive hooks
- `bullet.gd::_on_body_entered()` — knockback hook for orbital passive
- `scenes/world/fire_patch.tscn` — simple Area2D damage zone for fire trail passive
- `project.godot` — add `ultimate` input action (Left Shift)

---

## Feature 2 — XP Economy & Level Pacing

**Intent:** Player always feels progress, but late-game levels are meaningful and sparser. Higher-tier gems appear as the run progresses.

### New XP curve

Replace `max_xp = int(max_xp * 1.5)` with:

```gdscript
func xp_for_level(lvl: int) -> int:
    return int(60 + pow(lvl, 1.3) * 15)
```

Curve (rounded):
- L1→2: 75, L5→6: 170, L10→11: 360, L15→16: 600, L20→21: 890, L25→26: 1230, L30→31: 1620, L40→41: 2700, L50→51: 4100

Target: **~50 levels in 25 min** with the XP multiplier below. The flatter curve ensures early levels come every ~20s and late levels every ~55s, matching the Act pacing.

### XP multiplier over time

Player gets a passive `xp_multiplier` that grows with run time. Applied when a gem is collected.

```gdscript
# In player.gd::collect_gem()
var mult = 1.0 + (run_time / 300.0)  # +1x per 5 minutes, capped at +5x
xp += int(amount * min(mult, 6.0))
```

### Gem tiers

New `gem.tscn` variants (or data-driven single scene with `@export var tier: int`):

| Tier | Color | Base XP | Drop rule |
|---|---|---|---|
| Green | 0.2,1.0,0.3 | 1 | BASIC/FAST default |
| Blue | 0.3,0.5,1.0 | 5 | TANK, SPAWNER, any enemy after 10:00 |
| Purple | 0.8,0.3,1.0 | 25 | Elites, SUB_BOSS |
| Gold | 1.0,0.85,0.2 | 100 | BOSS drops 5× Gold, chest bonuses |

Implement by making `gem.gd` read `tier: int` and look up color + xp_value from a constant table. Enemy drops one gem, `tier` chosen from enemy stats + run time.

### Gem pickup radius

Add `pickup_radius` to player (default 60). Gems within radius accelerate toward player. Implement on gem `_physics_process`: if distance to player < player.pickup_radius, move toward player at increasing speed.

---

## Feature 3 — Weapon Fusion & Level Budget

**Intent:** Two specific weapons can fuse at level 3+ (standard) or at their max (level 6, legendary). Legendary fusion yields extra bonuses. Fused weapons have their own 12-level progression. Three legendary fused weapons fully leveled to 12 is the mathematically possible peak-build target.

### Level budget math

```
Base weapons max: 6  (reduced from 12 — milestones at 2, 4, 6)
Fused weapons max: 12 (unchanged — milestones at 3, 6, 9, 12)
Legendary fusion: both base weapons at level 6 (their max)
Standard fusion:  both base weapons at level 3

For 3 legendary fused weapons all maxed to 12:
  Equip 6 base weapons:          6 picks
  Level each to 6 (max):   6×5 = 30 picks
  Level 3 fused to 12:    3×11 = 33 picks
  Total needed:                  69 picks

Available in an optimised run:
  ~50 player levels (§Feature 2 curve)
  ~25 chest bonus picks (§Feature 5)
  Total available:               75 picks  ✓ (6 picks margin)

This is only achievable with near-100% weapon picks and good chest luck — intentionally hard.
```

### Base weapon milestone restructure

Reduce all `weapon_db.gd` milestone functions from 4 thresholds (3/6/9/12) to 2 (3/6):

```gdscript
func piercer_upgrades(level: int) -> Dictionary:
    var count = 1
    var pierce = 1
    if level >= 3: pierce = 2; count = 2       # milestone 1
    if level >= 6: pierce = 4; count = 4       # milestone 2 (max — ascension eligible)
    return {"count": count, "max_pierce": pierce}
```

This applies to all 8 base weapons. Each weapon still feels satisfying across 6 levels via the continuous multipliers (`cd_mult`, `damage_mult`, `speed_mult`) which remain.

### WeaponDB additions

```gdscript
var FUSIONS = {
  # key: sorted "id1+id2"
  "beam+piercer":    {"result": "rail_cannon",  "legendary_bonus": {"damage_mult": 1.5, "extra_count": 1}},
  "orb+star":        {"result": "saturn",       "legendary_bonus": {"spin_radius": 200.0, "count": 3}},
  "spread+burst":    {"result": "gatling_fan",  "legendary_bonus": {"burst_count": 12, "spread": PI}},
  "cross+crescent":  {"result": "sacred_cycle", "legendary_bonus": {"count": 4, "chasing": true}},
}
```

Fused weapons (`rail_cannon`, `saturn`, `gatling_fan`, `sacred_cycle`) are full entries in `WEAPONS` with 12-level progressions (milestones at 3, 6, 9, 12). They are tagged `"is_fused": true` so they cannot be fused again.

### Fusion flow

1. **Detection** in `hud.gd::generate_draft_options()`: scan all equipped weapon ID pairs; for each pair matching a `FUSIONS` key, check if both `level >= 3` (standard) or both `level >= 6` (legendary). If match found, inject a "FUSE" card (or "LEGENDARY FUSE" card) with high priority.
2. **Resolution**: `weapon_manager.fuse_weapons(id1, id2, result_id, is_legendary)` removes both source weapons, appends result at level 1 (legendary: start at level 3 + apply `legendary_bonus` to base stats permanently via `w["bonus"]` dict).
3. **UI cues**: Standard = cyan card border; Legendary = gold animated border + particle burst.

### Code changes

- `weapon_db.gd` — restructure all 8 upgrade functions to milestones at 3/6; add `FUSIONS` dict; add `is_fused` tag; add fused weapon entries (12-level progressions)
- `weapon_manager.gd::fuse_weapons()` — new method
- `hud.gd::generate_draft_options()` — inject fusion card, priority above single upgrades
- `weapon_manager.gd::add_weapon()` — ascension check now triggers at level 6 (not 12)

---

## Feature 4 — Destructibles & Consumables

**Intent:** Environmental objects (barrels, crates, bushes) spawn around the player and drop powerful one-shot consumables when broken. Max count limits spam.

### Entities

New scenes under `scenes/props/`:

- `destructible.tscn` — Area2D + polygon. `@export var health: float`, `@export var drop_table: Array[DropEntry]`.
- `consumable.tscn` — Area2D. `@export var type: ConsumableType`.

### Consumable types

| Type | Effect |
|---|---|
| `HEART_SMALL` | Heal 25 HP |
| `HEART_MEDIUM` | Heal 50 HP |
| `HEART_LARGE` | Heal 100 HP (full for most builds) |
| `DOUBLE_DAMAGE` | 2× damage for 10 seconds (all weapons) |
| `XP_VACUUM` | Pull every gem on screen to player over 1 second |
| `FREEZE` | Freeze all non-boss enemies for 3 seconds *(optional stretch)* |
| `MAGNET` | Double `pickup_radius` for 30 seconds *(optional stretch)* |

### Spawner

New `destructible_spawner.gd` attached to World:
- Maintains target count `max_alive = 8` (scales with Act: 4 → 8 → 10 → 10 → 6)
- Spawns at random off-screen edge position every 6–10 seconds if below max
- Drop weight: 60% hearts, 25% double-damage, 15% vacuum (tuned for Act)

### Player integration

- `player.gd::apply_buff(buff_type, duration)` — tracks active buff via timer dictionary
- `weapon_manager.gd` reads `player.damage_multiplier` and applies to `bullet.damage` during fire
- `xp_vacuum`: find all gems in `get_tree().get_nodes_in_group("gem")` and force-move them to player

---

## Feature 5 — Chests & Reward Drafts

**Intent:** Enemies occasionally drop chests. Opening gives a mini-draft. Rarity scales reward count.

### Drop rules

| Enemy | Chest drop chance | Rarity distribution |
|---|---|---|
| BASIC/FAST | 0.5% | 100% Common |
| TANK/SPAWNER | 3% | 70% Common, 30% Uncommon |
| Elite (§Feature 9) | 100% | 40% C, 50% U, 10% Rare |
| SUB_BOSS | 100% | Guaranteed Rare |
| BOSS | 100% | 2× Rare |

### Chest rarities

| Rarity | Color | Rewards |
|---|---|---|
| **Common** | Brown | 1 free upgrade (weapon-preferred) |
| **Uncommon** | Silver | 2 free upgrades |
| **Rare** | Gold | 4 free upgrades — 3 are weapon upgrades, 1 is **always** a stat giving +3 levels of that stat in one click |

### Entities & flow

- `chest.tscn` — Area2D, on body_entered → pauses game, emits `chest_opened(rarity)`
- `hud.gd::show_chest_menu(rarity, count)` — reuse draft UI but with `count` cards, all preselected-valid upgrades, no skip
- Weapon-preferred: draft pool prioritizes weapon upgrades before stats; stat upgrades only appear if no upgradeable weapons exist (except the mandatory mega-stat slot in Rare)

### Code changes

- `enemy.gd::die()` — roll drop table, instantiate chest at corpse position
- `hud.gd` — new `show_chest_menu(rarity)` path (shares draft pool builder with level-up)
- Mega-stat application: e.g. "+3 Max Health ×50" = +150 HP + full heal

---

## Feature 6 — Draft UI Refactor

**Intent:** Replace the dynamically-built `PanelContainer.new()` with a proper scene + theme. Foundation for future Vampire Survivors-style chest-opening reveal.

### Deliverables

- `scenes/ui/draft_screen.tscn` — CanvasLayer + PanelContainer + HBoxContainer with 4 `card.tscn` placeholder slots
- `scenes/ui/card.tscn` — Control with Icon placeholder (ColorRect for now), Name label, Level label, Description label
- `scenes/ui/draft_screen.gd` — exposes `populate(options: Array)` method
- Reveal tween: cards fade+scale-up in sequence (50ms stagger) using Godot's Tween
- Signal: `card_selected(option: Dictionary)` → HUD routes to weapon_manager or stat application

### Migration

Remove all `Button.new()`/`VBoxContainer.new()` in `hud.gd::show_draft_menu`. HUD instantiates `draft_screen.tscn`, calls `populate(options)`, connects `card_selected` signal.

---

## Feature 7 — Run Summary & End Screens

**Intent:** Replace the bare `Label.new()` win state. Give player data to chew on between runs.

### Tracked stats (new `RunStats` autoload or struct on GameManager)

```gdscript
var run_stats = {
  "time_survived": 0.0,
  "enemies_killed": 0,
  "damage_dealt": 0.0,
  "damage_taken": 0.0,
  "xp_collected": 0,
  "gems_collected": 0,
  "chests_opened": 0,
  "destructibles_broken": 0,
  "final_weapons": [],   # list of {id, level, ascended}
  "highest_level": 0,
  "death_cause": "",     # or "victory"
}
```

### Scenes

- `scenes/ui/run_summary.tscn` — shared by game over and win. Shows stats, time, "final build" card row (6 equipped weapons), and CONTINUE button → returns to main menu
- `scenes/ui/main_menu.tscn` — minimal for now: character select + START button + (later) meta-progression panel

### Code changes

- `game_manager.gd::on_player_died()` and `on_game_won()` both route to `run_summary.tscn` with `death_cause` set
- Increment stats from hook points: `enemy.die()`, `bullet._on_body_entered`, `player.take_damage`, `gem._on_body_entered`, `chest._on_opened`, `destructible.break()`

---

## Feature 7b — Pause Menu & Stats Overlay

**Intent:** Standard pause on Escape; a live stat inspector on Tab. Both are non-blocking QoL that players expect and that help them make informed draft choices.

### Pause Menu (Escape)

- `scenes/ui/pause_menu.tscn` — CanvasLayer (process_mode ALWAYS), shown/hidden by toggling `visible`. Covers screen with semi-transparent dark overlay.
- Buttons: **Resume** (unpause), **Controls** (show keybinds modal — Tab/Space/LShift/WASD), **Quit to Menu** (confirm dialog → `get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")`).
- `player.gd` handles `Input.is_action_just_pressed("ui_cancel")` → `GameManager.toggle_pause()`.
- `game_manager.gd::toggle_pause()` — single source of truth for `get_tree().paused` state. Prevents double-pause conflict with draft screen (if draft is open, Escape closes draft first before opening pause).

### Stats Overlay (Tab)

- `scenes/ui/stats_overlay.tscn` — CanvasLayer shown while Tab is held (not toggle; release = close).
- Left panel — **Active Weapons**: one card per slot (up to 6). Each card shows weapon name, level, current damage, cooldown, and the next milestone description. Ascended / Fused weapons show a badge.
- Centre panel — **Active Passives**: icon + name + short description for each unlocked passive. Ultimate icon with current cooldown remaining.
- Right panel — **Player Stats**: HP, Max HP, Move Speed, Damage Multiplier, XP Multiplier, Pickup Radius, Kills This Run, Time Elapsed, Chests Opened.
- Data is read live from player + weapon_manager — no caching needed.
- `hud.gd` creates and owns the overlay node; Tab hold check in `_process`.

### Code changes (Sprint 6)

- `scenes/ui/pause_menu.tscn` + `pause_menu.gd` — new
- `scenes/ui/stats_overlay.tscn` + `stats_overlay.gd` — new
- `scripts/autoloads/game_manager.gd` — add `toggle_pause()`, guard against double-pause
- `player.gd` — Escape / Tab input handling (both in `_input()` not `_physics_process`)
- `project.godot` — add `pause` input action (Escape, distinct from `ui_cancel`), `stats` action (Tab)

---

## Feature 8 — Meta-Progression Foundation *(scope: skeleton only)*

**Intent:** Start the scaffolding so gold from runs persists. Full skill tree deferred to post-art.

### v1 scope

- **Gold economy**: enemies drop 1 gold on 10% roll; bosses guaranteed 50 gold. Gold persists via `user://save.json`.
- **Persistent save**: `scripts/autoloads/save_manager.gd` handles read/write to `user://save.json`. Stores: `total_gold`, `unlocked_characters`, `best_time_per_character`, `weapons_ever_maxed`.
- **Character unlock gates**: default character free. Monk = 500g, Archer = 1000g, Berserker = 2000g, etc. Unlock shown on main menu.
- **Skill tree placeholder**: empty screen accessible from main menu. A single permanent upgrade slot: "+5% starting damage" for 200g to prove the loop.

Full tree (10–20 nodes across categories like Offense/Defense/Utility/Luck) is Sprint 11+ work.

---

## Feature 9 — Unique Mechanics (differentiators)

Features below distinguish this prototype from Vampire Survivors / Brotato.

### 9.1 Elite enemies
A regular enemy has a 1% chance to spawn as **Elite**: 3× health, glowing outline (colored polygon modulate), drops a guaranteed chest on death. Clear audio/visual cue planned for art pass.

### 9.2 Curse choices (Draft option)
Rarely (20% of level-ups after lvl 5), one of the 4 draft cards is a **Curse**: negative effect + massive bonus.
Example curses:
- "Bloodlust" — take 50% more damage, deal 50% more damage for the rest of the run
- "Hubris" — next 3 levels give +2 levels each, but can't heal for 2 minutes
- "Hunger" — XP requirements halved, max HP halved permanently

### 9.3 Weather events
At fixed times, a 30-second weather event modifies the run:
- **Blood Moon** (9:00): +50% damage dealt & taken
- **Gem Rain** (15:00): every enemy drops a Blue gem
- **Eclipse** (20:00): enemies spawn 3× faster, all drop chests on death

### 9.4 Combo system
Hitting 10+ enemies within 1 second grants a "Combo" stack (max 5). Each stack = +5% damage for 10 seconds. Shown as bar near crosshair. Resets if no hit for 1.5 seconds.

### 9.5 Pet collector
After unlocking (meta-progression), a small orbital pet follows the player, auto-collecting gems within 200px. Single upgrade in skill tree for now.

---

## Sprint Roadmap

Each sprint logged to `DEVELOP.md` on completion.

### Sprint 5 — Bug Fixes & Pacing Recalibration
- B1–B16 from audit
- New XP curve targeting 50 levels / 25 min (§Feature 2)
- Enemy scaling rework to piecewise-by-Act (§Pacing, §B3)
- Boss/sub-boss timing (§B4)
- Base weapon milestones restructured to 2 thresholds at 3/6 (§Feature 3)
- **Verification:** Play a full 25-min run, no crashes, boss spawns at 22:30, reach ~50 levels.

### Sprint 6 — Draft UI + Run Summary + Pause Menu + Stats Overlay
- `draft_screen.tscn`, `card.tscn`, tween reveal (§Feature 6)
- `run_summary.tscn`, stat tracking hooks (§Feature 7)
- `pause_menu.tscn`, Escape handling, `game_manager.toggle_pause()` (§Feature 7b)
- `stats_overlay.tscn`, Tab-hold to inspect weapons + passives + stats (§Feature 7b)
- Replace `game_manager.gd` win/lose paths
- Add `ultimate` (Left Shift) and `pause` (Escape) and `stats` (Tab) input actions to `project.godot`
- **Verification:** Die → summary shows real stats. Escape pauses cleanly. Tab shows live weapon/stat data. Left Shift input registered (no function yet).

### Sprint 7 — XP Tiers & Gem Economy
- Gem tiers (Green/Blue/Purple/Gold) (§Feature 2)
- Pickup radius with gem suction
- XP multiplier over run time
- **Verification:** Late-game enemies drop Blue+ gems; pickup radius feels noticeably better.

### Sprint 8 — Characters, Passives, Ultimates & Ascension
- `character_db.gd` + `passive_db.gd` autoloads (§Feature 1)
- `main_menu.tscn` with character select (2-3 characters minimum)
- `player.gd` — `active_passives[]`, passive hook dispatchers, `cast_ultimate()`, ultimate cooldown HUD arc
- `weapon_manager.gd` — `passive_on_fire()` hook, ascension swap at level 6
- 8 ascended weapon forms (§Feature 1)
- `fire_patch.tscn` for fire-trail passive
- Passive 2 unlock at player level 10 + banner notification
- **Verification:** Each character starts correctly; ultimates fire on LShift with cooldown; reach level 6 main weapon → ASCEND card appears; passive 2 unlocks at player level 10.

### Sprint 9 — Weapon Fusion & System Polish
- **Weapon Exclusivity & Ascension:** Characters now exclusively "own" their main weapon (`piercer`, `orb`, `beam`). `hud.gd` draft pool will explicitly exclude these if you aren't playing the matching character. Only the main weapon will spawn Ascension cards.
- **Three New Neutral Weapons (To replace the 3 restricted ones):**
  1. **Magic Missile:** Homing projectiles that automatically seek the nearest enemy. Ascends to `Arcane Barrage`.
  2. **Whip:** Horizontal sweeping arc that clears enemies right and left. Ascends to `Chain Whip`.
  3. **Daggers:** Fast, forward-firing burst of sharp blades with high single-target DPS. Ascends to `Phantom Daggers`.
- **Weapon Fusion:** `FUSIONS` dict + fused weapon entries (12-level progressions). `fuse_weapons()` in `weapon_manager.gd`. Fusion card injection in draft UI with priority.
- **Infinite Orbs Fix:** Orbital weapons will clear their existing projectiles before spawning a new burst, capping the number of orbs securely to match the weapon's level count.
- **Gem Lag Optimization & Visual Tiers:** `_check_fusion()` (O(N^2)) will be removed from `gem.gd`. `enemy.gd` will strictly cap gems at 300. Over-cap XP is absorbed into alive gems. To make this visible to the player, I will add highly prized visual indicators:
  - Add **Red Ruby** (500 XP) and **White Diamond** (2500 XP) color tiers.
  - Dynamically scale the `gem`'s size (Transform scale) up by +50% or +100% when hitting the ruby/diamond tier.
- **Balance Pass:** `weapon_db.gd` continuous damage scaling lowered from `20%` to `10%` per level. `enemy_spawner.gd` enemy HP scaling increased heavily (`total_time * 0.4` and above) to ensure enemies don't melt instantly off-screen.
- **Ultimate Reliability & Visual Feedback:** The ultimate input check will be robustly moved into `player.gd`'s `_physics_process()` exactly like the Dash so it triggers flawlessly. The `project.godot` input map will be updated to allow BOTH **Shift** and **Q** simultaneously so either mapping works. `Tween` flashes will be added to visually represent the ultimate triggering (e.g. flashing blue for Time Slow).
- **Verification:** Run game, test Shift and Q visuals. Verify new neutral weapons appear in the draft, while non-class main weapons do not. Verify red/white gems appear at the 15+ minute mark and orb count is accurate.

### Sprint 10 — Destructibles & Consumables
- `destructible.tscn`, `consumable.tscn` (§Feature 4)
- Spawner, drop tables, buff system
- XP Vacuum + Double Damage buffs
- **Verification:** Barrels spawn, drop consumables, buffs apply correctly for 10s.

### Sprint 11 — Chests
- `chest.tscn` + rarity tiers (§Feature 5)
- Drop rolls on enemy death
- Mega-stat application
- **Verification:** Kill sub-boss → Rare chest drops, 4-card draft includes mega-stat with +3 levels.

### Sprint 12 — Meta-Progression Skeleton
- Gold drops, `save_manager.gd`, `user://save.json` (§Feature 8)
- Character unlock gates on main menu
- Single permanent upgrade node as proof-of-loop
- **Verification:** Earn gold in run → visible in main menu → spend on unlock → next run reflects change.

### Sprint 13 — Unique Mechanics
- Elite enemies (§9.1)
- Curse cards in draft (§9.2)
- Weather events (§9.3)
- Combo system (§9.4)
- **Verification:** Trigger each in isolation via debug console; verify in a real run.

### Sprint 14 — Polish & Balance
- Damage numbers (small floating label scene), camera shake, hit flash
- Full 25-min balance pass: tune XP curve, enemy scaling, ascension power
- Boss attack patterns (currently boss just chases — give it a projectile ring + dash)
- **Verification:** 10 full runs; no run trivially winnable, no build soft-locked.

---

## Critical Files to Modify

| Purpose | File |
|---|---|
| Weapon data + ascension + fusion | `scripts/autoloads/weapon_db.gd` |
| Character data + passives + ultimates | `scripts/autoloads/character_db.gd` *(new)* |
| Passive ability definitions | `scripts/autoloads/passive_db.gd` *(new)* |
| Save / meta-progression | `scripts/autoloads/save_manager.gd` *(new)* |
| Pause menu | `scenes/ui/pause_menu.tscn` + `pause_menu.gd` *(new)* |
| Tab stats overlay | `scenes/ui/stats_overlay.tscn` + `stats_overlay.gd` *(new)* |
| Fire trail passive object | `scenes/world/fire_patch.tscn` + `fire_patch.gd` *(new)* |
| Run stat tracking | `scripts/autoloads/game_manager.gd` (extend) |
| XP curve, pickup radius, buff system | `scenes/player/player.gd` |
| Ascension swap, fusion, pool retrieval | `scenes/player/weapon_manager.gd` |
| Pool retrieval signal, bullet pooling fixes | `scenes/weapons/bullet.gd` |
| Boomerang range, bouncer reflection (§B8, §B10) | `scenes/weapons/bullet.gd` |
| Tier-based scaling, elite rolls, chest drops | `scenes/enemies/enemy.gd` |
| Act-based spawning, weather events | `scenes/world/enemy_spawner.gd` |
| Draft UI refactor, chest UI, HUD timer | `scenes/ui/hud.gd` → split into `hud.gd` + new `scenes/ui/draft_screen.gd` |
| Pool retrieval fix for all users | `scripts/autoloads/pool_manager.gd` |
| Gem tiers | `scenes/props/gem.gd` |
| New: destructibles/chests/consumables | `scenes/props/{destructible,consumable,chest}.tscn+.gd` *(new)* |

---

## Verification Strategy

After every sprint:
1. Run the game. Complete a full 25-minute session without crash.
2. Use Godot MCP to inspect scene state mid-run and verify node counts don't leak.
3. Log all changes as a dated entry in `DEVELOP.md` (per dev-log policy).
4. Spot-check pool reuse via editor remote debugger — confirm pools size up but don't grow unbounded.

---

## Out of Scope (for this plan)

- Art assets (sprites, audio, particles) — reserved for post-code-complete pass
- Networking / multiplayer
- Controller remapping UI
- Localization
- Achievements / cloud saves


## [2026-04-19] Sprint 10 & 11 Progress Checkpoint
- **Done:** Base stats system integrated, Boss scaling fixed, Draft UI updated natively, Chest spawning with Void Reliquary logic completed.
- **Pending:** Implement Static Anomalies (destructibles), Unstable Energies (consumables), and the Mythic Chest massive stat-dispenser logic.

