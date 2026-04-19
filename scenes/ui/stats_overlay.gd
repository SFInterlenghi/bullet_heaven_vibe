extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func show_overlay() -> void:
	visible = true
	_refresh()

func hide_overlay() -> void:
	visible = false

func _refresh() -> void:
	for child in get_children():
		child.queue_free()

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.1, 0.90)
	add_child(bg)

	var root_hbox = HBoxContainer.new()
	root_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	root_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	root_hbox.add_theme_constant_override("separation", 60)
	add_child(root_hbox)

	root_hbox.add_child(_panel("WEAPONS",      _weapons_text(player)))
	root_hbox.add_child(_panel("PLAYER STATS", _stats_text(player)))

# ── Helpers ───────────────────────────────────────────────────────────────────

func _panel(title_text: String, body_text: String) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(380, 0)
	vbox.add_theme_constant_override("separation", 10)

	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	vbox.add_child(title)

	vbox.add_child(HSeparator.new())

	var body = Label.new()
	body.text = body_text
	body.add_theme_font_size_override("font_size", 20)
	vbox.add_child(body)

	return vbox

func _weapons_text(player: Node) -> String:
	var manager = player.get_node_or_null("WeaponManager")
	if not manager or manager.equipped_weapons.is_empty():
		return "No weapons equipped"
	var lines: Array = []
	for w in manager.equipped_weapons:
		var up = WeaponDB.get_upgrade_data(w["id"], w["level"])
		lines.append("Lv.%-2d  %s" % [w["level"], w["data"]["name"]])
		lines.append("       DMG ×%.1f   Rate ×%.1f" % [
			up.get("damage_mult", 1.0),
			1.0 / up.get("cd_mult", 1.0)
		])
	return "\n".join(lines)

func _stats_text(player: Node) -> String:
	var s = GameManager.run_stats
	return (
		"HP            %.0f / %.0f\n" % [player.current_health, player.max_health] +
		"Move Speed    %.0f\n"         % player.move_speed +
		"Level         %d\n"           % player.level +
		"──────────────────────\n" +
		"Kills         %d\n"           % s.get("enemies_killed", 0) +
		"Dmg Dealt     %.0f\n"         % s.get("damage_dealt",   0.0) +
		"Dmg Taken     %.0f\n"         % s.get("damage_taken",   0.0) +
		"Gems          %d"             % s.get("gems_collected", 0)
	)
