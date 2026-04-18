extends Node

var WEAPONS = {
	"piercer": {
		"name": "The Piercer",
		"type": "straight",
		"shape": PackedVector2Array([Vector2(-10, -10), Vector2(10, -10), Vector2(10, 10), Vector2(-10, 10)]), # Square
		"color": Color(1.0, 0.4, 0.1),
		"base_cooldown": 1.2,
		"base_damage": 30.0,
		"base_speed": 600.0,
		"get_upgrades": "piercer_upgrades"
	},
	"orb": {
		"name": "The Orb",
		"type": "orbital",
		# Circle approximation
		"shape": PackedVector2Array([Vector2(0, -10), Vector2(7, -7), Vector2(10, 0), Vector2(7, 7), Vector2(0, 10), Vector2(-7, 7), Vector2(-10, 0), Vector2(-7, -7)]),
		"color": Color(0.2, 0.5, 1.0),
		"base_cooldown": 5.0, # rarely fires, just persists
		"base_damage": 20.0,
		"base_speed": 400.0,
		"get_upgrades": "orb_upgrades"
	},
	"spread": {
		"name": "The Spread",
		"type": "straight",
		# Pentagon
		"shape": PackedVector2Array([Vector2(0, -12), Vector2(11, -3), Vector2(7, 10), Vector2(-7, 10), Vector2(-11, -3)]),
		"color": Color(1.0, 0.2, 0.6),
		"base_cooldown": 1.5,
		"base_damage": 25.0,
		"base_speed": 450.0,
		"get_upgrades": "spread_upgrades"
	},
	"burst": {
		"name": "The Burst",
		"type": "straight",
		# Hexagon
		"shape": PackedVector2Array([Vector2(0, -10), Vector2(8, -5), Vector2(8, 5), Vector2(0, 10), Vector2(-8, 5), Vector2(-8, -5)]),
		"color": Color(0.4, 1.0, 0.2),
		"base_cooldown": 2.0,
		"base_damage": 15.0,
		"base_speed": 700.0,
		"get_upgrades": "burst_upgrades"
	},
	"cross": {
		"name": "The Cross",
		"type": "zone",
		# Cross geometry
		"shape": PackedVector2Array([Vector2(-4,-12), Vector2(4,-12), Vector2(4,-4), Vector2(12,-4), Vector2(12,4), Vector2(4,4), Vector2(4,12), Vector2(-4,12), Vector2(-4,4), Vector2(-12,4), Vector2(-12,-4), Vector2(-4,-4)]),
		"color": Color(1.0, 1.0, 0.2),
		"base_cooldown": 3.0,
		"base_damage": 10.0,
		"base_speed": 0.0, # Static
		"get_upgrades": "cross_upgrades"
	},
	"star": {
		"name": "The Bouncer",
		"type": "bounce",
		# Star
		"shape": PackedVector2Array([Vector2(0,-12), Vector2(3,-4), Vector2(12,-3), Vector2(5,3), Vector2(7,11), Vector2(0,6), Vector2(-7,11), Vector2(-5,3), Vector2(-12,-3), Vector2(-3,-4)]),
		"color": Color(1.0, 0.8, 0.1),
		"base_cooldown": 1.5,
		"base_damage": 20.0,
		"base_speed": 500.0,
		"get_upgrades": "star_upgrades"
	},
	"crescent": {
		"name": "The Boomerang",
		"type": "boomerang",
		# Crescent shape (simplified)
		"shape": PackedVector2Array([Vector2(0,-12), Vector2(5,-7), Vector2(7,0), Vector2(5,7), Vector2(0,12), Vector2(3,5), Vector2(4,0), Vector2(3,-5)]),
		"color": Color(0.3, 0.9, 1.0),
		"base_cooldown": 1.8,
		"base_damage": 35.0,
		"base_speed": 550.0,
		"get_upgrades": "crescent_upgrades"
	},
	"beam": {
		"name": "The Beam",
		"type": "beam",
		# Line / Thin Rect
		"shape": PackedVector2Array([Vector2(0,-2), Vector2(20,-2), Vector2(20,2), Vector2(0,2)]),
		"color": Color(0.9, 0.1, 1.0),
		"base_cooldown": 4.0,
		"base_damage": 60.0,
		"base_speed": 1500.0,
		"get_upgrades": "beam_upgrades"
	}
}

func get_weapon(key: String) -> Dictionary:
	return WEAPONS[key]

func get_upgrade_data(key: String, level: int) -> Dictionary:
	var weapon = WEAPONS[key]
	var func_name = weapon["get_upgrades"]
	var base_upgrades = call(func_name, level)
	
	# Apply massive intermediate leveling impacts!
	base_upgrades["cd_mult"] = max(0.2, 1.0 - (level * 0.05))
	base_upgrades["damage_mult"] = 1.0 + (level * 0.2)
	
	# If a milestone hasn't hardcoded a scale or speed limit, grant the intermediate ones
	if not base_upgrades.has("scale_mult"):
		base_upgrades["scale_mult"] = 1.0 + (level * 0.05)
	if not base_upgrades.has("speed_mult"):
		base_upgrades["speed_mult"] = 1.0 + (level * 0.08)
		
	return base_upgrades

# Milestone configuration maps! Each level yields properties
func piercer_upgrades(level: int) -> Dictionary:
	var count = 1
	var pierce = 1
	if level >= 3: pierce = 2
	if level >= 6: count = 2 # shoots forward and backward
	if level >= 9: pierce = 4
	if level >= 12: count = 4 # Quad cross shape
	return {"count": count, "max_pierce": pierce}

func orb_upgrades(level: int) -> Dictionary:
	var count = 1
	var radius = 80.0
	var speed_mult = 1.0
	if level >= 3: count = 2
	if level >= 6: speed_mult = 1.5
	if level >= 9: radius = 120.0
	if level >= 12: count = 4
	return {"count": count, "spin_radius": radius, "spin_speed": speed_mult}

func spread_upgrades(level: int) -> Dictionary:
	var count = 1
	var angle_spread = 0.0
	if level >= 3: 
		count = 3
		angle_spread = PI / 8
	if level >= 6:
		angle_spread = PI / 4
	if level >= 9:
		count = 4
	if level >= 12:
		count = 5
		angle_spread = PI / 2
	return {"count": count, "spread": angle_spread}

func burst_upgrades(level: int) -> Dictionary:
	var burst_amount = 3
	var burst_delay = 0.1
	var tracking = false
	if level >= 3: burst_amount = 4
	if level >= 6: burst_amount = 5; burst_delay = 0.05
	if level >= 9: burst_amount = 6
	if level >= 12: tracking = true
	return {"burst_count": burst_amount, "burst_delay": burst_delay, "tracking": tracking}

func cross_upgrades(level: int) -> Dictionary:
	var count = 1
	var scale = 1.0
	var duration = 2.0
	var chasing = false
	if level >= 3: count = 2
	if level >= 6: scale = 2.0
	if level >= 9: duration = 4.0
	if level >= 12: chasing = true
	return {"count": count, "scale_mult": scale, "duration": duration, "chasing": chasing}

func star_upgrades(level: int) -> Dictionary:
	var bounces = 2
	var count = 1
	if level >= 3: bounces = 3
	if level >= 6: bounces = 5
	if level >= 9: count = 2
	if level >= 12: bounces = 99 # near infinite for its short lifespan
	return {"max_bounces": bounces, "count": count}

func crescent_upgrades(level: int) -> Dictionary:
	var distance = 300.0
	var speed = 1.0
	var count = 1
	if level >= 3: distance = 400.0
	if level >= 6: speed = 1.5
	if level >= 9: distance = 500.0
	if level >= 12: count = 3
	return {"travel_dist": distance, "speed_mult": speed, "count": count}

func beam_upgrades(level: int) -> Dictionary:
	var count = 1
	var scale = 1.0
	var penetration = 1
	var duration = 0.1
	if level >= 3: scale = 2.0
	if level >= 6: duration = 0.5
	if level >= 9: penetration = 99
	if level >= 12: count = 2
	return {"count": count, "scale_mult": scale, "penetrate": penetration, "duration": duration}
