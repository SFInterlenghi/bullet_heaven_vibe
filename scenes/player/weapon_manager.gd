extends Node2D

@export var bullet_scene: PackedScene
var equipped_weapons: Array = []
var bullet_container: Node2D = null

func _ready() -> void:
	bullet_container = get_parent().get_parent().get_node("BulletContainer")
	# Auto-equip starting weapon
	add_weapon("piercer")

func add_weapon(id: String) -> void:
	for w in equipped_weapons:
		if w["id"] == id:
			w["level"] += 1
			if w["level"] > WeaponDB.WEAPONS[id].get("max_level", 12):
				w["level"] = WeaponDB.WEAPONS[id].get("max_level", 12)
			return
			
	if equipped_weapons.size() >= 6:
		return
		
	var data = WeaponDB.get_weapon(id)
	equipped_weapons.append({
		"id": id,
		"level": 1,
		"timer": data["base_cooldown"], # Preload timer to fire immediately upon picking up
		"data": data
	})

func get_closest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var curr_target = null
	var min_dist = INF
	for e in enemies:
		var d = global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			curr_target = e
	return curr_target

func _physics_process(delta: float) -> void:
	for w in equipped_weapons:
		w["timer"] += delta
		var upgrades = WeaponDB.get_upgrade_data(w["id"], w["level"])
		var actual_cd = w["data"]["base_cooldown"] * upgrades.get("cd_mult", 1.0)
		
		# Allow burst weapons to fire multiple rapidly
		if w["data"]["type"] == "burst" and w.has("bursting"):
			if w["burst_timer"] > 0:
				w["burst_timer"] -= delta
			elif w["bursts_left"] > 0:
				w["bursts_left"] -= 1
				w["burst_timer"] = upgrades["burst_delay"]
				_fire_projectile(w, upgrades, true)
			elif w["timer"] >= actual_cd:
				w["timer"] = 0.0
				w["bursting"] = true
				w["bursts_left"] = upgrades["burst_count"] - 1
				w["burst_timer"] = upgrades["burst_delay"]
				_fire_projectile(w, upgrades, false)
			continue
			
		if w["timer"] >= actual_cd:
			w["timer"] = 0.0
			var count = upgrades.get("count", 1)
			for i in range(count):
				_fire_projectile(w, upgrades, false, i, count)

func _fire_projectile(w: Dictionary, upgrades: Dictionary, is_sub_burst: bool, index: int = 0, total: int = 1) -> void:
	if bullet_scene == null or bullet_container == null:
		return
	
	var target = get_closest_enemy()
	var type = w["data"]["type"]
	
	var bullet = bullet_scene.instantiate()
	bullet_container.add_child(bullet)
	# Initialize our new generic projectile logic
	if bullet.has_method("init_weapon"):
		bullet.init_weapon(w, upgrades, global_position, target, index, total, get_parent())
