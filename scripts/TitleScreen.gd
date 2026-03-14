extends Control

# ── Stars drawn in _draw ──────────────────────────────────────────
const STAR_COUNT := 180
var _stars: Array = []
var _time: float  = 0.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for _i in STAR_COUNT:
		_stars.append({
			"pos": Vector2(rng.randf() * 1280.0, rng.randf() * 720.0),
			"r":   rng.randf_range(0.5, 2.0),
			"b":   rng.randf_range(0.3, 1.0),
			"blink_speed": rng.randf_range(0.3, 1.2),
			"blink_offset": rng.randf() * TAU,
		})
	_build_ui()

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	# Space background
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.014, 0.020, 0.050))

	# Stars with subtle twinkle
	for s in _stars:
		var blink := 0.5 + 0.5 * sin(_time * s["blink_speed"] + s["blink_offset"])
		var b     := s["b"] * (0.7 + 0.3 * blink)
		draw_circle(s["pos"], s["r"], Color(b, b, b * 1.06))

# ── UI ────────────────────────────────────────────────────────────
func _build_ui() -> void:
	var cx := 640.0
	var cy := 360.0

	# ── Title ────────────────────────────────────────────────────
	var title := Label.new()
	title.text = "RIFT RUN"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(cx - 260.0, cy - 180.0)
	title.size     = Vector2(520.0, 100.0)
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.05, 0.85, 1.0))
	add_child(title)

	var sub := Label.new()
	sub.text = "drill the planet  ·  read the market  ·  rule the rift"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(cx - 300.0, cy - 90.0)
	sub.size     = Vector2(600.0, 30.0)
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.38, 0.55, 0.72))
	add_child(sub)

	# ── Buttons ───────────────────────────────────────────────────
	_add_button("NEW GAME",    Vector2(cx - 110.0, cy - 10.0), _on_start)
	_add_button("HOW TO PLAY", Vector2(cx - 110.0, cy + 55.0), _on_how_to_play)

	# ── Version tag ───────────────────────────────────────────────
	var ver := Label.new()
	ver.text     = "5 rounds  ·  limited shots  ·  2 corporations  ·  upgrades between rounds"
	ver.position = Vector2(cx - 300.0, 675.0)
	ver.size     = Vector2(600.0, 20.0)
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ver.add_theme_font_size_override("font_size", 11)
	ver.add_theme_color_override("font_color", Color(0.3, 0.4, 0.5))
	add_child(ver)

func _add_button(text: String, pos: Vector2, callback: Callable) -> void:
	var btn := Button.new()
	btn.text     = text
	btn.position = pos
	btn.size     = Vector2(220.0, 48.0)
	btn.add_theme_font_size_override("font_size", 17)
	btn.pressed.connect(callback)
	add_child(btn)

# ── Button callbacks ─────────────────────────────────────────────
func _on_start() -> void:
	GameManager.reset_for_new_game()
	get_tree().change_scene_to_file("res://scenes/GameWorld.tscn")

func _on_how_to_play() -> void:
	add_child(_build_how_overlay())

func _build_how_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.82)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(bg)

	var panel := PanelContainer.new()
	panel.position = Vector2(315.0, 90.0)
	panel.size     = Vector2(650.0, 530.0)
	overlay.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "HOW TO PLAY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.05, 0.85, 1.0))
	vbox.add_child(title)

	var lines := [
		["Drilling",  "Click anywhere on or near the planet to drill there"],
		["Movement",  "The ship orbits around the planet and rotates to your click angle"],
		["Laser",     "It fires a laser inward — collecting every ore crystal in its path"],
		["Ore types", "Green = common (1 unit)  |  Cyan = uncommon (2)  |  Orange = rare (3)"],
		["Depth",     "By default the laser reaches ~55% of the planet — upgrade Deep Beam for more"],
		["Shots",     "You have a limited number of shots — choose your angles wisely!"],
		["Selling",   "Use the sell buttons at the bottom of the screen to offload your cargo"],
		["Market",    "Prices for each corp change every few seconds — sell to whoever pays more"],
		["Trends",    "▲ = rising    ▼ = falling    wait for the peak before you sell"],
		["Scanner",   "Buy the Surface Scanner upgrade to see faint ore hints on the planet surface"],
		["Goal",      "Maximise credits across 5 rounds — each planet has more and richer ore"],
	]

	for pair in lines:
		var hbox := HBoxContainer.new()
		hbox.add_theme_constant_override("separation", 10)
		vbox.add_child(hbox)

		var key_lbl := Label.new()
		key_lbl.text = pair[0]
		key_lbl.custom_minimum_size = Vector2(90, 0)
		key_lbl.add_theme_font_size_override("font_size", 13)
		key_lbl.add_theme_color_override("font_color", Color(0.2, 0.75, 1.0))
		hbox.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.text = pair[1]
		val_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		val_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", Color(0.80, 0.85, 0.90))
		hbox.add_child(val_lbl)

	var close_btn := Button.new()
	close_btn.text = "GOT IT"
	close_btn.pressed.connect(func(): overlay.queue_free())
	close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	vbox.add_child(close_btn)

	return overlay
