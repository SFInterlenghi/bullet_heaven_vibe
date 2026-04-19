extends CanvasLayer

@onready var timer_label = $MarginContainer/VBoxContainer/HBoxContainer/TimerLabel
@onready var health_bar  = $MarginContainer/VBoxContainer/HBoxContainer/HealthBar
@onready var xp_bar      = $MarginContainer/VBoxContainer/HBoxContainer/LevelContainer/XPBar
@onready var level_label = $MarginContainer/VBoxContainer/HBoxContainer/LevelContainer/LevelLabel

var time_elapsed: float = 0.0
var win_triggered: bool = false
var _last_tick_msec: int = 0  # real wall-clock reference for time_scale-immune timer

# Untyped so GDScript resolves custom signals/methods via dynamic dispatch at runtime.
var _draft_screen  = null
var _stats_overlay = null

# Ultimate cooldown bar — added dynamically in _ready()
var _ultimate_bar: ProgressBar = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("hud")
	_last_tick_msec = Time.get_ticks_msec()

	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.health_changed.connect(_on_player_health_changed)
		player.xp_changed.connect(_on_player_xp_changed)
		player.ultimate_changed.connect(_on_ultimate_changed)
		# show_banner() is called directly by hud systems; no player signal needed

	# ── Ultimate cooldown bar (second row in VBoxContainer) ───────────────────
	# VBox is grandparent of timer_label (timer → HBox → VBox)
	var vbox = timer_label.get_parent().get_parent()

	var ult_row = HBoxContainer.new()
	ult_row.add_theme_constant_override("separation", 8)
	vbox.add_child(ult_row)

	var ult_icon = Label.new()
	ult_icon.text = "⚡ Ultimate"
	ult_icon.add_theme_font_size_override("font_size", 15)
	ult_row.add_child(ult_icon)

	_ultimate_bar = ProgressBar.new()
	_ultimate_bar.custom_minimum_size = Vector2(180, 16)
	_ultimate_bar.max_value           = 1.0
	_ultimate_bar.value               = 1.0   # start ready
	_ultimate_bar.show_percentage     = false
	ult_row.add_child(_ultimate_bar)

	var ult_hint = Label.new()
	ult_hint.text = "[SHIFT/Q]"
	ult_hint.add_theme_font_size_override("font_size", 13)
	ult_hint.modulate = Color(0.7, 0.7, 0.7)
	ult_row.add_child(ult_hint)

	# ── Deferred UI spawns ────────────────────────────────────────────────────
	# Add to current_scene (not root) so they are freed automatically on reload.
	var pause_menu = load("res://scenes/ui/pause_menu.tscn").instantiate()
	get_tree().current_scene.call_deferred("add_child", pause_menu)

	_stats_overlay = load("res://scenes/ui/stats_overlay.tscn").instantiate()
	get_tree().current_scene.call_deferred("add_child", _stats_overlay)

# ── Draft screen ──────────────────────────────────────────────────────────────

func show_draft_menu() -> void:
	get_tree().paused = true

	if _draft_screen != null:
		_draft_screen.queue_free()

	_draft_screen = load("res://scenes/ui/draft_screen.tscn").instantiate()
	get_tree().current_scene.add_child(_draft_screen)
	_draft_screen.card_selected.connect(_on_draft_selected)
	_draft_screen.populate(generate_draft_options())

func generate_draft_options() -> Array:
	var options = []
	var player  = get_tree().get_first_node_in_group("player")
	var mgr     = player.get_node("WeaponManager") if player else null
	var equipped: Array = mgr.equipped_weapons if mgr else []

	var pool: Array         = []
	var equipped_ids: Array = []
	
	var char_id = GameManager.selected_character_id
	var main_weapon = ""
	if CharacterDB.CHARACTERS.has(char_id):
		main_weapon = CharacterDB.CHARACTERS[char_id]["main_weapon"]
		
	var restricted_main_weapons = []
	for cid in CharacterDB.CHARACTERS.keys():
		var mw = CharacterDB.CHARACTERS[cid]["main_weapon"]
		if mw != main_weapon:
			restricted_main_weapons.append(mw)
			
	# Task 8: Fusion injection
	if equipped.size() > 1:
		for i in range(equipped.size()):
			for j in range(i + 1, equipped.size()):
				var w1 = equipped[i]
				var w2 = equipped[j]
				var max_lv1 = WeaponDB.WEAPONS.get(w1["id"], {}).get("max_level", 6)
				var max_lv2 = WeaponDB.WEAPONS.get(w2["id"], {}).get("max_level", 6)
				if w1["level"] >= max_lv1 and w2["level"] >= max_lv2:
					var fusion = WeaponDB.get_fusion(w1["id"], w2["id"])
					if not fusion.is_empty():
						var fid = fusion["result"]
						if not equipped_ids.has(fid):
							pool.append({
								"type": "fusion",
								"id1": w1["id"],
								"id2": w2["id"],
								"result_id": fid,
								"data": WeaponDB.WEAPONS[fid]
							})

	for w in equipped:
		equipped_ids.append(w["id"])
		var wdata   = WeaponDB.WEAPONS.get(w["id"], {})
		var max_lv  = wdata.get("max_level", 12)

		# Level-up option for weapons not yet at cap
		if w["level"] < max_lv:
			pool.append({"type": "weapon", "id": w["id"], "data": wdata, "level": w["level"] + 1})

		# Ascension option: weapon is at max AND has an ascended form
		# Task 7: Only the main weapon is allowed to trigger the Ascension draft card.
		if w["level"] >= max_lv and wdata.has("ascended_id") and w["id"] == main_weapon:
			var asc_id = wdata["ascended_id"]
			if WeaponDB.WEAPONS.has(asc_id):
				pool.append({
					"type":        "ascend",
					"id":          w["id"],
					"ascended_id": asc_id,
					"data":        WeaponDB.WEAPONS[asc_id],
				})

	# New base weapons (exclude ascended forms — they're only reachable via ascension)
	if equipped.size() < 6:
		for key in WeaponDB.WEAPONS.keys():
			if equipped_ids.has(key):
				continue
			if restricted_main_weapons.has(key):
				continue
			if WeaponDB.WEAPONS[key].get("is_ascended", false):
				continue
			# Skip if the ascended form of this weapon is already equipped
			var asc_id = WeaponDB.WEAPONS[key].get("ascended_id", "")
			if asc_id != "" and equipped_ids.has(asc_id):
				continue
			pool.append({"type": "weapon", "id": key, "data": WeaponDB.WEAPONS[key], "level": 1})

	pool.shuffle()
	for i in range(min(3, pool.size())):
		options.append(pool[i])

	var available_passives = []
	var char_passives = CharacterDB.CHARACTERS[GameManager.selected_character_id]["passives"]
	for pid in char_passives:
		if not player.active_passives.has(pid):
			available_passives.append(pid)
	available_passives.shuffle()
	
	# If we didn't fill 3 weapon slots, pad with passives
	var passive_idx = 0
	while options.size() < 3 and passive_idx < available_passives.size():
		var pad_id = available_passives[passive_idx]
		options.append({
			"type": "passive",
			"id": pad_id,
			"data": PassiveDB.PASSIVES[pad_id]
		})
		passive_idx += 1
		
	# Guarantee Slot 4 is a passive, or if empty, a Stat
	if passive_idx < available_passives.size():
		var p_id = available_passives[passive_idx]
		options.append({
			"type": "passive",
			"id": p_id,
			"data": PassiveDB.PASSIVES[p_id]
		})
	else:
		# Full stat fallback pool — shuffle so no stat repeats in same draft
		var stat_pool = [
			{"type": "stat", "stat_id": "heal",         "stat_name": "Heal 50% HP"},
			{"type": "stat", "stat_id": "max_hp",       "stat_name": "Max HP +20"},
			{"type": "stat", "stat_id": "armor",        "stat_name": "Armor +1"},
			{"type": "stat", "stat_id": "speed",        "stat_name": "Move Speed +10%"},
			{"type": "stat", "stat_id": "crit",         "stat_name": "Crit Chance +5%"},
			{"type": "stat", "stat_id": "crit_damage",  "stat_name": "Crit Damage +20%"},
			{"type": "stat", "stat_id": "luck",         "stat_name": "Luck +10%"},
			{"type": "stat", "stat_id": "attack_speed", "stat_name": "Attack Speed +15%"},
			{"type": "stat", "stat_id": "cd_reduction", "stat_name": "Cooldown Reduction +10%"},
			{"type": "stat", "stat_id": "area",         "stat_name": "Area of Effect +10%"},
			{"type": "stat", "stat_id": "dodge",        "stat_name": "Dodge Chance +5%"},
			{"type": "stat", "stat_id": "regen",        "stat_name": "Health Regen +2/s"},
		]
		stat_pool.shuffle()
		# Exclude any stat already offered as a card in this draft
		var used_stats: Array = []
		for o in options:
			if o["type"] == "stat": used_stats.append(o["stat_id"])
		for s in stat_pool:
			if not used_stats.has(s["stat_id"]):
				options.append(s)
				break

	# Desperation fill if still < 4
	while options.size() < 4:
		options.append({"type": "stat", "stat_id": "heal", "stat_name": "Heal 50% HP"})

	options.shuffle()
	return options

func _on_draft_selected(opt: Dictionary) -> void:
	if _draft_screen:
		_draft_screen.queue_free()
		_draft_screen = null

	var player = get_tree().get_first_node_in_group("player")
	match opt["type"]:
		"weapon":
			player.get_node("WeaponManager").add_weapon(opt["id"])
		"ascend":
			player.get_node("WeaponManager").ascend_weapon(opt["id"])
		"fusion":
			player.get_node("WeaponManager").fuse_weapons(opt["id1"], opt["id2"])
		"passive":
			player.active_passives.append(opt["id"])
		"stat":
			_apply_stat(player, opt["stat_id"], 1)
			player.health_changed.emit(player.current_health, player.max_health)
		"mega_stat":
			_apply_stat(player, opt["stat_id"], 3)
			player.health_changed.emit(player.current_health, player.max_health)

	get_tree().paused = false

## Applies `stacks` increments of a single stat to the player.
## stacks=1 for normal draft picks; stacks=3 for Mythic/Rare mega-stat rewards.
func _apply_stat(player: Node, stat_id: String, stacks: int) -> void:
	for _i in range(stacks):
		match stat_id:
			"heal":
				player.current_health = min(player.current_health + player.max_health * 0.5, player.max_health)
			"max_hp":
				player.max_health += 20.0
				player.current_health += 20.0
			"armor":
				if "armor" in player: player.armor += 1.0
			"speed":
				player._base_move_speed += 20.0
				player.move_speed = player._base_move_speed
			"crit":
				if "crit_chance" in player: player.crit_chance = min(player.crit_chance + 0.05, 0.95)
			"crit_damage":
				if "crit_damage" in player: player.crit_damage += 0.2
			"luck":
				if "luck" in player: player.luck += 0.1
			"attack_speed":
				if "attack_speed" in player:
					player._base_attack_speed += 0.15
					player.attack_speed = player._base_attack_speed
			"cd_reduction":
				if "cd_reduction" in player: player.cd_reduction += 0.1
			"area":
				if "area_of_effect" in player: player.area_of_effect = min(player.area_of_effect + 0.1, 4.0)
			"dodge":
				if "dodge_chance" in player: player.dodge_chance = min(player.dodge_chance + 0.05, 0.75)
			"regen":
				if "health_regen" in player: player.health_regen += 2.0

# ── Input ─────────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if _draft_screen != null:
			return
		GameManager.toggle_pause()

@onready var dash_icon = get_node_or_null("DashIcon")

# ── Per-frame ─────────────────────────────────────────────────────────────────

func _process(_delta: float) -> void:
	if dash_icon:
		var p = get_tree().get_first_node_in_group("player")
		if p and "dash_cooldown_timer" in p:
			if p.dash_cooldown_timer <= 0.0:
				dash_icon.modulate = Color(0, 0, 0, 1.0)
			else:
				var ratio = 1.0 - (p.dash_cooldown_timer / p.dash_cooldown)
				dash_icon.modulate = Color(0, 0, 0, max(0.2, ratio))  # keep minimal visibility
				
	# Use real wall-clock delta so Engine.time_scale (Temporal Shift) doesn't skew the timer
	var now_msec: int = Time.get_ticks_msec()
	var real_delta: float = (now_msec - _last_tick_msec) / 1000.0
	_last_tick_msec = now_msec
	if not get_tree().paused:
		time_elapsed += real_delta

	# 25-min fallback win
	if not win_triggered and time_elapsed >= 1500.0:
		win_triggered = true
		get_tree().call_group("game_manager", "on_game_won")

	var minutes = int(time_elapsed / 60.0)
	var seconds  = int(time_elapsed) % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]

	# Stats overlay: show while Tab is held
	if _stats_overlay and _stats_overlay.is_inside_tree():
		if Input.is_action_just_pressed("stats"):
			_stats_overlay.show_overlay()
		elif Input.is_action_just_released("stats"):
			_stats_overlay.hide_overlay()

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_player_health_changed(current: float, maximum: float) -> void:
	health_bar.max_value = maximum
	health_bar.value     = current

func _on_player_xp_changed(current: int, maximum: int, lv: int) -> void:
	xp_bar.max_value = maximum
	xp_bar.value     = current
	level_label.text = "Level: %d" % lv

func _on_ultimate_changed(timer: float, cooldown_max: float) -> void:
	if _ultimate_bar == null:
		return
	if cooldown_max <= 0.0:
		_ultimate_bar.value = 1.0
		return
	# bar fills as timer counts toward 0 (ready = full bar)
	_ultimate_bar.value = 1.0 - (timer / cooldown_max)
	# Tint gold when ready, grey when cooling down
	_ultimate_bar.modulate = Color(1.0, 0.9, 0.1) if timer <= 0.0 else Color.WHITE

## Shows a timed banner notification at the top of the HUD.
## Called by player.show_banner_signal and directly by hud systems.
func show_banner(text: String, color: Color = Color(1.0, 0.9, 0.1)) -> void:
	var banner = Label.new()
	banner.text = text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.add_theme_font_size_override("font_size", 26)
	banner.modulate = color
	banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	banner.position = Vector2(0, 180)

	add_child(banner)

	var tw = create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(banner, "modulate", Color(color.r, color.g, color.b, 0.0), 0.6)
	tw.tween_callback(banner.queue_free)




func show_void_prompt(chest) -> void:
	var dlg = ConfirmationDialog.new()
	dlg.title = "Void Reliquary"
	dlg.dialog_text = "A Void Reliquary has been disturbed.\nAccept the curse to claim its Mythic power?"
	dlg.process_mode = Node.PROCESS_MODE_ALWAYS
	dlg.confirmed.connect(func():
		get_tree().paused = false
		if is_instance_valid(chest):
			chest.start_void_event()
		dlg.queue_free()
	)
	dlg.canceled.connect(func():
		get_tree().paused = false
		if is_instance_valid(chest) and chest.has_method("on_void_declined"):
			chest.on_void_declined()
		dlg.queue_free()
	)
	add_child(dlg)
	dlg.popup_centered()



func show_chest_menu(rarity: int) -> void:
	get_tree().paused = true

	if _draft_screen != null:
		_draft_screen.queue_free()

	_draft_screen = load("res://scenes/ui/draft_screen.tscn").instantiate()
	get_tree().current_scene.add_child(_draft_screen)
	_draft_screen.card_selected.connect(_on_draft_selected)

	var options = _build_chest_options(rarity)
	_draft_screen.populate(options)

	match rarity:
		0: show_banner("CHEST OPENED", Color(0.8, 0.6, 0.3))
		1: show_banner("UNCOMMON CHEST!", Color(0.8, 0.8, 0.8))
		2: show_banner("RARE CHEST!", Color(1.0, 0.8, 0.1))
		3: show_banner("✦ MYTHIC CHEST ✦", Color(0.2, 1.0, 0.9))

## Builds chest reward options based on rarity.
## 0=Common: 1 weapon/stat; 1=Uncommon: 2 weapon; 2=Rare: 3 weapon + 1 mega-stat; 3=Mythic: 4 mega-stats
func _build_chest_options(rarity: int) -> Array:
	var options: Array = []
	var player = get_tree().get_first_node_in_group("player")
	var mgr = player.get_node("WeaponManager") if player else null
	var equipped: Array = mgr.equipped_weapons if mgr else []

	# Weapon upgrade pool — prefer upgrades for existing weapons
	var weapon_pool: Array = []
	for w in equipped:
		var wdata = WeaponDB.WEAPONS.get(w["id"], {})
		var max_lv = wdata.get("max_level", 6)
		if w["level"] < max_lv:
			weapon_pool.append({"type": "weapon", "id": w["id"], "data": wdata, "level": w["level"] + 1})
	weapon_pool.shuffle()

	# Mega-stat pool (×3 application)
	var mega_stats = [
		{"type": "mega_stat", "stat_id": "max_hp",       "stat_name": "Max HP +60 (×3)"},
		{"type": "mega_stat", "stat_id": "armor",        "stat_name": "Armor +3 (×3)"},
		{"type": "mega_stat", "stat_id": "speed",        "stat_name": "Move Speed +30% (×3)"},
		{"type": "mega_stat", "stat_id": "crit",         "stat_name": "Crit Chance +15% (×3)"},
		{"type": "mega_stat", "stat_id": "attack_speed", "stat_name": "Attack Speed +45% (×3)"},
		{"type": "mega_stat", "stat_id": "cd_reduction", "stat_name": "CDR +30% (×3)"},
		{"type": "mega_stat", "stat_id": "area",         "stat_name": "Area of Effect +30% (×3)"},
		{"type": "mega_stat", "stat_id": "luck",         "stat_name": "Luck +30% (×3)"},
		{"type": "mega_stat", "stat_id": "dodge",        "stat_name": "Dodge Chance +15% (×3)"},
		{"type": "mega_stat", "stat_id": "regen",        "stat_name": "Health Regen +6/s (×3)"},
	]
	mega_stats.shuffle()

	match rarity:
		0:  # Common — 1 weapon upgrade or fallback stat
			if weapon_pool.size() > 0:
				options.append(weapon_pool[0])
			else:
				options.append({"type": "stat", "stat_id": "heal", "stat_name": "Heal 50% HP"})
		1:  # Uncommon — 2 weapon upgrades
			for i in range(min(2, weapon_pool.size())):
				options.append(weapon_pool[i])
			while options.size() < 2:
				options.append({"type": "stat", "stat_id": "heal", "stat_name": "Heal 50% HP"})
		2:  # Rare — 3 weapon upgrades + 1 guaranteed mega-stat
			for i in range(min(3, weapon_pool.size())):
				options.append(weapon_pool[i])
			while options.size() < 3:
				options.append({"type": "stat", "stat_id": "heal", "stat_name": "Heal 50% HP"})
			options.append(mega_stats[0])
		3:  # Mythic — 4 mega-stats
			for i in range(min(4, mega_stats.size())):
				options.append(mega_stats[i])

	return options
