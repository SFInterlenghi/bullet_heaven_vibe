extends Node2D

@export var bullet_scene: PackedScene
var equipped_weapons: Array = []
var bullet_container: Node2D = null

func _ready() -> void:
	# B13: robust container lookup — falls back to relative path if group not set.
	# To future-proof, add BulletContainer to the "bullet_container" group in world.tscn.
	bullet_container = get_tree().get_first_node_in_group("bullet_container")
	if bullet_container == null:
		bullet_container = get_parent().get_parent().get_node_or_null("BulletContainer")
	# Default starting weapon — overridden by player.apply_character()
	add_weapon("piercer")

func add_weapon(id: String) -> void:
	for w in equipped_weapons:
		if w["id"] == id:
			var max_lv = WeaponDB.WEAPONS[id].get("max_level", 12)
			w["level"] = min(w["level"] + 1, max_lv)
			return

	if equipped_weapons.size() >= 6:
		return

	var data = WeaponDB.get_weapon(id)
	equipped_weapons.append({
		"id":    id,
		"level": 1,
		"timer": data["base_cooldown"],  # preload timer → fire immediately on pickup
		"data":  data,
	})

## Swaps a max-level base weapon to its ascended form (level reset to 1).
func ascend_weapon(base_id: String) -> void:
	var wdata  = WeaponDB.WEAPONS.get(base_id, {})
	var asc_id = wdata.get("ascended_id", "")
	if asc_id == "" or not WeaponDB.WEAPONS.has(asc_id):
		push_warning("ascend_weapon: no ascended form for '%s'" % base_id)
		return
	for w in equipped_weapons:
		if w["id"] == base_id:
			w["id"]    = asc_id
			w["level"] = 1
			w["data"]  = WeaponDB.get_weapon(asc_id)
			w["timer"] = w["data"]["base_cooldown"]  # fire on first cycle
			return

func fuse_weapons(id1: String, id2: String) -> void:
	var fusion = WeaponDB.get_fusion(id1, id2)
	if fusion.is_empty():
		return
	var mythic_id = fusion["result"]

	var to_remove = []
	for w in equipped_weapons:
		if w["id"] == id1 or w["id"] == id2:
			to_remove.append(w)

	for w in to_remove:
		equipped_weapons.erase(w)

	# Clear out orbitals/bullets from fused weapons
	if bullet_container:
		for child in bullet_container.get_children():
			if child.get("weapon_id") in [id1, id2]:
				PoolManager.return_node_to_pool(child, "res://scenes/weapons/bullet.tscn")

	add_weapon(mythic_id)

	# Apply legendary bonus stats to the newly added fused weapon entry
	var bonus: Dictionary = fusion.get("legendary_bonus", {})
	if not bonus.is_empty():
		for w in equipped_weapons:
			if w["id"] == mythic_id:
				w["bonus"] = bonus
				break

func get_closest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemy")
	var curr_target = null
	var min_dist = INF
	for e in enemies:
		if e.get("is_dead") == true:
			continue
		var d = global_position.distance_to(e.global_position)
		if d < min_dist:
			min_dist = d
			curr_target = e
	return curr_target

func _physics_process(delta: float) -> void:
	# ── on_fire passive: twin_barrels ────────────────────────────────────────
	var player            = get_parent()
	var fire_damage_mult  = 1.0
	var fire_count_bonus  = 0
	if "active_passives" in player and "twin_barrels" in player.active_passives:
		var p            = PassiveDB.PASSIVES["twin_barrels"]
		fire_count_bonus = p.get("count_add", 0)
		fire_damage_mult = p.get("damage_mult", 0.75)

	for w in equipped_weapons:
		w["timer"] += delta
		var upgrades  = WeaponDB.get_upgrade_data(w["id"], w["level"])
		var base_cd   = w["data"]["base_cooldown"] * upgrades.get("cd_mult", 1.0)
		# attack_speed and cd_reduction both reduce effective cooldown
		var spd: float = player.attack_speed if "attack_speed" in player else 1.0
		var cdr: float = player.cd_reduction if "cd_reduction" in player else 0.0
		var actual_cd = base_cd / max(0.1, spd * (1.0 + cdr))

		# Burst sub-loop
		if w["data"]["type"] == "burst" and w.has("bursting"):
			if w["burst_timer"] > 0:
				w["burst_timer"] -= delta
			elif w["bursts_left"] > 0:
				w["bursts_left"] -= 1
				w["burst_timer"]  = upgrades["burst_delay"]
				_fire_projectile(w, upgrades, true, 0, 1, fire_damage_mult)
			elif w["timer"] >= actual_cd:
				w["timer"]       = 0.0
				w["bursting"]    = true
				w["bursts_left"] = upgrades["burst_count"] - 1
				w["burst_timer"] = upgrades["burst_delay"]
				_fire_projectile(w, upgrades, false, 0, 1, fire_damage_mult)
			continue

		if w["timer"] >= actual_cd:
			w["timer"] = 0.0
			
			# Sprint 9 fix: Cap orbitals by clearing the old batch before firing anew
			if w["data"]["type"] == "orbital" and bullet_container:
				for child in bullet_container.get_children():
					if child.get("weapon_id") == w["id"] and child.get("weapon_type") == "orbital":
						PoolManager.return_node_to_pool(child, "res://scenes/weapons/bullet.tscn")
						
			var bonus  = w.get("bonus", {})
			var count  = upgrades.get("count", 1) + fire_count_bonus + bonus.get("extra_count", 0)
			for i in range(count):
				_fire_projectile(w, upgrades, false, i, count, fire_damage_mult)

func _fire_projectile(w: Dictionary, upgrades: Dictionary, _is_sub_burst: bool, index: int = 0, total: int = 1, fire_damage_mult: float = 1.0) -> void:
	if bullet_scene == null or bullet_container == null:
		return

	var target = get_closest_enemy()
	var bullet = PoolManager.get_node_from_pool(bullet_scene)
	bullet_container.add_child(bullet)

	if bullet.has_method("init_weapon"):
		bullet.init_weapon(w, upgrades, global_position, target, index, total, get_parent())

	# Apply player's damage_multiplier (boosted by zen_threshold)
	var player = get_parent()
	if "damage_multiplier" in player:
		bullet.damage *= player.damage_multiplier

	# Apply legendary fusion bonus damage multiplier if present
	var bonus: Dictionary = w.get("bonus", {})
	if bonus.has("damage_mult"):
		bullet.damage *= bonus["damage_mult"]

	# twin_barrels: all projectiles this salvo deal reduced damage
	if fire_damage_mult != 1.0:
		bullet.damage *= fire_damage_mult

	# sniper_mode ultimate: next N shots deal 5× damage
	if "_sniper_shots" in player and player._sniper_shots > 0:
		bullet.damage    *= 5.0
		player._sniper_shots -= 1

	# Crit system: luck adds a small bonus to effective crit chance
	var effective_crit: float = player.crit_chance if "crit_chance" in player else 0.0
	if "luck" in player: effective_crit += (player.luck - 1.0) * 0.05
	if randf() < effective_crit:
		var crit_mult: float = player.crit_damage if "crit_damage" in player else 1.5
		bullet.damage *= crit_mult

	# piercing_eye passive: force full pierce on straight/beam weapons
	if "active_passives" in player and "piercing_eye" in player.active_passives:
		var pi_data = PassiveDB.PASSIVES["piercing_eye"]
		if bullet.weapon_type in pi_data.get("weapon_types", []):
			bullet.max_pierce = 9999
