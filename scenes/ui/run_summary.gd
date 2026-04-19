extends CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func populate(stats: Dictionary, cause: String) -> void:
	_build_ui(stats, cause)

func _build_ui(stats: Dictionary, cause: String) -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.05, 0.12, 0.97)
	add_child(bg)

	# CenterContainer keeps the root vbox centered regardless of its size
	var outer = CenterContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 28)
	outer.add_child(vbox)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title = Label.new()
	title.text = "YOU WIN!" if cause == "victory" else "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.modulate = Color(0.4, 1.0, 0.4) if cause == "victory" else Color(1.0, 0.3, 0.3)
	vbox.add_child(title)

	# ── Two-column panel ──────────────────────────────────────────────────────
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(1100, 400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	
	var columns = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 60)
	scroll.add_child(columns)

	columns.add_child(_build_weapon_panel(stats))
	columns.add_child(_build_stats_panel(stats))

	# ── Play Again ────────────────────────────────────────────────────────────
	var btn_wrap = CenterContainer.new()
	btn_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(btn_wrap)

	var btn = Button.new()
	btn.text = "Play Again"
	btn.custom_minimum_size = Vector2(220, 54)
	btn.add_theme_font_size_override("font_size", 28)
	btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
	)
	btn_wrap.add_child(btn)

# ── Weapon damage panel (left column) ────────────────────────────────────────

func _build_weapon_panel(stats: Dictionary) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(440, 0)
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = "WEAPON DAMAGE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var weapon_damage: Dictionary = stats.get("weapon_damage", {})

	if weapon_damage.is_empty():
		var empty = Label.new()
		empty.text = "(no data)"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty)
		return vbox

	# Build list with id included, sort by damage descending
	var entries: Array = []
	for wid in weapon_damage.keys():
		var e = weapon_damage[wid].duplicate()
		e["id"] = wid
		entries.append(e)
	entries.sort_custom(func(a, b): return a["damage"] > b["damage"])

	for entry in entries:
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		vbox.add_child(row)

		row.add_child(_make_weapon_icon(entry["id"], entry["color"]))

		var name_lbl = Label.new()
		name_lbl.text = entry["name"]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(name_lbl)

		var dmg_lbl = Label.new()
		dmg_lbl.text = "%.0f" % entry["damage"]
		dmg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		dmg_lbl.custom_minimum_size = Vector2(110, 0)
		dmg_lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(dmg_lbl)

	vbox.add_child(HSeparator.new())

	# Total row
	var total_row = HBoxContainer.new()
	total_row.add_theme_constant_override("separation", 10)
	vbox.add_child(total_row)

	# Empty space where icon would be
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(44, 0)
	total_row.add_child(spacer)

	var total_key = Label.new()
	total_key.text = "Total"
	total_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	total_key.add_theme_font_size_override("font_size", 22)
	total_row.add_child(total_key)

	var total_val = Label.new()
	total_val.text = "%.0f" % stats.get("damage_dealt", 0.0)
	total_val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	total_val.custom_minimum_size = Vector2(110, 0)
	total_val.add_theme_font_size_override("font_size", 22)
	total_row.add_child(total_val)

	return vbox

# ── Stats panel (right column) ────────────────────────────────────────────────

func _build_stats_panel(stats: Dictionary) -> VBoxContainer:
	var vbox = VBoxContainer.new()
	vbox.custom_minimum_size = Vector2(320, 0)
	vbox.add_theme_constant_override("separation", 8)

	var title = Label.new()
	title.text = "RUN STATS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	vbox.add_child(title)
	vbox.add_child(HSeparator.new())

	var mins = int(stats.get("time_survived", 0.0) / 60.0)
	var secs = int(stats.get("time_survived", 0.0)) % 60

	var pairs: Array = [
		["Time Survived",  "%02d:%02d" % [mins, secs]],
		["Level Reached",  str(stats.get("highest_level",  1))],
		["Enemies Killed", str(stats.get("enemies_killed", 0))],
		["Damage Taken",   "%.0f" % stats.get("damage_taken",   0.0)],
		["Gems Collected", str(stats.get("gems_collected", 0))],
	]

	for pair in pairs:
		var row = HBoxContainer.new()
		vbox.add_child(row)

		var key_lbl = Label.new()
		key_lbl.text = pair[0]
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		key_lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(key_lbl)

		var val_lbl = Label.new()
		val_lbl.text = pair[1]
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.custom_minimum_size = Vector2(100, 0)
		val_lbl.add_theme_font_size_override("font_size", 22)
		row.add_child(val_lbl)

	return vbox

# ── Weapon icon (mini polygon preview) ───────────────────────────────────────

func _make_weapon_icon(weapon_id: String, color: Color) -> Control:
	var icon = Control.new()
	icon.custom_minimum_size = Vector2(40, 40)

	# Pre-compute scaled polygon points so the draw lambda is trivial
	var draw_pts := PackedVector2Array()
	if weapon_id != "" and WeaponDB.WEAPONS.has(weapon_id):
		var shape: PackedVector2Array = WeaponDB.WEAPONS[weapon_id]["shape"]
		if shape.size() >= 3:
			var bmin_x := INF;  var bmin_y := INF
			var bmax_x := -INF; var bmax_y := -INF
			for p in shape:
				bmin_x = min(bmin_x, p.x); bmin_y = min(bmin_y, p.y)
				bmax_x = max(bmax_x, p.x); bmax_y = max(bmax_y, p.y)
			var sc: float = min(34.0 / max(bmax_x - bmin_x, 0.01), 34.0 / max(bmax_y - bmin_y, 0.01))
			var cx: float = (bmin_x + bmax_x) / 2.0
			var cy: float = (bmin_y + bmax_y) / 2.0
			for p in shape:
				draw_pts.append(Vector2((p.x - cx) * sc + 20.0, (p.y - cy) * sc + 20.0))

	# Capture by value so each icon has its own independent draw data
	var pts: PackedVector2Array = draw_pts
	var col: Color = color
	var node: Control = icon   # explicit capture to avoid ambiguity in the lambda

	icon.draw.connect(func():
		if pts.size() >= 3:
			node.draw_polygon(pts, PackedColorArray([col]))
		else:
			node.draw_circle(Vector2(20, 20), 12, col)
	)

	return icon
