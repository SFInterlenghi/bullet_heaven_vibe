extends CanvasLayer

# ─────────────────────────────────────────────────────────────────────────────
# MainMenu — character select screen.
# All UI is built procedurally.
#
# PITFALL #8: Button.text does NOT autowrap — the button grows as wide as its
# longest text line. Use PanelContainer + Labels with autowrap_mode inside a
# fixed-width container instead.  Each card here is a PanelContainer
# (custom_minimum_size.x = 260) so Labels with AUTOWRAP_WORD_SMART wrap
# at that width and expand HEIGHT, not WIDTH.
# ─────────────────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.04, 0.10)
	add_child(bg)

	# CenterContainer fills the screen and auto-centers its child — correct pattern
	# per Pitfall #3 (never use PRESET_CENTER on a size-0 container).
	var outer = CenterContainer.new()
	outer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(outer)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	outer.add_child(vbox)

	# ── Title ─────────────────────────────────────────────────────────────────
	var title = Label.new()
	title.text = "BULLET HEAVEN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	title.modulate = Color(1.0, 0.8, 0.1)
	vbox.add_child(title)

	var subtitle = Label.new()
	subtitle.text = "SELECT YOUR CHARACTER"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 22)
	subtitle.modulate = Color(0.8, 0.8, 0.8)
	vbox.add_child(subtitle)

	# ── Character cards ───────────────────────────────────────────────────────
	var cards_hbox = HBoxContainer.new()
	cards_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cards_hbox.add_theme_constant_override("separation", 20)
	vbox.add_child(cards_hbox)

	for char_id in ["wanderer", "monk", "archer"]:
		cards_hbox.add_child(_make_card(char_id))

func _make_card(char_id: String) -> PanelContainer:
	var cdata = CharacterDB.CHARACTERS[char_id]

	# PanelContainer with a fixed minimum width.
	# Labels inside use autowrap_mode — they contribute 0 to minimum WIDTH
	# and expand HEIGHT instead, keeping the card at exactly 260 px wide.
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(260, 0)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var cv = VBoxContainer.new()
	cv.add_theme_constant_override("separation", 6)
	margin.add_child(cv)

	# ── Name ──────────────────────────────────────────────────────────────────
	var name_lbl = Label.new()
	name_lbl.text = cdata["name"]
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 22)
	cv.add_child(name_lbl)

	cv.add_child(HSeparator.new())

	# ── Description  (autowrap — key to preventing card-width overflow) ────────
	var desc_lbl = Label.new()
	desc_lbl.text = cdata["desc"]
	desc_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_lbl.add_theme_font_size_override("font_size", 14)
	cv.add_child(desc_lbl)

	cv.add_child(HSeparator.new())

	# ── Stats ─────────────────────────────────────────────────────────────────
	for line in [
		"Weapon: " + WeaponDB.WEAPONS[cdata["main_weapon"]]["name"],
		"HP: %.0f   Speed: %.0f" % [cdata["base_health"], cdata["base_speed"]],
	]:
		var lbl = Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 15)
		cv.add_child(lbl)

	cv.add_child(HSeparator.new())

	# ── Passives ──────────────────────────────────────────────────────────────
	var pt = Label.new()
	pt.text = "Passives:"
	pt.add_theme_font_size_override("font_size", 15)
	cv.add_child(pt)

	for i in range(cdata["passives"].size()):
		var pid   = cdata["passives"][i]
		var pname = PassiveDB.PASSIVES[pid]["name"] if PassiveDB.PASSIVES.has(pid) else pid
		var p_lbl = Label.new()
		p_lbl.text                 = ("  • " + pname) + (" ★ Lv.10" if i == 2 else "")
		p_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
		p_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p_lbl.add_theme_font_size_override("font_size", 14)
		if i == 2:
			p_lbl.modulate = Color(0.65, 0.65, 0.65)  # locked — greyed out
		cv.add_child(p_lbl)

	cv.add_child(HSeparator.new())

	# ── Ultimate ──────────────────────────────────────────────────────────────
	var ult_lbl = Label.new()
	ult_lbl.text = "Ult: " + _ultimate_name(cdata["ultimate"]) + " (%.0fs)" % cdata["ultimate_cooldown"]
	ult_lbl.add_theme_font_size_override("font_size", 14)
	cv.add_child(ult_lbl)

	# ── Select button ─────────────────────────────────────────────────────────
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 6)
	cv.add_child(spacer)

	var select_btn = Button.new()
	select_btn.text = "▶  Play"
	select_btn.add_theme_font_size_override("font_size", 18)
	cv.add_child(select_btn)

	select_btn.pressed.connect(func():
		GameManager.selected_character_id = char_id
		GameManager.reset_run_stats()
		get_tree().change_scene_to_file("res://scenes/world/world.tscn")
	)

	# Stagger fade-in per card
	panel.modulate = Color(1, 1, 1, 0)
	panel.scale    = Vector2(0.92, 0.92)
	var delay = ["wanderer", "monk", "archer"].find(char_id) * 0.08
	var tw = create_tween()
	tw.tween_interval(delay)
	tw.tween_property(panel, "modulate", Color.WHITE, 0.18)
	tw.parallel().tween_property(panel, "scale", Vector2.ONE, 0.18)

	return panel

func _ultimate_name(ult_id: String) -> String:
	match ult_id:
		"temporal_shift": return "Temporal Shift"
		"aegis":          return "Aegis"
		"sniper_mode":    return "Sniper Mode"
	return ult_id.capitalize()
