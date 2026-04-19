extends Node

# ─────────────────────────────────────────────────────────────────────────────
# PassiveDB — defines all passive abilities.
#
# Each entry declares:
#   hook      : when the passive fires (used for dispatch in player.gd)
#               "on_fire"        → weapon_manager calls player.passive_on_fire()
#               "on_take_damage" → player.take_damage() applies reduction
#               "on_kill"        → enemy.die() calls player.passive_on_kill()
#               "on_move"        → player._physics_process spawns fire patches
#               "on_hit"         → bullet._on_body_entered applies knockback
#   + hook-specific params (see individual entries)
# ─────────────────────────────────────────────────────────────────────────────

var PASSIVES: Dictionary = {
	# ── Wanderer passives ────────────────────────────────────────────────────
	"twin_barrels": {
		"name":        "Twin Barrels",
		"desc":        "Fires 2 projectiles per shot. Each deals 75% damage.",
		"hook":        "on_fire",
		"count_add":   1,      # extra projectiles per fire
		"damage_mult": 0.75,   # damage factor applied to every projectile
	},
	"armor_shards": {
		"name":             "Armor Shards",
		"desc":             "Take 15% less damage from all sources.",
		"hook":             "on_take_damage",
		"damage_reduction": 0.15,
	},
	"momentum_stacks": {
		"name":          "Momentum",
		"desc":          "Consecutive kills within 2s stack +3% speed (max 10).",
		"hook":          "on_kill",
		"stack_max":     10,
		"speed_mult":    0.03,  # fraction of base_speed added per stack
		"decay_time":    2.0,   # seconds without a kill before stacks reset
	},

	# ── Monk passives ────────────────────────────────────────────────────────
	"orbit_knockback": {
		"name":            "Orbital Force",
		"desc":            "Orb weapons knock back enemies on hit.",
		"hook":            "on_hit",
		"knockback_force": 300.0,
		"weapon_type":     "orbital",   # only applies to this weapon type
	},
	"fire_trail": {
		"name":           "Blazing Steps",
		"desc":           "Leaves fire patches while moving (8 DPS, 2s duration).",
		"hook":           "on_move",
		"spawn_rate":     0.35,   # seconds between patch spawns
		"patch_damage":   8.0,
		"patch_duration": 2.0,
	},
	"zen_threshold": {
		"name":         "Zen Threshold",
		"desc":         "Every 20/50/100 kills permanently boosts all damage by 10%.",
		"hook":         "on_kill",
		"thresholds":   [20, 50, 100],
		"damage_boost": 0.10,
	},

	# ── Archer passives ──────────────────────────────────────────────────────
	"piercing_eye": {
		"name":        "Piercing Eye",
		"desc":        "Beam and straight-type weapons always fully pierce enemies.",
		"hook":        "on_init",   # applied in bullet.init_weapon
		"force_pierce": true,
		"weapon_types": ["straight", "beam"],
	},
}

func _ready() -> void:
	pass  # data-only autoload
