extends Control

var _credit_lbl: Label
var _card_data: Dictionary = {}  # key -> { cost_lbl, level_lbl, buy_btn }

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.014, 0.024, 0.055)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Thin accent line at top
	var line := ColorRect.new()
	line.color    = Color(0.0, 0.52, 1.0, 0.7)
	line.size     = Vector2(1280, 3)
	line.position = Vector2(0, 58)
	add_child(line)

	# Header
	var header_lbl := Label.new()
	header_lbl.text = "— UPGRADE SHOP —"
	header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_lbl.position = Vector2(0, 10)
	header_lbl.size     = Vector2(1280, 40)
	header_lbl.add_theme_font_size_override("font_size", 30)
	header_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.1))
	add_child(header_lbl)

	# Credits display
	_credit_lbl = Label.new()
	_credit_lbl.text = "Credits available: " + str(GameManager.credits)
	_credit_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_credit_lbl.position = Vector2(0, 66)
	_credit_lbl.size     = Vector2(1280, 30)
	_credit_lbl.add_theme_font_size_override("font_size", 20)
	_credit_lbl.add_theme_color_override("font_color", Color(0.15, 1.0, 0.48))
	add_child(_credit_lbl)

	# Round blurb
	var prev_round := GameManager.round_num - 1
	var next_round := GameManager.round_num
	var blurb := Label.new()
	blurb.text = "Round %d complete — preparing Round %d of %d" % [prev_round, next_round, GameManager.MAX_ROUNDS]
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.position = Vector2(0, 96)
	blurb.size     = Vector2(1280, 24)
	blurb.add_theme_font_size_override("font_size", 13)
	blurb.add_theme_color_override("font_color", Color(0.45, 0.55, 0.65))
	add_child(blurb)

	# Upgrade cards
	var keys   := GameManager.upgrades.keys()
	var cols   := 3
	var card_w := 270.0
	var card_h := 185.0
	var gap_x  := 24.0
	var gap_y  := 18.0
	var rows   := int(ceil(float(keys.size()) / float(cols)))
	var grid_w := cols * card_w + (cols - 1) * gap_x
	var start_x := (1280.0 - grid_w) * 0.5
	var start_y := 128.0

	for i in keys.size():
		var key := keys[i]
		var col := i % cols
		var row := i / cols
		var pos := Vector2(start_x + col * (card_w + gap_x), start_y + row * (card_h + gap_y))
		_build_card(key, pos, Vector2(card_w, card_h))

	# Continue button
	var total_h := start_y + rows * (card_h + gap_y)
	var btn_y   := max(total_h + 14.0, 580.0)
	var btn := Button.new()
	btn.text     = "NEXT ROUND  ▶"
	btn.position = Vector2(530, btn_y)
	btn.size     = Vector2(220, 50)
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(_on_next_round)
	add_child(btn)

func _build_card(key: String, pos: Vector2, sz: Vector2) -> void:
	var u: Dictionary = GameManager.upgrades[key]

	# Card background
	var card_bg := ColorRect.new()
	card_bg.color    = Color(0.05, 0.09, 0.18, 0.9)
	card_bg.position = pos
	card_bg.size     = sz
	add_child(card_bg)

	# Border line (drawn via separate rects on edges — quick approach)
	var border := ColorRect.new()
	border.color    = Color(0.1, 0.22, 0.42)
	border.position = pos
	border.size     = sz
	# We'll draw it as a thin outline by layering below card_bg... simpler: just set border color on panel.
	# For simplicity, overlap a 2px border rect behind.
	add_child(border)
	border.z_index = card_bg.z_index - 1

	# Padding container
	var pad := 12.0
	var inner_pos := pos + Vector2(pad, pad)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = u["name"].to_upper()
	name_lbl.position = inner_pos
	name_lbl.size     = Vector2(sz.x - pad * 2, 24)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", Color(0.25, 0.80, 1.0))
	add_child(name_lbl)

	# Description
	var desc_lbl := Label.new()
	desc_lbl.text = u["desc"]
	desc_lbl.position = inner_pos + Vector2(0, 26)
	desc_lbl.size     = Vector2(sz.x - pad * 2, 44)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.60, 0.68, 0.78))
	add_child(desc_lbl)

	# Level dots
	var level_lbl := Label.new()
	level_lbl.position = inner_pos + Vector2(0, 74)
	level_lbl.size     = Vector2(sz.x - pad * 2, 22)
	level_lbl.add_theme_font_size_override("font_size", 16)
	add_child(level_lbl)

	# Cost / maxed label
	var cost_lbl := Label.new()
	cost_lbl.position = inner_pos + Vector2(0, 98)
	cost_lbl.size     = Vector2(sz.x - pad * 2, 22)
	cost_lbl.add_theme_font_size_override("font_size", 14)
	add_child(cost_lbl)

	# Buy button
	var buy_btn := Button.new()
	buy_btn.position = inner_pos + Vector2(0, 125)
	buy_btn.size     = Vector2(sz.x - pad * 2, 36)
	buy_btn.add_theme_font_size_override("font_size", 14)
	buy_btn.pressed.connect(_on_buy.bind(key))
	add_child(buy_btn)

	_card_data[key] = {
		"level_lbl": level_lbl,
		"cost_lbl":  cost_lbl,
		"buy_btn":   buy_btn,
	}
	_refresh_card(key)

func _refresh_card(key: String) -> void:
	var u: Dictionary    = GameManager.upgrades[key]
	var data: Dictionary = _card_data[key]

	# Level dots
	var dots := ""
	for i in u["max_level"]:
		dots += "●" if i < u["level"] else "○"
	data["level_lbl"].text = "Level: " + dots

	if u["level"] >= u["max_level"]:
		data["level_lbl"].add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		data["cost_lbl"].text = "MAXED OUT"
		data["cost_lbl"].add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
		data["buy_btn"].text     = "MAXED"
		data["buy_btn"].disabled = true
	else:
		data["level_lbl"].add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
		var cost := GameManager.get_upgrade_cost(key)
		data["cost_lbl"].text = "Cost: " + str(cost) + " credits"
		var can_afford := GameManager.can_afford_upgrade(key)
		data["cost_lbl"].add_theme_color_override("font_color",
			Color(1.0, 0.70, 0.15) if can_afford else Color(0.7, 0.35, 0.35))
		data["buy_btn"].text     = "BUY UPGRADE"
		data["buy_btn"].disabled = not can_afford

func _on_buy(key: String) -> void:
	if GameManager.buy_upgrade(key):
		_credit_lbl.text = "Credits available: " + str(GameManager.credits)
		# Refresh all cards (affordability may have changed)
		for k in _card_data:
			_refresh_card(k)

func _on_next_round() -> void:
	get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")
