extends Node

# ─────────────────────────────────────────────────────────────────────────────
# CharacterDB — defines each playable character.
#
# Each entry holds:
#   main_weapon     : starting weapon ID (also the ascension-eligible weapon)
#   base_*          : initial player stats applied in player.apply_character()
#   passives        : list of 3 passive IDs from PassiveDB
#                     Passives 0 & 1 are active from run start.
#                     Passive 2 unlocks at player level 10.
#   ultimate        : ultimate ability ID  (string key used in player.cast_ultimate)
#   ultimate_cooldown: seconds between uses
# ─────────────────────────────────────────────────────────────────────────────

var CHARACTERS: Dictionary = {
	"wanderer": {
		"name":              "The Wanderer",
		"desc":              "Balanced fighter with a powerful piercing main weapon.",
		"main_weapon":       "piercer",
		"base_health":       100.0,
		"base_speed":        200.0,
		"pickup_radius":     120.0,
		"passives":          ["twin_barrels", "armor_shards", "momentum_stacks"],
		"ultimate":          "temporal_shift",
		"ultimate_cooldown": 90.0,
	},
	"monk": {
		"name":              "The Monk",
		"desc":              "Fast and agile. Orbiting weapons and fire leave destruction.",
		"main_weapon":       "orb",
		"base_health":       80.0,
		"base_speed":        230.0,
		"pickup_radius":     150.0,
		"passives":          ["orbit_knockback", "fire_trail", "zen_threshold"],
		"ultimate":          "aegis",
		"ultimate_cooldown": 60.0,
	},
	"archer": {
		"name":              "The Archer",
		"desc":              "Long-range specialist. Beams always pierce; every shot counts.",
		"main_weapon":       "beam",
		"base_health":       90.0,
		"base_speed":        210.0,
		"pickup_radius":     120.0,
		"passives":          ["piercing_eye", "armor_shards", "twin_barrels"],
		"ultimate":          "sniper_mode",
		"ultimate_cooldown": 75.0,
	},
}

func _ready() -> void:
	pass  # data-only autoload
