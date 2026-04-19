extends Node

# ─────────────────────────────────────────────────────────────────
# BASE WEAPONS  (max_level = 6, milestones at 3 and 6)
# Base weapons have an ascended_id pointing to its ascended form.
# Fused (Mythic) weapons are only available when merging two specific components.
# ─────────────────────────────────────────────────────────────────
var FUSIONS = {
	"beam_piercer": {"w1": "beam", "w2": "piercer", "result": "omega_beam"},
	"orb_spread": {"w1": "orb", "w2": "spread", "result": "vortex_storm"},
	"burst_dagger": {"w1": "burst", "w2": "dagger", "result": "blade_dance"},
	"cross_whip": {"w1": "cross", "w2": "whip", "result": "divine_scourge"},
}

func get_fusion(id1: String, id2: String) -> Dictionary:
	for key in FUSIONS:
		var f = FUSIONS[key]
		if (f["w1"] == id1 and f["w2"] == id2) or (f["w1"] == id2 and f["w2"] == id1):
			return f
	return {}

var WEAPONS = {
	"piercer": {
		"name": "The Piercer",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(-10,-10), Vector2(10,-10), Vector2(10,10), Vector2(-10,10)]),
		"color": Color(1.0, 0.4, 0.1),
		"base_cooldown": 1.2,
		"base_damage": 30.0,
		"base_speed": 600.0,
		"get_upgrades": "piercer_upgrades",
		"max_level": 6,
		"ascended_id": "lancer",
	},
	"orb": {
		"name": "The Orb",
		"type": "orbital",
		"shape": PackedVector2Array([Vector2(0,-10), Vector2(7,-7), Vector2(10,0), Vector2(7,7), Vector2(0,10), Vector2(-7,7), Vector2(-10,0), Vector2(-7,-7)]),
		"color": Color(0.2, 0.5, 1.0),
		"base_cooldown": 5.0,
		"base_damage": 20.0,
		"base_speed": 400.0,
		"get_upgrades": "orb_upgrades",
		"max_level": 6,
		"ascended_id": "phantom_orb",
	},
	"spread": {
		"name": "The Spread",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(0,-12), Vector2(11,-3), Vector2(7,10), Vector2(-7,10), Vector2(-11,-3)]),
		"color": Color(1.0, 0.2, 0.6),
		"base_cooldown": 1.5,
		"base_damage": 25.0,
		"base_speed": 450.0,
		"get_upgrades": "spread_upgrades",
		"max_level": 6,
		"ascended_id": "typhoon",
	},
	"burst": {
		"name": "The Burst",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(0,-10), Vector2(8,-5), Vector2(8,5), Vector2(0,10), Vector2(-8,5), Vector2(-8,-5)]),
		"color": Color(0.4, 1.0, 0.2),
		"base_cooldown": 2.0,
		"base_damage": 15.0,
		"base_speed": 700.0,
		"get_upgrades": "burst_upgrades",
		"max_level": 6,
		"ascended_id": "storm_burst",
	},
	"cross": {
		"name": "The Cross",
		"type": "zone",
		"shape": PackedVector2Array([Vector2(-4,-12), Vector2(4,-12), Vector2(4,-4), Vector2(12,-4), Vector2(12,4), Vector2(4,4), Vector2(4,12), Vector2(-4,12), Vector2(-4,4), Vector2(-12,4), Vector2(-12,-4), Vector2(-4,-4)]),
		"color": Color(1.0, 1.0, 0.2),
		"base_cooldown": 3.0,
		"base_damage": 10.0,
		"base_speed": 0.0,
		"get_upgrades": "cross_upgrades",
		"max_level": 6,
		"ascended_id": "sacred_cross",
	},
	"star": {
		"name": "The Bouncer",
		"type": "bounce",
		"shape": PackedVector2Array([Vector2(0,-12), Vector2(3,-4), Vector2(12,-3), Vector2(5,3), Vector2(7,11), Vector2(0,6), Vector2(-7,11), Vector2(-5,3), Vector2(-12,-3), Vector2(-3,-4)]),
		"color": Color(1.0, 0.8, 0.1),
		"base_cooldown": 1.5,
		"base_damage": 20.0,
		"base_speed": 500.0,
		"get_upgrades": "star_upgrades",
		"max_level": 6,
		"ascended_id": "supernova",
	},
	"crescent": {
		"name": "The Boomerang",
		"type": "boomerang",
		"shape": PackedVector2Array([Vector2(0,-24), Vector2(10,-14), Vector2(14,0), Vector2(10,14), Vector2(0,24), Vector2(6,10), Vector2(8,0), Vector2(6,-10)]),
		"color": Color(0.3, 0.9, 1.0),
		"base_cooldown": 1.8,
		"base_damage": 35.0,
		"base_speed": 550.0,
		"get_upgrades": "crescent_upgrades",
		"max_level": 6,
		"ascended_id": "hurricane",
	},
	"beam": {
		"name": "The Beam",
		"type": "beam",
		"shape": PackedVector2Array([Vector2(0,-4), Vector2(200,-4), Vector2(200,4), Vector2(0,4)]),
		"color": Color(0.9, 0.1, 1.0),
		"base_cooldown": 4.0,
		"base_damage": 60.0,
		"base_speed": 1500.0,
		"get_upgrades": "beam_upgrades",
		"max_level": 6,
		"ascended_id": "death_ray",
	},

	# ─────────────────────────────────────────────────────────────────
	# ASCENDED WEAPONS  (max_level = 12, milestones at 3 / 6 / 9 / 12)
	# Accessed only via ascension — never appear as new-weapon draft picks.
	# ─────────────────────────────────────────────────────────────────

	"lancer": {
		"name": "The Lancer",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(-10,-10), Vector2(10,-10), Vector2(10,10), Vector2(-10,10)]),
		"color": Color(1.0, 0.6, 0.05),
		"base_cooldown": 0.9,
		"base_damage": 45.0,
		"base_speed": 700.0,
		"get_upgrades": "lancer_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"phantom_orb": {
		"name": "Phantom Orbs",
		"type": "orbital",
		"shape": PackedVector2Array([Vector2(0,-10), Vector2(7,-7), Vector2(10,0), Vector2(7,7), Vector2(0,10), Vector2(-7,7), Vector2(-10,0), Vector2(-7,-7)]),
		"color": Color(0.1, 0.8, 1.0),
		"base_cooldown": 4.0,
		"base_damage": 30.0,
		"base_speed": 500.0,
		"get_upgrades": "phantom_orb_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"typhoon": {
		"name": "Typhoon",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(0,-12), Vector2(11,-3), Vector2(7,10), Vector2(-7,10), Vector2(-11,-3)]),
		"color": Color(1.0, 0.1, 0.8),
		"base_cooldown": 1.2,
		"base_damage": 35.0,
		"base_speed": 520.0,
		"get_upgrades": "typhoon_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"storm_burst": {
		"name": "Storm Burst",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(0,-10), Vector2(8,-5), Vector2(8,5), Vector2(0,10), Vector2(-8,5), Vector2(-8,-5)]),
		"color": Color(0.2, 1.0, 0.1),
		"base_cooldown": 1.5,
		"base_damage": 22.0,
		"base_speed": 800.0,
		"get_upgrades": "storm_burst_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"sacred_cross": {
		"name": "Sacred Cross",
		"type": "zone",
		"shape": PackedVector2Array([Vector2(-4,-12), Vector2(4,-12), Vector2(4,-4), Vector2(12,-4), Vector2(12,4), Vector2(4,4), Vector2(4,12), Vector2(-4,12), Vector2(-4,4), Vector2(-12,4), Vector2(-12,-4), Vector2(-4,-4)]),
		"color": Color(1.0, 1.0, 0.05),
		"base_cooldown": 2.5,
		"base_damage": 18.0,
		"base_speed": 0.0,
		"get_upgrades": "sacred_cross_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"supernova": {
		"name": "Supernova",
		"type": "bounce",
		"shape": PackedVector2Array([Vector2(0,-12), Vector2(3,-4), Vector2(12,-3), Vector2(5,3), Vector2(7,11), Vector2(0,6), Vector2(-7,11), Vector2(-5,3), Vector2(-12,-3), Vector2(-3,-4)]),
		"color": Color(1.0, 0.95, 0.0),
		"base_cooldown": 1.2,
		"base_damage": 30.0,
		"base_speed": 600.0,
		"get_upgrades": "supernova_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"hurricane": {
		"name": "Hurricane",
		"type": "boomerang",
		"shape": PackedVector2Array([Vector2(0,-24), Vector2(10,-14), Vector2(14,0), Vector2(10,14), Vector2(0,24), Vector2(6,10), Vector2(8,0), Vector2(6,-10)]),
		"color": Color(0.1, 1.0, 0.9),
		"base_cooldown": 1.4,
		"base_damage": 50.0,
		"base_speed": 650.0,
		"get_upgrades": "hurricane_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"death_ray": {
		"name": "Death Ray",
		"type": "beam",
		"shape": PackedVector2Array([Vector2(0,-4), Vector2(200,-4), Vector2(200,4), Vector2(0,4)]),
		"color": Color(0.7, 0.0, 1.0),
		"base_cooldown": 3.0,
		"base_damage": 90.0,
		"base_speed": 1500.0,
		"get_upgrades": "death_ray_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},

	"magic_missile": {
		"name": "Magic Missile",
		"type": "zone",
		"shape": PackedVector2Array([Vector2(-4,-4), Vector2(4,-4), Vector2(0,6)]),
		"color": Color(0.5, 0.8, 1.0),
		"base_cooldown": 1.2,
		"base_damage": 15.0,
		"base_speed": 400.0,
		"get_upgrades": "magic_missile_upgrades",
		"max_level": 6,
		"ascended_id": "arcane_barrage",
	},
	"arcane_barrage": {
		"name": "Arcane Barrage",
		"type": "zone",
		"shape": PackedVector2Array([Vector2(-4,-4), Vector2(4,-4), Vector2(0,6)]),
		"color": Color(0.2, 0.5, 1.0),
		"base_cooldown": 0.8,
		"base_damage": 25.0,
		"base_speed": 500.0,
		"get_upgrades": "arcane_barrage_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"whip": {
		"name": "Whip",
		"type": "beam",
		"shape": PackedVector2Array([Vector2(0,-2), Vector2(120,-2), Vector2(120,2), Vector2(0,2)]),
		"color": Color(0.8, 0.4, 0.1),
		"base_cooldown": 1.5,
		"base_damage": 35.0,
		"base_speed": 0.0,
		"get_upgrades": "whip_upgrades",
		"max_level": 6,
		"ascended_id": "chain_whip",
	},
	"chain_whip": {
		"name": "Chain Whip",
		"type": "beam",
		"shape": PackedVector2Array([Vector2(0,-3), Vector2(160,-3), Vector2(160,3), Vector2(0,3)]),
		"color": Color(0.9, 0.2, 0.1),
		"base_cooldown": 1.0,
		"base_damage": 55.0,
		"base_speed": 0.0,
		"get_upgrades": "chain_whip_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"dagger": {
		"name": "Dagger",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(-12,-2), Vector2(12,-2), Vector2(16,0), Vector2(12,2), Vector2(-12,2)]),
		"color": Color(0.9, 0.9, 0.9),
		"base_cooldown": 0.8,
		"base_damage": 12.0,
		"base_speed": 800.0,
		"get_upgrades": "dagger_upgrades",
		"max_level": 6,
		"ascended_id": "phantom_daggers",
	},
	"phantom_daggers": {
		"name": "Phantom Daggers",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(-12,-2), Vector2(12,-2), Vector2(16,0), Vector2(12,2), Vector2(-12,2)]),
		"color": Color(0.4, 0.1, 0.6),
		"base_cooldown": 0.4,
		"base_damage": 20.0,
		"base_speed": 1000.0,
		"get_upgrades": "phantom_daggers_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},

	"omega_beam": {
		"name": "Omega Beam (Mythic)",
		"type": "beam",
		"shape": PackedVector2Array([Vector2(0,-10), Vector2(300,-10), Vector2(300,10), Vector2(0,10)]),
		"color": Color(1.0, 0.9, 0.2),
		"base_cooldown": 2.0,
		"base_damage": 150.0,
		"base_speed": 2000.0,
		"get_upgrades": "mythic_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"vortex_storm": {
		"name": "Vortex Storm (Mythic)",
		"type": "orbital",
		"shape": PackedVector2Array([Vector2(-10,-10), Vector2(10,-10), Vector2(10,10), Vector2(-10,10)]),
		"color": Color(0.2, 0.8, 0.9),
		"base_cooldown": 1.0,
		"base_damage": 80.0,
		"base_speed": 400.0,
		"get_upgrades": "mythic_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"blade_dance": {
		"name": "Blade Dance (Mythic)",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(-4,-12), Vector2(4,-12), Vector2(0,12)]),
		"color": Color(1.0, 0.3, 0.3),
		"base_cooldown": 0.3,
		"base_damage": 40.0,
		"base_speed": 1200.0,
		"get_upgrades": "mythic_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
	"divine_scourge": {
		"name": "Divine Scourge (Mythic)",
		"type": "bounce",
		"shape": PackedVector2Array([Vector2(-8,-8), Vector2(8,-8), Vector2(8,8), Vector2(-8,8)]),
		"color": Color(1.0, 0.8, 0.5),
		"base_cooldown": 1.5,
		"base_damage": 200.0,
		"base_speed": 800.0,
		"get_upgrades": "mythic_upgrades",
		"max_level": 12,
		"is_ascended": true,
	},
}


# ─────────────────────────────────────────────────────────────────
# PUBLIC API
# ─────────────────────────────────────────────────────────────────
func get_weapon(key: String) -> Dictionary:
	return WEAPONS[key]

func get_upgrade_data(key: String, level: int) -> Dictionary:
	var weapon = WEAPONS[key]
	var base_upgrades = call(weapon["get_upgrades"], level)

	# Continuous multipliers — apply every level regardless of milestones.
	base_upgrades["cd_mult"]     = max(0.2, 1.0 - level * 0.05)
	base_upgrades["damage_mult"] = 1.0 + level * 0.1

	if not base_upgrades.has("scale_mult"):
		base_upgrades["scale_mult"] = 1.0 + level * 0.05
	if not base_upgrades.has("speed_mult"):
		base_upgrades["speed_mult"] = 1.0 + level * 0.08

	return base_upgrades


# ─────────────────────────────────────────────────────────────────
# BASE WEAPON UPGRADE FUNCTIONS  (milestones: 3 and 6)
# ─────────────────────────────────────────────────────────────────

func piercer_upgrades(level: int) -> Dictionary:
	var count = 1
	var pierce = 1
	if level >= 3: count = 2;  pierce = 2   # Forward + backward, pierces 2
	if level >= 6: count = 4;  pierce = 4   # Quad cross, heavy pierce (ascension eligible)
	return {"count": count, "max_pierce": pierce}

func orb_upgrades(level: int) -> Dictionary:
	var count = 1
	var radius = 80.0
	if level >= 3: count = 2;  radius = 100.0  # Second orb
	if level >= 6: count = 4;  radius = 130.0  # Full ring (ascension eligible)
	return {"count": count, "spin_radius": radius, "spin_speed": 1.0}

func spread_upgrades(level: int) -> Dictionary:
	var count = 1
	var angle_spread = 0.0
	if level >= 3: count = 3;  angle_spread = PI / 4   # Fan spread
	if level >= 6: count = 5;  angle_spread = PI / 2   # Wide fan (ascension eligible)
	return {"count": count, "spread": angle_spread}

func burst_upgrades(level: int) -> Dictionary:
	var burst_amount = 3
	var burst_delay  = 0.10
	var tracking     = false
	if level >= 3: burst_amount = 4;  burst_delay = 0.08
	if level >= 6: burst_amount = 6;  burst_delay = 0.04;  tracking = true  # Ascension eligible
	return {"burst_count": burst_amount, "burst_delay": burst_delay, "tracking": tracking}

func cross_upgrades(level: int) -> Dictionary:
	var count    = 1
	var scale    = 1.0
	var duration = 2.0
	var chasing  = false
	if level >= 3: count = 2;  scale = 1.5
	if level >= 6: count = 3;  scale = 2.5;  duration = 4.0;  chasing = true  # Ascension eligible
	return {"count": count, "scale_mult": scale, "duration": duration, "chasing": chasing}

func star_upgrades(level: int) -> Dictionary:
	var bounces = 2
	var count   = 1
	if level >= 3: bounces = 4;  count = 2
	if level >= 6: bounces = 99; count = 2   # Near-infinite bounces (ascension eligible)
	return {"max_bounces": bounces, "count": count}

func crescent_upgrades(level: int) -> Dictionary:
	var distance  = 300.0
	var speed     = 1.0
	var count     = 1
	if level >= 3: distance = 400.0;  count = 2
	if level >= 6: distance = 550.0;  speed = 1.5;  count = 3  # Ascension eligible
	return {"travel_dist": distance, "speed_mult": speed, "count": count}

func beam_upgrades(level: int) -> Dictionary:
	var count       = 1
	var scale       = 1.0
	var penetration = 1
	var duration    = 0.1
	if level >= 3: scale = 2.0;  duration = 0.3
	if level >= 6: penetration = 99;  count = 2;  duration = 0.6  # Ascension eligible
	return {"count": count, "scale_mult": scale, "penetrate": penetration, "duration": duration}

# ─────────────────────────────────────────────────────────────────
# ASCENDED WEAPON UPGRADE FUNCTIONS  (milestones: 3 / 6 / 9 / 12)
# ─────────────────────────────────────────────────────────────────

func lancer_upgrades(level: int) -> Dictionary:
	# Omnidirectional lance barrage
	var count  = 4
	var pierce = 4
	if level >= 3:  count = 6;   pierce = 8
	if level >= 6:  count = 8;   pierce = 16
	if level >= 9:  count = 12;  pierce = 32
	if level >= 12: count = 16;  pierce = 99  # True omnidirectional, full pierce
	return {"count": count, "max_pierce": pierce}

func phantom_orb_upgrades(level: int) -> Dictionary:
	# Dense orbital ring, large radius
	var count  = 4
	var radius = 120.0
	if level >= 3:  count = 6;   radius = 150.0
	if level >= 6:  count = 8;   radius = 180.0
	if level >= 9:  count = 10;  radius = 220.0
	if level >= 12: count = 14;  radius = 260.0
	return {"count": count, "spin_radius": radius, "spin_speed": 1.4}

func typhoon_upgrades(level: int) -> Dictionary:
	# Near-360° saturation
	var count        = 7
	var angle_spread = PI * 0.75
	if level >= 3:  count = 9;   angle_spread = PI * 1.2
	if level >= 6:  count = 12;  angle_spread = PI * 1.6
	if level >= 9:  count = 16;  angle_spread = PI * 1.9
	if level >= 12: count = 24;  angle_spread = TAU  # Full circle
	return {"count": count, "spread": angle_spread}

func storm_burst_upgrades(level: int) -> Dictionary:
	# Extreme burst count with full tracking
	var burst_amount = 8
	var burst_delay  = 0.06
	if level >= 3:  burst_amount = 12;  burst_delay = 0.05
	if level >= 6:  burst_amount = 16;  burst_delay = 0.04
	if level >= 9:  burst_amount = 20;  burst_delay = 0.03
	if level >= 12: burst_amount = 30;  burst_delay = 0.02
	return {"burst_count": burst_amount, "burst_delay": burst_delay, "tracking": true}

func sacred_cross_upgrades(level: int) -> Dictionary:
	# Massive chasing zones
	var count    = 3
	var scale    = 2.5
	var duration = 5.0
	if level >= 3:  count = 5;  scale = 3.5;  duration = 7.0
	if level >= 6:  count = 7;  scale = 4.5;  duration = 9.0
	if level >= 9:  count = 9;  scale = 6.0;  duration = 12.0
	if level >= 12: count = 12; scale = 8.0;  duration = 15.0
	return {"count": count, "scale_mult": scale, "duration": duration, "chasing": true}

func supernova_upgrades(level: int) -> Dictionary:
	# Infinite-bounce storm
	var count = 3
	if level >= 3:  count = 5
	if level >= 6:  count = 7
	if level >= 9:  count = 10
	if level >= 12: count = 14
	return {"max_bounces": 99, "count": count}

func hurricane_upgrades(level: int) -> Dictionary:
	# Many heavy boomerangs, great range
	var dist  = 600.0
	var count = 4
	if level >= 3:  dist = 750.0;  count = 6
	if level >= 6:  dist = 900.0;  count = 8
	if level >= 9:  dist = 1100.0; count = 10
	if level >= 12: dist = 1400.0; count = 14
	return {"travel_dist": dist, "speed_mult": 1.6, "count": count}

func death_ray_upgrades(level: int) -> Dictionary:
	# Multi-beam annihilation
	var count    = 2
	var scale    = 3.0
	var duration = 0.8
	if level >= 3:  count = 3;  scale = 4.5;  duration = 1.1
	if level >= 6:  count = 4;  scale = 6.0;  duration = 1.5
	if level >= 9:  count = 5;  scale = 8.0;  duration = 2.0
	if level >= 12: count = 8;  scale = 10.0; duration = 2.5
	return {"count": count, "scale_mult": scale, "penetrate": 99, "duration": duration}

func magic_missile_upgrades(level: int) -> Dictionary:
	var count = 1
	var chasing = true
	var duration = 3.0
	if level >= 3: count = 3
	if level >= 6: count = 5
	return {"count": count, "chasing": chasing, "duration": duration}

func arcane_barrage_upgrades(level: int) -> Dictionary:
	var count = 6
	var chasing = true
	var duration = 4.0
	if level >= 3: count = 8
	if level >= 6: count = 10
	if level >= 9: count = 14
	if level >= 12: count = 20
	return {"count": count, "chasing": chasing, "duration": duration}

func whip_upgrades(level: int) -> Dictionary:
	var count = 1
	var scale = 1.0
	var duration = 0.2
	if level >= 3: count = 2; scale = 1.2
	if level >= 6: count = 2; scale = 1.5
	# Whip hits left and right
	return {"count": count, "scale_mult": scale, "duration": duration, "spread": PI}

func chain_whip_upgrades(level: int) -> Dictionary:
	var count = 2
	var scale = 1.5
	var duration = 0.2
	if level >= 3: count = 4; scale = 1.8
	if level >= 6: count = 6; scale = 2.0
	if level >= 9: count = 8; scale = 2.5
	if level >= 12: count = 12; scale = 3.0
	return {"count": count, "scale_mult": scale, "duration": duration, "spread": PI}

func dagger_upgrades(level: int) -> Dictionary:
	var count = 2
	var penetrate = 1
	if level >= 3: count = 4
	if level >= 6: count = 6; penetrate = 2
	return {"count": count, "max_pierce": penetrate}

func phantom_daggers_upgrades(level: int) -> Dictionary:
	var count = 8
	var penetrate = 3
	if level >= 3: count = 10
	if level >= 6: count = 12; penetrate = 4
	if level >= 9: count = 16; penetrate = 5
	if level >= 12: count = 24; penetrate = 8
	return {"count": count, "max_pierce": penetrate}

func mythic_upgrades(level: int) -> Dictionary:
	var count = 3 + level
	var scale = 2.0 + level * 0.2
	var penetrate = 10 + level
	var duration = 2.0 + level * 0.1
	return {"count": count, "scale_mult": scale, "max_pierce": penetrate, "duration": duration}
