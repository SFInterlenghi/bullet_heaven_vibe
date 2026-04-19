extends CanvasLayer

signal card_selected(option: Dictionary)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func populate(options: Array) -> void:
	# Clear any previous content from a prior level-up in this run
	for child in get_children():
		child.queue_free()

	var overlay = ColorRect.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.72)
	add_child(overlay)

	# CenterContainer fills the screen and auto-centers its child regardless of
	# child size — avoids the PRESET_CENTER pitfall where a size-0 container pins
	# its top-left to the screen center instead of centering the content.
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var title = Label.new()
	title.text = "LEVEL UP — CHOOSE AN UPGRADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	vbox.add_child(title)

	var hbox = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 14)
	vbox.add_child(hbox)

	for i in range(options.size()):
		hbox.add_child(_make_card(options[i], i * 0.07))

# ── Card builder ─────────────────────────────────────────────────────────────

func _make_card(opt: Dictionary, tween_delay: float) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(240, 300)
	btn.add_theme_font_size_override("font_size", 18)
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.modulate = Color(1, 1, 1, 0)  # invisible at spawn
	btn.scale    = Vector2(0.85, 0.85)

	var tween_target_color = Color.WHITE

	if opt["type"] == "weapon":
		var is_new  = opt["level"] == 1
		var header  = ("✦ NEW  " if is_new else "↑ LV.UP  ") + opt["data"]["name"]
		var lv_line = "→ Level %d" % opt["level"]
		btn.text = header + "\n" + lv_line + "\n\n" + _describe_upgrade(opt["id"], opt["level"])

	elif opt["type"] == "ascend":
		# Ascension card — gold tint, prominent branding
		var asc_data = opt["data"]
		btn.text = (
			"✦ ASCEND ✦\n"
			+ asc_data["name"] + "\n\n"
			+ "Transforms your maxed weapon\ninto its ultimate form.\n\n"
			+ "Resets to Lv.1 — already\nsuperior to base max level.\nMax Level: 12"
		)
		tween_target_color = Color(1.0, 0.85, 0.1, 1.0)  # gold

	elif opt["type"] == "fusion":
		var fusion_data = opt["data"]
		btn.text = (
			"✮ MYTHIC FUSION ✮\n"
			+ fusion_data["name"] + "\n\n"
			+ "Consumes your two maxed\ncomponents to forge a\nlegendary artifact.\n\n"
			+ "Supersedes any base weapon.\nMax Level: 12"
		)
		tween_target_color = Color(0.1, 1.0, 0.85, 1.0)  # cyan

	elif opt["type"] == "passive":
		var p_data = opt["data"]
		btn.text = (
			"⊕ NEW PASSIVE ⊕\n"
			+ p_data["name"] + "\n\n"
			+ p_data["desc"]
		)
		tween_target_color = Color(0.5, 1.0, 0.3, 1.0) # light green

	else:  # stat
		btn.text = "STAT UP\n\n" + opt["stat_name"]

	btn.pressed.connect(func(): card_selected.emit(opt))

	# Reveal tween: staggered fade-in + scale-up
	var tw = create_tween()
	tw.tween_interval(tween_delay)
	tw.tween_property(btn, "modulate", tween_target_color, 0.15)
	tw.parallel().tween_property(btn, "scale", Vector2.ONE, 0.15)

	return btn

# ── Upgrade description helper ────────────────────────────────────────────────

func _describe_upgrade(weapon_id: String, level: int) -> String:
	var up = WeaponDB.get_upgrade_data(weapon_id, level)
	var lines: Array = []

	lines.append("DMG  ×%.1f" % up.get("damage_mult", 1.0))
	lines.append("Rate ×%.1f" % (1.0 / up.get("cd_mult", 1.0)))

	if up.has("count") and up["count"] > 1:
		lines.append("%d projectiles" % up["count"])
	if up.has("max_pierce") and up["max_pierce"] > 1:
		lines.append("Pierce %d" % up["max_pierce"])
	if up.has("burst_count"):
		lines.append("Burst ×%d" % up["burst_count"])
	if up.has("max_bounces") and up["max_bounces"] > 0:
		var b = up["max_bounces"]
		lines.append("%s bounces" % ("∞" if b >= 99 else str(b)))
	if up.has("spin_radius"):
		lines.append("Orbit r=%.0f" % up["spin_radius"])
	if up.has("travel_dist"):
		lines.append("Range %.0f" % up["travel_dist"])
	if up.has("duration") and up["duration"] > 0.15:
		lines.append("%.1fs zone" % up["duration"])
	if up.has("chasing") and up["chasing"]:
		lines.append("★ Chasing")
	if up.has("tracking") and up["tracking"]:
		lines.append("★ Tracking")

	var max_lv = WeaponDB.WEAPONS[weapon_id].get("max_level", 12)
	if level >= max_lv:
		var asc_id = WeaponDB.WEAPONS[weapon_id].get("ascended_id", "")
		if asc_id != "" and WeaponDB.WEAPONS.has(asc_id):
			lines.append("✦ MAX — Ascend → " + WeaponDB.WEAPONS[asc_id]["name"])
		else:
			lines.append("✦ MAX LEVEL")

	return "\n".join(lines)
